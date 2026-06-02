data "aws_iam_role" "lambda_inference" {
  name = "rapiro-lsa-lambda-inference-role"
}

data "aws_dynamodb_table" "sessions" {
  name = "rapiro-lsa-sessions"
}

data "aws_s3_bucket" "models_datasets" {
  bucket = "rapiro-lsa-models-datasets-295552411532"
}

resource "aws_lambda_function" "inference" {
  function_name = "${var.project_name}-inference"

  role    = data.aws_iam_role.lambda_inference.arn
  handler = "app.handler"
  runtime = "python3.11"

  filename         = "${path.module}/lambda_function.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda_function.zip")

  timeout     = 10
  memory_size = 256

  environment {
    variables = {
      DYNAMODB_TABLE = data.aws_dynamodb_table.sessions.name
      S3_BUCKET      = data.aws_s3_bucket.models_datasets.bucket
    }
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}