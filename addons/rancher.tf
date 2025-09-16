############################################
# Rancher (instalación condicional)
############################################

locals {
  rancher_hostname_clean = trimspace(var.rancher_hostname)
  install_rancher        = local.rancher_hostname_clean != ""
}

resource "kubernetes_namespace" "cattle_system" {
  count = local.install_rancher ? 1 : 0
  metadata { name = "cattle-system" }
}

resource "helm_release" "rancher" {
  count      = local.install_rancher ? 1 : 0
  name       = "rancher"
  repository = "https://releases.rancher.com/server-charts/stable"
  chart      = "rancher"
  version    = "2.12.1"
  namespace  = kubernetes_namespace.cattle_system[0].metadata[0].name

  # El Ingress y NGINX deben existir antes
  depends_on = [helm_release.ingress_nginx]

  # Evita que Terraform quede colgado esperando hooks
  wait    = false
  timeout = 900

  values = [
    yamlencode({
      hostname          = local.rancher_hostname_clean
      bootstrapPassword = var.rancher_admin_password
      ingress = {
        ingressClassName = "nginx"
        tls = { source = "rancher" } # el chart genera el TLS
      }
      replicas = 1

      # Arranque sin Fleet para no disparar los helm-operation iniciales
      extraEnv = [{
        name  = "CATTLE_FEATURES"
        value = "-fleet"
      }]
    })
  ]
}
