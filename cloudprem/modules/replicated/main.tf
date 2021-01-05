resource "helm_release" "replicated" {
  name  = "replicated"
  chart = "${path.module}/charts/replicated"

  namespace = "default"

  set {
    name  = "license_secret"
    value = kubernetes_secret.replicated_license.metadata.0.name
  }
}