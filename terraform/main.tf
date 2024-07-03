terraform {
  required_version = ">= 1.9"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.14.0"
    }
    null = {}
  }
}

module "k8s_cluster" {
  source          = "./k8s_cluster"
  ssh_private_key = var.ssh_private_key
  master_ip       = var.master_ip
  worker_ips      = var.worker_ips
  kubeconfig      = var.kubeconfig
}

module "cert_manager" {
  source     = "./cert_manager"
  kubeconfig = var.kubeconfig
  depends_on = [module.k8s_cluster]
}

module "hostpath_provisioner" {
  source     = "./hostpath_provisioner"
  kubeconfig = var.kubeconfig
  depends_on = [module.cert_manager]
}

module "metallb" {
  source     = "./metallb"
  kubeconfig = var.kubeconfig
  depends_on = [module.k8s_cluster]
}

module "observability" {
  source     = "./observability"
  depends_on = [module.k8s_cluster]
}

module "cosmos_node" {
  source     = "./cosmos_node"
  depends_on = [module.k8s_cluster]
}
