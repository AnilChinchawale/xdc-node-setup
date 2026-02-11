variable "droplet_name" {
  description = "Name of the droplet"
  type        = string
}

variable "size" {
  description = "Droplet size"
  type        = string
  default     = "s-4vcpu-8gb"
}

variable "region" {
  description = "DigitalOcean region"
  type        = string
  default     = "nyc1"
}

variable "ssh_key_ids" {
  description = "List of SSH key fingerprints"
  type        = list(string)
}

variable "data_volume_size" {
  description = "Size of data volume in GB"
  type        = number
  default     = 100
}

variable "node_type" {
  description = "Type of XDC node"
  type        = string
  default     = "full"
}

variable "network" {
  description = "XDC network"
  type        = string
  default     = "mainnet"
}

variable "client" {
  description = "XDC client"
  type        = string
  default     = "XDPoSChain"
}

variable "enable_public_rpc" {
  description = "Enable public RPC"
  type        = bool
  default     = false
}

variable "allowed_ssh_ips" {
  description = "Allowed IPs for SSH"
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
}

variable "allowed_rpc_ips" {
  description = "Allowed IPs for RPC"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "tags" {
  description = "Tags for the droplet"
  type        = list(string)
  default     = []
}
