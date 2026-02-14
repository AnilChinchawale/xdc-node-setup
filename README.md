# XDC Node Setup

<div align="center">

**Production-ready XDC Network node deployment in minutes**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/Docker-20.10+-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![XDC Network](https://img.shields.io/badge/XDC-Network-brightgreen)](https://xdc.network/)

</div>

---

## Features

- 🚀 **One-command deployment** — Get a node running in under 5 minutes
- 🔒 **Security hardened** — SSH hardening, firewall, fail2ban, audit logging
- 📊 **Built-in monitoring** — Prometheus + Grafana dashboards on port 8888
- 🌐 **Multi-network support** — Mainnet, Testnet (Apothem), Devnet
- 📡 **SkyNet integration** — Auto-registers with XDC SkyNet for fleet monitoring
- 💾 **Fast sync** — Snapshot download with resume support
- 🔄 **Version management** — Automatic updates and health checks
- 🛠️ **Powerful CLI** — Single `xdc` command for all operations

---

## Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/AnilChinchawale/XDC-Node-Setup.git
cd XDC-Node-Setup

# 2. Run the installer
sudo ./setup.sh

# 3. Check node status
xdc status
```

Your node will be running and syncing. Access the dashboard at `http://localhost:8888`

---

## Requirements

| Component | Requirement |
|-----------|-------------|
| **OS** | Linux x86_64 (Ubuntu 20.04+, Debian 11+, RHEL 8+) |
| **Docker** | 20.10+ with Docker Compose v2+ |
| **RAM** | 4GB minimum, 16GB+ recommended |
| **Disk** | 100GB minimum, 500GB+ SSD recommended |
| **Network** | Stable internet connection, 100 Mbps+ |

---

## CLI Reference

The `xdc` command provides full control over your node:

| Command | Description |
|---------|-------------|
| `xdc status` | Display current node status and sync progress |
| `xdc start` | Start the XDC node container |
| `xdc stop` | Stop the XDC node container |
| `xdc restart` | Restart the node (graceful) |
| `xdc logs` | View node logs (follow mode) |
| `xdc attach` | Attach to the XDC console |
| `xdc peers` | List connected peers |
| `xdc health` | Run full health check with security score |
| `xdc info` | Show detailed node and chain info |
| `xdc sync` | Check sync status and block height |
| `xdc backup` | Create encrypted backup of node data |
| `xdc snapshot` | Download and apply chain snapshot for fast sync |
| `xdc security` | Run security audit and apply hardening |
| `xdc monitor` | Open monitoring dashboard |
| `xdc update` | Check for and apply version updates |
| `xdc help` | Show command help |

**Examples:**

```bash
# Watch status in real-time
xdc status --watch

# Follow logs
xdc logs --follow

# Download and apply snapshot for fast sync
xdc snapshot download --network mainnet
xdc snapshot apply

# Start with monitoring stack
xdc start --monitoring

# Run health check with notifications
xdc health --full --notify
```

---

## Dashboard

The built-in web dashboard provides real-time monitoring on **port 8888**:

![Dashboard Screenshot](docs/images/dashboard-overview.png)

**Features:**
- Live block height and sync status
- Peer count and network health
- CPU, memory, and disk usage
- Security score with recommendations
- Alert timeline and notifications

Access at: `http://localhost:8888` (or `http://<your-server-ip>:8888`)

---

## Monitoring (Optional)

Enable the full Prometheus + Grafana monitoring stack:

```bash
xdc start --monitoring
```

**Includes:**
- **Prometheus** — Metrics collection (port 9090)
- **Grafana** — Visualization dashboards (port 3000)
- **Node Exporter** — System metrics
- **cAdvisor** — Container metrics

**Grafana Access:**
- URL: `http://localhost:3000`
- Default credentials: `admin` / `admin`
- Pre-configured dashboards for XDC node metrics

---

## Configuration

Configuration files are stored in `{network}/.xdc-node/config.toml`

### Location by Network

- **Mainnet:** `mainnet/.xdc-node/config.toml`
- **Testnet:** `testnet/.xdc-node/config.toml`
- **Devnet:** `devnet/.xdc-node/config.toml`

### Key Settings

```toml
[node]
NetworkId = 50           # 50 = mainnet, 51 = testnet
DataDir = "/xdcchain"
HTTPPort = 8545
WSPort = 8546
Port = 30303

[eth]
SyncMode = "full"        # full, fast, or archive
GCMode = "full"

[networking]
MaxPeers = 50
NAT = "any"
```

**Edit configuration:**

```bash
# View current config
xdc config list

# Edit config file
nano mainnet/.xdc-node/config.toml

# Apply changes
xdc restart
```

---

## Networks

XDC Node Setup supports multiple networks:

| Network | Network ID | Use Case | Snapshot Available |
|---------|------------|----------|-------------------|
| **Mainnet** | 50 | Production | ✅ Yes |
| **Testnet (Apothem)** | 51 | Development & Testing | ✅ Yes |
| **Devnet** | 551 | Local Development | ❌ No |

**Switch networks:**

```bash
# Configure during setup
sudo NETWORK=testnet ./setup.sh

# Or manually switch
cd testnet
docker-compose up -d
```

---


## Multi-Client Support

XDC Node Setup supports **three different clients** for improved network diversity and resilience:

### Available Clients

| Client | Version | Type | Recommended For |
|--------|---------|------|-----------------|
| **Stable** | v2.6.8 | Official Docker image | Production, Default |
| **Geth PR5** | Latest | Built from source | Testing latest features |
| **Erigon-XDC** | Latest | Built from source | Multi-client diversity |

### Client Features

#### 🟢 XDC Stable (v2.6.8) — **Recommended**
- Official production-ready Docker image
- Battle-tested on mainnet
- No build time required
- RPC on port **8545**

#### 🔵 XDC Geth PR5
- Latest geth with XDPoS consensus (`feature/xdpos-consensus` branch)
- Built from source with Go 1.22+
- Same RPC API as stable
- RPC on port **8545**
- **Build time:** ~10-15 minutes

#### 🟣 Erigon-XDC — **Experimental**
- Multi-client diversity for network resilience
- Built from source with Go 1.22+
- **Dual P2P sentries:** eth/63 (port **30304**) + eth/68 (port **30311**)
- RPC on port **8547**
- **Build time:** ~10-15 minutes

### Selecting a Client

During setup, you'll be prompted to choose a client:

```bash
Client Selection
=================
1) XDC Stable (v2.6.8) - Official Docker image (recommended)
2) XDC Geth PR5 - Latest geth with XDPoS (builds from source, ~10-15 min)
3) Erigon-XDC - Multi-client diversity, experimental (builds from source, ~10-15 min)

Select client [1-3] (default: 1):
```

### Starting with a Specific Client

You can override the configured client at runtime:

```bash
# Start with default client (from config)
xdc start

# Start with specific client
xdc start --client stable
xdc start --client geth-pr5
xdc start --client erigon

# Check current client
xdc client
```

### Client Information

```bash
$ xdc client
XDC Client Information

Configured Client: stable
  Config: /opt/xdc-node/mainnet/.xdc-node/client.conf

Running Client:
  Version: XDPoSChain/v2.6.8-stable
  Type:    XDC Stable

Available Clients:
  1. stable    - XDC Stable (v2.6.8) - Official Docker image
  2. geth-pr5  - XDC Geth PR5 - Latest geth with XDPoS
  3. erigon    - Erigon-XDC - Multi-client diversity

To switch clients, run: xdc start --client <name>
```

### Network Diversity Benefits

Running different clients helps:
- ✅ Prevent single-client bugs from affecting the entire network
- ✅ Improve network resilience and decentralization
- ✅ Test new features before mainnet rollout
- ✅ Catch consensus issues early

### Port Configuration

| Client | HTTP-RPC | P2P (eth/63) | P2P (eth/68) |
|--------|----------|--------------|--------------|
| Stable | 8545 | 30303 | — |
| Geth PR5 | 8545 | 30303 | — |
| Erigon-XDC | **8547** | **30304** | **30311** |

**Note:** Erigon uses different ports to avoid conflicts with other clients.

### Learn More

For detailed setup instructions, configuration options, and troubleshooting for each client:

- **[Erigon-XDC Client Guide](docs/ERIGON.md)** — Multi-client diversity, dual P2P sentries, peer connection guide
- **[Geth PR5 Client Guide](docs/GETH-PR5.md)** — Latest go-ethereum with XDPoS, state schemes, comparison table
- **[Dashboard Setup Guide](docs/DASHBOARD.md)** — SkyOne monitoring dashboard configuration

---

## SkyNet Integration

XDC Node Setup automatically registers your node with **XDC SkyNet** for fleet-wide monitoring and analytics.

**Features:**
- 📊 Centralized dashboard for all your nodes
- 🔔 Unified alerting across your fleet
- 📈 Historical metrics and analytics
- 🌍 Network-wide statistics

**How it works:**
1. During setup, the installer creates a unique node identifier
2. Node metrics are automatically reported to SkyNet every 15 minutes
3. Access your fleet at: [https://skynet.xdc.network](https://skynet.xdc.network)

**Disable SkyNet (optional):**

```bash
# Edit config
xdc config set skynet_enabled false
xdc restart
```

---

## Snapshot Download

Fast-sync your node using official XDC Network snapshots instead of syncing from genesis.

**Download and apply snapshot:**

```bash
# Download latest mainnet snapshot
xdc snapshot download --network mainnet

# Apply snapshot (node must be stopped)
xdc stop
xdc snapshot apply
xdc start
```

**Features:**
- ⚡ **Fast sync** — Skip weeks of blockchain sync
- 🔄 **Resume support** — Interrupted downloads can resume
- ✅ **Verification** — Automatic checksum validation
- 🗜️ **Compressed** — Reduced download size

**Manual download (if needed):**

```bash
# Check available snapshots
xdc snapshot list

# Download specific snapshot
xdc snapshot download --date 2026-02-10

# Verify snapshot integrity
xdc snapshot verify snapshot-mainnet-2026-02-10.tar.gz
```

Snapshots are updated daily and hosted at: `https://download.xdc.network/snapshots/`

---

## Troubleshooting

### Node won't sync

```bash
# Check if node is running
xdc status

# Check peer count
xdc peers

# If no peers, restart with fresh peer discovery
xdc stop
rm -rf mainnet/.xdc-node/geth/nodes
xdc start
```

### High CPU/Memory usage

```bash
# Check resource usage
xdc info

# Reduce cache if needed (edit config.toml)
[node]
Cache = 2048  # Reduce from default 4096

# Restart to apply
xdc restart
```

### Disk space running out

```bash
# Check disk usage
df -h

# Enable pruning (archive nodes excluded)
xdc config set prune_mode full
xdc restart

# Or use a snapshot to start fresh
xdc backup create  # Backup first!
xdc snapshot apply
```

### Can't access dashboard

```bash
# Check if port 8888 is open
sudo ufw allow 8888

# Check if dashboard is running
docker ps | grep dashboard

# Restart dashboard
xdc monitor restart
```

### Connection refused (RPC)

```bash
# Check RPC is enabled
xdc config get rpc_enabled  # Should be true

# Check RPC is listening
netstat -tlnp | grep 8545

# Allow RPC port if needed
sudo ufw allow 8545
```

**More help:**
- [Full Troubleshooting Guide](docs/TROUBLESHOOTING.md)
- [GitHub Issues](https://github.com/AnilChinchawale/XDC-Node-Setup/issues)
- [XDC Network Docs](https://docs.xdc.community/)

---

## Contributing

Contributions are welcome! Here's how to get started:

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/my-feature`
3. **Commit** your changes: `git commit -am 'Add new feature'`
4. **Push** to the branch: `git push origin feature/my-feature`
5. **Submit** a Pull Request

**Development guidelines:**
- All scripts must pass `shellcheck` linting
- Include error handling (`set -euo pipefail`)
- Add tests for new features
- Update documentation

---

## License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

---

<div align="center">

**[Documentation](docs/)** • **[Issues](https://github.com/AnilChinchawale/XDC-Node-Setup/issues)** • **[XDC Network](https://xdc.network/)**

Built with ❤️ for the XDC Network community

</div>
