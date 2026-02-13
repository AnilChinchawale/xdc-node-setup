# DigitalOcean XDC Node Deployment

1-Click deployment of XDC Network nodes on DigitalOcean.

## Quick Start

### Option 1: Marketplace 1-Click (Coming Soon)

Deploy directly from DigitalOcean Marketplace:

1. Visit [DigitalOcean Marketplace](https://marketplace.digitalocean.com)
2. Search for "XDC Network Node"
3. Click "Create Droplet"
4. Select your plan and region
5. Deploy!

### Option 2: Custom Snapshot

Build and deploy your own snapshot:

```bash
# Set API token
export DIGITALOCEAN_TOKEN="your-api-token"

# Build snapshot
cd cloud/digitalocean
packer build packer.json

# Create droplet from snapshot
doctl compute droplet create xdc-node \
  --image <snapshot-id> \
  --size s-4vcpu-8gb \
  --region nyc3 \
  --ssh-keys <key-id> \
  --wait
```

### Option 3: Cloud-Init on Standard Ubuntu

Use cloud-init with a standard Ubuntu droplet:

```bash
# Create droplet with cloud-init
doctl compute droplet create xdc-node \
  --image ubuntu-22-04-x64 \
  --size s-4vcpu-8gb \
  --region nyc3 \
  --ssh-keys <key-id> \
  --user-data-file cloudinit.yaml \
  --wait
```

## Recommended Droplet Sizes

| Node Type | Droplet Size | vCPUs | RAM | Storage | Monthly Cost |
|-----------|-------------|-------|-----|---------|--------------|
| Full Node | s-4vcpu-8gb | 4 | 8 GB | 500 GB | $48 |
| Full Node | s-8vcpu-16gb | 8 | 16 GB | 1000 GB | $96 |
| Archive | s-8vcpu-16gb | 8 | 16 GB | 2000 GB | $160 |
| Masternode | s-8vcpu-16gb | 8 | 16 GB | 1000 GB | $96 |
| RPC Node | c-4 | 4 | 8 GB | 750 GB | $72 |

## Post-Deployment

### Connect via SSH

```bash
ssh root@<droplet-ip>
```

### Check Node Status

```bash
# Quick status check
xdc-status

# Full health check
/opt/xdc-node/scripts/node-health-check.sh

# View logs
xdc-logs

# View specific service logs
xdc-logs xdc-node
xdc-logs prometheus
xdc-logs grafana
```

### Access Grafana

1. Open http://your-droplet-ip:3000
2. Login with credentials from `/opt/xdc-node/.env`
3. Default: admin / [randomly generated]

To view the password:
```bash
grep GRAFANA_ADMIN_PASSWORD /opt/xdc-node/.env
```

### Update Node

```bash
cd /opt/xdc-node

# Pull latest images
docker-compose pull

# Restart with new images
docker-compose up -d

# Or use auto-update script
/opt/xdc-node/scripts/auto-update.sh
```

## Configuration

### Change Network

Edit `/opt/xdc-node/.env`:

```bash
# Change from mainnet to testnet
NETWORK=testnet
```

Then restart:
```bash
cd /opt/xdc-node
docker-compose down
docker-compose up -d
```

### Configure as Masternode

1. Edit `/opt/xdc-node/.env`:
```bash
NODE_TYPE=masternode
COINBASE_ADDR=0xYourCoinbaseAddress
PRIVATE_KEY=your-private-key
```

2. Restart the node

### Add Block Storage

For archive nodes or growing chain data:

```bash
# Create volume
doctl compute volume create xdc-data \
  --region nyc3 \
  --size 2000 \
  --fs-type ext4

# Attach to droplet
doctl compute volume-action attach <volume-id> <droplet-id>

# SSH and mount
ssh root@<droplet-ip>
mkfs.ext4 /dev/sda
mount /dev/sda /opt/xdc-node
```

## Firewall

Firewall rules are pre-configured via cloud-init:

| Port | Protocol | Purpose |
|------|----------|---------|
| 22 | TCP | SSH |
| 30303 | TCP/UDP | XDC P2P |
| 8545 | TCP | RPC HTTP |
| 8546 | TCP | RPC WebSocket |
| 3000 | TCP | Grafana |

Modify with UFW:
```bash
# View status
ufw status

# Restrict RPC to specific IP
ufw delete allow 8545/tcp
ufw allow from 203.0.113.0 to any port 8545
```

## Monitoring

### Built-in Monitoring

- **Prometheus**: http://localhost:9090 (local only)
- **Grafana**: http://droplet-ip:3000
- **Node Exporter**: System metrics
- **cAdvisor**: Container metrics

### DigitalOcean Monitoring

Enable additional monitoring:
```bash
curl -sSL https://insights.nyc3.cdn.digitaloceanspaces.com/install.sh | sudo bash
```

### Alerts

Set up alerts via:
- Grafana Alerting
- DigitalOcean Monitoring Alerts
- Uptime checks

## Backup

### Snapshot Backup

```bash
# Create snapshot
doctl compute droplet-action snapshot <droplet-id> \
  --snapshot-name "xdc-backup-$(date +%Y%m%d)"

# List snapshots
doctl compute snapshot list
```

### Volume Backup

```bash
# Create volume snapshot
doctl compute volume snapshot <volume-id> \
  --snapshot-name "xdc-data-backup"
```

## Troubleshooting

### Node Not Starting

```bash
# Check logs
journalctl -u xdc-node.service

# Check Docker
docker ps -a
docker logs xdc-node

# Check resources
free -h
df -h
```

### Sync Issues

```bash
# Check sync status
curl -s -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' | jq

# Check peers
curl -s -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' | jq
```

### Disk Space

```bash
# Check usage
df -h /opt/xdc-node

# Clean Docker
docker system prune -a

# Expand volume (if using block storage)
resize2fs /dev/sda
```

## Cost Optimization

### Reserved Capacity

No reserved instances on DigitalOcean, but consider:
- Long-term droplet discounts
- Volume snapshots vs backups

### Right-sizing

Monitor and adjust:
```bash
# Check resource usage
/opt/xdc-node/scripts/node-health-check.sh --full
```

## Support

- **Documentation**: https://docs.xdc.network
- **GitHub Issues**: https://github.com/XDC-Node-Setup/issues
- **Community**: https://discord.gg/xdc

## Resources

- [DigitalOcean Droplet Documentation](https://docs.digitalocean.com/products/droplets/)
- [DigitalOcean API Reference](https://docs.digitalocean.com/reference/api/)
- [XDC Network Documentation](https://docs.xdc.network)
