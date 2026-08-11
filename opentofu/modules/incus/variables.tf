variable "incus_remote" {
  description = "Incus remote name"
  type        = string
}

variable "storage_pool" {
  description = "Incus ZFS storage pool name"
  type        = string
}

variable "bridge_interface" {
  description = "Host Linux bridge interface"
  type        = string
}

variable "talos_version" {
  description = "Talos OS version string (e.g. v1.9.0)"
  type        = string
}

variable "talos_schematic_id" {
  description = "Talos Image Factory schematic ID (must include siderolabs/qemu-guest-agent)"
  type        = string
}

variable "cp_count" {
  type = number
}

variable "cp_cpu" {
  type = string
}

variable "cp_memory" {
  type = string
}

variable "cp_disk" {
  type = string
}

variable "worker_count" {
  type = number
}

variable "worker_cpu" {
  type = string
}

variable "worker_memory" {
  type = string
}

variable "worker_disk" {
  type = string
}
