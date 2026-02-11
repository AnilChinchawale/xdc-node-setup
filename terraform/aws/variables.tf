variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "instance_name" {
  description = "Name tag for the instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "c6i.2xlarge"
}

variable "ami_id" {
  description = "AMI ID (leave empty for latest Ubuntu)"
  type        = string
  default     = ""
}

variable "key_name" {
  description = "Name of the SSH key pair"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "root_volume_size" {
  description = "Size of root volume in GB"
  type        = number
  default     = 100
}

variable "data_volume_size" {
  description = "Size of data volume in GB"
  type        = number
  default     = 1000
}

variable "data_volume_type" {
  description = "Type of data volume"
  type        = string
  default     = "gp3"
}

variable "encrypt_volumes" {
  description = "Enable volume encryption"
  type        = bool
  default     = true
}

variable "node_type" {
  description = "Type of XDC node (validator, rpc, archive)"
  type        = string
  default     = "full"
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

variable "enable_public_rpc" {
  description = "Enable public RPC access"
  type        = bool
  default     = false
}

variable "allowed_ssh_cidr" {
  description = "Allowed CIDR blocks for SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_rpc_cidr" {
  description = "Allowed CIDR blocks for RPC"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "enable_s3_backup" {
  description = "Enable S3 backup access"
  type        = bool
  default     = false
}

variable "s3_backup_bucket" {
  description = "S3 bucket for backups"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Project = "xdc-node"
    Managed = "terraform"
  }
}
