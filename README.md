<div align="center">

<img src="https://github.com/user-attachments/assets/0248f379-cc4a-4a59-a400-014a750c61fa" align="center" width="144px" height="144px"/>

### My Homelab Kubernetes Cluster <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/2728/512.gif" alt="✨" width="16" height="16">

_... single-node baremetal Talos Linux automated via [Flux](https://github.com/fluxcd/flux2), [Renovate](https://github.com/renovatebot/renovate) and [GitHub Actions](https://github.com/features/actions)_ <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f916/512.gif" alt="🤖" width="16" height="16">

</div>

<div align="center">

[![Talos](https://img.shields.io/badge/Talos_Linux-v1.13.9-3b82f6.svg?style=for-the-badge&logo=talos&logoColor=white)](https://talos.dev)&nbsp;&nbsp;
[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.36.0-326ce5.svg?style=for-the-badge&logo=kubernetes&logoColor=white)](https://kubernetes.io)&nbsp;&nbsp;
[![Flux](https://img.shields.io/badge/GitOps-Flux_CD-2d88ff.svg?style=for-the-badge&logo=flux&logoColor=white)](https://fluxcd.io)&nbsp;&nbsp;
[![Tailscale](https://img.shields.io/badge/Tailscale-v1.102.3-24292f.svg?style=for-the-badge&logo=tailscale&logoColor=white)](https://tailscale.com)&nbsp;&nbsp;
[![Renovate](https://img.shields.io/badge/Renovate-enabled-brightgreen.svg?style=for-the-badge&logo=renovate&logoColor=white)](https://docs.renovatebot.com/)

</div>

<div align="center">

[![Lint & Validate](https://img.shields.io/github/actions/workflow/status/isaacvicente/homelab/lint.yaml?branch=main&label=Lint%20%26%20Validate&style=for-the-badge&logo=githubactions&logoColor=white)](https://github.com/isaacvicente/homelab/actions/workflows/lint.yaml)&nbsp;&nbsp;
[![Security Scan](https://img.shields.io/github/actions/workflow/status/isaacvicente/homelab/security.yaml?branch=main&label=Security%20Scan&style=for-the-badge&logo=githubactions&logoColor=white)](https://github.com/isaacvicente/homelab/actions/workflows/security.yaml)

</div>

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f4a1/512.gif" alt="💡" width="20" height="20"> Overview

This repository contains the declarative configuration for my baremetal Kubernetes homelab. Everything adheres to **Infrastructure as Code (IaC)** and **GitOps** principles using **Talos Linux**, **Flux CD**, **SOPS + age**, **Renovate**, and **GitHub Actions**.

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f331/512.gif" alt="🌱" width="20" height="20"> Kubernetes & Hardware

The cluster runs on **Talos Linux**, an immutable, secure, and ephemeral Linux distribution built strictly for Kubernetes. It runs directly on baremetal hardware with no hypervisors or VM layers.

🔸 _[Click here](talos/talconfig.yaml) to view my declarative Talos configuration._

### Node Specifications

| Hostname | Role | CPU | RAM | Storage | IP Address | OS |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`homelab`** | Controlplane + Worker | Intel Core i7 (8 vCPUs) | 32 GB DDR4 | 480 GB SSD (Kingston SA400) | `192.168.18.100/24` | Talos Linux v1.13.9 |

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f4e6/512.gif" alt="📦" width="20" height="20"> Core Components

- **[Flux CD](https://fluxcd.io/)**: GitOps continuous delivery engine that automatically reconciles all manifests from the `kubernetes/` directory.
- **[Longhorn](https://longhorn.io/)**: Distributed cloud-native block storage configured for single-node resilience (`replicaCount: 1`).
- **[Tailscale](https://tailscale.com/)**:
  - **Operator (In-Cluster)**: Automated HTTPS MagicDNS Ingress endpoints and secure Kubernetes API server proxy.
  - **System Extension (OS-Level)**: Runs directly under Talos `machined` for out-of-band remote `talosctl` management independent of Kubernetes health.
- **[SOPS](https://github.com/getsops/sops) + [age](https://github.com/FiloSottile/age)**: In-repo secret encryption for cluster PKI and Kubernetes secrets.
- **[Renovate](https://docs.renovatebot.com/)**: Automated dependency updates for Helm charts, GitHub Actions, Talos Linux, and Kubernetes.

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f4c1/512.gif" alt="📁" width="20" height="20"> Repository Structure

```
homelab/
├── .github/                           # CI workflows (lint, security) & Renovate config
├── docs/                              # Deployment & Tailscale runbooks
├── talos/                             # Declarative Talos machine configuration (talhelper)
│   ├── talconfig.yaml                 # Node specs, network, and Image Factory extensions
│   ├── talsecret.sops.yaml            # Encrypted cluster PKI & secrets
│   └── talenv.sops.yaml               # Encrypted environment secrets (Tailscale auth key)
├── kubernetes/                        # Flux CD GitOps tree
│   ├── flux-system/                   # Flux sync & controllers
│   └── apps/
│       ├── storage/longhorn/          # Longhorn storage engine & Tailscale Ingress
│       └── network/tailscale/         # Tailscale operator, API proxy, & RBAC
├── Taskfile.yaml                      # Declarative automation tasks (go-task)
└── Makefile                           # Backward-compatible forwarding wrapper
```

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/26a1/512.gif" alt="⚡" width="20" height="20"> Quick Start & Automation

Automation is powered by **`go-task`** (`Taskfile.yaml`). Run `task` to view all available commands:

```bash
task age-key          # 1. Generate local age encryption key
task secrets          # 2. Generate and encrypt cluster secrets
task generate         # 3. Render Talos machine configurations
# Flash ISO → Boot node into maintenance mode → then:
task apply            # 4. Install Talos OS to disk
task bootstrap        # 5. Bootstrap etcd control plane
task kubeconfig       # 6. Fetch admin kubeconfig (~/.kube/homelab.yaml)
export GITHUB_TOKEN=ghp_...
task flux-init        # 7. Bootstrap Flux CD GitOps controllers
task sops-secret      # 8. Inject age decryption key into cluster
```

### Day-2 Maintenance

```bash
task lint             # Run local validation checks (talhelper + kustomize)
task upgrade          # Upgrade Talos OS and system extensions on running node
```

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f4d6/512.gif" alt="📖" width="20" height="20"> Documentation

- 🚀 **[Deployment Guide](docs/deployment-guide.md)** — Complete step-by-step walkthrough from baremetal to running cluster.
- 🔒 **[Tailscale & SOPS Guide](docs/tailscale-setup.md)** — Setting up secure remote access, HTTPS Ingresses, and out-of-band node management.
