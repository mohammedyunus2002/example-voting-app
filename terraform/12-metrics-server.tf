resource "helm_release" "metrics_server" {
  count = local.kubernetes_ready ? 1 : 0
  name  = "metrics-server"

  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = "3.12.1"

  timeout = 600
  values  = [file("${path.module}/values/metrics-server.yaml")]

  depends_on = [
    aws_eks_node_group.general,
    aws_eks_addon.pod_identity
  ]
}