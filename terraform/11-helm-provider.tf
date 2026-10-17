provider "helm" {
  kubernetes = {
    host                   = var.kube_host != "" ? var.kube_host : "https://127.0.0.1"
    cluster_ca_certificate = base64decode(var.kube_ca != "" ? var.kube_ca : "ZHVtbXk=")
    token                  = var.kube_token
  }
}

provider "kubernetes" {
  host                   = var.kube_host != "" ? var.kube_host : "https://127.0.0.1"
  cluster_ca_certificate = base64decode(var.kube_ca != "" ? var.kube_ca : "ZHVtbXk=")
  token                  = var.kube_token
}
