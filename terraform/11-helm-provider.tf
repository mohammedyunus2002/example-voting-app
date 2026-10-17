provider "helm" {
  kubernetes = {
    host                   = var.kube_host != "" ? var.kube_host : "https://127.0.0.1"
    cluster_ca_certificate = var.kube_ca != "" ? base64decode(var.kube_ca) : file("${path.module}/placeholder-ca.pem")
    token                  = var.kube_token
  }
}

provider "kubernetes" {
  host                   = var.kube_host != "" ? var.kube_host : "https://127.0.0.1"
  cluster_ca_certificate = var.kube_ca != "" ? base64decode(var.kube_ca) : file("${path.module}/placeholder-ca.pem")
  token                  = var.kube_token
}
