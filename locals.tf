locals {
  suffix = var.resource_suffix == "" ? "" : "-${var.resource_suffix}"

  s3_bucket_name       = "${var.project_name}-models-datasets-${data.aws_caller_identity.current.account_id}${local.suffix}"
  dynamodb_table_name  = "${var.project_name}-sessions${local.suffix}"
  lambda_function_name = "${var.project_name}-inference${local.suffix}"

  lambda_role_name   = "${var.project_name}-lambda-inference-role${local.suffix}"
  lambda_policy_name = "${var.project_name}-lambda-inference-policy${local.suffix}"

  ec2_backend_name          = "${var.project_name}-ec2-backend${local.suffix}"
  ec2_role_name             = "${var.project_name}-ec2-backend-role${local.suffix}"
  ec2_policy_name           = "${var.project_name}-ec2-backend-policy${local.suffix}"
  ec2_instance_profile_name = "${var.project_name}-ec2-backend-profile${local.suffix}"
  ec2_security_group_name   = "${var.project_name}-ec2-backend-sg${local.suffix}"

  cloudwatch_log_group_name = "/aws/lambda/${local.lambda_function_name}"

  iot_thing_name  = "${var.project_name}-thing${local.suffix}"
  iot_policy_name = "${var.project_name}-iot-policy${local.suffix}"
  iot_rule_name   = replace("${var.project_name}-rapiro-to-lambda${local.suffix}", "-", "_")

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Repository  = "cloud-rapiroLSA"
    ManagedBy   = "terraform"
  }
}
