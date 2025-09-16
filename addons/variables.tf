variable "region" {
  type        = string
  description = "AWS region, p.ej. us-east-1"
}

variable "aws_profile" {
  type        = string
  description = "Perfil de AWS CLI, p.ej. eks-operator"
}

variable "cluster_name" {
  type        = string
  description = "Nombre del clúster EKS"
}

# Importante para las 2 fases
variable "rancher_hostname" {
  description = "FQDN/hostname para Rancher; vacío = no instalar Rancher todavía"
  type        = string
  default     = ""
}

variable "rancher_admin_password" {
  description = "Password inicial del usuario admin de Rancher"
  type        = string
  sensitive   = true
}