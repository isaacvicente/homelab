# Homelab — Baremetal Talos Linux with talhelper & Flux CD

A declarative, single-node baremetal Kubernetes homelab.

**Stack:** Talos Linux · `talhelper` · SOPS + `age` · Flannel CNI · Flux CD (GitOps) · Longhorn Storage · Tailscale Operator

---

## Architecture

```
Dell Optiplex 7050 (Baremetal Talos Linux — 32 GB RAM, 8 vCPUs)
│
├── Hardware Extensions (Talos Image Factory via talhelper)
│   ├── siderolabs/intel-ucode        (CPU microcode)
│   ├── siderolabs/i915-ucode         (Intel iGPU / QuickSync)
│   ├── siderolabs/iscsi-tools        (Longhorn CSI)
│   └── siderolabs/util-linux-tools   (fstrim / filesystem tools)
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

- `talosctl`, `talhelper`, `sops`, `age`, `flux`, `kubectl`

See [Deployment Guide](docs/deployment-guide.md) for install instructions.

---

## Quick Start

```bash
make age-key          # 1. Create age encryption key
make secrets          # 2. Generate & encrypt cluster secrets
make generate         # 3. Render Talos machine configs
# Flash Talos ISO → boot Dell Optiplex → then:
make apply            # 4. Push config to node
make bootstrap        # 5. Bootstrap etcd
make kubeconfig       # 6. Fetch kubeconfig
export GITHUB_TOKEN=ghp_...
make flux-init        # 7. Bootstrap Flux CD
```

- **Full walkthrough:** [docs/deployment-guide.md](docs/deployment-guide.md)
- **Tailscale remote access:** [docs/tailscale-setup.md](docs/tailscale-setup.md)
