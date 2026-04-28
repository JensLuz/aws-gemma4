data "aws_ami" "deep_learning" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Deep Learning Base OSS Nvidia Driver GPU AMI (Ubuntu 22.04)*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_eip" "gemma" {
  domain = "vpc"

  tags = {
    Name    = "${var.project_name}-eip"
    Project = var.project_name
  }
}

locals {
  public_domain = "${replace(aws_eip.gemma.public_ip, ".", "-")}.sslip.io"

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    model_name     = var.model_name
    webui_title    = var.webui_title
    domain         = local.public_domain
    admin_email    = var.admin_email
    ollama_user     = var.ollama_basic_auth_user == null ? "" : var.ollama_basic_auth_user
    ollama_password = var.ollama_basic_auth_password == null ? "" : var.ollama_basic_auth_password
  })
}

resource "aws_instance" "gemma" {
  ami                    = data.aws_ami.deep_learning.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.gemma.key_name
  vpc_security_group_ids = [aws_security_group.gemma.id]
  subnet_id              = data.aws_subnets.default.ids[0]

  user_data                   = local.user_data
  user_data_replace_on_change = true

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    iops        = 6000
    throughput  = 1000
    encrypted   = true
  }

  dynamic "instance_market_options" {
    for_each = var.use_spot ? [1] : []
    content {
      market_type = "spot"
      spot_options {
        spot_instance_type = "one-time"
      }
    }
  }

  tags = {
    Name    = "${var.project_name}-host"
    Project = var.project_name
  }
}

resource "aws_eip_association" "gemma" {
  instance_id   = aws_instance.gemma.id
  allocation_id = aws_eip.gemma.id
}
