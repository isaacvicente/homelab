output "kubeconfig_raw" {
  description = "Raw kubeconfig content"
  value       = talos_cluster_kubeconfig.cluster.kubeconfig_raw
  sensitive   = true
}

output "talosconfig" {
  description = "Raw talosconfig content"
  value       = data.talos_client_configuration.cluster.talos_config
  sensitive   = true
}

output "cluster_endpoint" {
  value = "https://${var.cluster_vip}:6443"
}
