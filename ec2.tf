data "aws_ami" "ubuntu_lts" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "rapiro_backend" {
  count = var.enable_ec2_backend ? 1 : 0

  ami                         = data.aws_ami.ubuntu_lts.id
  instance_type               = var.ec2_instance_type
  iam_instance_profile        = aws_iam_instance_profile.ec2_backend[0].name
  vpc_security_group_ids      = [aws_security_group.ec2_backend[0].id]
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/ec2_user_data.sh", {
    main_py                 = file("${path.module}/ec2_app/main.py")
    requirements_txt        = file("${path.module}/ec2_app/requirements.txt")
    requirements_vision_txt = file("${path.module}/ec2_app/requirements-vision.txt")
    ec2_diagnose_sh         = file("${path.module}/scripts/ec2_diagnose.sh")
    ec2_restart_backend_sh  = file("${path.module}/scripts/ec2_restart_backend.sh")
    dynamodb_table          = aws_dynamodb_table.sessions.name
    s3_bucket               = aws_s3_bucket.model_artifacts.bucket
    s3_events_prefix        = "events/"
    aws_region              = var.aws_region
    api_token               = var.api_token
  })

  user_data_replace_on_change = true

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  tags = merge(local.common_tags, {
    Name      = local.ec2_backend_name
    Component = "ec2-backend"
  })
}
