variable "kube_host" {
  type    = string
  default = ""
}

variable "kube_ca" {
  type    = string
  default = ""
}

variable "kube_token" {
  type      = string
  default   = ""
  sensitive = true
}
