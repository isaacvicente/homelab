# AGENTS.md — Repository Guide for AI Agents

This document is the authoritative guide for AI coding agents and automated tools operating on this codebase. It documents the single-node baremetal Talos Linux homelab architecture, directory layout, core design decisions, operational constraints, and verification protocols.

---

## 1. System Architecture Overview

This project configures a single-node baremetal Kubernetes homelab on a physical host running **Talos Linux**.

```
Physical Host (Baremetal Talos Linux — 32 GB RAM, 8 vCPUs, Static IP: 192.168.18.100/24)
│
├── NIC (enp0s31f6 — static IP: 192.168.18.100/24, gateway: 192.168.18.1)
├── Disk (/dev/sda or /dev/nvme0n1)
│
└── Kubernetes (Single-Node: Controlplane + Worker roles)
    ├── allowSchedulingOnControlPlanes: true
    ├── Default Flannel CNI
    └── Kube API Endpoint: https://192.168.18.100:6443
```

### Key Capabilities & Components
- **OS & Cluster Bootstrap**: Talos Linux (immutable, API-driven, security-focused Kubernetes OS).
- **Tooling**: Pure `talosctl` workflow orchestrated via `Makefile` — no Ansible, no Incus, no OpenTofu.
- **Single-Node Scheduling**: Configured with `allowSchedulingOnControlPlanes: true` so application pods (Home Assistant, Plex, local storage) run seamlessly on the single physical node.
- **CNI**: Flannel (built-in default CNI in Talos; requires zero extra configuration).

---

## 2. Directory Layout

```
homelab/
├── AGENTS.md                 # This document (AI Agent guide)
├── Makefile                  # talosctl workflow automation targets
├── README.md                 # Human-facing documentation
├── .gitignore                # Git exclusion rules (secrets, configs, kubeconfigs)
└── talos/
    ├── patches/
    │   ├── controlplane.yaml # Static IP, allow-scheduling, hostname, DNS
    │   └── install.yaml      # Target disk (/dev/sda) & wipe settings
    ├── secrets.yaml          # Gitignored — generated cluster PKI & secrets
    ├── controlplane.yaml     # Gitignored — generated machine configuration
    └── talosconfig           # Gitignored — client config for talosctl
```

---

## 3. Core Design Principles & Architectural Guardrails

When modifying this codebase, AI agents **must strictly adhere** to the following guardrails:

### Guardrail 1 — Baremetal Direct (No Hypervisors or Host VMs)
- Talos Linux runs directly on the baremetal hardware as the host OS.
- **Do not** introduce hypervisors, Incus, Proxmox, or Docker/VM layers to run Talos.

### Guardrail 2 — Config Patches Only (Do Not Commit Generated Configs)
- All cluster customizations must live in `talos/patches/*.yaml`.
- Generated files (`talos/secrets.yaml`, `talos/controlplane.yaml`, `talos/talosconfig`) contain PKI tokens/keys and are **strictly gitignored**.

### Guardrail 3 — Single-Node Workload Support
- The control plane patch must include `allowSchedulingOnControlPlanes: true` under `cluster:`, as there are no separate worker nodes.

### Guardrail 4 — Use Default Flannel CNI
- Flannel is the default CNI provided by Talos Linux. It requires zero extra patches or Helm charts.

### Guardrail 5 — Separation of Workload Management
- This repository is responsible **strictly** for OS machine configuration, etcd bootstrap, and generating client credentials (`kubeconfig` / `talosconfig`).
- Application workloads, GitOps operators (ArgoCD/Flux), and Helm charts belong in a dedicated Kubernetes manifests repository or post-bootstrap GitOps pipeline.

---

## 4. Verification & Testing Commands

Before submitting any code modifications, AI agents **must** verify:

```bash
# 1. Check YAML syntax of all patch files
python3 -c "import yaml, glob; [yaml.safe_load(open(f)) for f in glob.glob('talos/patches/*.yaml')]"

# 2. Check Makefile targets
make help
```

---

## 5. Security & Git Hygiene

- **Sensitive Files**: Never commit secrets, credentials, or generated machine configs. The following are gitignored:
  - `talos/secrets.yaml`
  - `talos/controlplane.yaml`
  - `talos/worker.yaml`
  - `talos/talosconfig`
  - `*.kubeconfig`
  - `kubeconfig.yaml`
