# XDC Node on AWS

This Terraform module deploys an XDC node on AWS EC2.

## Features

- VPC with public subnet
- Security group with XDC-specific rules
- EC2 instance with EBS volume for chain data
- User data script for automated setup
- Optional: Application Load Balancer for RPC endpoints

## Usage

```hcl
module "xdc_node" {
  source = "./terraform/aws"
  
  instance_name = "xdc-validator-01"
  instance_type = "c6i.2xlarge"
  region        = "us-east-1"
  
  node_type = "validator"
  network   = "mainnet"
  
  key_name = "my-aws-key"
}
```

## Variables

See `variables.tf` for all available options.

## Outputs

See `outputs.tf` for available outputs.
