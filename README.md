# Homelab — Baremetal Talos Linux with talhelper & Flux CD

A production-grade, declarative, single-node baremetal Kubernetes homelab on a **Dell Optiplex 7050** physical host.

**Stack:** Talos Linux · `talhelper` · SOPS + `age` · Flannel CNI · Flux CD (GitOps) · Longhorn Storage · Tailscale Operator

---

## Architecture

```
Dell Optiplex 7050 (Baremetal Talos Linux — 32 GB RAM, 8 vCPUs)
│
├── Hardware Extensions (Talos Image Factory via talhelper)
│   ├── siderolabs/intel-ucode      (Intel 6th/7th Gen CPU stability)
│   ├── siderolabs/i915-ucode       (Intel HD 530/630 QuickSync for Plex)
│   ├── siderolabs/iscsi-tools      (Longhorn CSI support)
│   └── siderolabs/util-linux-tools (fstrim for SSDs + filesystem tools)
│
├── Network & OS Layer
│   ├── Static IP: 192.168.18.100/24 (enp0s31f6, Gateway: 192.168.18.1)
│   ├── Hostname: homelab
│   └── Flannel CNI (built-in default)
│
├── Automation & Secrets
│   ├── talhelper                   (talos/talconfig.yaml)
│   └── SOPS + age                  (talos/talsecret.sops.yaml)
│
└── GitOps & Core Workloads
    ├── Flux CD                     (Automated reconciliation from kubernetes/apps/)
    ├── Longhorn Storage Engine     (Single-node: defaultReplicaCount=1)
    └── Tailscale Operator          (Remote access via private HTTPS MagicDNS)
```

---

## Prerequisites

On your **development machine**:
- `talosctl` (e.g. `curl -sL https://talos.dev/install | sh`)
- `talhelper` (e.g. `brew install budimanjojo/tap/talhelper` or `go install github.com/budimanjojo/talhelper@latest`)
- `sops` (e.g. `brew install sops`)
- `age` (e.g. `brew install age`)
- `flux` (e.g. `brew install fluxcd/tap/flux`)
- `kubectl`

---

## Quick Start & Deployment Workflow

### 1. Initialize Age Encryption Key

```bash
make age-key
```
This generates `~/.config/sops/age/keys.txt` (if not already present) and displays your public key. Paste your public key into `.sops.yaml`.

---

### 2. Generate Cluster Secrets & Machine Configurations

```bash
# 1. Generate & encrypt cluster secrets
make secrets

# 2. Generate machine configs (talos/clusterconfig/)
make generate
```

---

### 3. Flash Talos ISO to USB & Boot Server

1. Download the baremetal Talos ISO from [factory.talos.dev](https://factory.talos.dev) or use your schematic URL from `talos/talconfig.yaml`.
2. Flash to USB:
   ```bash
   sudo dd if=metal-amd64.iso of=/dev/sdX bs=4M status=progress && sync
   ```
3. Boot the Dell Optiplex 7050 from the USB into **maintenance mode**.

---

### 4. Install Talos & Bootstrap Kubernetes

From your development machine:
```bash
# Push machine configuration (formats disk & installs Talos):
make apply

# After the server reboots into Talos, bootstrap etcd:
make bootstrap

# Fetch administrative kubeconfig:
make kubeconfig
```

---

### 5. Bootstrap Flux CD, Longhorn & Tailscale Operator

```bash
export KUBECONFIG=~/.kube/homelab.yaml
kubectl get nodes -o wide

# Bootstrap Flux CD GitOps engine:
make flux-init
```

Flux will automatically connect to this GitHub repository and reconcile all manifests in `kubernetes/apps/`, deploying:
- **Longhorn Storage**: Single-node persistent volume storage (`defaultReplicaCount: 1`).
- **Tailscale Operator**: Deployed in `network` namespace.

---

### 6. Connect Tailscale for Remote Access (Optional)

1. Create a Tailscale OAuth Client at [login.tailscale.com/admin/settings/oauth](https://login.tailscale.com/admin/settings/oauth) with scope: `Devices (Read & Write)`.
2. Create the OAuth secret in Kubernetes:
   ```bash
   kubectl create secret generic operator-oauth -n network \
     --from-literal=client_id="<YOUR_CLIENT_ID>" \
     --from-literal=client_secret="<YOUR_CLIENT_SECRET>"
   ```
3. To expose any service with an automatic private HTTPS domain (e.g. Longhorn UI or Home Assistant), simply annotate its Service:
   ```yaml
   metadata:
     annotations:
       tailscale.com/expose: "true"
       tailscale.com/hostname: "longhorn"
   ```

---

## Repository Structure

```
homelab/
├── AGENTS.md                          # AI agent architectural guide
├── Makefile                           # Workflow targets (secrets, generate, apply, bootstrap, etc.)
├── README.md                          # Documentation
├── .sops.yaml                         # SOPS encryption rules
├── .gitignore                         # Secret & generated cache exclusions
│
├── talos/
│   ├── talconfig.yaml                 # Single declarative source of truth
│   └── talsecret.sops.yaml            # SOPS-encrypted cluster PKI
│
└── kubernetes/                        # Flux CD GitOps tree
    ├── flux-system/                   # Flux synchronization manifests
    └── apps/
        ├── kustomization.yaml         # App aggregator
        ├── storage/
        │   └── longhorn/              # Longhorn Storage (single-node replica=1)
        └── network/
            └── tailscale/             # Tailscale Operator (remote access)
```

---

## Operational Commands

| Command | Description |
|---|---|
| `make age-key` | Display or create local `age` encryption key |
| `make secrets` | Generate & encrypt Talos PKI secrets |
| `make generate` | Render machine configs via `talhelper` |
| `make apply` | Apply machine config to node over LAN |
| `make bootstrap` | Bootstrap single-node etcd cluster |
| `make kubeconfig` | Fetch admin credentials to `~/.kube/homelab.yaml` |
| `make flux-init` | Bootstrap Flux CD GitOps engine into cluster |
| `make reset` | Factory reset the physical server |
