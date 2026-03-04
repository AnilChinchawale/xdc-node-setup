# XDC Node Setup - Configuration Guide

**Version:** 1.0  
**Date:** March 4, 2026

---

## Table of Contents

1. [Configuration Overview](#configuration-overview)
2. [Environment Variables](#environment-variables)
3. [Config.toml Reference](#configtoml-reference)
4. [Network Configuration](#network-configuration)
5. [Client-Specific Configuration](#client-specific-configuration)
6. [Security Configuration](#security-configuration)
7. [Monitoring Configuration](#monitoring-configuration)
8. [Troubleshooting](#troubleshooting)

---

## Configuration Overview

XDC Node Setup uses a hierarchical configuration system:

1. **Environment Variables** - Highest priority, runtime overrides
2. **config.toml** - Node-specific configuration
3. **Docker Compose** - Container orchestration settings
4. **Default Values** - Fallback configuration

### Configuration Files Location

```
XDC-Node-Setup/
├── mainnet/
│   ├── .xdc-node/
│   │   ├── config.toml      # Node configuration
│   │   ├── node.env         # Environment variables
│   │   └── client.conf      # Client selection
│   └── xdcchain/            # Blockchain data
├── testnet/
│   └── ...
└── docker/
    └── docker-compose.yml   # Container configuration
```

---

## Environment Variables

### Core Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `NETWORK` | mainnet | Network: mainnet, testnet, devnet, apothem |
| `NODE_TYPE` | full | Node type: full, archive, rpc, masternode |
| `CLIENT` | stable | Client: stable, geth-pr5, erigon, nethermind, reth |
| `SYNC_MODE` | snap | Sync mode: full, snap, fast |

### Port Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `RPC_PORT` | 8545 | JSON-RPC HTTP port |
| `WS_PORT` | 8546 | WebSocket port |
| `P2P_PORT` | 30303 | P2P networking port |
| `DASHBOARD_PORT` | 7070 | SkyOne dashboard port |
| `METRICS_PORT` | 6060 | Prometheus metrics port |

### Erigon-Specific Ports

| Variable | Default | Description |
|----------|---------|-------------|
| `ERIGON_RPC_PORT` | 8547 | Erigon RPC port |
| `ERIGON_AUTHRPC_PORT` | 8561 | Erigon authenticated RPC |
| `ERIGON_P2P_PORT` | 30304 | Erigon P2P (eth/63) |
| `ERIGON_P2P_PORT_68` | 30311 | Erigon P2P (eth/68) |

### Data Directories

| Variable | Default | Description |
|----------|---------|-------------|
| `DATA_DIR` | ./mainnet/xdcchain | Blockchain data directory |
| `STATE_DIR` | ./mainnet/.xdc-node | Node state directory |
| `CONFIG_DIR` | ./configs | Configuration templates |

### Feature Flags

| Variable | Default | Description |
|----------|---------|-------------|
| `ENABLE_MONITORING` | false | Enable Prometheus/Grafana |
| `ENABLE_SKYNET` | false | Enable SkyNet fleet monitoring |
| `ENABLE_SECURITY` | true | Enable security hardening |
| `ENABLE_UPDATES` | true | Enable auto-updates |

### Security Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `RPC_CORS` | localhost | CORS allowed origins |
| `RPC_VHOSTS` | localhost | Virtual hosts whitelist |
| `WS_ORIGINS` | localhost | WebSocket allowed origins |
| `RPC_ADDR` | 127.0.0.1 | RPC bind address |

---

## Config.toml Reference

### Example Configuration

```toml
# XDC Node Configuration
# Network: mainnet (Chain ID: 50)

[node]
NetworkId = 50
DataDir = "/xdcchain"
HTTPPort = 8545
WSPort = 8546
Port = 30303
MaxPeers = 50

[eth]
SyncMode = "snap"
GCMode = "full"
Cache = 4096

[eth.txpool]
PriceLimit = 1
PriceBump = 10
AccountSlots = 16
GlobalSlots = 4096
AccountQueue = 64
GlobalQueue = 1024

[rpc]
HTTPHost = "127.0.0.1"
HTTPVirtualHosts = ["localhost"]
HTTPCors = ["localhost"]
WSHost = "127.0.0.1"
WSOrigins = ["localhost"]

[metrics]
Enabled = true
Port = 6060

[xdpos]
Epoch = 900
Gap = 450
```

### Configuration Sections

#### [node] Section

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| NetworkId | int | 50 | Network identifier |
| DataDir | string | /xdcchain | Data directory path |
| HTTPPort | int | 8545 | RPC HTTP port |
| WSPort | int | 8546 | WebSocket port |
| Port | int | 30303 | P2P port |
| MaxPeers | int | 50 | Maximum peer connections |

#### [eth] Section

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| SyncMode | string | snap | Sync mode: full, snap, fast |
| GCMode | string | full | Garbage collection mode |
| Cache | int | 4096 | Memory cache in MB |

#### [rpc] Section

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| HTTPHost | string | 127.0.0.1 | HTTP bind address |
| HTTPVirtualHosts | []string | ["localhost"] | Virtual hosts |
| HTTPCors | []string | ["localhost"] | CORS origins |
| WSHost | string | 127.0.0.1 | WebSocket bind address |
| WSOrigins | []string | ["localhost"] | WS allowed origins |

---

## Network Configuration

### Mainnet (Chain ID: 50)

```toml
[node]
NetworkId = 50

# Bootnodes
BootstrapNodes = [
  "enode://9a977b1ac4320fa2c862dcaf536aaaea3a8f8f7cd14e3bcde32e5a1c0152bd17bd18bfdc3c2ca8c4a0f3da153c62935fea1dc040cc1e66d2c07d6b4c91e2ed42@bootnode.xinfin.network:30303"
]
```

### Testnet/Apothem (Chain ID: 51)

```toml
[node]
NetworkId = 51

# Bootnodes
BootstrapNodes = [
  "enode://91e59fa1b034ae35e9f4e8a99cc6621f09d74e76a6220abb6c93b29ed41a9e1fc4e5b70e2c5fc43f883cffbdcd6f4f6cbc1d23af077f28c2aecc22403355d4b1@bootnodes.apothem.network:30312"
]
```

### Devnet (Chain ID: 551)

```toml
[node]
NetworkId = 551

# Local bootnodes - configure as needed
BootstrapNodes = []
```

---

## Client-Specific Configuration

### Geth Stable

```yaml
# docker-compose.yml
services:
  xdc-node:
    image: xinfinorg/xdposchain:v2.6.8
    ports:
      - "8545:8545"      # RPC
      - "8546:8546"      # WebSocket
      - "30303:30303"    # P2P
      - "6060:6060"      # Metrics
```

### Erigon-XDC

```yaml
# docker-compose.erigon.yml
services:
  xdc-erigon:
    image: anilchinchawale/erix:latest
    ports:
      - "8547:8547"      # RPC
      - "8561:8561"      # Auth RPC
      - "30304:30304"    # P2P (eth/63)
      - "30311:30311"    # P2P (eth/68)
      - "9091:9091"      # Private API
    environment:
      - ERIGON_CHAIN=xdc
```

### Nethermind-XDC

```yaml
# docker-compose.nethermind.yml
services:
  xdc-nethermind:
    image: anilchinchawale/nmx:latest
    ports:
      - "8558:8558"      # RPC
      - "30306:30306"    # P2P
    environment:
      - NETHERMIND_CONFIG=xdc
      - NETHERMIND_JSONRPCCONFIG_ENABLED=true
      - NETHERMIND_JSONRPCCONFIG_HOST=0.0.0.0
      - NETHERMIND_JSONRPCCONFIG_PORT=8558
```

### Reth-XDC

```yaml
# docker-compose.reth.yml
services:
  xdc-reth:
    image: xdc/reth:latest
    ports:
      - "7073:7073"      # RPC
      - "40303:40303"    # P2P
      - "40304:40304"    # Discovery
```

---

## Security Configuration

### Secure RPC Configuration

```bash
# .env
# Bind to localhost only
RPC_ADDR=127.0.0.1
WS_ADDR=127.0.0.1

# Restrict CORS
RPC_CORS=localhost
RPC_VHOSTS=localhost
WS_ORIGINS=localhost

# Enable authentication (if supported)
RPC_API=eth,net,web3
# Remove admin, personal from public API
```

### Firewall Configuration

```bash
# UFW rules
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (restrict to your IP)
sudo ufw allow from YOUR_IP to any port 22

# Allow P2P
sudo ufw allow 30303/tcp
sudo ufw allow 30303/udp

# Allow additional client P2P ports (if multi-client)
sudo ufw allow 30304/tcp  # Erigon
sudo ufw allow 30306/tcp  # Nethermind

# Dashboard (optional, restrict if possible)
sudo ufw allow 7070/tcp

# Enable firewall
sudo ufw enable
```

### Nginx Reverse Proxy

```nginx
# /etc/nginx/sites-available/xdc-rpc
server {
    listen 443 ssl http2;
    server_name rpc.yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;

    location / {
        # Rate limiting
        limit_req zone=rpc burst=20 nodelay;
        
        # Proxy to local RPC
        proxy_pass http://127.0.0.1:8545;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        
        # Authentication
        auth_basic "XDC RPC";
        auth_basic_user_file /etc/nginx/.htpasswd;
    }
}
```

---

## Monitoring Configuration

### Prometheus Configuration

```yaml
# prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'xdc-node'
    static_configs:
      - targets: ['xdc-node:6060']
    metrics_path: /debug/metrics/prometheus
  
  - job_name: 'erigon-node'
    static_configs:
      - targets: ['xdc-erigon:6071']
```

### Alertmanager Configuration

```yaml
# alertmanager.yml
global:
  smtp_smarthost: 'localhost:587'
  smtp_from: 'alerts@yourdomain.com'

route:
  receiver: 'default'
  routes:
    - match:
        severity: critical
      receiver: 'pagerduty'
    - match:
        severity: warning
      receiver: 'email'

receivers:
  - name: 'default'
    email_configs:
      - to: 'admin@yourdomain.com'
  
  - name: 'pagerduty'
    pagerduty_configs:
      - service_key: 'your-key'
```

### SkyNet Integration

```bash
# Enable SkyNet monitoring
export ENABLE_SKYNET=true
export SKYNET_API_URL=https://net.xdc.network
export SKYNET_API_KEY=your-api-key

# Node will auto-register on first start
```

---

## Troubleshooting

### Configuration Not Applied

```bash
# Check config file location
xdc config list

# Verify file permissions
ls -la mainnet/.xdc-node/config.toml

# Restart node to apply changes
xdc restart
```

### Port Conflicts

```bash
# Check port usage
sudo ss -tlnp | grep -E '8545|30303|7070'

# Find free ports
xdc config set RPC_PORT 8546
xdc config set P2P_PORT 30304
```

### Client Not Starting

```bash
# Check client configuration
cat mainnet/.xdc-node/client.conf

# Verify Docker image
docker pull xinfinorg/xdposchain:v2.6.8

# Check logs
xdc logs --follow
```

---

## Related Documentation

- [Architecture Overview](ARCHITECTURE.md)
- [API Reference](API.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md)
- [Security Audit](SECURITY_AUDIT.md)
