# XDC Node Deployment - DigitalOcean Example
# This example demonstrates deploying an XDC node on DigitalOcean

terraform {
  required_version = ">= 1.3.0"
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

# ============================================
# Variables
# ============================================

variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "DigitalOcean region"
  type        = string
  default     = "nyc3"
}

variable "node_name" {
  description = "Name of the XDC node"
  type        = string
  default     = "xdc-node-do"
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

variable "droplet_size" {
  description = "Droplet size"
  type        = string
  default     = "s-4vcpu-8gb-amd"  # 4 vCPU, 8 GB RAM
}

variable "data_volume_size" {
  description = "Size of data volume in GB"
  type        = number
  default     = 500
}

variable "ssh_key_ids" {
  description = "List of SSH key IDs to add to the droplet"
  type        = list(string)
  default     = []
}

variable "ssh_public_keys" {
  description = "SSH public keys (if not using existing keys)"
  type        = list(string)
  default     = []
}

variable "enable_public_rpc" {
  description = "Enable public RPC access"
  type        = bool
  default     = false
}

variable "enable_monitoring" {
  description = "Enable DigitalOcean monitoring"
  type        = bool
  default     = true
}

variable "enable_backups" {
  description = "Enable DigitalOcean backups"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags for the droplet"
  type        = list(string)
  default     = ["xdc-node", "blockchain"]
}

# ============================================
# Provider
# ============================================

provider "digitalocean" {
  token = var.do_token
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
  cloud_provider = "digitalocean"
  region         = var.region

  # Network settings
  enable_rpc        = true
  enable_ws         = false
  enable_metrics    = true
  enable_public_rpc = var.enable_public_rpc

  # Storage
  data_volume_size = var.data_volume_size

  # SSH keys
  ssh_public_keys = var.ssh_public_keys

  # Tags
  tags = {
    Project     = "XDC-Node"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

# ============================================
# VPC
# ============================================

resource "digitalocean_vpc" "xdc" {
  name     = "${var.node_name}-vpc"
  region   = var.region
  ip_range = "10.10.10.0/24"
}

# ============================================
# Firewall
# ============================================

resource "digitalocean_firewall" "xdc" {
  name = "${var.node_name}-firewall"

  droplet_ids = [digitalocean_droplet.xdc.id]

  # SSH
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]  # Restrict in production
  }

  # P2P TCP
  inbound_rule {
    protocol         = "tcp"
    port_range       = "30303"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # P2P UDP
  inbound_rule {
    protocol         = "udp"
    port_range       = "30303"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # RPC (conditionally public)
  dynamic "inbound_rule" {
    for_each = var.enable_public_rpc ? [1] : []
    content {
      protocol         = "tcp"
      port_range       = "8545"
      source_addresses = ["0.0.0.0/0", "::/0"]
    }
  }

  # Metrics (internal only)
  inbound_rule {
    protocol         = "tcp"
    port_range       = "6060"
    source_addresses = ["10.10.10.0/24"]
  }

  # All outbound
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

# ============================================
# Droplet
# ============================================

resource "digitalocean_droplet" "xdc" {
  name     = var.node_name
  region   = var.region
  size     = var.droplet_size
  image    = "ubuntu-22-04-x64"
  vpc_uuid = digitalocean_vpc.xdc.id

  ssh_keys   = var.ssh_key_ids
  monitoring = var.enable_monitoring
  backups    = var.enable_backups

  user_data = base64decode(module.xdc_node.cloud_init_config)

  tags = var.tags
}

# ============================================
# Block Storage Volume
# ============================================

resource "digitalocean_volume" "xdc_data" {
  name                    = "${var.node_name}-data"
  region                  = var.region
  size                    = var.data_volume_size
  initial_filesystem_type = "ext4"
  description             = "XDC node chain data"

  tags = var.tags
}

resource "digitalocean_volume_attachment" "xdc_data" {
  droplet_id = digitalocean_droplet.xdc.id
  volume_id  = digitalocean_volume.xdc_data.id
}

# ============================================
# Reserved IP (Optional)
# ============================================

resource "digitalocean_reserved_ip" "xdc" {
  region = var.region
}

resource "digitalocean_reserved_ip_assignment" "xdc" {
  ip_address = digitalocean_reserved_ip.xdc.ip_address
  droplet_id = digitalocean_droplet.xdc.id
}

# ============================================
# Outputs
# ============================================

output "droplet_id" {
  description = "Droplet ID"
  value       = digitalocean_droplet.xdc.id
}

output "public_ip" {
  description = "Public IP address"
  value       = digitalocean_reserved_ip.xdc.ip_address
}

output "private_ip" {
  description = "Private IP address"
  value       = digitalocean_droplet.xdc.ipv4_address_private
}

output "rpc_endpoint" {
  description = "RPC endpoint"
  value       = "http://${digitalocean_reserved_ip.xdc.ip_address}:8545"
}

output "ssh_command" {
  description = "SSH command"
  value       = "ssh root@${digitalocean_reserved_ip.xdc.ip_address}"
}

output "enode_url" {
  description = "Enode URL for peering"
  value       = "enode://NODE_PUBLIC_KEY@${digitalocean_reserved_ip.xdc.ip_address}:30303"
}

output "volume_id" {
  description = "Data volume ID"
  value       = digitalocean_volume.xdc_data.id
}
