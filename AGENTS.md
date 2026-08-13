# AGENTS.md — Repository Guide for AI Agents

This document is the authoritative guide for AI coding agents and automated tools operating on this codebase. It documents the homelab architecture, technology stack, directory layout, core design decisions, operational constraints, and verification protocols.

---

## 1. System Architecture Overview

This project provisions a production-grade, highly available Kubernetes homelab on a single physical host running **Ubuntu Server 22.04**.

```
Physical Host (Ubuntu 22.04 — 32 GB RAM, 8 vCPUs, Static IP: 192.168.18.100/24)
│
├── enp0s31f6 ──► br0 (Linux bridge via Netplan — static host IP 192.168.18.100/24)
├── MinIO (systemd service via .deb package on :9000) → S3 remote state for OpenTofu
│
└── Incus (ZFS loop-backed storage pool)
    ├── talos-cp-1      2 vCPU  4 GB RAM  40 GB Disk  ─┐
    ├── talos-cp-2      2 vCPU  4 GB RAM  40 GB Disk   ├─ Control Plane  (Layer 2 VIP: 192.168.18.200)
    ├── talos-cp-3      2 vCPU  4 GB RAM  40 GB Disk  ─┘
    ├── talos-worker-1  4 vCPU  6 GB RAM  60 GB Disk  ─┐
    ├── talos-worker-2  4 vCPU  6 GB RAM  60 GB Disk   ├─ Workers
    └── talos-worker-3  4 vCPU  6 GB RAM  60 GB Disk  ─┘
```

