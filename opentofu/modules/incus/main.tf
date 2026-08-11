terraform {
  required_providers {
    incus = {
      source  = "lxc/incus"
      version = ">= 1.0.2"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0.0"
    }
  }
}

# Import the custom Talos image (with qemu-guest-agent) from factory.talos.dev.
resource "null_resource" "import_talos_image" {
  triggers = {
    schematic = var.talos_schematic_id
    version   = var.talos_version
  }

  provisioner "local-exec" {
    command = <<-EOT
      incus image import \
        "https://factory.talos.dev/image/${var.talos_schematic_id}/${var.talos_version}/metal-amd64.raw.xz" \
        --alias "talos-${var.talos_version}" \
        --type vm \
        --remote ${var.incus_remote} 2>/dev/null || true
    EOT
  }
}

resource "incus_profile" "talos_cp" {
  name        = "talos-cp"
  description = "Talos OS control plane profile"

  config = {
    "limits.cpu"          = var.cp_cpu
    "limits.memory"       = var.cp_memory
    "security.secureboot" = "false"
  }

  device {
    name = "root"
    type = "disk"
    properties = {
      path = "/"
      pool = var.storage_pool
      size = var.cp_disk
    }
  }
}

resource "incus_profile" "talos_worker" {
  name        = "talos-worker"
  description = "Talos OS worker node profile"

  config = {
    "limits.cpu"          = var.worker_cpu
    "limits.memory"       = var.worker_memory
    "security.secureboot" = "false"
  }

  device {
    name = "root"
    type = "disk"
    properties = {
      path = "/"
      pool = var.storage_pool
      size = var.worker_disk
    }
  }
}

resource "incus_instance" "talos_cp" {
  count    = var.cp_count
  name     = "talos-cp-${count.index + 1}"
  image    = "talos-${var.talos_version}"
  type     = "virtual-machine"
  profiles = [incus_profile.talos_cp.name]

  config = {
    "boot.autostart" = "true"
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      nictype = "bridged"
      parent  = var.bridge_interface
    }
  }

  depends_on = [null_resource.import_talos_image]
}

resource "incus_instance" "talos_worker" {
  count    = var.worker_count
  name     = "talos-worker-${count.index + 1}"
  image    = "talos-${var.talos_version}"
  type     = "virtual-machine"
  profiles = [incus_profile.talos_worker.name]

  config = {
    "boot.autostart" = "true"
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      nictype = "bridged"
      parent  = var.bridge_interface
    }
  }

  depends_on = [null_resource.import_talos_image]
}
