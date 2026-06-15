# Proveedor principal de AWS para RAPIRO-LSA.
# La región se define por variable para soportar despliegues por workspace/región.
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# Datos de la cuenta actual para construir ARNs y nombres únicos.
data "aws_caller_identity" "current" {}
