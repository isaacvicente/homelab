# --- Incus connection ---
variable "incus_remote" {
  description = "Incus remote name as configured by Ansible"
  type        = string
  default     = "homelab"
}

variable "storage_pool" {
  description = "Incus ZFS storage pool name"
  type        = string
  default     = "default"
}

variable "bridge_interface" {
  description = "Host Linux bridge interface that VMs attach to for home LAN access"
  type        = string
  default     = "br0"
}

# --- Talos image ---
variable "talos_version" {
  description = "Talos OS version string"
  type        = string
  default     = "v1.9.0"
}

variable "talos_schematic_id" {
  description = "Talos Image Factory schematic ID. Generate at factory.talos.dev with siderolabs/qemu-guest-agent."
  type        = string
}

# --- Cluster identity ---
variable "cluster_name" {
  description = "Kubernetes cluster name"
  type        = string
  default     = "homelab"
}

variable "cluster_vip" {
  description = "Layer 2 Virtual IP for HA Kubernetes API. Must be outside your router's DHCP pool."
  type        = string
  default     = "192.168.18.200"
}

# --- Control plane sizing ---
variable "cp_count" {
  type    = number
  default = 3
}

variable "cp_cpu" {
  type    = string
  default = "2"
}

variable "cp_memory" {
  type    = string
  default = "4GiB"
}

variable "cp_disk" {
  type    = string
  default = "40GiB"
}

# --- Worker sizing ---
variable "worker_count" {
  type    = number
  default = 3
}

variable "worker_cpu" {
  type    = string
  default = "4"
}

variable "worker_memory" {
  type    = string
  default = "6GiB"
}

variable "worker_disk" {
  type    = string
  default = "60GiB"
}
