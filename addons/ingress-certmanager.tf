resource "kubernetes_namespace" "ingress_nginx" {
  metadata { name = "ingress-nginx" }
}

resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  namespace  = kubernetes_namespace.ingress_nginx.metadata[0].name
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.13.2"
  wait       = true

  values = [<<-YAML
    controller:
      ingressClass: nginx
      ingressClassResource:
        enabled: true
        default: true
        name: nginx
      service:
        type: LoadBalancer
    YAML
  ]
}

resource "kubernetes_namespace" "cert_manager" {
  metadata { name = "cert-manager" }
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  namespace  = kubernetes_namespace.cert_manager.metadata[0].name
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "v1.18.2"
  wait       = true

  values = [<<-YAML
    crds:
      enabled: true
    YAML
  ]
}

# Para exponer el DNS/IP del LB de ingress como output
data "kubernetes_service" "ingress_nginx_controller" {
  depends_on = [helm_release.ingress_nginx]

  metadata {
    name      = "ingress-nginx-controller"
    namespace = kubernetes_namespace.ingress_nginx.metadata[0].name
  }
}
