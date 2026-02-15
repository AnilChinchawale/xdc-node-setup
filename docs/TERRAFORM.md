# XDC Node Terraform Architecture

This document describes the architecture and design decisions for the XDC Node Terraform infrastructure.

## Overview

The Terraform configuration provides Infrastructure as Code (IaC) for deploying XDC blockchain nodes across multiple cloud providers with consistent configuration, security, and monitoring.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         XDC Node Terraform Stack                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                     terraform/modules/xdc-node                   │   │
│  │                      (Reusable Core Module)                      │   │
│  ├─────────────────────────────────────────────────────────────────┤   │
│  │  • main.tf        - Core logic, local values, templates         │   │
│  │  • variables.tf   - All configurable inputs                     │   │
│  │  • outputs.tf     - Computed outputs for downstream use         │   │
│  │  • templates/     - Cloud-init and configuration templates      │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                              │                                          │
│         ┌────────────────────┼────────────────────┐                    │
│         │                    │                    │                    │
│         ▼                    ▼                    ▼                    │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐             │
│  │    AWS      │     │DigitalOcean │     │   Hetzner   │             │
│  │  Example    │     │   Example   │     │   Example   │             │
│  ├─────────────┤     ├─────────────┤     ├─────────────┤             │
│  │ • VPC       │     │ • VPC       │     │ • Network   │             │
│  │ • EC2       │     │ • Droplet   │     │ • Server    │             │
│  │ • EBS       │     │ • Volume    │     │ • Volume    │             │
│  │ • SG        │     │ • Firewall  │     │ • Firewall  │             │
│  │ • IAM       │     │ • Reserved  │     │ • Floating  │             │
│  │             │     │   IP        │     │   IP        │             │
│  └─────────────┘     └─────────────┘     └─────────────┘             │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## Design Principles

### 1. Module-Based Architecture

The core `xdc-node` module encapsulates all XDC-specific logic:

- **Network configurations** (mainnet, testnet, devnet)
- **Client configurations** (XDPoSChain, Erigon)
- **Node type configurations** (full, archive, validator, RPC)
- **Cloud-init templates** for consistent provisioning

Cloud-specific resources (instances, volumes, networking) are implemented in the examples.

### 2. Configuration-Driven Deployment

All deployments are driven by variables, not code changes:

```hcl
module "xdc_node" {
  source = "../../modules/xdc-node"
  
  # These variables drive all behavior
  node_name  = "xdc-mainnet-01"
  network    = "mainnet"      # Determines chain ID, bootnodes
  client     = "XDPoSChain"   # Determines image, config
  node_type  = "full"         # Determines sync mode, gcmode
}
```

### 3. Security by Default

- **Encrypted volumes** enabled by default
- **Restrictive firewall rules** - only required ports
- **SSH access** requires explicit CIDR allowlisting
- **RPC access** internal only by default
- **Fail2ban and UFW** configured on instances

### 4. Cloud Agnostic

The module produces cloud-init configuration that works on any cloud provider:

```hcl
output "cloud_init_config" {
  value = base64encode(local.cloud_init_config)
}
```

## Component Details

### Core Module: `modules/xdc-node`

#### Local Values

The module uses local values to compute derived configurations:

```hcl
locals {
  network_config = {
    mainnet = {
      chain_id     = 50
      bootnodes    = "enode://..."
      genesis_url  = "https://..."
    }
    testnet = { ... }
  }
  
  client_config = {
    XDPoSChain = {
      image        = "xinfin/xdc-node:latest"
      min_memory   = 8
      min_storage  = 500
    }
    "erigon-xdc" = { ... }
  }
  
  selected_network = local.network_config[var.network]
  selected_client  = local.client_config[var.client]
}
```

#### Cloud-Init Template

The cloud-init template provisions nodes consistently:

1. **Package installation**: Docker, utilities
2. **Configuration files**: Docker Compose, systemd service
3. **Firewall setup**: UFW rules for required ports
4. **Security hardening**: Fail2ban, automatic updates
5. **Service startup**: XDC node container

### Cloud Examples

Each cloud example provides:

| Component | AWS | DigitalOcean | Hetzner |
|-----------|-----|--------------|---------|
| Network | VPC, Subnet, IGW | VPC | Network, Subnet |
| Firewall | Security Group | Firewall | Firewall |
| Compute | EC2 Instance | Droplet | Server |
| Storage | EBS Volume | Block Storage | Volume |
| Static IP | Elastic IP | Reserved IP | Floating IP |

## Data Flow

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  Variables   │────▶│  Module      │────▶│  Outputs     │
│              │     │  Processing  │     │              │
│ • network    │     │              │     │ • rpc_url    │
│ • client     │     │ • Lookups    │     │ • enode_url  │
│ • node_type  │     │ • Templates  │     │ • ssh_cmd    │
│ • region     │     │ • Validation │     │ • cloud-init │
└──────────────┘     └──────────────┘     └──────────────┘
                            │
                            ▼
                     ┌──────────────┐
                     │ Cloud-Init   │
                     │ Config       │
                     │              │
                     │ • Packages   │
                     │ • Files      │
                     │ • Commands   │
                     └──────────────┘
