resource "aws_security_group" "ec2_backend" {
  count = var.enable_ec2_backend ? 1 : 0

  name        = local.ec2_security_group
  description = "Security Group para backend EC2 FastAPI RAPIRO-LSA"

  ingress {
    description = "FastAPI HTTP backend"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Outbound completo para instalar dependencias y acceder a AWS APIs"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name      = local.ec2_security_group
    Component = "ec2-backend"
  })
}

resource "aws_security_group_rule" "ec2_backend_ssh" {
  count = var.enable_ec2_backend && var.allowed_ssh_cidr != "" ? 1 : 0

  type              = "ingress"
  security_group_id = aws_security_group.ec2_backend[0].id
  description       = "SSH restringido por variable allowed_ssh_cidr"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.allowed_ssh_cidr]
}
