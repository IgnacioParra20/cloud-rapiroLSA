data "archive_file" "lambda_inference" {
  type        = "zip"
  source_file = "${path.module}/lambda/app.py"
  output_path = "${path.module}/build/lambda_function.zip"
}

resource "aws_lambda_function" "inference" {
  function_name = "${var.project_name}-inference"

  role    = aws_iam_role.lambda_inference.arn
  handler = "app.handler"
  runtime = "python3.11"

  filename         = data.archive_file.lambda_inference.output_path
  source_code_hash = data.archive_file.lambda_inference.output_base64sha256

  timeout     = 10
  memory_size = 256

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.sessions.name
      S3_BUCKET      = aws_s3_bucket.model_artifacts.bucket
    }
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}
