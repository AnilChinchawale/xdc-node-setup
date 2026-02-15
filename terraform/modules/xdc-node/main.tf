# XDC Node Module - Main Configuration
# Reusable module for deploying XDC nodes across any cloud provider

terraform {
  required_version = ">= 1.3.0"
}

# Local values for computed configuration
locals {
  # Network-specific configurations
  network_config = {
    mainnet = {
      chain_id     = 50
      network_name = "XDC Mainnet"
      bootnodes    = "enode://abc@1.2.3.4:30303"
      genesis_url  = "https://raw.githubusercontent.com/XinFinOrg/XinFin-Node/master/mainnet/genesis.json"
    }
    testnet = {
      chain_id     = 51
      network_name = "XDC Apothem Testnet"
      bootnodes    = "enode://def@5.6.7.8:30303"
      genesis_url  = "https://raw.githubusercontent.com/XinFinOrg/XinFin-Node/master/testnet/genesis.json"
    }
    devnet = {
      chain_id     = 552
      network_name = "XDC Devnet"
      bootnodes    = ""
      genesis_url  = ""
    }
  }

  # Client-specific configurations
  client_config = {
    XDPoSChain = {
      image           = "xinfin/xdc-node:latest"
      binary_name     = "XDC"
      data_dir        = "/xdcchain"
      rpc_modules     = "eth,net,web3,txpool,debug"
      metrics_port    = 6060
      min_memory_gb   = 8
      min_storage_gb  = 500
    }
    "erigon-xdc" = {
      image           = "xinfinorg/erigon-xdc:latest"
      binary_name     = "erigon"
      data_dir        = "/data/erigon"
      rpc_modules     = "eth,net,web3,txpool,trace,debug"
      metrics_port    = 6060
      min_memory_gb   = 16
      min_storage_gb  = 1000
    }
  }

  # Node type configurations
  node_type_config = {
    full = {
      sync_mode = "snap"
      gcmode    = "full"
      archive   = false
    }
    archive = {
      sync_mode = "full"
      gcmode    = "archive"
      archive   = true
    }
    validator = {
      sync_mode = "snap"
      gcmode    = "full"
      archive   = false
      mining    = true
    }
    rpc = {
      sync_mode   = "snap"
      gcmode      = "full"
      archive     = false
      rpc_enabled = true
    }
  }

  # Selected configurations
  selected_network = local.network_config[var.network]
  selected_client  = local.client_config[var.client]
  selected_type    = local.node_type_config[var.node_type]

  # Resource tags
  common_tags = merge(var.tags, {
    "xdc:network"   = var.network
    "xdc:client"    = var.client
    "xdc:node-type" = var.node_type
    "xdc:managed"   = "terraform"
    "xdc:version"   = var.xdc_version
  })

  # Cloud-init user data
  cloud_init_config = templatefile("${path.module}/templates/cloud-init.yml.tpl", {
    network         = var.network
    client          = var.client
    node_type       = var.node_type
    node_name       = var.node_name
    rpc_enabled     = var.enable_rpc
    ws_enabled      = var.enable_ws
    metrics_enabled = var.enable_metrics
    bootnodes       = local.selected_network.bootnodes
    extra_flags     = var.extra_flags
    ssh_keys        = var.ssh_public_keys
  })
}

# Random suffix for unique naming
resource "random_id" "node" {
  byte_length = 4
}

# Generate node key if not provided
resource "tls_private_key" "node_key" {
  count     = var.node_private_key == "" ? 1 : 0
  algorithm = "ECDSA"
  ecdsa_curve = "P256"
}

# Store node key locally
resource "local_sensitive_file" "node_key" {
  count    = var.node_private_key == "" ? 1 : 0
  content  = tls_private_key.node_key[0].private_key_pem
  filename = "${path.root}/keys/${var.node_name}-nodekey.pem"
}

# Null resource for post-deployment validation
resource "null_resource" "validate_node" {
  count = var.enable_health_check ? 1 : 0

  triggers = {
    node_ip = var.node_ip
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for XDC node to be ready..."
      for i in {1..60}; do
        if curl -s -X POST -H "Content-Type: application/json" \
          --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
          http://${var.node_ip}:${var.rpc_port}/ > /dev/null 2>&1; then
          echo "Node is responding to RPC requests"
          exit 0
        fi
        echo "Attempt $i/60 - Node not ready yet..."
        sleep 10
      done
      echo "Warning: Node health check timed out"
      exit 0
    EOT
  }
}

# Data source for node status (after deployment)
data "http" "node_status" {
  count = var.enable_health_check && var.node_ip != "" ? 1 : 0

  url = "http://${var.node_ip}:${var.rpc_port}/"
  method = "POST"

  request_headers = {
    Content-Type = "application/json"
  }

  request_body = jsonencode({
    jsonrpc = "2.0"
    method  = "eth_syncing"
    params  = []
    id      = 1
  })

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "XDC node RPC is not responding"
    }
  }
}
