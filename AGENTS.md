# AGENTS.md — Repository Guide for AI Agents

This document is the authoritative guide for AI coding agents operating on this repository. It defines the single-node baremetal Talos Linux homelab architecture, directory layout, core design decisions, operational constraints, and verification protocols.

---

## 1. System Architecture Overview

This repository configures a single-node baremetal Kubernetes homelab on a physical **Dell Optiplex 7050** host running **Talos Linux** with **Flux CD GitOps** and **Longhorn Storage**.

```
Dell Optiplex 7050 (Baremetal Talos Linux — 32 GB RAM, 8 vCPUs, Static IP: 192.168.18.100/24)
│
├── Hardware Extensions (Talos Image Factory via talhelper)
│   ├── siderolabs/intel-ucode      (Intel 6th/7th Gen CPU stability)
│   ├── siderolabs/i915-ucode       (Intel HD 530/630 QuickSync for Plex)
│   ├── siderolabs/iscsi-tools      (Longhorn CSI prerequisite)
│   └── siderolabs/util-linux-tools (fstrim for SSDs + CSI filesystem tools)
│
├── Automation & Secret Layer
│   ├── talhelper                   (Single declarative talos/talconfig.yaml)
│   └── SOPS + age                  (Encrypted secrets: talos/talsecret.sops.yaml)
│
├── Kubernetes (Single Node: Controlplane + Worker roles)
│   ├── allowSchedulingOnControlPlanes: true
│   ├── Default Flannel CNI
│   └── Kube API Endpoint: https://192.168.18.100:6443
│
└── GitOps & Storage (Flux CD)
    ├── Flux CD Controllers         (Auto-reconciliation from kubernetes/ directory)
    └── Longhorn Storage Engine     (Single-node configured: defaultReplicaCount: 1)
```

---

## 2. Directory Layout

```
homelab/
├── AGENTS.md                          # This document (AI Agent guide)
├── Makefile                           # talhelper & Flux automation targets
├── README.md                          # Human-facing documentation
├── .sops.yaml                         # SOPS encryption rules (age public key)
├── .gitignore                         # Exclusions (unencrypted private keys, clusterconfig)
│
├── talos/                             # Talos OS machine configuration
│   ├── talconfig.yaml                 # Declarative source of truth for Talos
│   └── talsecret.sops.yaml            # SOPS-encrypted cluster PKI & secrets (safe in Git)
│
└── kubernetes/                        # Flux CD GitOps tree
    ├── flux-system/
    │   ├── gotk-sync.yaml             # Flux sync definition
    │   └── kustomization.yaml
    └── apps/
        ├── kustomization.yaml         # App aggregator
        └── storage/
            ├── kustomization.yaml
            └── longhorn/
                ├── namespace.yaml
                ├── helmrepository.yaml
                ├── helmrelease.yaml   # Single-node replica=1 settings
                └── kustomization.yaml
```

---

## 3. Core Design Principles & Architectural Guardrails

When modifying this codebase, AI agents **must strictly adhere** to the following guardrails:

### Guardrail 1 — Baremetal Direct (No Hypervisors or VMs)
- Talos Linux runs directly on the baremetal hardware as the host OS.
- **Do not** introduce hypervisors, Incus, Proxmox, OpenTofu, or Docker/VM layers to run Talos.

### Guardrail 2 — Declarative talhelper Configuration Only
- All Talos node definitions, hardware extensions, disk install targets, and network interfaces must be maintained in `talos/talconfig.yaml`.
- Generated files in `talos/clusterconfig/` contain machine configurations and talosconfigs; they are **strictly gitignored**.

### Guardrail 3 — Secrets via SOPS + age
- Cluster PKI secrets must live in `talos/talsecret.sops.yaml` encrypted with SOPS and `age`.
- Never commit unencrypted private age keys (`keys.txt`), raw certificates, or plaintext cluster secrets.

### Guardrail 4 — Single-Node Scheduling & Longhorn Constraints
- The control plane configuration must include `allowSchedulingOnControlPlanes: true`.
- Longhorn must be configured with `defaultSettings.defaultReplicaCount: 1` since only one physical node exists.

### Guardrail 5 — Built-in Flannel CNI
- Flannel is the default CNI provided by Talos Linux. It requires zero extra patches or Helm charts.

### Guardrail 6 — Flux CD for Kubernetes Workloads
- All Kubernetes applications, CRDs, namespaces, and Helm charts belong in `kubernetes/apps/` and must be declared as Flux `Kustomization` or `HelmRelease` manifests.

---

## 4. Verification & Testing Commands

Before submitting code modifications, AI agents **must** verify:

```bash
# 1. Check YAML syntax across talos/ and kubernetes/
python3 -c "import yaml, glob; [list(yaml.safe_load_all(open(f))) for f in glob.glob('talos/*.yaml') + glob.glob('kubernetes/**/*.yaml', recursive=True)]"


# 2. Check Makefile targets
make help
```

---

## 5. Security & Git Hygiene

- Tracked safely in Git: `.sops.yaml`, `talos/talconfig.yaml`, `talos/talsecret.sops.yaml` (encrypted).
- Strictly gitignored: `talos/clusterconfig/`, `*.kubeconfig`, `kubeconfig.yaml`, `keys.txt`.
