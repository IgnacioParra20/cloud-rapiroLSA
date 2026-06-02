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