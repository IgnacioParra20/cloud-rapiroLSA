terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Proveedor principal de AWS para RAPIRO-LSA.
# us-east-1 es una de las regiones con mayor disponibilidad de servicios
# y aplica a la Capa Gratuita de AWS para los recursos definidos aquí.
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# Datos de la cuenta actual para construir ARNs y nombres únicos.
data "aws_caller_identity" "current" {}
