variable "controller_count" {
  description = "Number of k3s controller nodes"
  type        = number
  default     = 3
}

variable "worker_count" {
  description = "Number of k3s worker nodes"
  type        = number
  default     = 3
}

variable "instance_image" {
  description = "Image to use for instances"
  type        = string
  default     = "images:ubuntu/24.04"
}

variable "k3s_network" {
  description = "K3s network configuration"
  type = object({
    name         = string
    description  = string
    ipv4_address = string
    ipv4_nat     = string
  })
  default = {
    name         = "k3s"
    description  = "K3s network to attach instances to"
    ipv4_address = "10.150.19.1/24"
    ipv4_nat     = "true"
  }
}

variable "storage_pool" {
  description = "Incus storage pool for root disk"
  type        = string
  default     = "default"
}

variable "k3s_profile" {
  description = "K3s profile configuration"
  type = object({
    name        = string
    description = string
    cpu         = string
    memory      = string
  })
  default = {
    name        = "k3s"
    description = "Profile for k3s cluster instances"
    cpu         = "2"
    memory      = "4GB"
  }
}
