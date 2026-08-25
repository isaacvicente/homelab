# Deployment Guide

Step-by-step guide to deploy the homelab from scratch.

---

## Prerequisites

Install the following on your **development machine**:

- `talosctl` — [talos.dev/install](https://talos.dev/install) (e.g. `curl -sL https://talos.dev/install | sh`)
- `talhelper` — `brew install budimanjojo/tap/talhelper` or `go install github.com/budimanjojo/talhelper@latest`
- `sops` — `brew install sops`
- `age` — `brew install age`
- `flux` — `brew install fluxcd/tap/flux`
- `kubectl`

---

## 1. Initialize Age Encryption Key

```bash
make age-key
```

This generates `~/.config/sops/age/keys.txt` (if not already present) and displays
your public key. Paste the public key into `.sops.yaml`.

---

## 2. Generate Cluster Secrets & Machine Configs

```bash
# Generate & encrypt cluster secrets
make secrets

# Generate machine configs (talos/clusterconfig/)
make generate
```

---

## 3. Flash Talos ISO & Boot the Server

1. Download the baremetal Talos ISO from [factory.talos.dev](https://factory.talos.dev)
   or use the schematic URL from `talos/talconfig.yaml`.
2. Flash to USB:

   ```bash
   sudo dd if=metal-amd64.iso of=/dev/sdX bs=4M status=progress && sync
   ```
3. Boot the Dell Optiplex 7050 from the USB into **maintenance mode**.

---

## 4. Install Talos & Bootstrap Kubernetes

From your development machine:

```bash
# Push machine config (formats disk & installs Talos):
make apply

# After the server reboots into Talos, bootstrap etcd:
make bootstrap

# Fetch admin kubeconfig:
make kubeconfig
```

Verify the cluster is running:

```bash
export KUBECONFIG=~/.kube/homelab.yaml
kubectl get nodes -o wide
```

---

## 5. Bootstrap Flux CD

Flux CD requires a GitHub Personal Access Token (PAT) to bootstrap. The token is
used **only during bootstrap** to register an SSH deploy key on the repository —
it is not stored in the cluster.

### Create a GitHub PAT

1. Go to [github.com/settings/tokens](https://github.com/settings/tokens)
2. Create a **fine-grained** token scoped to the `homelab` repository with:
   - **Administration**: Read and write
   - **Contents**: Read and write
   - **Metadata**: Read-only
3. Export it:

   ```bash
   export GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ```

### Run the bootstrap

```bash
make flux-init
```

Flux will:

- Install its controllers into the `flux-system` namespace
- Push `gotk-components.yaml` and `gotk-sync.yaml` to the repository
- Register an SSH deploy key for ongoing Git sync
- Begin reconciling all manifests under `kubernetes/apps/`

This automatically deploys:

- **Longhorn Storage** — single-node persistent volumes (`defaultReplicaCount: 1`)
- **Tailscale Operator** — see [Tailscale Setup](tailscale-setup.md)
