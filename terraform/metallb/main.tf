resource "kubernetes_namespace" "metallb" {
  metadata {
    name = "metallb-system"
    labels = {
      "pod-security.kubernetes.io/audit"   = "privileged"
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/warn"    = "privileged"
    }
  }
}

locals {
  yaml_content = file("${path.module}/metallb-native.yaml")
  components   = split("---", local.yaml_content)
}

resource "kubernetes_manifest" "metallb" {
  count    = length(local.components)
  manifest = yamldecode(trimspace(local.components[count.index]))
}

resource "null_resource" "metallb_address_pool" {
  provisioner "local-exec" {
    command = <<EOT
      kubectl rollout status deployment/controller -n metallb-system --kubeconfig ${var.kubeconfig}
      kubectl rollout status daemonset/speaker -n metallb-system --kubeconfig ${var.kubeconfig}
      kubectl apply -f ${path.module}/address-pool.yaml --kubeconfig ${var.kubeconfig}
    EOT
  }
  depends_on = [kubernetes_manifest.metallb]
}
