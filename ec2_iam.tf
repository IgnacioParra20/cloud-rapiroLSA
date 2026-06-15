resource "aws_iam_role" "ec2_backend" {
  count = var.enable_ec2_backend ? 1 : 0

  name = local.ec2_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_policy" "ec2_backend" {
  count = var.enable_ec2_backend ? 1 : 0

  name        = local.ec2_policy_name
  description = "Permisos para backend EC2 RAPIRO-LSA: DynamoDB, S3 y CloudWatch Logs."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "WriteAndReadSessionHistory"
        Effect = "Allow"
        Action = [
          "dynamodb:DescribeTable",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = aws_dynamodb_table.sessions.arn
      },
      {
        Sid    = "ReadWriteEvidenceBucket"
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
        Sid    = "WriteBasicCloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ec2_backend" {
  count = var.enable_ec2_backend ? 1 : 0

  role       = aws_iam_role.ec2_backend[0].name
  policy_arn = aws_iam_policy.ec2_backend[0].arn
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_managed_instance_core" {
  count = var.enable_ec2_backend ? 1 : 0

  role       = aws_iam_role.ec2_backend[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_backend" {
  count = var.enable_ec2_backend ? 1 : 0

  name = local.ec2_instance_profile_name
  role = aws_iam_role.ec2_backend[0].name

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ec2_cloudwatch_agent_server_policy" {
  count = var.enable_ec2_backend ? 1 : 0

  role       = aws_iam_role.ec2_backend[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
