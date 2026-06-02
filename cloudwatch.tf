resource "aws_cloudwatch_log_group" "lambda_inference_logs" {
  name              = "/aws/lambda/${aws_lambda_function.inference.function_name}"
  retention_in_days = 7

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}
resource "aws_cloudwatch_log_metric_filter" "lambda_error_filter" {
  name           = "${var.project_name}-lambda-error-filter"
  log_group_name = aws_cloudwatch_log_group.lambda_inference_logs.name
  pattern        = "ERROR"

  metric_transformation {
    name      = "${var.project_name}-lambda-errors"
    namespace = "RAPIRO-LSA/Lambda"
    value     = "1"
  }
}
resource "aws_cloudwatch_metric_alarm" "lambda_error_alarm" {
  alarm_name          = "${var.project_name}-lambda-error-alarm"
  alarm_description   = "Alarma cuando la Lambda de inferencia registra errores."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = aws_cloudwatch_log_metric_filter.lambda_error_filter.metric_transformation[0].name
  namespace           = "RAPIRO-LSA/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}