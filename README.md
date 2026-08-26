<div align="center">

<img src="https://github.com/user-attachments/assets/0248f379-cc4a-4a59-a400-014a750c61fa" align="center" width="144px" height="144px"/>

### My homelab k8s cluster <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/2728/512.gif" alt="✨" width="16" height="16">

_... single-node baremetal Talos Linux automated via [Flux](https://github.com/fluxcd/flux2) and [Renovate](https://github.com/renovatebot/renovate)_ <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f916/512.gif" alt="🤖" width="16" height="16">

</div>

<div align="center">

[![Talos](https://img.shields.io/badge/Talos_Linux-v1.13.9-3b82f6.svg?style=for-the-badge&logo=talos&logoColor=white)](https://talos.dev)&nbsp;&nbsp;
[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.36.0-326ce5.svg?style=for-the-badge&logo=kubernetes&logoColor=white)](https://kubernetes.io)&nbsp;&nbsp;
[![Flux](https://img.shields.io/badge/GitOps-Flux_CD-2d88ff.svg?style=for-the-badge&logo=flux&logoColor=white)](https://fluxcd.io)&nbsp;&nbsp;
[![Tailscale](https://img.shields.io/badge/Tailscale-v1.102.3-24292f.svg?style=for-the-badge&logo=tailscale&logoColor=white)](https://tailscale.com)&nbsp;&nbsp;
[![Renovate](https://img.shields.io/badge/Renovate-enabled-brightgreen.svg?style=for-the-badge&logo=renovate&logoColor=white)](https://docs.renovatebot.com/)

</div>

<div align="center">

[![Lint & Validate](https://github.com/isaacvicente/homelab/actions/workflows/lint.yaml/badge.svg?branch=main)](https://github.com/isaacvicente/homelab/actions/workflows/lint.yaml)&nbsp;&nbsp;
[![Security & Secret Scan](https://github.com/isaacvicente/homelab/actions/workflows/security.yaml/badge.svg?branch=main)](https://github.com/isaacvicente/homelab/actions/workflows/security.yaml)

</div>

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
