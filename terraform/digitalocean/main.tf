terraform {
  required_version = ">= 1.3.0"
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  # Token set via DIGITALOCEAN_TOKEN environment variable
}

# Firewall
resource "digitalocean_firewall" "xdc" {
  name = "${var.droplet_name}-firewall"

  droplet_ids = [digitalocean_droplet.xdc.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = var.allowed_ssh_ips
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "30303"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "udp"
    port_range       = "30303"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  dynamic "inbound_rule" {
    for_each = var.enable_public_rpc ? [1] : []
    content {
      protocol         = "tcp"
      port_range       = "8545-8546"
      source_addresses = var.allowed_rpc_ips
    }
  }

  inbound_rule {
    protocol         = "icmp"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

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
}

# Volume for chain data
resource "digitalocean_volume" "xdc_data" {
  region                  = var.region
  name                    = "${var.droplet_name}-data"
  size                    = var.data_volume_size
  initial_filesystem_type = "ext4"
}

resource "digitalocean_volume_attachment" "xdc_data" {
  droplet_id = digitalocean_droplet.xdc.id
  volume_id  = digitalocean_volume.xdc_data.id
}

# Droplet
resource "digitalocean_droplet" "xdc" {
  name       = var.droplet_name
  size       = var.size
  image      = "ubuntu-22-04-x64"
  region     = var.region
  ssh_keys   = var.ssh_key_ids
  monitoring = true

  user_data = templatefile("${path.module}/cloud-init.yml", {
    node_type = var.node_type
    network   = var.network
    client    = var.client
  })

  tags = concat(var.tags, ["xdc-node", var.node_type, var.network])
}
