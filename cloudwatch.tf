locals {
  cloudwatch_backend_log_group = "/rapiro-lsa/ec2-backend/${var.aws_region}"
  cloudwatch_dashboard_name    = "${var.project_name}-monitoring${local.suffix}"
  cloudwatch_alarm_prefix      = "${var.project_name}${local.suffix}"
}

resource "aws_sns_topic" "monitoring_alerts" {
  count = var.enable_ec2_backend && var.enable_cloudwatch_monitoring && var.monitoring_alarm_email != "" ? 1 : 0

  name = "${local.cloudwatch_alarm_prefix}-monitoring-alerts"
}

resource "aws_sns_topic_subscription" "monitoring_alerts_email" {
  count = var.enable_ec2_backend && var.enable_cloudwatch_monitoring && var.monitoring_alarm_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.monitoring_alerts[0].arn
  protocol  = "email"
  endpoint  = var.monitoring_alarm_email
}

resource "aws_cloudwatch_metric_alarm" "ec2_cpu_high" {
  count = var.enable_ec2_backend && var.enable_cloudwatch_monitoring ? 1 : 0

  alarm_name          = "${local.cloudwatch_alarm_prefix}-ec2-cpu-high"
  alarm_description   = "CPU alta sostenida en el backend EC2 RAPIRO-LSA. No modifica la instancia; solo alerta."
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  threshold           = var.monitoring_cpu_high_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.rapiro_backend[0].id
  }

  alarm_actions = var.monitoring_alarm_email == "" ? [] : [aws_sns_topic.monitoring_alerts[0].arn]
  ok_actions    = var.monitoring_alarm_email == "" ? [] : [aws_sns_topic.monitoring_alerts[0].arn]
}

resource "aws_cloudwatch_metric_alarm" "ec2_status_check_failed" {
  count = var.enable_ec2_backend && var.enable_cloudwatch_monitoring ? 1 : 0

  alarm_name          = "${local.cloudwatch_alarm_prefix}-ec2-status-check-failed"
  alarm_description   = "Falla de status check en la instancia EC2 del backend RAPIRO-LSA. No modifica la instancia; solo alerta."
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.rapiro_backend[0].id
  }

  alarm_actions = var.monitoring_alarm_email == "" ? [] : [aws_sns_topic.monitoring_alerts[0].arn]
  ok_actions    = var.monitoring_alarm_email == "" ? [] : [aws_sns_topic.monitoring_alerts[0].arn]
}

resource "aws_cloudwatch_dashboard" "backend_monitoring" {
  count = var.enable_ec2_backend && var.enable_cloudwatch_monitoring ? 1 : 0

  dashboard_name = local.cloudwatch_dashboard_name

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "EC2 backend - CPU"
          region  = var.aws_region
          view    = "timeSeries"
          stacked = false
          period  = 300
          stat    = "Average"
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.rapiro_backend[0].id]
          ]
          annotations = {
            horizontal = [
              {
                label = "Umbral CPU alta"
                value = var.monitoring_cpu_high_threshold
              }
            ]
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "EC2 backend - status checks"
          region  = var.aws_region
          view    = "timeSeries"
          stacked = false
          period  = 60
          stat    = "Maximum"
          metrics = [
            ["AWS/EC2", "StatusCheckFailed", "InstanceId", aws_instance.rapiro_backend[0].id],
            [".", "StatusCheckFailed_Instance", ".", "."],
            [".", "StatusCheckFailed_System", ".", "."]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "EC2 backend - red"
          region  = var.aws_region
          view    = "timeSeries"
          stacked = false
          period  = 300
          stat    = "Sum"
          metrics = [
            ["AWS/EC2", "NetworkIn", "InstanceId", aws_instance.rapiro_backend[0].id],
            [".", "NetworkOut", ".", "."]
          ]
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Últimos errores del backend"
          region = var.aws_region
          query  = "SOURCE '${local.cloudwatch_backend_log_group}' | fields @timestamp, @logStream, @message | filter @message like /ERROR|Exception|Traceback|Request rejected/ | sort @timestamp desc | limit 50"
          view   = "table"
        }
      }
    ]
  })
}
