# XDC Node Setup - Architecture Overview

**Version:** 1.0  
**Date:** February 25, 2026  
**Project:** XDC Node Setup (SkyOne)

---

## Table of Contents

1. [System Architecture](#1-system-architecture)
2. [Component Overview](#2-component-overview)
3. [Multi-Client Support](#3-multi-client-support)
4. [Security Architecture](#4-security-architecture)
5. [Monitoring Stack](#5-monitoring-stack)
6. [Deployment Options](#6-deployment-options)
7. [Data Flow](#7-data-flow)

---

## 1. System Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         XDC Node Setup Architecture                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────┐    ┌──────────────┐    ┌─────────────┐                 │
│  │   CLI Tool  │    │  SkyOne UI   │    │  SkyNet API │                 │
│  │   (xdc)     │◄──►│  (Port 7070) │◄──►│  (Optional) │                 │
│  └──────┬──────┘    └──────┬───────┘    └─────────────┘                 │
│         │                  │                                             │
│         ▼                  ▼                                             │
│  ┌──────────────────────────────────────────────────┐                   │
│  │              Docker Compose Stack                 │                   │
│  ├──────────────────────────────────────────────────┤                   │
│  │  ┌───────────┐  ┌───────────┐  ┌──────────────┐  │                   │
│  │  │ XDC Node  │  │  SkyOne   │  │ Prometheus   │  │                   │
│  │  │  (Geth/   │  │ Dashboard │  │  (Metrics)   │  │                   │
│  │  │  Erigon)  │  │           │  │              │  │                   │
│  │  └─────┬─────┘  └───────────┘  └──────────────┘  │                   │
│  │        │                                         │                   │
│  │        ▼                                         │                   │
│  │  ┌───────────┐  ┌───────────┐                   │                   │
│  │  │  XDC Chain │  │   Data    │                   │                   │
│  │  │   Data    │  │  Volume   │                   │                   │
│  │  └───────────┘  └───────────┘                   │                   │
│  └──────────────────────────────────────────────────┘                   │
│                          │                                              │
│                          ▼                                              │
│  ┌──────────────────────────────────────────────────┐                   │
│  │              XDC P2P Network                      │                   │
│  │         (Mainnet / Testnet / Devnet)              │                   │
│  └──────────────────────────────────────────────────┘                   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Component Overview

### 2.1 XDC Node

The core blockchain client supporting multiple implementations:

| Client | Type | Status | RPC Port | P2P Port |
|--------|------|--------|----------|----------|
| XDC Stable | Official Docker | Production | 8545 | 30303 |
| Geth PR5 | Source Build | Testing | 8545 | 30303 |
| Erigon-XDC | Source Build | Experimental | 8547 | 30304/30311 |
| Nethermind-XDC | .NET Build | Beta | 8558 | 30306 |
| Reth-XDC | Rust Build | Alpha | 7073 | 40303 |

### 2.2 SkyOne Dashboard

Single-node monitoring dashboard built with Next.js:

- **Port:** 7070
- **Features:**
  - Real-time metrics
  - Log viewer
  - Peer map
  - Alert timeline
  - Security score

### 2.3 SkyNet Agent

Optional fleet monitoring integration:

- Auto-registers node with SkyNet
- Sends heartbeats every 30s
- Reports metrics and incidents
- Receives remote commands

---

## 3. Multi-Client Support

### Client Selection

```bash
# Interactive selection
./setup.sh

# Command line
xdc start --client erigon

# Environment variable
CLIENT=erigon ./setup.sh
```

### Port Mapping

```yaml
# docker-compose.multiclient.yml
services:
  xdc-geth:
    ports:
      - "8545:8545"    # RPC
      - "30303:30303"  # P2P
      
  xdc-erigon:
    ports:
      - "8547:8547"    # RPC
      - "30304:30304"  # P2P (eth/63)
      - "30311:30311"  # P2P (eth/68)
      
  xdc-nethermind:
    ports:
      - "8558:8558"    # RPC
      - "30306:30306"  # P2P
```

### Client-Specific Configuration

```bash
# Erigon
ERIGON_MEMORY=12G
ERIGON_CPUS=4
RPC_PORT=8547
P2P_PORT=30304

# Nethermind
NETHERMIND_MEMORY=12G
RPC_PORT=8558
P2P_PORT=30306

# Reth
RETH_MEMORY=16G
RPC_PORT=7073
P2P_PORT=40303
```

---

## 4. Security Architecture

### 4.1 Container Security

```yaml
security_opt:
  - no-new-privileges:true
cap_drop:
  - ALL
cap_add:
  - CHOWN
  - SETGID
  - SETUID
read_only: true
tmpfs:
  - /tmp:nosuid,size=100m,noexec
```

### 4.2 Network Security

| Service | Bind Address | External Access |
|---------|--------------|-----------------|
| RPC | 127.0.0.1:8545 | No (localhost only) |
| WS | 127.0.0.1:8546 | No (localhost only) |
| P2P | 0.0.0.0:30303 | Yes (required) |
| Dashboard | 0.0.0.0:7070 | Optional |

### 4.3 Authentication

```bash
# Dashboard authentication (optional)
DASHBOARD_AUTH_ENABLED=true
DASHBOARD_USER=admin
DASHBOARD_PASS=secure_password

# API key authentication
SKYNET_API_KEY=your_secure_key
```

---

## 5. Monitoring Stack

### 5.1 Prometheus Metrics

| Metric | Description | Interval |
|--------|-------------|----------|
| block_height | Current block number | 15s |
| peer_count | Connected peers | 15s |
| sync_status | Sync progress | 15s |
| cpu_usage | System CPU % | 30s |
| memory_usage | System memory % | 30s |
| disk_usage | Disk utilization | 60s |

### 5.2 Health Checks

```yaml
healthcheck:
  test: ["CMD-SHELL", "curl -sf http://localhost:8545 ..."]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 300s
```

### 5.3 Alert Rules

```yaml
# alerts.yml
groups:
  - name: xdc-node
    rules:
      - alert: NodeDown
        expr: up{job="xdc-node"} == 0
        for: 5m
        
      - alert: SyncStall
        expr: rate(block_height[5m]) == 0
        for: 10m
        
      - alert: LowPeers
        expr: peer_count < 10
        for: 5m
```

---

## 6. Deployment Options

### 6.1 Docker Compose (Recommended)

```bash
# Single node
docker compose up -d

# With monitoring
docker compose -f docker-compose.yml -f docker-compose.monitoring.yml up -d

# Multi-client
docker compose -f docker-compose.multiclient.yml up -d
```

### 6.2 Kubernetes

```bash
# Install Helm chart
helm install xdc-node ./k8s/helm/xdc-node

# With custom values
helm install xdc-node ./k8s/helm/xdc-node -f values.production.yaml
```

### 6.3 Cloud Deployment

| Platform | Template | Cost/Month |
|----------|----------|------------|
| AWS | Packer AMI | ~$140 |
| DigitalOcean | Marketplace | ~$48 |
| Akash | SDL | ~$20-40 |

---

## 7. Data Flow

### 7.1 Node Startup

```
1. setup.sh
   └── Detect OS, install Docker
   
2. docker compose up
   ├── Pull images
   ├── Create volumes
   └── Start containers
   
3. xdc-node
   ├── Load genesis
   ├── Connect to bootnodes
   └── Start sync
   
4. xdc-agent
   ├── Register with SkyNet (optional)
   └── Start dashboard
```

### 7.2 Metric Collection

```
┌───────────┐     ┌───────────┐     ┌───────────┐
│ XDC Node  │────►│  Agent    │────►│  SkyNet   │
│           │     │ (30s)     │     │ (API)     │
└───────────┘     └───────────┘     └───────────┘
       │                                │
       └────────► Prometheus ◄──────────┘
                  (15s)
```

### 7.3 Alert Flow

```
┌───────────┐     ┌───────────┐     ┌───────────┐
│  Incident │────►│  Alert    │────►│  Channel  │
│  Detected │     │  Engine   │     │ (Telegram)│
└───────────┘     └───────────┘     └───────────┘
       │
       └────────► GitHub Issue
                  (Auto-created)
```

---

## References

- [Setup Guide](./SETUP.md)
- [Configuration Guide](./CONFIGURATION.md)
- [Troubleshooting](./TROUBLESHOOTING.md)
- [XDPoS Consensus Guide](./XDPOS_CONSENSUS_GUIDE.md)

---

*Document maintained by XDC EVM Expert Agent*
