output "droplet_id" {
  description = "ID of the droplet"
  value       = digitalocean_droplet.xdc.id
}

output "droplet_ip" {
  description = "Public IP of the droplet"
  value       = digitalocean_droplet.xdc.ipv4_address
}

output "droplet_urn" {
  description = "URN of the droplet"
  value       = digitalocean_droplet.xdc.urn
}

output "volume_id" {
  description = "ID of the data volume"
  value       = digitalocean_volume.xdc_data.id
}

output "firewall_id" {
  description = "ID of the firewall"
  value       = digitalocean_firewall.xdc.id
}
