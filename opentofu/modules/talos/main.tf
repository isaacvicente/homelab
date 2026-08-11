terraform {
  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = ">= 0.7.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0.0"
    }
  }
}

resource "talos_machine_secrets" "cluster" {}

# Control plane config — only patch: L2 VIP on eth0.
# Flannel CNI and kube-proxy are Talos defaults; no patches needed.
data "talos_machine_configuration" "cp" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${var.cluster_vip}:6443"
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.cluster.machine_secrets

  config_patches = [
    yamlencode({
      machine = {
        network = {
          interfaces = [{
            interface = "eth0"
            dhcp      = true
            vip       = { ip = var.cluster_vip }
          }]
        }
      }
    }),
  ]
}

# Worker config — only patch: node role label.
data "talos_machine_configuration" "worker" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${var.cluster_vip}:6443"
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.cluster.machine_secrets

  config_patches = [
    yamlencode({
      machine = {
        nodeLabels = { "node-role.kubernetes.io/worker" = "" }
      }
    }),
  ]
}

resource "talos_machine_configuration_apply" "cp" {
  count                       = var.cp_count
  client_configuration        = talos_machine_secrets.cluster.client_configuration
  machine_configuration_input = data.talos_machine_configuration.cp.machine_configuration
  node                        = var.cp_ips[count.index]
}

resource "talos_machine_configuration_apply" "worker" {
  count                       = var.worker_count
  client_configuration        = talos_machine_secrets.cluster.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = var.worker_ips[count.index]
}

resource "talos_machine_bootstrap" "cluster" {
  client_configuration = talos_machine_secrets.cluster.client_configuration
  node                 = var.cp_ips[0]
  depends_on           = [talos_machine_configuration_apply.cp]
}

resource "talos_cluster_kubeconfig" "cluster" {
  client_configuration = talos_machine_secrets.cluster.client_configuration
  node                 = var.cp_ips[0]
  depends_on           = [talos_machine_bootstrap.cluster]
}

data "talos_client_configuration" "cluster" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.cluster.client_configuration
  endpoints            = [var.cluster_vip]
  nodes                = var.cp_ips
}

# Write credentials to disk for kubectl / talosctl use.
resource "local_file" "kubeconfig" {
  content         = talos_cluster_kubeconfig.cluster.kubeconfig_raw
  filename        = var.kubeconfig_path
  file_permission = "0600"
}

resource "local_file" "talosconfig" {
  content         = data.talos_client_configuration.cluster.talos_config
  filename        = "${dirname(var.kubeconfig_path)}/talosconfig.yaml"
  file_permission = "0600"
}
