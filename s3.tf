# Bucket privado para modelos entrenados (MLP/LSTM) y datasets como LSA64.
# Se agrega el Account ID al nombre para cumplir la unicidad global requerida por S3.
resource "aws_s3_bucket" "model_artifacts" {
  bucket = local.s3_bucket_name
}

# Bloqueo explícito de acceso público: defensa en profundidad para artefactos de IA y datasets.
resource "aws_s3_bucket_public_access_block" "model_artifacts" {
  bucket = aws_s3_bucket.model_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versionado para conservar historial de modelos y poder volver a versiones anteriores.
resource "aws_s3_bucket_versioning" "model_artifacts" {
  bucket = aws_s3_bucket.model_artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Cifrado del lado del servidor con claves administradas por S3 (SSE-S3), sin costo adicional.
resource "aws_s3_bucket_server_side_encryption_configuration" "model_artifacts" {
  bucket = aws_s3_bucket.model_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Propiedad de objetos simplificada: deshabilita ACLs y evita exposiciones accidentales.
resource "aws_s3_bucket_ownership_controls" "model_artifacts" {
  bucket = aws_s3_bucket.model_artifacts.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
