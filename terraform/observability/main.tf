locals {
  yaml_content = file("${path.module}/metrics-server-components.yaml")
  components   = split("---", local.yaml_content)
}

resource "kubernetes_manifest" "metrics_server" {
  count    = length(local.components)
  manifest = yamldecode(trimspace(local.components[count.index]))
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

resource "kubernetes_manifest" "grafana_dashboard" {
  manifest   = yamldecode(file("${path.module}/grafana-dashboard.yaml"))
  depends_on = [kubernetes_namespace.monitoring]
}

resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "kube-prometheus"
  version    = "9.5.4"
  namespace  = "monitoring"
  values = [
    file("${path.module}/prometheus-values.yaml")
  ]
}

resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "grafana"
  version    = "11.3.6"
  namespace  = "monitoring"
  values = [
    file("${path.module}/grafana-values.yaml")
  ]
}
