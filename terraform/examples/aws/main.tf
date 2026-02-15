# XDC Node Deployment - AWS Example
# This example demonstrates deploying an XDC node on AWS EC2

terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ============================================
# Variables
# ============================================

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "node_name" {
  description = "Name of the XDC node"
  type        = string
  default     = "xdc-node-aws"
}

variable "network" {
  description = "XDC network (mainnet, testnet)"
  type        = string
  default     = "mainnet"
}

variable "client" {
  description = "XDC client (XDPoSChain, erigon-xdc)"
  type        = string
  default     = "XDPoSChain"
}

variable "node_type" {
  description = "Node type (full, archive, validator, rpc)"
  type        = string
  default     = "full"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "m6i.xlarge"  # 4 vCPU, 16 GB RAM
}

variable "data_volume_size" {
  description = "Size of data volume in GB"
  type        = number
  default     = 500
}

variable "ssh_key_name" {
  description = "Name of existing SSH key pair"
  type        = string
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = []  # Add your IP for security
}

variable "enable_public_rpc" {
  description = "Enable public RPC access"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

# ============================================
# Provider
# ============================================

provider "aws" {
  region = var.region
}

# ============================================
# Data Sources
# ============================================

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# ============================================
# Use the XDC Node Module
# ============================================

module "xdc_node" {
  source = "../../modules/xdc-node"

  node_name      = var.node_name
  network        = var.network
  client         = var.client
  node_type      = var.node_type
  cloud_provider = "aws"
  region         = var.region

  # Network settings
  enable_rpc        = true
  enable_ws         = false
  enable_metrics    = true
  enable_public_rpc = var.enable_public_rpc
  allowed_rpc_cidrs = var.enable_public_rpc ? ["0.0.0.0/0"] : ["10.0.0.0/8"]
  allowed_ssh_cidrs = var.allowed_ssh_cidrs

  # Storage
  data_volume_size = var.data_volume_size

  # Tags
  tags = merge(var.tags, {
    Project     = "XDC-Node"
    Environment = "production"
    ManagedBy   = "terraform"
  })
}

# ============================================
# VPC Configuration
# ============================================

resource "aws_vpc" "xdc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.node_name}-vpc"
  }
}

resource "aws_internet_gateway" "xdc" {
  vpc_id = aws_vpc.xdc.id

  tags = {
    Name = "${var.node_name}-igw"
  }
}

resource "aws_subnet" "xdc" {
  vpc_id                  = aws_vpc.xdc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.node_name}-subnet"
  }
}

resource "aws_route_table" "xdc" {
  vpc_id = aws_vpc.xdc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.xdc.id
  }

  tags = {
    Name = "${var.node_name}-rt"
  }
}

resource "aws_route_table_association" "xdc" {
  subnet_id      = aws_subnet.xdc.id
  route_table_id = aws_route_table.xdc.id
}

# ============================================
# Security Group
# ============================================

resource "aws_security_group" "xdc" {
  name_prefix = "${var.node_name}-sg"
  vpc_id      = aws_vpc.xdc.id

  # SSH
  dynamic "ingress" {
    for_each = length(var.allowed_ssh_cidrs) > 0 ? var.allowed_ssh_cidrs : []
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  # P2P TCP
  ingress {
    from_port   = 30303
    to_port     = 30303
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # P2P UDP
  ingress {
    from_port   = 30303
    to_port     = 30303
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # RPC (if public)
  dynamic "ingress" {
    for_each = var.enable_public_rpc ? [1] : []
    content {
      from_port   = 8545
      to_port     = 8545
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  # Metrics (internal only)
  ingress {
    from_port   = 6060
    to_port     = 6060
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  # Outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.node_name}-sg"
  }
}

# ============================================
# EC2 Instance
# ============================================

resource "aws_instance" "xdc" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.ssh_key_name
  vpc_security_group_ids = [aws_security_group.xdc.id]
  subnet_id              = aws_subnet.xdc.id

  root_block_device {
    volume_size           = 50
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = module.xdc_node.cloud_init_config

  tags = {
    Name        = var.node_name
    Network     = var.network
    Client      = var.client
    NodeType    = var.node_type
  }
}

# ============================================
# EBS Volume for Chain Data
# ============================================

resource "aws_ebs_volume" "xdc_data" {
  availability_zone = data.aws_availability_zones.available.names[0]
  size              = var.data_volume_size
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "${var.node_name}-data"
  }
}

resource "aws_volume_attachment" "xdc_data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.xdc_data.id
  instance_id = aws_instance.xdc.id
}

# ============================================
# Outputs
# ============================================

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.xdc.id
}

output "public_ip" {
  description = "Public IP address"
  value       = aws_instance.xdc.public_ip
}

output "rpc_endpoint" {
  description = "RPC endpoint"
  value       = "http://${aws_instance.xdc.public_ip}:8545"
}

output "ssh_command" {
  description = "SSH command"
  value       = "ssh ubuntu@${aws_instance.xdc.public_ip}"
}

output "enode_url" {
  description = "Enode URL for peering"
  value       = "enode://NODE_PUBLIC_KEY@${aws_instance.xdc.public_ip}:30303"
}
