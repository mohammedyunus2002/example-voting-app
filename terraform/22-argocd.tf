resource "helm_release" "argocd" {
  count = local.kubernetes_ready ? 1 : 0
  name  = "argocd"

  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "7.7.12"
  timeout          = 1200

  values = [file("${path.module}/values/argocd.yaml")]

  depends_on = [helm_release.aws_lbc]
}

resource "helm_release" "argocd_apps" {
  count = local.kubernetes_ready ? 1 : 0
  name  = "argocd-apps"

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  namespace  = "argocd"
  version    = "2.0.2"

  values = [file("${path.module}/values/argocd-apps.yaml")]

  depends_on = [helm_release.argocd]
}
