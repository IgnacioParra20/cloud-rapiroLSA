variable "project_name" {
  description = "Nombre corto del proyecto usado como prefijo para los recursos AWS."
  type        = string
  default     = "rapiro-lsa"
}

variable "aws_region" {
  description = "Región AWS donde se desplegará la infraestructura base."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Ambiente lógico de despliegue para etiquetado y separación de recursos."
  type        = string
  default     = "dev"
}

variable "lambda_function_name" {
  description = "Nombre esperado de la función Lambda de inferencia; se usa para limitar permisos de logs."
  type        = string
  default     = "rapiro-lsa-inference"
}

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Repository  = "cloud-rapiroLSA"
  }
}
