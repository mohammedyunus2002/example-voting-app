resource "helm_release" "argocd" {
  name = "argocd"

  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "7.7.12"
  timeout          = 600

  values = [file("${path.module}/values/argocd.yaml")]

  depends_on = [aws_eks_node_group.general]
}

resource "helm_release" "argocd_apps" {
  name = "argocd-apps"

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  namespace  = "argocd"
  version    = "2.0.2"

  values = [file("${path.module}/values/argocd-apps.yaml")]

  depends_on = [helm_release.argocd]
}
