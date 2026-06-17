variable "project_name" {
  description = "Nombre corto del proyecto usado como prefijo para los recursos AWS."
  type        = string
  default     = "rapiro-lsa"
}

variable "aws_region" {
  description = "AWS region donde se desplegará la infraestructura"
  type        = string
  default     = "sa-east-1"
}

variable "environment" {
  description = "Ambiente lógico de despliegue para etiquetado y separación de recursos."
  type        = string
  default     = "dev"
}

variable "resource_suffix" {
  description = "Sufijo opcional para diferenciar recursos por región o entorno"
  type        = string
  default     = "sae1"
}

variable "instance_type" {
  description = "Tipo de instancia EC2 para backend RAPIRO-LSA. Nombre preferido para nuevas configuraciones."
  type        = string
  default     = "t3.medium"
}

variable "api_token" {
  description = "Token simple para proteger el backend EC2 FastAPI usado por RAPIRO/Python"
  type        = string
  sensitive   = true
}

variable "ec2_instance_type" {
  description = "Compatibilidad hacia atrás: tipo de instancia EC2. Si se define, sobrescribe instance_type."
  type        = string
  default     = null
  nullable    = true
}

variable "enable_ec2_backend" {
  description = "Habilita backend EC2 para procesamiento continuo"
  type        = bool
  default     = true
}

variable "allowed_ssh_cidr" {
  description = "CIDR permitido para SSH. Vacío para no abrir SSH."
  type        = string
  default     = ""
}
