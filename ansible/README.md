# XDC Node Ansible Infrastructure

Enterprise-grade Ansible automation for deploying and managing XDC Network nodes.

## Features

- **Multi-region inventory** with validators, RPC nodes, archive nodes
- **Rolling updates** with health checks after each node
- **Security hardening** based on CIS benchmarks
- **Monitoring stack** with Prometheus and Grafana
- **Automated backups** with S3/remote storage support

## Directory Structure

```
ansible/
├── ansible.cfg              # Ansible configuration
├── inventory/
│   └── hosts.yml.template   # Multi-region inventory template
├── playbooks/
│   ├── site.yml             # Master playbook
│   ├── deploy-node.yml      # Full node deployment
│   ├── security-harden.yml  # Security hardening
│   ├── update-client.yml    # Rolling updates
│   ├── setup-monitoring.yml # Monitoring stack
│   └── backup-restore.yml   # Backup operations
└── roles/
    ├── xdc-common/          # Base packages, timezone, NTP
    ├── xdc-node/            # Client install, config, systemd
    ├── xdc-security/        # SSH, UFW, fail2ban, auditd
    ├── xdc-monitoring/      # Docker, Prometheus, Grafana
    └── xdc-backup/          # Backup scripts, cron jobs
```

## Quick Start

### 1. Setup Inventory

```bash
# Copy and edit the inventory template
cp inventory/hosts.yml.template inventory/hosts.yml
vim inventory/hosts.yml
```

Update with your server IPs and configuration.

### 2. Test Connectivity

```bash
ansible -i inventory/hosts.yml all -m ping
```

### 3. Deploy Nodes

```bash
# Full deployment
ansible-playbook -i inventory/hosts.yml playbooks/site.yml

# Deploy specific group
ansible-playbook -i inventory/hosts.yml playbooks/deploy-node.yml --limit validators

# Dry run
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --check
```

## Playbooks

### site.yml - Master Playbook

Runs all deployment tasks in order:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/site.yml
```

### deploy-node.yml - Node Deployment

Deploys XDC node software:

```bash
# Deploy to all nodes
ansible-playbook -i inventory/hosts.yml playbooks/deploy-node.yml

# Deploy specific client
ansible-playbook -i inventory/hosts.yml playbooks/deploy-node.yml \
  -e "client=erigon-xdc"

# Deploy to testnet
ansible-playbook -i inventory/hosts.yml playbooks/deploy-node.yml \
  -e "xdc_network=testnet"
```

### security-harden.yml - Security Hardening

Applies CIS benchmark security settings:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/security-harden.yml
```

### update-client.yml - Rolling Updates

Updates nodes one at a time with health checks:

```bash
# Check for updates
ansible-playbook -i inventory/hosts.yml playbooks/update-client.yml \
  --tags check

# Apply updates
ansible-playbook -i inventory/hosts.yml playbooks/update-client.yml \
  -e "target_version=v2.6.0"
```

### setup-monitoring.yml - Monitoring Stack

Deploys Prometheus, Grafana, and exporters:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/setup-monitoring.yml
```

### backup-restore.yml - Backup Operations

```bash
# Create backup
ansible-playbook -i inventory/hosts.yml playbooks/backup-restore.yml \
  --tags backup

# Restore from backup
ansible-playbook -i inventory/hosts.yml playbooks/backup-restore.yml \
  --tags restore \
  -e "restore_file=/backup/xdc-node/latest.tar.gz"

# List backups
ansible-playbook -i inventory/hosts.yml playbooks/backup-restore.yml \
  --tags list
```

## Roles

### xdc-common

Base system configuration:
- Package installation
- Timezone and NTP
- System limits
- Log rotation

### xdc-node

XDC client deployment:
- Build from source
- Systemd service
- Configuration management

### xdc-security

Security hardening:
- SSH hardening
- UFW firewall
- Fail2ban
- Auditd
- Sysctl tuning

### xdc-monitoring

Monitoring stack:
- Docker installation
- Prometheus
- Grafana
- Node Exporter
- Alertmanager

### xdc-backup

Backup automation:
- Backup scripts
- Cron scheduling
- S3 upload (optional)
- Retention management

## Variables

### Common Variables

```yaml
# Node configuration
client: XDPoSChain  # or erigon-xdc
node_role: full     # full, validator, rpc, archive
xdc_network: mainnet

# Data directories
xdc_data_dir: /xdc-data
xdc_logs_dir: /var/log/xdc

# Network ports
rpc_port: 8545
ws_port: 8546
p2p_port: 30303

# Security
ssh_port: 12141
fail2ban_maxretry: 3
```

### Per-Host Variables

Set in inventory for each host:

```yaml
validator-01:
  ansible_host: 65.21.27.213
  node_role: validator
  client: XDPoSChain
  xdc_network: mainnet
```

## Requirements

- Ansible 2.12+
- Python 3.8+ on control node
- Ubuntu 20.04/22.04/24.04 on target hosts
- SSH access with sudo privileges

## Best Practices

1. **Always test in staging first**
2. **Use `--check` for dry runs**
3. **Limit to specific hosts during updates**
4. **Monitor nodes during rolling updates**
5. **Keep inventory in version control**

## Troubleshooting

### Connection Issues

```bash
# Test SSH
ssh -i ~/.ssh/key user@host

# Verbose mode
ansible-playbook -vvv playbooks/site.yml
```

### Task Failures

```bash
# Start from specific task
ansible-playbook playbooks/site.yml --start-at-task "Task Name"

# Run specific tags
ansible-playbook playbooks/site.yml --tags security
```

## Support

- Issues: https://github.com/AnilChinchawale/XDC-Node-Setup/issues
- XDC Docs: https://docs.xdc.community
