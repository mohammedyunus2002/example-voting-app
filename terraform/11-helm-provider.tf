provider "helm" {
  kubernetes = {
    host                   = local.kube_host != "" ? local.kube_host : "https://127.0.0.1"
    cluster_ca_certificate = local.kube_ca != "" ? base64decode(local.kube_ca) : file("${path.module}/placeholder-ca.pem")
    exec = local.kubernetes_ready ? {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks", "get-token",
        "--cluster-name", "${local.env}-${local.eks_name}",
        "--region", local.region
      ]
    } : null
  }
}

provider "kubernetes" {
  host                   = local.kube_host != "" ? local.kube_host : "https://127.0.0.1"
  cluster_ca_certificate = local.kube_ca != "" ? base64decode(local.kube_ca) : file("${path.module}/placeholder-ca.pem")

  dynamic "exec" {
    for_each = local.kubernetes_ready ? [1] : []
    content {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks", "get-token",
        "--cluster-name", "${local.env}-${local.eks_name}",
        "--region", local.region
      ]
    }
  }
}
