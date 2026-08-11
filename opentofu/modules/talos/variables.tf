variable "cluster_name" {
  type = string
}

variable "cluster_vip" {
  type = string
}

variable "cp_ips" {
  type = list(string)
}

variable "worker_ips" {
  type = list(string)
}

variable "cp_count" {
  type = number
}

variable "worker_count" {
  type = number
}

variable "kubeconfig_path" {
  description = "Local path where kubeconfig.yaml will be written"
  type        = string
  default     = "./kubeconfig.yaml"
}
