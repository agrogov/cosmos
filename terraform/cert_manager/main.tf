resource "kubernetes_namespace" "cert_manager_namespace" {
  metadata {
    name = "cert-manager"
  }
}

locals {
  yaml_cert_manager = file("${path.module}/cert-manager.yaml")
  cert_manager      = split("---", local.yaml_cert_manager)
}

resource "kubernetes_manifest" "cert_manager" {
  count      = length(local.cert_manager)
  manifest   = yamldecode(trimspace(local.cert_manager[count.index]))
  depends_on = [kubernetes_namespace.cert_manager_namespace]
}

resource "null_resource" "cert_manager_rollout_status" {
  provisioner "local-exec" {
    command = <<EOT
      kubectl rollout status deployment/cert-manager -n cert-manager --kubeconfig ${var.kubeconfig}
      kubectl rollout status deployment/cert-manager-webhook -n cert-manager --kubeconfig ${var.kubeconfig}
    EOT
  }
  depends_on = [kubernetes_namespace.cert_manager_namespace, kubernetes_manifest.cert_manager]
}
