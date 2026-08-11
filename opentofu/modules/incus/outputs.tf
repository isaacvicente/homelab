output "cp_ips" {
  description = "Control plane IPs (reported by qemu-guest-agent)"
  value       = [for i in incus_instance.talos_cp : i.ipv4_address]
}

output "worker_ips" {
  description = "Worker IPs (reported by qemu-guest-agent)"
  value       = [for i in incus_instance.talos_worker : i.ipv4_address]
}
