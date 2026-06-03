# Proveedor principal de AWS para RAPIRO-LSA.
# us-east-2 es la region configurada para desplegar esta infraestructura
# y aplica a la Capa Gratuita de AWS para los recursos definidos aquí.
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# Datos de la cuenta actual para construir ARNs y nombres únicos.
data "aws_caller_identity" "current" {}
