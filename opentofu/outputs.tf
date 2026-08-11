output "cp_ips" {
  description = "Control plane node IPs"
  value       = module.incus.cp_ips
}

output "worker_ips" {
  description = "Worker node IPs"
  value       = module.incus.worker_ips
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint via Layer 2 VIP"
  value       = module.talos.cluster_endpoint
}
