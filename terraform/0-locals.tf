locals {
  env              = "staging"
  region           = "us-east-2"
  zone1            = "us-east-2a"
  zone2            = "us-east-2b"
  eks_name         = "demo"
  eks_version      = "1.35"
  kube_host        = trimspace(var.kube_host)
  kube_ca          = trimspace(var.kube_ca)
  kube_token       = trimspace(var.kube_token)
  kubernetes_ready = local.kube_host != ""
}