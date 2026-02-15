# XDC Node Deployment - Hetzner Cloud Example
# This example demonstrates deploying an XDC node on Hetzner Cloud

terraform {
  required_version = ">= 1.3.0"
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
  }
}

# ============================================
# Variables
# ============================================

variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

variable "location" {
  description = "Hetzner location (nbg1, fsn1, hel1)"
  type        = string
  default     = "nbg1"  # Nuremberg
}

variable "node_name" {
  description = "Name of the XDC node"
  type        = string
  default     = "xdc-node-hetzner"
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

variable "server_type" {
  description = "Hetzner server type"
  type        = string
  default     = "cpx31"  # 4 vCPU, 8 GB RAM, 160 GB NVMe
}

variable "data_volume_size" {
  description = "Size of data volume in GB"
  type        = number
  default     = 500
}

variable "ssh_public_keys" {
  description = "SSH public keys"
  type        = list(string)
}

variable "enable_public_rpc" {
  description = "Enable public RPC access"
  type        = bool
  default     = false
}

variable "enable_ipv6" {
  description = "Enable IPv6"
  type        = bool
  default     = true
}

variable "labels" {
  description = "Labels for resources"
  type        = map(string)
  default = {
    project = "xdc-node"
    managed = "terraform"
  }
}

# ============================================
# Provider
# ============================================

provider "hcloud" {
  token = var.hcloud_token
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
  cloud_provider = "hetzner"
  region         = var.location

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
# SSH Keys
# ============================================

resource "hcloud_ssh_key" "xdc" {
  count      = length(var.ssh_public_keys)
  name       = "${var.node_name}-key-${count.index}"
  public_key = var.ssh_public_keys[count.index]
  labels     = var.labels
}

# ============================================
# Network
# ============================================

resource "hcloud_network" "xdc" {
  name     = "${var.node_name}-network"
  ip_range = "10.0.0.0/16"
  labels   = var.labels
}

resource "hcloud_network_subnet" "xdc" {
  network_id   = hcloud_network.xdc.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.1.0/24"
}

# ============================================
# Firewall
# ============================================

resource "hcloud_firewall" "xdc" {
  name   = "${var.node_name}-firewall"
  labels = var.labels

  # SSH
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = ["0.0.0.0/0", "::/0"]  # Restrict in production
  }

  # P2P TCP
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "30303"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  # P2P UDP
  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "30303"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  # RPC (conditionally public)
  dynamic "rule" {
    for_each = var.enable_public_rpc ? [1] : []
    content {
      direction  = "in"
      protocol   = "tcp"
      port       = "8545"
      source_ips = ["0.0.0.0/0", "::/0"]
    }
  }

  # Metrics (internal only)
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "6060"
    source_ips = ["10.0.0.0/16"]
  }

  # All outbound
  rule {
    direction       = "out"
    protocol        = "tcp"
    port            = "1-65535"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction       = "out"
    protocol        = "udp"
    port            = "1-65535"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction       = "out"
    protocol        = "icmp"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }
}

# ============================================
# Server
# ============================================

resource "hcloud_server" "xdc" {
  name        = var.node_name
  server_type = var.server_type
  image       = "ubuntu-22.04"
  location    = var.location
  ssh_keys    = hcloud_ssh_key.xdc[*].id
  labels      = var.labels

  public_net {
    ipv4_enabled = true
    ipv6_enabled = var.enable_ipv6
  }

  network {
    network_id = hcloud_network.xdc.id
    ip         = "10.0.1.10"
  }

  firewall_ids = [hcloud_firewall.xdc.id]

  user_data = base64decode(module.xdc_node.cloud_init_config)

  depends_on = [
    hcloud_network_subnet.xdc
  ]
}

# ============================================
# Volume
# ============================================

resource "hcloud_volume" "xdc_data" {
  name      = "${var.node_name}-data"
  size      = var.data_volume_size
  location  = var.location
  format    = "ext4"
  labels    = var.labels
}

resource "hcloud_volume_attachment" "xdc_data" {
  volume_id = hcloud_volume.xdc_data.id
  server_id = hcloud_server.xdc.id
  automount = true
}

# ============================================
# Floating IP (Optional)
# ============================================

resource "hcloud_floating_ip" "xdc" {
  type          = "ipv4"
  home_location = var.location
  labels        = var.labels
}

resource "hcloud_floating_ip_assignment" "xdc" {
  floating_ip_id = hcloud_floating_ip.xdc.id
  server_id      = hcloud_server.xdc.id
}

# ============================================
# Outputs
# ============================================

output "server_id" {
  description = "Server ID"
  value       = hcloud_server.xdc.id
}

output "public_ip" {
  description = "Public IP address"
  value       = hcloud_floating_ip.xdc.ip_address
}

output "server_ip" {
  description = "Server's primary public IP"
  value       = hcloud_server.xdc.ipv4_address
}

output "private_ip" {
  description = "Private IP address"
  value       = hcloud_server.xdc.network[*].ip
}

output "ipv6_address" {
  description = "IPv6 address"
  value       = var.enable_ipv6 ? hcloud_server.xdc.ipv6_address : null
}

output "rpc_endpoint" {
  description = "RPC endpoint"
  value       = "http://${hcloud_floating_ip.xdc.ip_address}:8545"
}

output "ssh_command" {
  description = "SSH command"
  value       = "ssh root@${hcloud_floating_ip.xdc.ip_address}"
}

output "enode_url" {
  description = "Enode URL for peering"
  value       = "enode://NODE_PUBLIC_KEY@${hcloud_floating_ip.xdc.ip_address}:30303"
}

output "volume_id" {
  description = "Data volume ID"
  value       = hcloud_volume.xdc_data.id
}