```

## State Management

### Remote State Architecture

```
┌────────────────────────────────────────────────────┐
│                   S3 Bucket                        │
│             terraform-state-bucket                  │
├────────────────────────────────────────────────────┤
│  xdc-nodes/                                        │
│  ├── mainnet/                                      │
│  │   ├── aws/terraform.tfstate                    │
│  │   ├── do/terraform.tfstate                     │
│  │   └── hetzner/terraform.tfstate                │
│  └── testnet/                                      │
│      ├── aws/terraform.tfstate                    │
│      └── ...                                       │
└────────────────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────────────┐
│              DynamoDB Table                        │
│           terraform-state-locks                    │
│                                                    │
│  Prevents concurrent modifications                 │
└────────────────────────────────────────────────────┘
```

### State Isolation Strategy

```hcl
# Backend configuration per environment
terraform {
  backend "s3" {
    bucket         = "xdc-terraform-state"
    key            = "${var.network}/${var.cloud_provider}/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

## Security Architecture

### Network Security

```
                    Internet
                        │
                        ▼
               ┌────────────────┐
               │   Firewall     │
               │                │
               │ • 30303 ✓ P2P  │
               │ • 22 ✓ SSH     │
               │ • 8545 ? RPC   │
               │ • 6060 ✗ Int   │
               └────────────────┘
                        │
                        ▼
               ┌────────────────┐
               │   XDC Node     │
               │                │
               │ ┌────────────┐ │
               │ │ Docker     │ │
               │ │ Container  │ │
               │ └────────────┘ │
               │                │
               │ UFW + Fail2ban │
               └────────────────┘
```

### Access Control Matrix

| Resource | Admin | RPC Client | P2P Peer | Monitoring |
|----------|-------|------------|----------|------------|
| SSH (22) | ✓ | ✗ | ✗ | ✗ |
| RPC (8545) | ✓ | ✓* | ✗ | ✗ |
| WS (8546) | ✓ | ✓* | ✗ | ✗ |
| P2P (30303) | ✓ | ✗ | ✓ | ✗ |
| Metrics (6060) | ✓ | ✗ | ✗ | ✓ |

\* When `enable_public_rpc = true`

## Scaling Patterns

### Horizontal Scaling

Deploy multiple nodes using count or for_each:

```hcl
variable "node_count" {
  default = 3
}

module "xdc_nodes" {
  source   = "../../modules/xdc-node"
  for_each = toset([for i in range(var.node_count) : "node-${i}"])

  node_name = each.value
  network   = "mainnet"
  # ...
}
```

### Multi-Region Deployment

```hcl
locals {
  regions = {
    us = "us-east-1"
    eu = "eu-west-1"
    ap = "ap-southeast-1"
  }
}

module "xdc_nodes" {
  source   = "../../modules/xdc-node"
  for_each = local.regions

  node_name = "xdc-${each.key}"
  region    = each.value
}
```

## Monitoring Integration

### Prometheus Metrics

The module exposes metrics for Prometheus scraping:

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'xdc-nodes'
    static_configs:
      - targets: 
        - 'node1:6060'
        - 'node2:6060'
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
```

### Key Metrics

| Metric | Description |
|--------|-------------|
| `chain_head_block` | Current block number |
| `p2p_peers` | Connected peer count |
| `txpool_pending` | Pending transactions |
| `system_memory_*` | Memory usage |
| `system_cpu_*` | CPU usage |

## Cost Estimation

### Typical Monthly Costs

| Provider | Node Type | Instance | Storage | Total |
|----------|-----------|----------|---------|-------|
| AWS | Full | $70 | $50 | ~$120 |
| DO | Full | $48 | $50 | ~$100 |
| Hetzner | Full | $15 | $22 | ~$40 |
| AWS | Archive | $280 | $200 | ~$500 |
| Hetzner | Archive | $60 | $90 | ~$150 |

*Prices are estimates and may vary by region*

## Migration Path

### From Manual Deployment

1. Export existing node configuration
2. Create `terraform.tfvars` with matching settings
3. Import existing resources: `terraform import`
4. Validate with `terraform plan`
5. Apply to manage state

### Between Cloud Providers

1. Stop source node
2. Export chain data (optional - can resync)
3. Deploy new infrastructure
4. Restore data or let node sync
5. Update DNS/load balancer
6. Destroy old infrastructure

## Future Enhancements

- [ ] Multi-cloud load balancing
- [ ] Automatic failover
- [ ] Snapshot-based scaling
- [ ] Cost optimization recommendations
- [ ] Compliance reporting (SOC2, etc.)

## Related Documentation

- [Terraform README](../terraform/README.md)
- [Cloud Provider Docs](../cloud/README.md)
- [Monitoring Guide](./MONITORING.md)
- [Security Guide](./SECURITY.md)
