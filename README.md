# Homelab

A fully automated, HA Kubernetes homelab on a single Ubuntu Server 22.04 physical host.

**Stack:** Incus · Talos OS (Flannel CNI) · OpenTofu (modular) · Ansible · MinIO (.deb package)

## Architecture

```
Physical Host (Ubuntu 22.04 — 32 GB RAM, 8 cores)
│
├── enp0s31f6 ──► br0 (Linux bridge, gets IP from home router via DHCP)
├── MinIO (systemd :9000)  → OpenTofu S3 remote state backend
│
└── Incus (ZFS loop-backed storage pool)
    ├── talos-cp-1      2 vCPU  4 GB  40 GB  ─┐
    ├── talos-cp-2      2 vCPU  4 GB  40 GB   ├─ Control Plane  VIP: 192.168.18.200
    ├── talos-cp-3      2 vCPU  4 GB  40 GB  ─┘
    ├── talos-worker-1  4 vCPU  6 GB  60 GB  ─┐
    ├── talos-worker-2  4 vCPU  6 GB  60 GB   ├─ Workers
    └── talos-worker-3  4 vCPU  6 GB  60 GB  ─┘
```

All VMs get IPs via DHCP from your home router. `qemu-guest-agent` reports IPs back to Incus so OpenTofu discovers them dynamically — no router access or static MAC configuration needed.
Control planes share a **Layer 2 VIP** (`192.168.18.200`) for high availability — no external load balancer needed.
**Flannel** is used as the default built-in CNI for simplicity. App deployments and Helm charts are managed via GitOps (ArgoCD/Flux) after cluster setup.

## Tool Stack

| Layer | Tool | Purpose |
|---|---|---|
| Host OS | Ubuntu Server 22.04 | Bare-metal operating system |
| Virtualization | [Incus](https://linuxcontainers.org/incus/) | Type-1 VM hypervisor |
| Storage | ZFS (loop-backed) | VM disk pool |
| Networking | Linux bridge (`br0`) + Netplan | Flat L2 access to home LAN |
| CNI | Flannel | Built-in default Talos OS CNI |
| State backend | [MinIO](https://min.io/) | Self-hosted S3 for OpenTofu remote state (installed via official .deb package) |
| Host config | [Ansible](https://www.ansible.com/) | Idempotent host provisioning |
| IaC | [OpenTofu](https://opentofu.org/) | VM and cluster provisioning (modular design) |
| Kubernetes OS | [Talos Linux](https://www.talos.dev/) | Immutable, API-driven Kubernetes OS |
| Talos images | [factory.talos.dev](https://factory.talos.dev) | Custom Talos image with `siderolabs/qemu-guest-agent` extension |

## Prerequisites

**Control machine** (your laptop/workstation):
- `ansible` ≥ 2.15 + `community.crypto` collection (`ansible-galaxy collection install community.crypto`)
- `opentofu` ≥ 1.2
- `incus` client
- `talosctl`, `kubectl`
- `make`

**Physical host**: SSH access with sudo, Ubuntu Server 22.04.

## Quick Start

### 1. Configure inventory

```bash
cp ansible/inventory/inventory.ini.example ansible/inventory/inventory.ini
# Edit: set your server IP/hostname under [metal]
```

### 2. Create Ansible Vault (MinIO credentials)

```bash
make vault-create
# Paste:
#   minio_root_user: "minioadmin"
#   minio_root_password: "your-strong-password"
export MINIO_PASS=your-strong-password
```

### 3. Copy variable file & generate Talos schematic ID

```bash
cp opentofu/terraform.tfvars.example opentofu/terraform.tfvars
make schematic
# Visit factory.talos.dev, select siderolabs/qemu-guest-agent extension,
# click Generate, and paste schematic ID into opentofu/terraform.tfvars
```

### 4. Run Ansible — configure the host

```bash
make setup
```

This installs MinIO (.deb package), enables its systemd service (auto-starts on boot), creates the `tfstate` bucket, installs Incus, configures the `br0` bridge, and initializes the ZFS storage pool.

### 5. Provision VMs and bootstrap Kubernetes

```bash
make init
make apply
```

This imports the Talos factory image into Incus, creates 6 VMs, applies machine configs, and bootstraps the HA cluster.

### 6. Verify the cluster

```bash
make kubeconfig
export KUBECONFIG=~/.kube/homelab.yaml
kubectl get nodes -o wide
curl -k https://192.168.18.200:6443/version
```

## Project Structure

```
homelab/
├── Makefile                        # Workflow automation
├── ansible/
│   ├── setup.yaml                  # Main playbook (MinIO + Incus)
│   ├── ansible.cfg
│   ├── inventory/
│   │   └── inventory.ini           # Target host — gitignored, copy from .example
│   ├── group_vars/all/
│   │   └── vault.yaml              # MinIO credentials (Ansible Vault encrypted)
│   └── roles/
│       ├── minio/                  # Installs MinIO via official .deb package
│       │   ├── defaults/main.yaml
│       │   ├── handlers/main.yaml
│       │   ├── tasks/main.yaml
│       │   └── templates/
│       │       ├── minio.env.j2
│       │       └── minio.service.j2
│       └── incus/                  # Installs and configures Incus
│           ├── defaults/main.yaml
│           ├── handlers/main.yaml
│           ├── tasks/
│           │   ├── main.yaml
│           │   ├── repo_deb.yaml
│           │   ├── install.yaml
│           │   ├── bridge.yaml     # Configures br0 via netplan
│           │   ├── init.yaml
│           │   └── client.yaml
│           └── templates/
│               ├── incus.sources.j2
│               ├── preseed.yaml.j2
│               └── bridge.yaml.j2
└── opentofu/
    ├── main.tf                     # Root: backend, providers, calls modules
    ├── variables.tf                # Root inputs
    ├── outputs.tf                  # Root outputs
    ├── terraform.tfvars.example    # Variable template — copy to terraform.tfvars
    └── modules/
        ├── incus/                  # Incus VM provisioning & factory image import
        │   ├── main.tf
        │   ├── variables.tf
        │   └── outputs.tf
        └── talos/                  # Talos machine configs, bootstrap, credentials
            ├── main.tf
            ├── variables.tf
            └── outputs.tf
```

## Sensitive Files (gitignored)

| File | Contents |
|---|---|
| `opentofu/kubeconfig.yaml` | Kubernetes admin credentials |
| `opentofu/talosconfig.yaml` | `talosctl` admin credentials |
| `opentofu/terraform.tfvars` | Your variable values (including schematic ID) |
| `opentofu/.terraform/` | Provider cache |
| `ansible/inventory/inventory.ini` | Server IP address |
| `ansible/group_vars/all/vault.yaml` | MinIO credentials (encrypted) |
