resource "helm_release" "cert_manager" {
  count = local.kubernetes_ready ? 1 : 0
  name  = "cert-manager"

  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  version          = "v1.14.5"

  timeout = 1200

  set = [
    {
      name  = "installCRDs"
      value = "true"
    },
    {
      name  = "replicaCount"
      value = "1"
    },
    {
      name  = "webhook.replicaCount"
      value = "1"
    },
    {
      name  = "cainjector.replicaCount"
      value = "1"
    },
    {
      name  = "resources.requests.cpu"
      value = "50m"
    },
    {
      name  = "resources.requests.memory"
      value = "64Mi"
    }
  ]

  depends_on = [helm_release.external_nginx]
}