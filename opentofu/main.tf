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

# K3s node profile with 4GB RAM and 2 vCPU
resource "incus_profile" "k3s" {
  name        = "k3s"
  description = "Profile for k3s cluster instances"

  config = {
    "limits.cpu"    = "2"
    "limits.memory" = "4GB"
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      network = "incusbr0"
    }
  }

  device {
    name = "root"
    type = "disk"
    properties = {
      path = "/"
      pool = "default"
    }
  }
}

# K3s controller nodes
resource "incus_instance" "k3s_controller" {
  count    = 2
  name     = "k3s-controller-${count.index + 1}"
  image    = "images:ubuntu/24.04"
  profiles = [incus_profile.k3s.name]

  config = {
    "boot.autostart" = true
  }
}

# K3s worker nodes
resource "incus_instance" "k3s_worker" {
  count    = 2
  name     = "k3s-worker-${count.index + 1}"
  image    = "images:ubuntu/24.04"
  profiles = [incus_profile.k3s.name]

  config = {
    "boot.autostart" = true
  }
}
