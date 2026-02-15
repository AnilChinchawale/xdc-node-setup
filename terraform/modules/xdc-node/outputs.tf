# XDC Node Module - Outputs

# ============================================
# Node Identity
# ============================================

output "node_name" {
  description = "Name of the deployed XDC node"
  value       = var.node_name
}

output "node_id" {
  description = "Unique identifier for this deployment"
  value       = random_id.node.hex
}

output "enode_url" {
  description = "Enode URL for P2P networking"
  value       = var.node_ip != "" ? "enode://${local.node_public_key}@${var.node_ip}:${var.p2p_port}" : ""
}

# ============================================
# Network Endpoints
# ============================================

output "node_ip" {
  description = "Public IP address of the node"
  value       = var.node_ip
}

output "rpc_endpoint" {
  description = "HTTP RPC endpoint URL"
  value       = var.enable_rpc && var.node_ip != "" ? "http://${var.node_ip}:${var.rpc_port}" : ""
}

output "rpc_endpoint_https" {
  description = "HTTPS RPC endpoint URL (if DNS configured)"
  value       = var.enable_dns && var.dns_record_name != "" ? "https://${var.dns_record_name}.${var.dns_zone}:${var.rpc_port}" : ""
}

output "ws_endpoint" {
  description = "WebSocket endpoint URL"
  value       = var.enable_ws && var.node_ip != "" ? "ws://${var.node_ip}:${var.ws_port}" : ""
}

output "metrics_endpoint" {
  description = "Prometheus metrics endpoint URL"
  value       = var.enable_metrics && var.node_ip != "" ? "http://${var.node_ip}:${var.metrics_port}/metrics" : ""
}

output "p2p_endpoint" {
  description = "P2P networking endpoint"
  value       = var.node_ip != "" ? "${var.node_ip}:${var.p2p_port}" : ""
}

# ============================================
# DNS
# ============================================

output "dns_name" {
  description = "DNS name for the node"
  value       = var.enable_dns && var.dns_record_name != "" ? "${var.dns_record_name}.${var.dns_zone}" : ""
}

# ============================================
# Configuration
# ============================================

output "network" {
  description = "XDC network"
  value       = var.network
}

output "chain_id" {
  description = "Chain ID for the network"
  value       = local.selected_network.chain_id
}

output "client" {
  description = "XDC client implementation"
  value       = var.client
}

output "node_type" {
  description = "Type of node deployed"
  value       = var.node_type
}

output "xdc_version" {
  description = "Version of XDC client"
  value       = var.xdc_version
}

# ============================================
# Cloud Provider Details
# ============================================

output "cloud_provider" {
  description = "Cloud provider used"
  value       = var.cloud_provider
}

output "region" {
  description = "Region of deployment"
  value       = var.region
}

output "instance_size" {
  description = "Instance size"
  value       = var.instance_size
}

# ============================================
# Storage
# ============================================

output "data_volume_size_gb" {
  description = "Size of data volume in GB"
  value       = var.data_volume_size
}

# ============================================
# SSH Access
# ============================================

output "ssh_command" {
  description = "SSH command to connect to the node"
  value       = var.node_ip != "" ? "ssh ubuntu@${var.node_ip}" : ""
}

# ============================================
# Useful Commands
# ============================================

output "useful_commands" {
  description = "Useful commands for managing the node"
  value = var.node_ip != "" ? {
    check_sync_status = "curl -s -X POST -H 'Content-Type: application/json' --data '{\"jsonrpc\":\"2.0\",\"method\":\"eth_syncing\",\"params\":[],\"id\":1}' http://${var.node_ip}:${var.rpc_port}/"
    get_block_number  = "curl -s -X POST -H 'Content-Type: application/json' --data '{\"jsonrpc\":\"2.0\",\"method\":\"eth_blockNumber\",\"params\":[],\"id\":1}' http://${var.node_ip}:${var.rpc_port}/"
    get_peer_count    = "curl -s -X POST -H 'Content-Type: application/json' --data '{\"jsonrpc\":\"2.0\",\"method\":\"net_peerCount\",\"params\":[],\"id\":1}' http://${var.node_ip}:${var.rpc_port}/"
    get_node_info     = "curl -s -X POST -H 'Content-Type: application/json' --data '{\"jsonrpc\":\"2.0\",\"method\":\"admin_nodeInfo\",\"params\":[],\"id\":1}' http://${var.node_ip}:${var.rpc_port}/"
    view_logs         = "ssh ubuntu@${var.node_ip} 'sudo docker logs -f xdc-node'"
    restart_node      = "ssh ubuntu@${var.node_ip} 'sudo docker restart xdc-node'"
  } : {}
}

# ============================================
# Tags
# ============================================

output "tags" {
  description = "Tags applied to resources"
  value       = local.common_tags
}

# ============================================
# Internal Values (for module composition)
# ============================================

output "cloud_init_config" {
  description = "Cloud-init configuration (base64 encoded)"
  value       = base64encode(local.cloud_init_config)
  sensitive   = true
}

output "network_config" {
  description = "Network-specific configuration"
  value       = local.selected_network
}

output "client_config" {
  description = "Client-specific configuration"
  value       = local.selected_client
}

output "node_type_config" {
  description = "Node type configuration"
  value       = local.selected_type
}

# ============================================
# Computed Values
# ============================================

locals {
  # Node public key (derived from private key if generated)
  node_public_key = var.node_private_key != "" ? var.node_private_key : (
    length(tls_private_key.node_key) > 0 ? tls_private_key.node_key[0].public_key_openssh : ""
  )
}