### Key Capabilities & Components
- **Host Management**: Ansible configures the bare-metal OS, installs MinIO as a systemd service, sets up Incus with a ZFS storage pool, and creates the host `br0` bridge.
- **VM Provisioning**: OpenTofu provisions 6 virtual machines (3 Control Planes, 3 Workers) on Incus.
- **OS & Cluster Bootstrap**: Talos Linux (immutable, API-driven Kubernetes OS).
- **CNI**: Flannel (built-in default CNI in Talos; requires zero extra configuration).
- **High Availability**: Layer 2 Virtual IP (`192.168.18.200`) shared across control plane nodes via gratuitous ARP for HA Kubernetes API access.
- **Dynamic IP Discovery**: Talos VMs run a custom image with `siderolabs/qemu-guest-agent` built via [factory.talos.dev](https://factory.talos.dev), allowing Incus to report VM IPs to OpenTofu dynamically. No router access or static MAC/DHCP reservations required.

---

## 2. Directory Layout & Module Structure

```
homelab/
├── AGENTS.md                       # This document (AI Agent guide)
├── Makefile                        # Workflow automation targets
├── README.md                       # Human-facing documentation
├── .gitignore                      # Git exclusion rules
├── ansible/
│   ├── setup.yaml                  # Main Ansible playbook
│   ├── ansible.cfg                 # Ansible configuration
│   ├── inventory/
│   │   ├── inventory.ini.example   # Example inventory template
│   │   └── inventory.ini           # Local target host inventory (gitignored)
│   ├── group_vars/all/
│   │   └── vault.yaml              # Ansible Vault encrypted MinIO secrets (gitignored)
│   └── roles/
│       ├── minio/                  # Installs MinIO server via official .deb package
│       │   ├── defaults/main.yaml  # Pinned version RELEASE.2024-11-07T00-52-20Z
│       │   ├── handlers/main.yaml
│       │   ├── tasks/main.yaml
│       │   └── templates/          # minio.env.j2, minio.service.j2
│       └── incus/                  # Installs Incus, configures br0 & ZFS pool
│           ├── defaults/main.yaml  # Bridge IP (192.168.18.100), gateway, DNS defaults
│           ├── handlers/main.yaml
│           ├── tasks/
│           │   ├── main.yaml
│           │   ├── repo_deb.yaml
│           │   ├── install.yaml
│           │   ├── bridge.yaml     # Disables cloud-init, removes 50-cloud-init.yaml, deploys br0
│           │   ├── init.yaml
│           │   └── client.yaml
│           └── templates/          # incus.sources.j2, preseed.yaml.j2, bridge.yaml.j2
└── opentofu/
    ├── main.tf                     # Root module: S3 backend, providers, module invocations
    ├── variables.tf                # Root input variables
    ├── outputs.tf                  # Root outputs (delegates to child modules)
    ├── terraform.tfvars.example    # Variable inputs template
    ├── terraform.tfvars            # Local variable inputs (gitignored)
    └── modules/
        ├── incus/                  # Incus VM provisioning & factory image import
        │   ├── main.tf
        │   ├── variables.tf
        │   └── outputs.tf           # Exports cp_ips and worker_ips via guest agent
        └── talos/                  # Talos configs, machine apply, etcd bootstrap, credentials
            ├── main.tf
            ├── variables.tf
            └── outputs.tf           # Exports kubeconfig_raw, talosconfig, cluster_endpoint
```

---

## 3. Core Design Principles & Architectural Guardrails

When modifying this codebase, AI agents **must strictly adhere** to the following guardrails:

### Guardrail 1 — No Router Access Assumptions
- **Do not** reintroduce static MAC addresses, router-side DHCP reservations, or fixed VM IPs in OpenTofu.
- All VM IP discovery must rely on `incus_instance.ipv4_address` enabled by the `siderolabs/qemu-guest-agent` extension in the custom Talos factory image (`talos_schematic_id`).

### Guardrail 2 — Strict Scope Boundary for OpenTofu
- OpenTofu's responsibility **ends** at provisioning VMs, applying Talos machine configs, bootstrapping etcd, and outputting `kubeconfig.yaml` / `talosconfig.yaml`.
- **Do not** add Helm resources, Kubernetes manifests, ingress controllers, or application charts to OpenTofu.
- Workload and application management is strictly delegated to a post-bootstrap GitOps engine (e.g., ArgoCD or Flux).

### Guardrail 3 — Use Default Flannel CNI
- Flannel is the default CNI provided by Talos Linux. It requires zero custom patches or Helm charts.
- **Do not** add patches disabling Flannel or kube-proxy in `modules/talos/main.tf` unless explicitly instructed.

### Guardrail 4 — MinIO via `.deb` Package with Pinned Version
- MinIO is installed on the physical host via the official `.deb` package (`ansible.builtin.apt` with `deb:`) as a systemd service (`enabled: true`).
- Always keep `minio_version` pinned in `ansible/roles/minio/defaults/main.yaml` so upgrades are deliberate and never happen unexpectedly during routine Ansible runs.

### Guardrail 5 — Host Bridge Isolation from Cloud-Init
- Host network bridge (`br0`) uses static IP `192.168.18.100/24`.
- The Ansible bridge task explicitly disables cloud-init network management (`/etc/cloud/cloud.cfg.d/99-disable-network-config.cfg`) and deletes `/etc/netplan/50-cloud-init.yaml`.
- **Do not** remove these cloud-init isolation steps, as cloud-init would otherwise overwrite `/etc/netplan/` on host reboot and break bridge networking.

### Guardrail 6 — Modular OpenTofu Design
- Keep child modules (`modules/incus/` and `modules/talos/`) clean, encapsulated, and decoupled.
- Communication between modules must pass strictly through root module outputs and inputs in `opentofu/main.tf`.

---

## 4. Verification & Testing Commands

Before submitting any code modifications, AI agents **must** run the following verification steps:

```bash
# 1. Check Ansible playbook syntax
cd ansible && ansible-playbook --syntax-check setup.yaml

# 2. Check OpenTofu code formatting across all modules
cd opentofu && tofu fmt -check -recursive

# 3. Validate OpenTofu modules and root configuration
cd opentofu && tofu init -backend=false && tofu validate
```

All three commands **must pass cleanly** (`exit 0`).

---

## 5. Security & Git Hygiene

- **Sensitive Files**: Never commit secrets, credentials, state files, or private tokens. The following patterns are strictly gitignored:
  - `opentofu/terraform.tfvars`
  - `opentofu/kubeconfig.yaml`
  - `opentofu/talosconfig.yaml`
  - `opentofu/.terraform/`
  - `ansible/inventory/inventory.ini`
  - `ansible/group_vars/all/vault.yaml`
- **Ansible Vault**: Sensitive Ansible variables (such as `minio_root_password`) must be encrypted via `ansible-vault` in `ansible/group_vars/all/vault.yaml`.
- **Example Templates**: When adding new configurable variables, always update `terraform.tfvars.example` or `inventory.ini.example` accordingly.
