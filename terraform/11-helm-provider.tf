provider "helm" {
  kubernetes = {
    host                   = local.kube_host != "" ? local.kube_host : "https://127.0.0.1"
    cluster_ca_certificate = local.kube_ca != "" ? base64decode(local.kube_ca) : file("${path.module}/placeholder-ca.pem")
    token                  = local.kube_token
  }
}

provider "kubernetes" {
  host                   = local.kube_host != "" ? local.kube_host : "https://127.0.0.1"
  cluster_ca_certificate = local.kube_ca != "" ? base64decode(local.kube_ca) : file("${path.module}/placeholder-ca.pem")
  token                  = local.kube_token
}
