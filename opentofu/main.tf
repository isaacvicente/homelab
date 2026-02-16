terraform {
  required_providers {
    incus = {
      source  = "lxc/incus"
      version = ">= 1.0.2"
    }
  }

  required_version = "~> 1.2"
}

provider "incus" {}

# K3s network
resource "incus_network" "k3s" {
  name = var.k3s_network.name

  config = {
    "ipv4.address" = var.k3s_network.ipv4_address
    "ipv4.nat"     = var.k3s_network.ipv4_nat
  }
}

# K3s node profile
resource "incus_profile" "k3s" {
  name        = var.k3s_profile.name
  description = var.k3s_profile.description

  config = {
    "limits.cpu"    = var.k3s_profile.cpu
    "limits.memory" = var.k3s_profile.memory
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      network = var.k3s_network.name
    }
  }

  device {
    name = "root"
    type = "disk"
    properties = {
      path = "/"
      pool = var.storage_pool
    }
  }
}

# K3s controller nodes
resource "incus_instance" "k3s_controller" {
  count    = var.controller_count
  name     = "k3s-controller-${count.index + 1}"
  image    = var.instance_image
  profiles = [incus_profile.k3s.name]

  config = {
    "boot.autostart" = true
  }
}

# K3s worker nodes
resource "incus_instance" "k3s_worker" {
  count    = var.worker_count
  name     = "k3s-worker-${count.index + 1}"
  image    = var.instance_image
  profiles = [incus_profile.k3s.name]

  config = {
    "boot.autostart" = true
  }
}
