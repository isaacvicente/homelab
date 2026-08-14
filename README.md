# Homelab — Single-Node Baremetal Talos Linux

A single-node baremetal Kubernetes homelab running [Talos Linux](https://www.talos.dev/) directly on physical hardware.

**Stack:** Talos Linux · Flannel CNI · `talosctl` · Local Storage

---

## Architecture

```
Physical Host (Baremetal Talos Linux — 32 GB RAM, 8 vCPUs)
│
├── NIC (enp0s31f6 — Static IP: 192.168.18.100/24, Gateway: 192.168.18.1)
├── Disk (/dev/sda — wiped and provisioned directly by Talos)
│
└── Kubernetes (Single Node: Controlplane + Worker roles)
    ├── allowSchedulingOnControlPlanes: true
    ├── Default Flannel CNI
    └── Kube API Endpoint: https://192.168.18.100:6443
```

- **Baremetal Immutable OS**: No host Ubuntu OS, no Incus, no virtualization overhead. The entire 32 GB RAM and 8 vCPUs are available to Kubernetes workloads.
- **Single-Node Scheduling**: `allowSchedulingOnControlPlanes: true` allows all your home workloads (Home Assistant, Plex, storage, etc.) to run on the single control-plane node.
- **Flannel CNI**: Talos default built-in CNI requiring zero configuration.

---

## Prerequisites

On your **workstation / laptop**:
- `talosctl` (e.g. `curl -sL https://talos.dev/install | sh`)
- `kubectl`
- `make`
- A USB drive to flash the Talos baremetal ISO

---

## Installation & Bootstrap Workflow

### 1. Download & Flash the Talos ISO

Generate the baremetal ISO link:
```bash
make iso
```
Download `metal-amd64.iso` from [factory.talos.dev](https://factory.talos.dev) and flash to your USB drive using Balena Etcher or `dd`:
```bash
sudo dd if=metal-amd64.iso of=/dev/sdX bs=4M status=progress && sync
```

### 2. Boot the Physical Machine from USB

Plug the USB into the physical server and boot from it. Talos will start in **maintenance mode** and obtain a temporary DHCP IP (or listen on default interfaces).

### 3. Generate Cluster Secrets & Machine Config

From your workstation:
```bash
# Generate cluster PKI secrets (gitignored)
make secrets

# Generate controlplane.yaml with your custom network/install patches
make generate
```

> [!TIP]
> If your server uses an NVMe disk instead of SATA/SAS, edit `talos/patches/install.yaml` to set `disk: /dev/nvme0n1` before generating configs.

### 4. Apply Configuration to the Node

Push the configuration over the network to the server:
```bash
make apply
```
Talos will format the target disk, install the OS, reboot into the installed system, and configure static IP `192.168.18.100`.

### 5. Bootstrap etcd & Fetch Kubeconfig

Once the server boots from disk:
```bash
# Bootstrap the single-node etcd cluster (run once)
make bootstrap

# Fetch admin kubeconfig to ~/.kube/homelab.yaml
make kubeconfig
```

### 6. Verify the Cluster

```bash
export KUBECONFIG=~/.kube/homelab.yaml
kubectl get nodes -o wide
kubectl get pods -A
```

---

## Project Structure

```
homelab/
├── AGENTS.md                 # AI agent operating instructions & architecture guide
├── Makefile                  # talosctl workflow targets (secrets, generate, apply, bootstrap, kubeconfig)
├── README.md                 # Project documentation
├── .gitignore                # Git exclusions (secrets, machine configs, kubeconfigs)
└── talos/
    └── patches/
        ├── controlplane.yaml # Static IP (192.168.18.100), hostname, allowSchedulingOnControlPlanes
        └── install.yaml      # Target disk (/dev/sda) & wipe setting
```

---

## Maintenance & Operations

| Task | Command | Description |
|---|---|---|
| **View Node Status** | `talosctl -n 192.168.18.100 --talosconfig talos/talosconfig dashboard` | Interactive TUI dashboard |
| **View Node Logs** | `talosctl -n 192.168.18.100 --talosconfig talos/talosconfig dmesg` | Kernel log messages |
| **Inspect Disks** | `talosctl -n 192.168.18.100 --talosconfig talos/talosconfig disks` | List host disks & partitions |
| **Factory Reset** | `make reset` | Wipes the disk and restarts in maintenance mode |
