# XDC Node on DigitalOcean

This Terraform module deploys an XDC node on DigitalOcean.

## Features

- DigitalOcean Droplet
- Cloud Firewall with XDC rules
- Volume for chain data
- Cloud-init for automated setup

## Usage

```hcl
module "xdc_node" {
  source = "./terraform/digitalocean"
  
  droplet_name = "xdc-validator-01"
  size         = "s-4vcpu-8gb"
  region       = "nyc1"
  
  node_type = "validator"
  network   = "mainnet"
}
```

## Variables

See `variables.tf` for all available options.
