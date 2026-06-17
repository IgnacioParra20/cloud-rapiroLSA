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

variable "cloudwatch_alarm_email" {
  description = "Email opcional para recibir notificaciones de alarmas CloudWatch mediante SNS. Vacío deshabilita notificaciones."
  type        = string
  default     = ""
}

variable "cloudwatch_cpu_alarm_threshold" {
  description = "Porcentaje de CPU promedio que dispara la alarma de CPU alta."
  type        = number
  default     = 80
}

variable "cloudwatch_memory_alarm_threshold" {
  description = "Porcentaje de memoria usada que dispara la alarma de memoria alta reportada por CloudWatch Agent."
  type        = number
  default     = 85
}

variable "cloudwatch_disk_alarm_threshold" {
  description = "Porcentaje de disco usado que dispara la alarma de disco alto reportada por CloudWatch Agent."
  type        = number
  default     = 85
}

variable "cloudwatch_backend_error_alarm_threshold" {
  description = "Cantidad de errores de backend en un periodo de 5 minutos que dispara la alarma."
  type        = number
  default     = 1
}
