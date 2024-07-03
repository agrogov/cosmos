resource "kubernetes_namespace" "hostpath_provisioner_namespace" {
  metadata {
    name = "hostpath-provisioner"
  }
}

locals {
  yaml_hostpath_webhook  = file("${path.module}/webhook.yaml")
  hostpath_webhook       = split("---", local.yaml_hostpath_webhook)
  yaml_hostpath_operator = file("${path.module}/operator.yaml")
  hostpath_operator      = split("---", local.yaml_hostpath_operator)
}

resource "kubernetes_manifest" "hostpath_provisioner_webhook" {
  count      = length(local.hostpath_webhook)
  manifest   = yamldecode(trimspace(local.hostpath_webhook[count.index]))
  depends_on = [kubernetes_namespace.hostpath_provisioner_namespace]
}

resource "kubernetes_manifest" "hostpath_provisioner_operator" {
  count      = length(local.hostpath_operator)
  manifest   = yamldecode(trimspace(local.hostpath_operator[count.index]))
  depends_on = [kubernetes_manifest.hostpath_provisioner_webhook]
}

resource "null_resource" "hostpath_provisioner_cr_storageclass" {
  provisioner "local-exec" {
    command = <<EOT
      kubectl rollout status deployment/hostpath-provisioner-operator -n hostpath-provisioner --kubeconfig ${var.kubeconfig}
      kubectl apply -f "${path.module}/cr.yaml" --kubeconfig ${var.kubeconfig}
      kubectl apply -f "${path.module}/storageclass.yaml" --kubeconfig ${var.kubeconfig}
      kubectl rollout status daemonset/hostpath-provisioner-csi -n hostpath-provisioner --kubeconfig ${var.kubeconfig}
    EOT
  }
  depends_on = [kubernetes_manifest.hostpath_provisioner_operator]
}
