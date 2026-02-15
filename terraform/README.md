# XDC Node Terraform Module

Deploy XDC nodes across multiple cloud providers using Terraform.

## Overview

This Terraform configuration provides:
- **Reusable Module**: `modules/xdc-node` - Deploy XDC nodes with consistent configuration
- **Cloud Examples**: Ready-to-use examples for AWS, DigitalOcean, and Hetzner
- **Security Best Practices**: Firewall rules, encrypted volumes, SSH key management
- **Flexible Configuration**: Support for mainnet, testnet, multiple clients

## Quick Start

### Prerequisites

1. Install [Terraform](https://www.terraform.io/downloads) >= 1.3.0
2. Configure cloud provider credentials
3. Have an SSH key pair ready

### Deploy on AWS

```bash
cd examples/aws

# Initialize Terraform
terraform init

# Create terraform.tfvars
cat > terraform.tfvars <<EOF
region       = "us-east-1"
node_name    = "my-xdc-node"
network      = "mainnet"
ssh_key_name = "my-ssh-key"
allowed_ssh_cidrs = ["YOUR_IP/32"]
EOF

# Review the plan
terraform plan

# Deploy
terraform apply
```

### Deploy on DigitalOcean

```bash
cd examples/digitalocean

cat > terraform.tfvars <<EOF
do_token     = "your-digitalocean-token"
region       = "nyc3"
node_name    = "my-xdc-node"
network      = "mainnet"
ssh_key_ids  = ["12345678"]
EOF

terraform init && terraform apply
```

### Deploy on Hetzner

```bash
cd examples/hetzner

cat > terraform.tfvars <<EOF
hcloud_token    = "your-hetzner-token"
location        = "nbg1"
node_name       = "my-xdc-node"
network         = "mainnet"
ssh_public_keys = ["ssh-ed25519 AAAA..."]
EOF

terraform init && terraform apply
```

## Module Usage

Use the module directly in your Terraform configuration:

```hcl
module "xdc_mainnet" {
  source = "github.com/AnilChinchawale/xdc-node-setup//terraform/modules/xdc-node"

  node_name      = "xdc-mainnet-01"
  network        = "mainnet"
  client         = "XDPoSChain"
  node_type      = "full"
  cloud_provider = "aws"
  region         = "us-east-1"

  # Network
  enable_rpc     = true
  enable_ws      = false
  enable_metrics = true

  # Storage
  data_volume_size = 500

  # Tags
  tags = {
    Environment = "production"
    Team        = "blockchain"
  }
}
```

## Variables

### Required

| Variable | Description | Type |
|----------|-------------|------|
| `node_name` | Name of the XDC node | `string` |
| `network` | Network: `mainnet`, `testnet`, `devnet` | `string` |

### Optional

| Variable | Description | Default |
|----------|-------------|---------|
| `client` | XDC client: `XDPoSChain`, `erigon-xdc` | `XDPoSChain` |
| `node_type` | Node type: `full`, `archive`, `validator`, `rpc` | `full` |
| `cloud_provider` | Cloud: `aws`, `digitalocean`, `hetzner` | `aws` |
| `region` | Deployment region | `us-east-1` |
| `instance_size` | Size: `small`, `medium`, `large`, `xlarge` | `medium` |
| `data_volume_size` | Data volume in GB | `500` |
| `enable_rpc` | Enable HTTP RPC | `true` |
| `enable_ws` | Enable WebSocket | `false` |
| `enable_metrics` | Enable metrics endpoint | `true` |
| `enable_public_rpc` | Allow public RPC access | `false` |

See `modules/xdc-node/variables.tf` for the complete list.

## Outputs

| Output | Description |
|--------|-------------|
| `node_ip` | Public IP address |
| `rpc_endpoint` | HTTP RPC URL |
| `ws_endpoint` | WebSocket URL |
| `metrics_endpoint` | Prometheus metrics URL |
| `enode_url` | P2P enode URL |
| `ssh_command` | SSH connection command |

## Architecture

```
terraform/
├── provider.tf                    # Provider requirements
├── modules/
│   └── xdc-node/                  # Reusable XDC node module
│       ├── main.tf                # Main resources
│       ├── variables.tf           # Input variables
│       ├── outputs.tf             # Output values
│       └── templates/
│           └── cloud-init.yml.tpl # Cloud-init template
├── examples/
│   ├── aws/main.tf                # AWS deployment
│   ├── digitalocean/main.tf       # DigitalOcean deployment
│   └── hetzner/main.tf            # Hetzner deployment
├── aws/                           # Legacy AWS configs
├── digitalocean/                  # Legacy DO configs
└── hetzner/                       # Legacy Hetzner configs
```

## Instance Sizing

### Recommended Sizes by Node Type

| Node Type | CPU | RAM | Storage | AWS | DO | Hetzner |
|-----------|-----|-----|---------|-----|-----|---------|
| Full | 4 | 8GB | 500GB | m6i.xlarge | s-4vcpu-8gb | cpx31 |
| Archive | 8 | 32GB | 2TB | r6i.2xlarge | m-8vcpu-64gb | cpx51 |
| Validator | 4 | 16GB | 500GB | m6i.xlarge | m-4vcpu-32gb | cpx41 |
| RPC | 8 | 32GB | 1TB | m6i.2xlarge | g-8vcpu-32gb | cpx51 |

### Erigon Requirements (Higher)

| Node Type | CPU | RAM | Storage |
|-----------|-----|-----|---------|
| Full | 8 | 16GB | 1TB |
| Archive | 16 | 64GB | 3TB |

## Security

### Best Practices Implemented

1. **SSH Access**: Restricted to specified CIDR blocks
2. **RPC Access**: Internal only by default
3. **Volume Encryption**: Enabled by default
4. **Firewall Rules**: Minimal required ports only
5. **Fail2ban**: Enabled on all instances
6. **Automatic Updates**: Security updates enabled

### Firewall Ports

| Port | Protocol | Purpose | Access |
|------|----------|---------|--------|
| 22 | TCP | SSH | Restricted |
| 30303 | TCP/UDP | P2P | Public |
| 8545 | TCP | HTTP RPC | Restricted |
| 8546 | TCP | WebSocket | Restricted |
| 6060 | TCP | Metrics | Internal |

## State Management

### Remote State (Recommended)

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "xdc-node/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

### Workspaces

Use workspaces for multiple environments:

```bash
terraform workspace new mainnet
terraform workspace new testnet
terraform workspace select mainnet
terraform apply
```

## Monitoring Integration

### Prometheus Scraping

Add to your Prometheus configuration:

```yaml
scrape_configs:
  - job_name: 'xdc-node'
    static_configs:
      - targets: ['<node_ip>:6060']
    metrics_path: /debug/metrics/prometheus
```

### Grafana Dashboard

Import the XDC node dashboard: `docs/grafana/xdc-node-dashboard.json`

## Troubleshooting

### Check Node Status

```bash
# SSH into the node
ssh ubuntu@<node_ip>

# Check container status
sudo docker ps

# View logs
sudo docker logs -f xdc-node

# Check sync status
xdc-status
```

### Common Issues

1. **Node not syncing**: Check firewall allows port 30303
2. **RPC not responding**: Verify `enable_rpc = true`
3. **Out of disk space**: Increase `data_volume_size`
4. **Connection refused**: Wait for node to fully start

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test with `terraform validate` and `terraform fmt`
4. Submit a pull request

## License

Apache 2.0 - See [LICENSE](../LICENSE)
