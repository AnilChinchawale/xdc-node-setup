# XDC Node Setup - Terraform Provider Configuration
# This file defines the required providers for XDC node deployment across multiple clouds

terraform {
  required_version = ">= 1.3.0"

  required_providers {
    # AWS Provider for EC2 deployments
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    # DigitalOcean Provider for Droplet deployments
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }

    # Hetzner Cloud Provider for server deployments
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }

    # Random provider for resource naming
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }

    # Null provider for local-exec provisioners
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }

    # TLS provider for SSH key generation
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }

    # Local provider for file operations
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }

    # HTTP provider for health checks
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }
}

# Provider configurations are handled in the cloud-specific modules
# or in the root module when using the xdc-node module directly.
#
# Example provider configuration:
#
# provider "aws" {
#   region = "us-east-1"
# }
#
# provider "digitalocean" {
#   token = var.do_token
# }
#
# provider "hcloud" {
#   token = var.hcloud_token
# }
