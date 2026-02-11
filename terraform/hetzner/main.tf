terraform {
  required_version = ">= 1.3.0"
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
  }
}

provider "hcloud" {
  # Token set via HCLOUD_TOKEN environment variable
}

# Firewall
resource "hcloud_firewall" "xdc" {
  name = "${var.server_name}-firewall"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = var.allowed_ssh_ips
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "30303"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction = "in"
    protocol  = "udp"
    port      = "30303"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  dynamic "rule" {
    for_each = var.enable_public_rpc ? [1] : []
    content {
      direction  = "in"
      protocol   = "tcp"
      port       = "8545-8546"
      source_ips = var.allowed_rpc_ips
    }
  }

  rule {
    direction = "in"
    protocol  = "icmp"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

# Volume for chain data
resource "hcloud_volume" "xdc_data" {
  name      = "${var.server_name}-data"
  size      = var.data_volume_size
  server_id = hcloud_server.xdc.id
  format    = "ext4"
}

# Server
resource "hcloud_server" "xdc" {
  name        = var.server_name
  server_type = var.server_type
  image       = "ubuntu-22.04"
  location    = var.location
  ssh_keys    = var.ssh_key_ids
  firewall_ids = [hcloud_firewall.xdc.id]

  labels = merge(var.labels, {
    node_type = var.node_type
    network   = var.network
  })

  user_data = templatefile("${path.module}/cloud-init.yml", {
    node_type = var.node_type
    network   = var.network
    client    = var.client
  })
}
