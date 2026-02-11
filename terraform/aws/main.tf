terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# VPC Configuration
resource "aws_vpc" "xdc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.instance_name}-vpc"
  })
}

resource "aws_internet_gateway" "xdc" {
  vpc_id = aws_vpc.xdc.id

  tags = merge(var.tags, {
    Name = "${var.instance_name}-igw"
  })
}

resource "aws_subnet" "xdc" {
  vpc_id                  = aws_vpc.xdc.id
  cidr_block              = var.subnet_cidr
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.instance_name}-subnet"
  })
}

resource "aws_route_table" "xdc" {
  vpc_id = aws_vpc.xdc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.xdc.id
  }

  tags = merge(var.tags, {
    Name = "${var.instance_name}-rt"
  })
}

resource "aws_route_table_association" "xdc" {
  subnet_id      = aws_subnet.xdc.id
  route_table_id = aws_route_table.xdc.id
}

# Security Group
resource "aws_security_group" "xdc" {
  name_prefix = "${var.instance_name}-sg"
  vpc_id      = aws_vpc.xdc.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr
  }

  # XDC P2P TCP
  ingress {
    from_port   = 30303
    to_port     = 30303
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # XDC P2P UDP
  ingress {
    from_port   = 30303
    to_port     = 30303
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # RPC (restricted)
  dynamic "ingress" {
    for_each = var.enable_public_rpc ? [1] : []
    content {
      from_port   = 8545
      to_port     = 8545
      protocol    = "tcp"
      cidr_blocks = var.allowed_rpc_cidr
    }
  }

  # WebSocket (restricted)
  dynamic "ingress" {
    for_each = var.enable_public_rpc ? [1] : []
    content {
      from_port   = 8546
      to_port     = 8546
      protocol    = "tcp"
      cidr_blocks = var.allowed_rpc_cidr
    }
  }

  # Monitoring (internal only)
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.instance_name}-sg"
  })
}

# IAM Role for S3 backup access
resource "aws_iam_role" "xdc" {
  count = var.enable_s3_backup ? 1 : 0

  name = "${var.instance_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "xdc_s3" {
  count = var.enable_s3_backup ? 1 : 0

  name = "${var.instance_name}-s3-policy"
  role = aws_iam_role.xdc[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_backup_bucket}",
          "arn:aws:s3:::${var.s3_backup_bucket}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "xdc" {
  count = var.enable_s3_backup ? 1 : 0

  name = "${var.instance_name}-profile"
  role = aws_iam_role.xdc[0].name
}

# EBS Volume for chain data
resource "aws_ebs_volume" "xdc_data" {
  availability_zone = "${var.region}a"
  size              = var.data_volume_size
  type              = var.data_volume_type
  encrypted         = var.encrypt_volumes

  tags = merge(var.tags, {
    Name = "${var.instance_name}-data"
  })
}

# EC2 Instance
resource "aws_instance" "xdc" {
  ami                    = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.xdc.id]
  subnet_id              = aws_subnet.xdc.id
  iam_instance_profile   = var.enable_s3_backup ? aws_iam_instance_profile.xdc[0].name : null

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = var.encrypt_volumes
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/user-data.sh", {
    node_type = var.node_type
    network   = var.network
    client    = var.client
  })

  tags = merge(var.tags, {
    Name = var.instance_name
  })
}

resource "aws_volume_attachment" "xdc_data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.xdc_data.id
  instance_id = aws_instance.xdc.id
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
