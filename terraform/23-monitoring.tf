resource "helm_release" "kube_prometheus_stack" {
  count = local.kubernetes_ready ? 1 : 0
  name  = "kube-prometheus-stack"

  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  version          = "65.1.0"
  timeout          = 1200

  values = [file("${path.module}/values/kube-prometheus-stack.yaml")]

  depends_on = [helm_release.argocd]
}
