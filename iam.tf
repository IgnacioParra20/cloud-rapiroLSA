# Rol asumible únicamente por AWS Lambda para ejecutar la inferencia de IA.
resource "aws_iam_role" "lambda_inference" {
  name = local.lambda_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Política de mínimo privilegio para la Lambda de inferencia:
# - Lee modelos/datasets desde el bucket privado S3.
# - Escribe y consulta registros de sesiones en DynamoDB.
# - Invoca Amazon Polly para síntesis de voz.
# - Escribe logs operativos en CloudWatch Logs para observabilidad básica.
resource "aws_iam_policy" "lambda_inference" {
  name        = local.lambda_policy_name
  description = "Permisos mínimos para inferencia RAPIRO-LSA: S3 read, DynamoDB sessions, Polly y logs."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadModelArtifactsFromS3"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.model_artifacts.arn,
          "${aws_s3_bucket.model_artifacts.arn}/*"
        ]
      },
      {
        Sid    = "WriteSessionHistoryToDynamoDB"
        Effect = "Allow"
        Action = [
          "dynamodb:BatchWriteItem",
          "dynamodb:DescribeTable",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:UpdateItem"
        ]
        Resource = aws_dynamodb_table.sessions.arn
      },
      {
        Sid    = "SynthesizeSpeechWithPolly"
        Effect = "Allow"
        Action = [
          "polly:SynthesizeSpeech"
        ]
        Resource = "*"
      },
      {
        Sid    = "WriteLambdaLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:${local.cloudwatch_log_group_name}",
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:${local.cloudwatch_log_group_name}:*"
        ]
      }
    ]
  })
}

# Asociación de la política al rol que usará la Lambda de inferencia.
resource "aws_iam_role_policy_attachment" "lambda_inference" {
  role       = aws_iam_role.lambda_inference.name
  policy_arn = aws_iam_policy.lambda_inference.arn
}
