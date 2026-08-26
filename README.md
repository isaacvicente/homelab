# Homelab — Baremetal Talos Linux with talhelper & Flux CD

[![Lint & Validate](https://github.com/isaacvicente/homelab/actions/workflows/lint.yaml/badge.svg)](https://github.com/isaacvicente/homelab/actions/workflows/lint.yaml)
[![Security & Secret Scan](https://github.com/isaacvicente/homelab/actions/workflows/security.yaml/badge.svg)](https://github.com/isaacvicente/homelab/actions/workflows/security.yaml)
[![Renovate](https://img.shields.io/badge/renovate-enabled-brightgreen.svg)](https://docs.renovatebot.com/)
[![Talos Linux](https://img.shields.io/badge/Talos_Linux-v1.13.9-3b82f6.svg)](https://talos.dev)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.36.0-326ce5.svg?logo=kubernetes&logoColor=white)](https://kubernetes.io)
[![Flux CD](https://img.shields.io/badge/GitOps-Flux_CD-2d88ff.svg?logo=flux&logoColor=white)](https://fluxcd.io)

A declarative, single-node baremetal Kubernetes homelab.

**Stack:** Talos Linux · `talhelper` · SOPS + `age` · Flannel CNI · Flux CD (GitOps) · Longhorn Storage · Tailscale Operator

---

## Architecture

```
Dell Optiplex 7050 (Baremetal Talos Linux — 32 GB RAM, 8 vCPUs)
│
├── Hardware Extensions (Talos Image Factory via talhelper)
│   ├── siderolabs/intel-ucode        (CPU microcode)
│   ├── siderolabs/i915               (Intel iGPU / QuickSync)
│   ├── siderolabs/iscsi-tools        (Longhorn CSI)
│   ├── siderolabs/util-linux-tools   (fstrim / filesystem tools)
│   └── siderolabs/tailscale          (Baremetal OS-level Tailnet integration)
│
├── Network & OS
│   ├── Static IP: 192.168.18.100/24
│   └── Flannel CNI (built-in)
│
└── GitOps Workloads (Flux CD)
    ├── Longhorn Storage   (single-node, replica=1)
    └── Tailscale Operator (private HTTPS via MagicDNS)
```

---

## Prerequisites

- `task` (`go-task`), `talosctl`, `talhelper`, `sops`, `age`, `flux`, `kubectl`

See [Deployment Guide](docs/deployment-guide.md) for install instructions.

---

## Quick Start

```bash
task age-key          # 1. Create age encryption key
task secrets          # 2. Generate & encrypt cluster secrets
task generate         # 3. Render Talos machine configs
# Flash Talos ISO → boot Dell Optiplex → then:
task apply            # 4. Push config to node
task bootstrap        # 5. Bootstrap etcd
task kubeconfig       # 6. Fetch kubeconfig
export GITHUB_TOKEN=ghp_...
task flux-init        # 7. Bootstrap Flux CD
task sops-secret      # 8. Inject age decryption key into Flux (for encrypted secrets)
```

- **Full walkthrough:** [docs/deployment-guide.md](docs/deployment-guide.md)
- **Tailscale remote access:** [docs/tailscale-setup.md](docs/tailscale-setup.md)
