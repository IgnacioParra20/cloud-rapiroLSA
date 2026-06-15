output "aws_region" {
  description = "Región AWS activa para este workspace."
  value       = var.aws_region
}

output "resource_suffix" {
  description = "Sufijo aplicado a los recursos de este workspace."
  value       = var.resource_suffix
}

output "s3_bucket_name" {
  description = "Nombre del bucket S3 privado para modelos entrenados, datasets y evidencias."
  value       = aws_s3_bucket.model_artifacts.bucket
}

output "s3_bucket_arn" {
  description = "ARN del bucket S3 privado para modelos entrenados, datasets y evidencias."
  value       = aws_s3_bucket.model_artifacts.arn
}

output "dynamodb_table_name" {
  description = "Nombre de la tabla DynamoDB de historial de sesiones."
  value       = aws_dynamodb_table.sessions.name
}

output "dynamodb_table_arn" {
  description = "ARN de la tabla DynamoDB de historial de sesiones."
  value       = aws_dynamodb_table.sessions.arn
}

output "ec2_backend_public_ip" {
  description = "IP pública del backend EC2 principal. Null si enable_ec2_backend=false."
  value       = var.enable_ec2_backend ? aws_instance.rapiro_backend[0].public_ip : null
}

output "ec2_backend_public_dns" {
  description = "DNS público del backend EC2 principal. Null si enable_ec2_backend=false."
  value       = var.enable_ec2_backend ? aws_instance.rapiro_backend[0].public_dns : null
}

output "ec2_backend_url" {
  description = "URL base HTTP del backend EC2 FastAPI. Null si enable_ec2_backend=false."
  value       = var.enable_ec2_backend ? "http://${aws_instance.rapiro_backend[0].public_ip}:8000" : null
}

output "ec2_instance_id" {
  description = "ID de la instancia EC2 backend. Null si enable_ec2_backend=false."
  value       = var.enable_ec2_backend ? aws_instance.rapiro_backend[0].id : null
}
