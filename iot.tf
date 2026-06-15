resource "aws_iot_thing" "rapiro" {
  name = local.iot_thing_name

  attributes = {
    Project     = var.project_name
    Environment = var.environment
    Device      = "RAPIRO"
  }
}

resource "aws_iot_topic_rule" "rapiro_to_lambda" {
  name        = local.iot_rule_name
  description = "Regla IoT que envía mensajes MQTT de RAPIRO hacia Lambda."
  enabled     = true
  sql_version = "2016-03-23"

  sql = "SELECT * FROM 'rapiro/lsa/keypoints'"

  lambda {
    function_arn = aws_lambda_function.inference.arn
  }

  tags = local.common_tags
}

resource "aws_lambda_permission" "allow_iot_invoke_lambda" {
  statement_id  = "AllowExecutionFromIoTCore"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.inference.function_name
  principal     = "iot.amazonaws.com"
  source_arn    = aws_iot_topic_rule.rapiro_to_lambda.arn
}

resource "aws_iot_policy" "rapiro_policy" {
  name = local.iot_policy_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iot:Connect"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iot:Publish"
        ]
        Resource = [
          "arn:aws:iot:${var.aws_region}:${data.aws_caller_identity.current.account_id}:topic/rapiro/lsa/keypoints"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "iot:Subscribe",
          "iot:Receive"
        ]
        Resource = "*"
      }
    ]
  })
}