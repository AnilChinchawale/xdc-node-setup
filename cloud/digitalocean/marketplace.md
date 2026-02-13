# DigitalOcean Marketplace Submission Guide

This guide covers submitting the XDC Node as a 1-Click App on DigitalOcean Marketplace.

## Prerequisites

- DigitalOcean account with API access
- Packer installed locally
- XDC Node source code ready

## Building the Snapshot

### 1. Set Up Environment

```bash
export DIGITALOCEAN_TOKEN="your-do-api-token"
export XDC_VERSION="v2.6.8"
```

### 2. Validate Packer Template

```bash
cd cloud/digitalocean
packer validate packer.json
```

### 3. Build the Snapshot

```bash
packer build packer.json
```

This will:
- Create a temporary droplet
- Install Docker and XDC node
- Configure the environment
- Create a snapshot in multiple regions
- Clean up temporary resources

### 4. Note the Snapshot ID

After build completion, note the snapshot ID from the output:
```
==> digitalocean: Creating snapshot: xdc-node-2024-01-15-143022
==> digitalocean: Snapshot ID: 12345678
```

## Marketplace Submission

### Step 1: Vendor Portal

1. Visit [DigitalOcean Vendor Portal](https://marketplace.digitalocean.com/vendors)
2. Sign up as a vendor or log in
3. Create a new 1-Click App submission

### Step 2: App Information

**Basic Info:**
- **Name**: XDC Network Node
- **Tagline**: Deploy a full XDC blockchain node in minutes
- **Category**: Blockchain / Developer Tools
- **Short Description**: One-click deployment of XDC Network nodes for mainnet, testnet, or devnet.

**Detailed Description:**
```
XDC Network Node provides a complete, production-ready blockchain node deployment on DigitalOcean. 

Features:
- Pre-configured Docker environment
- Automatic node synchronization
- Built-in monitoring with Grafana dashboards
- Secure firewall configuration
- Fail2ban protection
- Auto-start on boot

Node Types Supported:
- Full Node: Participate in network consensus
- Archive Node: Full historical state access
- Masternode: Block production and validation
- RPC Node: API endpoint for dApps

What's Included:
- XDC Client (XDPoSChain) v2.6.8
- Docker & Docker Compose
- Prometheus monitoring
- Grafana visualization
- Node health checks
- Auto-update scripts

Getting Started:
1. Create droplet from this image
2. SSH into your droplet
3. Run 'xdc-status' to check node status
4. Access Grafana at http://your-droplet-ip:3000

Use Cases:
- Blockchain infrastructure
- dApp development
- Network participation
- RPC endpoint hosting
- Validator operations
```

### Step 3: Technical Details

**Supported Regions:**
- nyc1, nyc3
- sfo3
- ams3
- sgp1
- lon1
- fra1
- tor1
- blr1

**Recommended Plans:**
| Node Type | Droplet Size | Monthly Cost |
|-----------|-------------|--------------|
| Full Node | s-4vcpu-8gb | $48 |
| Archive | s-8vcpu-16gb | $96 |
| Masternode | s-8vcpu-16gb | $96 |
| RPC Node | c-4 | $72 |

**Default Username:** `root`
**Authentication:** SSH Key (required)

### Step 4: Configuration

**User Data:** Not required (pre-baked in image)

**Firewall:** Pre-configured via cloud-init
- 22/tcp (SSH)
- 30303/tcp+udp (XDC P2P)
- 8545/tcp (RPC HTTP)
- 8546/tcp (RPC WebSocket)
- 3000/tcp (Grafana)

### Step 5: Images

Upload the following assets:

**Logo:** (300x300px, PNG)
- XDC logo with transparent background

**Screenshots:** (1200x800px, PNG)
1. Terminal showing xdc-status output
2. Grafana dashboard
3. Docker containers running

### Step 6: Documentation

**Getting Started Guide:**

```markdown
# Getting Started with XDC Node

## Connect to Your Droplet

```bash
ssh root@your-droplet-ip
```

## Check Node Status

```bash
xdc-status
```

## View Logs

```bash
xdc-logs
```

## Access Grafana

1. Open http://your-droplet-ip:3000
2. Default credentials: admin / [check /opt/xdc-node/.env]
3. Change password on first login

## Update Node

```bash
cd /opt/xdc-node
docker-compose pull
docker-compose up -d
```

## Support

- Documentation: https://docs.xdc.network
- GitHub: https://github.com/XDC-Node-Setup
- Discord: https://discord.gg/xdc
```

## Testing Checklist

Before submission, verify:

- [ ] Snapshot creates droplet successfully
- [ ] Docker containers start automatically
- [ ] Node begins syncing within 5 minutes
- [ ] xdc-status command works
- [ ] Grafana accessible on port 3000
- [ ] RPC endpoints respond
- [ ] Firewall rules applied correctly
- [ ] SSH access works with key
- [ ] No error messages in logs
- [ ] Reboot persists configuration

## Submission Process

1. Submit application via Vendor Portal
2. DigitalOcean reviews (3-5 business days)
3. Address any feedback
4. Receive approval
5. App goes live on Marketplace

## Post-Launch Maintenance

### Update Cycle

1. Build new snapshot with updated XDC version
2. Submit update via Vendor Portal
3. DigitalOcean reviews and publishes

### Monitoring

Track:
- Number of deployments
- User feedback/ratings
- Support requests
- Droplet success rate

## Pricing Considerations

DigitalOcean takes 0% for open-source 1-Click Apps. 

Consider offering:
- Free community support
- Paid enterprise support plans
- Managed node services

## Legal Requirements

Ensure compliance with:
- DigitalOcean Terms of Service
- Open source licenses (GPL, Apache 2.0, etc.)
- XDC Network governance rules

## Marketing Assets

Prepare:
- Social media announcement
- Blog post tutorial
- Video walkthrough
- Documentation site
