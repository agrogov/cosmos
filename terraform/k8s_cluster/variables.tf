variable "master_ip" {
  description = "IP address of the Kubernetes master node."
  type        = string
}

variable "worker_ips" {
  description = "List of worker nodes' IPs"
  type        = set(string)
}

variable "ssh_user" {
  description = "SSH user for connecting to the VMs."
  type        = string
  default     = "ubuntu"
}

variable "ssh_private_key" {
  description = "Path to the SSH private key."
  type        = string
}

variable "kubeconfig" {
  description = "Path to the kubeconfig file."
  type        = string
}
