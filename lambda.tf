data "archive_file" "lambda_inference" {
  type        = "zip"
  source_file = "${path.module}/lambda/app.py"
  output_path = "${path.module}/build/lambda_function.zip"
}

resource "aws_lambda_function" "inference" {
  function_name = local.lambda_function_name

  role    = aws_iam_role.lambda_inference.arn
  handler = "app.handler"
  runtime = "python3.11"

  filename         = data.archive_file.lambda_inference.output_path
  source_code_hash = data.archive_file.lambda_inference.output_base64sha256

  timeout     = 10
  memory_size = 256

  environment {
    variables = {
      API_TOKEN        = var.api_token
      DYNAMODB_TABLE   = aws_dynamodb_table.sessions.name
      S3_BUCKET        = aws_s3_bucket.model_artifacts.bucket
      S3_EVENTS_PREFIX = "events/"
    }
  }

  tags = local.common_tags
}

resource "aws_lambda_function_url" "rapiro_ingest_url" {
  function_name      = aws_lambda_function.inference.function_name
  authorization_type = "NONE"

  cors {
    allow_origins = ["*"]
    allow_methods = ["POST"]
    allow_headers = ["content-type", "x-api-key"]
  }
}

resource "aws_lambda_permission" "allow_function_url_invoke" {
  statement_id           = "AllowExecutionFromLambdaFunctionUrl"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.inference.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}
