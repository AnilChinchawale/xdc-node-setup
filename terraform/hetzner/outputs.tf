output "server_id" {
  description = "ID of the server"
  value       = hcloud_server.xdc.id
}

output "server_ip" {
  description = "Public IP of the server"
  value       = hcloud_server.xdc.ipv4_address
}

output "server_ipv6" {
  description = "Public IPv6 of the server"
  value       = hcloud_server.xdc.ipv6_address
}

output "volume_id" {
  description = "ID of the data volume"
  value       = hcloud_volume.xdc_data.id
}

output "firewall_id" {
  description = "ID of the firewall"
  value       = hcloud_firewall.xdc.id
}
