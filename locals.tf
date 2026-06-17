locals {
  suffix            = var.resource_suffix == "" ? "" : "-${var.resource_suffix}"
  ec2_instance_type = coalesce(var.ec2_instance_type, var.instance_type)

  s3_bucket_name      = "${var.project_name}-models-datasets-${data.aws_caller_identity.current.account_id}${local.suffix}"
  dynamodb_table_name = "${var.project_name}-sessions${local.suffix}"
  ec2_backend_name    = "${var.project_name}-ec2-backend${local.suffix}"
  ec2_role_name       = "${var.project_name}-ec2-backend-role${local.suffix}"
  ec2_policy_name     = "${var.project_name}-ec2-backend-policy${local.suffix}"
  ec2_profile_name    = "${var.project_name}-ec2-backend-profile${local.suffix}"
  ec2_security_group  = "${var.project_name}-ec2-backend-sg${local.suffix}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Repository  = "cloud-rapiroLSA"
    ManagedBy   = "terraform"
  }
}
