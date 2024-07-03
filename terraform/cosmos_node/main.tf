resource "kubernetes_namespace" "cosmos_namespace" {
  metadata {
    name = "cosmos"
  }
}

locals {
  yaml_content = file("${path.module}/gaia-deployment.yaml")
  components   = split("---", local.yaml_content)
}

resource "kubernetes_manifest" "gaia_node" {
  count      = length(local.components)
  manifest   = yamldecode(trimspace(local.components[count.index]))
  depends_on = [kubernetes_namespace.cosmos_namespace]
}
