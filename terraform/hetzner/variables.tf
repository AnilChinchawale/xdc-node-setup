variable "server_name" {
  description = "Name of the server"
  type        = string
}

variable "server_type" {
  description = "Hetzner server type"
  type        = string
  default     = "cpx31"
}

variable "location" {
  description = "Hetzner location"
  type        = string
  default     = "fsn1"
}

variable "ssh_key_ids" {
  description = "List of SSH key IDs"
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

variable "labels" {
  description = "Labels for the server"
  type        = map(string)
  default     = {}
}
