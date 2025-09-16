############################################
# Outputs
############################################

# URL final de Rancher (vacía si no se instala)
output "rancher_url" {
  description = "URL de Rancher cuando se instala"
  value       = local.rancher_hostname_clean != "" ? "https://${local.rancher_hostname_clean}" : ""
}

# (Opcional) Hostname/IP del LB de ingress-nginx, si ya tienes estos data/recursos
# data "kubernetes_service" "ingress_nginx_controller" {
#   metadata {
#     name      = "ingress-nginx-controller"
#     namespace = "ingress-nginx"
#   }
# }
# output "ingress_lb_hostname" {
#   value = try(data.kubernetes_service.ingress_nginx_controller.status[0].load_balancer[0].ingress[0].hostname, "")
# }
# output "ingress_lb_ip" {
#   value = try(data.kubernetes_service.ingress_nginx_controller.status[0].load_balancer[0].ingress[0].ip, "")
# }
