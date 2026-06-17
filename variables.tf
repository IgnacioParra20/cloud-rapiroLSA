variable "project_name" {
  description = "Nombre corto del proyecto usado como prefijo para los recursos AWS."
  type        = string
  default     = "rapiro-lsa"
}

variable "aws_region" {
  description = "AWS region donde se desplegará la infraestructura. Por defecto usa São Paulo para coincidir con el estado actual."
  type        = string
  default     = "sa-east-1"
}

variable "environment" {
  description = "Ambiente lógico de despliegue para etiquetado y separación de recursos."
  type        = string
  default     = "dev"
}

variable "resource_suffix" {
  description = "Sufijo opcional para diferenciar recursos por región o entorno. Por defecto coincide con sa-east-1."
  type        = string
  default     = "sae1"
}

variable "api_token" {
  description = "Token simple para proteger el backend EC2 FastAPI usado por RAPIRO/Python"
  type        = string
  sensitive   = true
}

variable "ec2_instance_type" {
  description = "Tipo de instancia EC2 para backend RAPIRO-LSA"
  type        = string
  default     = "t3.micro"
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
