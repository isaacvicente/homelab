terraform {
  # Remote state stored in MinIO on the physical host.
  # MinIO is set up by Ansible before this runs.
  # Credentials and endpoint are passed via `tofu init -backend-config` flags.
  backend "s3" {
    bucket                      = "tfstate"
    key                         = "homelab/terraform.tfstate"
    region                      = "us-east-1"
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    use_path_style              = true
  }

  required_providers {
    incus = {
      source  = "lxc/incus"
      version = ">= 1.0.2"
    }
    talos = {
      source  = "siderolabs/talos"
      version = ">= 0.7.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0.0"
    }
  }

  required_version = "~> 1.2"
}

provider "incus" {}

provider "talos" {}

module "incus" {
  source = "./modules/incus"

  incus_remote       = var.incus_remote
  storage_pool       = var.storage_pool
  bridge_interface   = var.bridge_interface
  talos_version      = var.talos_version
  talos_schematic_id = var.talos_schematic_id

  cp_count  = var.cp_count
  cp_cpu    = var.cp_cpu
  cp_memory = var.cp_memory
  cp_disk   = var.cp_disk

  worker_count  = var.worker_count
  worker_cpu    = var.worker_cpu
  worker_memory = var.worker_memory
  worker_disk   = var.worker_disk
}

module "talos" {
  source = "./modules/talos"

  cluster_name    = var.cluster_name
  cluster_vip     = var.cluster_vip
  cp_ips          = module.incus.cp_ips
  worker_ips      = module.incus.worker_ips
  cp_count        = var.cp_count
  worker_count    = var.worker_count
  kubeconfig_path = "${path.module}/kubeconfig.yaml"
}
