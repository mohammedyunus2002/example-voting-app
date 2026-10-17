resource "helm_release" "kube_prometheus_stack" {
  name = "kube-prometheus-stack"

  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  version          = "65.1.0"
  timeout          = 900

  values = [file("${path.module}/values/kube-prometheus-stack.yaml")]

  depends_on = [aws_eks_node_group.general]
}
