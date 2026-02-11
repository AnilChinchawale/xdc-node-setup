# XDC Node Ansible Automation

This directory contains Ansible playbooks and roles for automating XDC node deployment, management, and operations.

## Prerequisites

- Ansible 2.12+ installed on your control machine
- SSH access to target hosts with key-based authentication
- Python 3.8+ on target hosts

### Installation

```bash
# Install Ansible
pip install ansible ansible-lint

# Install required collections
ansible-galaxy collection install community.general ansible.posix
```

## Directory Structure

```
ansible/
├── ansible.cfg              # Ansible configuration
├── inventory/
│   └── hosts.yml.template   # Inventory template
├── playbooks/
│   ├── deploy-node.yml      # Deploy new XDC node
│   ├── security-harden.yml  # Apply security hardening
│   ├── update-client.yml    # Rolling client updates
│   ├── setup-monitoring.yml # Deploy monitoring stack
│   └── backup-restore.yml   # Backup/restore operations
└── roles/
    ├── xdc-common/          # Base system configuration
    ├── xdc-node/            # Node installation
    ├── xdc-security/        # Security hardening
    └── xdc-monitoring/      # Monitoring setup
```

## Quick Start

### 1. Set Up Inventory

```bash
# Copy and customize the inventory template
cp inventory/hosts.yml.template inventory/hosts.yml
vim inventory/hosts.yml
```

### 2. Test Connectivity

```bash
# Ping all hosts
ansible all -m ping

# Check host facts
ansible all -m setup | head -50
```

### 3. Deploy a New Node

```bash
# Deploy to a specific host
ansible-playbook playbooks/deploy-node.yml --limit test-geth

# Deploy with custom variables
ansible-playbook playbooks/deploy-node.yml \
  --limit test-geth \
  -e "xdc_network=testnet" \
  -e "rpc_port=8545"
```

## Playbooks

### deploy-node.yml

Deploys a new XDC node with full configuration.

```bash
# Basic deployment
ansible-playbook playbooks/deploy-node.yml --limit <host>

# Custom deployment
ansible-playbook playbooks/deploy-node.yml --limit <host> \
  -e "client=XDPoSChain" \
  -e "xdc_network=mainnet" \
  -e "xdc_data_dir=/data/xdc"
```

**Variables:**
| Variable | Default | Description |
|----------|---------|-------------|
| `client` | XDPoSChain | Client type (XDPoSChain or erigon-xdc) |
| `xdc_network` | mainnet | Network (mainnet or testnet) |
| `xdc_data_dir` | /root/XDC-Node | Data directory |
| `rpc_port` | 8545 | RPC port |
| `p2p_port` | 30303 | P2P port |

### security-harden.yml

Applies comprehensive security hardening.

```bash
# Apply all security hardening
ansible-playbook playbooks/security-harden.yml

# Apply specific tags only
ansible-playbook playbooks/security-harden.yml --tags "ssh,firewall"

# Skip certain components
ansible-playbook playbooks/security-harden.yml --skip-tags "auditd"
```

**Tags:**
- `ssh` - SSH hardening
- `firewall` - UFW firewall
- `fail2ban` - Fail2ban configuration
- `auditd` - Audit logging
- `sysctl` - Kernel parameters
- `updates` - Unattended upgrades

### update-client.yml

Performs rolling updates one node at a time.

```bash
# Update all nodes
ansible-playbook playbooks/update-client.yml

# Update specific version
ansible-playbook playbooks/update-client.yml -e "target_version=v2.0.0"

# Update specific host first
ansible-playbook playbooks/update-client.yml --limit test-geth
```

### setup-monitoring.yml

Deploys monitoring stack (Prometheus, Grafana, exporters).

```bash
# Deploy monitoring
ansible-playbook playbooks/setup-monitoring.yml

# With custom Grafana password
ansible-playbook playbooks/setup-monitoring.yml \
  -e "grafana_admin_password=MySecurePassword123"
```

**Access URLs (via SSH tunnel):**
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000 (admin/xdc-admin-changeme)
- Node Exporter: http://localhost:9100

### backup-restore.yml

Manages backups and restoration.

```bash
# Create backup
ansible-playbook playbooks/backup-restore.yml --limit prod-geth

# Restore from backup
ansible-playbook playbooks/backup-restore.yml \
  --limit prod-geth \
  -e "restore=true" \
  -e "backup_file=/root/backups/xdc-backup-2024-01-15.tar.gz"
```

## Roles

### xdc-common

Base system configuration applied to all nodes:
- Package installation
- Timezone and NTP
- System limits
- Sysctl tuning
- Log rotation

### xdc-node

Node-specific configuration:
- Client build/installation
- Data directory setup
- Systemd service
- Genesis initialization

### xdc-security

Security hardening:
- SSH hardening
- UFW firewall
- Fail2ban
- Auditd
- File permissions

### xdc-monitoring

Monitoring deployment:
- Docker installation
- Prometheus + Grafana
- Node exporter
- Alert rules

## Common Tasks

### Check Node Status

```bash
# Check sync status
ansible xdc_nodes -m shell -a "curl -s localhost:8545 -X POST -H 'Content-Type: application/json' --data '{\"jsonrpc\":\"2.0\",\"method\":\"eth_syncing\",\"params\":[],\"id\":1}' | jq ."

# Check peer count
ansible xdc_nodes -m shell -a "curl -s localhost:8545 -X POST -H 'Content-Type: application/json' --data '{\"jsonrpc\":\"2.0\",\"method\":\"net_peerCount\",\"params\":[],\"id\":1}' | jq ."
```

### Service Management

```bash
# Restart node
ansible prod-geth -m systemd -a "name=xdc-node state=restarted"

# Check service status
ansible xdc_nodes -m shell -a "systemctl status xdc-node"

# View logs
ansible prod-geth -m shell -a "journalctl -u xdc-node -n 50"
```

### Inventory Management

```bash
# List all hosts
ansible all --list-hosts

# List by group
ansible validators --list-hosts
ansible rpc_nodes --list-hosts

# Check host variables
ansible-inventory --host prod-geth
```

## Best Practices

1. **Always test on test nodes first**
   ```bash
   ansible-playbook playbooks/update-client.yml --limit test_nodes
   ```

2. **Use check mode for dry runs**
   ```bash
   ansible-playbook playbooks/security-harden.yml --check --diff
   ```

3. **Use tags for targeted runs**
   ```bash
   ansible-playbook playbooks/deploy-node.yml --tags "config,systemd"
   ```

4. **Keep secrets in vault**
   ```bash
   ansible-vault create group_vars/all/vault.yml
   ansible-playbook playbook.yml --ask-vault-pass
   ```

## Troubleshooting

### Connection Issues

```bash
# Debug SSH connection
ansible prod-geth -m ping -vvvv

# Check SSH config
ansible prod-geth -m debug -a "var=ansible_ssh_common_args"
```

### Playbook Debugging

```bash
# Verbose output
ansible-playbook playbooks/deploy-node.yml -vvv

# Step through tasks
ansible-playbook playbooks/deploy-node.yml --step

# Start at specific task
ansible-playbook playbooks/deploy-node.yml --start-at-task="Start XDC node"
```

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines.
