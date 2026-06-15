output "aws_region" {
  description = "Región AWS activa para este workspace."
  value       = var.aws_region
}

output "resource_suffix" {
  description = "Sufijo aplicado a los recursos de este workspace."
  value       = var.resource_suffix
}

output "s3_bucket_name" {
  description = "Nombre del bucket S3 privado para modelos entrenados y datasets."
  value       = aws_s3_bucket.model_artifacts.bucket
}

output "s3_bucket_arn" {
  description = "ARN del bucket S3 privado para modelos entrenados y datasets."
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

output "lambda_inference_role_name" {
  description = "Nombre del rol IAM para la Lambda de inferencia."
  value       = aws_iam_role.lambda_inference.name
}

output "lambda_inference_role_arn" {
  description = "ARN del rol IAM para la Lambda de inferencia."
  value       = aws_iam_role.lambda_inference.arn
}

output "lambda_inference_policy_arn" {
  description = "ARN de la política IAM adjunta al rol de inferencia."
  value       = aws_iam_policy.lambda_inference.arn
}

output "lambda_inference_function_name" {
  description = "Nombre de la función Lambda de inferencia."
  value       = aws_lambda_function.inference.function_name
}

output "lambda_inference_function_arn" {
  description = "ARN de la función Lambda de inferencia."
  value       = aws_lambda_function.inference.arn
}

output "cloudwatch_lambda_log_group" {
  description = "Grupo de logs de CloudWatch para la Lambda de inferencia."
  value       = aws_cloudwatch_log_group.lambda_inference_logs.name
}

output "iot_thing_name" {
  description = "Nombre del Thing IoT que representa al robot RAPIRO."
  value       = aws_iot_thing.rapiro.name
}

output "iot_topic_rule_name" {
  description = "Nombre de la regla IoT que invoca Lambda."
  value       = aws_iot_topic_rule.rapiro_to_lambda.name
}

output "iot_mqtt_topic" {
  description = "Topic MQTT usado para enviar eventos desde RAPIRO."
  value       = "rapiro/lsa/keypoints"
}

output "lambda_function_url" {
  description = "URL HTTP principal para registrar eventos detectados por RAPIRO"
  value       = aws_lambda_function_url.rapiro_ingest_url.function_url
}
