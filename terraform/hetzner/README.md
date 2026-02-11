# XDC Node on Hetzner Cloud

This Terraform module deploys an XDC node on Hetzner Cloud.

## Features

- Hetzner Cloud Server
- Firewall with XDC-specific rules
- Volume for chain data
- Cloud-init for automated setup

## Usage

```hcl
module "xdc_node" {
  source = "./terraform/hetzner"
  
  server_name = "xdc-validator-01"
  server_type = "cpx31"
  location    = "fsn1"
  
  node_type = "validator"
  network   = "mainnet"
}
```

## Variables

See `variables.tf` for all available options.
