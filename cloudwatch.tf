locals {
  cloudwatch_alarm_actions = var.enable_ec2_backend && var.cloudwatch_alarm_email != "" ? [aws_sns_topic.cloudwatch_alarms[0].arn] : []
  cloudwatch_log_group     = "/rapiro-lsa/ec2-backend/${var.aws_region}"
}

resource "aws_cloudwatch_log_group" "ec2_backend" {
  count = var.enable_ec2_backend ? 1 : 0

  name              = local.cloudwatch_log_group
  retention_in_days = 7

  tags = local.common_tags
}

resource "aws_sns_topic" "cloudwatch_alarms" {
  count = var.enable_ec2_backend && var.cloudwatch_alarm_email != "" ? 1 : 0

  name = "${var.project_name}-cloudwatch-alarms${local.suffix}"

  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "cloudwatch_alarm_email" {
  count = var.enable_ec2_backend && var.cloudwatch_alarm_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.cloudwatch_alarms[0].arn
  protocol  = "email"
  endpoint  = var.cloudwatch_alarm_email
}

resource "aws_cloudwatch_metric_alarm" "ec2_status_check_failed" {
  count = var.enable_ec2_backend ? 1 : 0

  alarm_name          = "${local.ec2_backend_name}-status-check-failed"
  alarm_description   = "La instancia EC2 del backend RAPIRO-LSA falló un status check de AWS."
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.cloudwatch_alarm_actions
  ok_actions          = local.cloudwatch_alarm_actions

  dimensions = {
    InstanceId = aws_instance.rapiro_backend[0].id
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "ec2_high_cpu" {
  count = var.enable_ec2_backend ? 1 : 0

  alarm_name          = "${local.ec2_backend_name}-high-cpu"
  alarm_description   = "CPU alta sostenida en la instancia EC2 del backend RAPIRO-LSA."
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.cloudwatch_cpu_alarm_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.cloudwatch_alarm_actions
  ok_actions          = local.cloudwatch_alarm_actions

  dimensions = {
    InstanceId = aws_instance.rapiro_backend[0].id
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "ec2_high_memory" {
  count = var.enable_ec2_backend ? 1 : 0

  alarm_name          = "${local.ec2_backend_name}-high-memory"
  alarm_description   = "Memoria alta sostenida reportada por CloudWatch Agent en el backend RAPIRO-LSA."
  namespace           = "CWAgent"
  metric_name         = "mem_used_percent"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.cloudwatch_memory_alarm_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = local.cloudwatch_alarm_actions
  ok_actions          = local.cloudwatch_alarm_actions

  dimensions = {
    InstanceId = aws_instance.rapiro_backend[0].id
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "ec2_high_disk" {
  count = var.enable_ec2_backend ? 1 : 0

  alarm_name          = "${local.ec2_backend_name}-high-disk"
  alarm_description   = "Disco alto sostenido reportado por CloudWatch Agent en el backend RAPIRO-LSA."
  namespace           = "CWAgent"
  metric_name         = "disk_used_percent"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.cloudwatch_disk_alarm_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = local.cloudwatch_alarm_actions
  ok_actions          = local.cloudwatch_alarm_actions

  dimensions = {
    InstanceId = aws_instance.rapiro_backend[0].id
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_log_metric_filter" "backend_errors" {
  count = var.enable_ec2_backend ? 1 : 0

  name           = "${local.ec2_backend_name}-backend-errors"
  log_group_name = aws_cloudwatch_log_group.ec2_backend[0].name
  pattern        = "{ $.level = \"ERROR\" }"

  metric_transformation {
    name      = "BackendErrors"
    namespace = "RAPIRO-LSA/Backend"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "backend_log_events" {
  count = var.enable_ec2_backend ? 1 : 0

  name           = "${local.ec2_backend_name}-backend-log-events"
  log_group_name = aws_cloudwatch_log_group.ec2_backend[0].name
  pattern        = ""

  metric_transformation {
    name          = "BackendLogEvents"
    namespace     = "RAPIRO-LSA/Backend"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "backend_errors" {
  count = var.enable_ec2_backend ? 1 : 0

  alarm_name          = "${local.ec2_backend_name}-backend-errors"
  alarm_description   = "El backend RAPIRO-LSA registró errores en CloudWatch Logs."
  namespace           = "RAPIRO-LSA/Backend"
  metric_name         = "BackendErrors"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = var.cloudwatch_backend_error_alarm_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.cloudwatch_alarm_actions
  ok_actions          = local.cloudwatch_alarm_actions

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "backend_no_recent_logs" {
  count = var.enable_ec2_backend ? 1 : 0

  alarm_name          = "${local.ec2_backend_name}-no-recent-logs"
  alarm_description   = "No llegaron logs recientes del backend RAPIRO-LSA; puede indicar caída del servicio o del CloudWatch Agent."
  namespace           = "RAPIRO-LSA/Backend"
  metric_name         = "BackendLogEvents"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 3
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = local.cloudwatch_alarm_actions
  ok_actions          = local.cloudwatch_alarm_actions

  tags = local.common_tags
}

resource "aws_cloudwatch_dashboard" "rapiro_backend" {
  count = var.enable_ec2_backend ? 1 : 0

  dashboard_name = "${local.ec2_backend_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "EC2 CPU / Status"
          region  = var.aws_region
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.rapiro_backend[0].id, { stat = "Average" }],
            ["AWS/EC2", "StatusCheckFailed", "InstanceId", aws_instance.rapiro_backend[0].id, { stat = "Maximum", yAxis = "right" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Memoria / Disco (CloudWatch Agent)"
          region  = var.aws_region
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["CWAgent", "mem_used_percent", "InstanceId", aws_instance.rapiro_backend[0].id, { stat = "Average" }],
            ["CWAgent", "disk_used_percent", "InstanceId", aws_instance.rapiro_backend[0].id, { stat = "Average" }]
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
          title   = "Errores y actividad del backend"
          region  = var.aws_region
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["RAPIRO-LSA/Backend", "BackendErrors", { stat = "Sum" }],
            ["RAPIRO-LSA/Backend", "BackendLogEvents", { stat = "Sum" }]
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
          title  = "Últimos errores backend"
          region = var.aws_region
          query  = "SOURCE '${local.cloudwatch_log_group}' | fields @timestamp, level, message, session_id, detected_sign, confidence | filter level = 'ERROR' or @message like /ERROR/ | sort @timestamp desc | limit 20"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 12
        width  = 24
        height = 6
        properties = {
          title  = "Frames procesados"
          region = var.aws_region
          query  = "SOURCE '${local.cloudwatch_log_group}' | fields @timestamp, session_id, device_id, detected_sign, confidence, stable, keypoints_count, mediapipe_available | filter event = 'frame_processed' | sort @timestamp desc | limit 50"
        }
      }
    ]
  })
}
