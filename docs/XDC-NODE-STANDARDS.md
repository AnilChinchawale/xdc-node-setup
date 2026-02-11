# XDC Node Infrastructure Standards

> Industry-grade standards for running XDC Network nodes — security, compliance, monitoring, and automated version management.

**Live Dashboard:** [cloud.xdcrpc.com/admin/nodes](https://cloud.xdcrpc.com/admin/nodes)

---

## Table of Contents

1. [Server Security](#1-server-security)
2. [Audit & Compliance](#2-audit--compliance)
3. [Smart Engineering](#3-smart-engineering)
4. [Single-Pane Monitoring](#4-single-pane-monitoring)
5. [Version Management](#5-version-management--auto-update)
6. [Security Scorecard](#6-security-scorecard)
7. [XDC-Specific Requirements](#7-xdc-specific-requirements)
8. [Quick Start](#8-quick-start)

---

## 1. Server Security

### SSH Hardening
```bash
# /etc/ssh/sshd_config
PermitRootLogin prohibit-password   # Key-only auth
PasswordAuthentication no            # Disable password login
Port 12141                          # Non-standard port
MaxAuthTries 3
AllowUsers root                     # Explicit allowlist
```

### Firewall (UFW)
```bash
ufw default deny incoming
ufw default allow outgoing
ufw allow 12141/tcp    # SSH (custom port)
ufw allow 30303/tcp    # XDC P2P
ufw allow 30303/udp    # XDC P2P discovery
# RPC ports (internal only — never expose publicly)
# ufw allow from 127.0.0.1 to any port 8545
ufw enable
```

> ⚠️ **Never expose RPC ports (8545, 8989) to the internet.** Use a reverse proxy (Nginx) with rate limiting and API key authentication.

### Fail2ban
```ini
# /etc/fail2ban/jail.local
[sshd]
enabled = true
port = 12141
maxretry = 3
bantime = 3600
findtime = 600
```

### Disk Encryption
- **LUKS** for data-at-rest encryption on chain data volumes
- Encrypt `/root/xdcchain` and `/root/erigon-data` partitions
- Store keys in hardware security module (HSM) for production

### Secrets Management
- **Never store secrets in `.env` files on disk** in production
- Use HashiCorp Vault, AWS Secrets Manager, or SOPS-encrypted configs
- Rotate credentials every 90 days
- Separate secrets per environment (test/staging/prod)

---

## 2. Audit & Compliance

### SOC 2 Type II
The gold standard for RPC infrastructure providers (Alchemy, Infura, QuickNode all maintain it):
- **Security**: Access controls, encryption, network security
- **Availability**: Uptime SLAs, redundancy, disaster recovery
- **Processing Integrity**: Accurate data processing, error handling
- **Confidentiality**: Data classification, encryption at rest/transit
- **Privacy**: PII handling, data retention policies

### Audit Logging
```bash
# Install and configure auditd
apt install auditd audispd-plugins
# Log all admin commands
auditctl -a always,exit -F arch=b64 -S execve -F uid=0 -k admin-commands
# Log file access to chain data
auditctl -w /root/xdcchain -p rwxa -k chaindata-access
# Log SSH events
auditctl -w /var/log/auth.log -p wa -k auth-log
```

### Change Management
- All server configs tracked in Git
- Infrastructure-as-Code (Ansible/Terraform)
- PR-based deploys with mandatory review
- Rollback procedures documented and tested

### Log Retention
| Log Type | Retention | Storage |
|----------|-----------|---------|
| Audit logs | 1 year | Encrypted S3 |
| RPC access logs | 90 days | Compressed local |
| System logs | 30 days | Local + remote syslog |
| Security events | 2 years | Immutable storage |

---

## 3. Smart Engineering

### Client Diversity
Running multiple client implementations prevents single-point-of-failure bugs:

| Client | Status | Purpose |
|--------|--------|---------|
| **geth-xdc** (XDPoSChain) | ✅ Production | Primary consensus client |
| **erigon-xdc** | 🔄 Syncing | Alternative client for diversity |

> XDC Network goal: No single client should run >66% of nodes to prevent consensus bugs from causing chain halts.

### Geographic Distribution
Recommended minimum for production RPC infrastructure:
- **3+ regions** (e.g., EU, US, Asia)
- **2+ providers** per region (Hetzner, OVH, AWS)
- Round-robin DNS or global load balancer

### Circuit Breakers & Failover
- eRPC automatically routes around unhealthy upstreams
- Node health checks every 15 minutes via cron
- Automatic restart via watchdog script (`/root/erigon-watchdog.sh`)
- Telegram alerts on node failure

---

## 4. Single-Pane Monitoring

### Dashboard: `/admin/nodes`
Single page showing all XDC nodes:
- **Sync status** — block height vs mainnet head
- **Peer count** — P2P connectivity health
- **System metrics** — CPU, RAM, disk usage
- **Client version** — current vs latest release
- **Security score** — 0-100 per server
- **Uptime history** — last 30 days

### Grafana Dashboards
- **eRPC Metrics**: Request rates, latency, error rates per upstream
- **Node Health**: Block heights, peer counts, sync progress
- **Access**: [cloud.xdcrpc.com/grafana](https://cloud.xdcrpc.com/grafana)

### Alerting Rules
| Condition | Severity | Action |
|-----------|----------|--------|
| Node offline > 5 min | 🔴 Critical | Telegram alert + auto-restart |
| Block height behind > 100 | 🟡 Warning | Telegram alert |
| Peer count = 0 | 🟡 Warning | Telegram alert |
| Disk usage > 85% | 🟡 Warning | Telegram alert |
| Disk usage > 95% | 🔴 Critical | Telegram alert + prune old data |
| New client version available | 🔵 Info | Telegram notification |
| Security score < 70 | 🟡 Warning | Review required |

---

## 5. Version Management & Auto-Update

### Version Mapping (`configs/versions.json`)
```json
{
  "schemaVersion": 1,
  "checkIntervalHours": 6,
  "clients": {
    "XDPoSChain": {
      "repo": "XinFinOrg/XDPoSChain",
      "current": "v2.6.0",
      "latest": "v2.6.0",
      "autoUpdate": false,
      "nodes": [
        { "host": "65.21.27.213", "role": "production" },
        { "host": "95.217.56.168", "role": "test" },
        { "host": "175.110.113.12", "role": "gcx" }
      ]
    },
    "erigon-xdc": {
      "repo": "AnilChinchawale/erigon-xdc",
      "current": "0.1.0-alpha",
      "autoUpdate": false
    }
  }
}
```

### How It Works
1. **Check script** runs every 6 hours via cron
2. Queries GitHub Releases API for each `repo`
3. Compares `current` vs `latest` version
4. If mismatch detected:
   - `autoUpdate: true` → Pull, build, rolling restart (test first, then prod)
   - `autoUpdate: false` → Telegram notification with changelog link
5. All updates logged to `reports/node-health-YYYY-MM-DD.json`

### Update Strategy
```
New Release Detected
        │
        ▼
   ┌─────────┐     autoUpdate: true
   │  Notify  │────────────────────►  Deploy to TEST
   │  Admin   │                           │
   └─────────┘                       Run tests
        │                                │
   autoUpdate: false              Tests pass?
        │                          Yes ──┤── No → Alert
        ▼                                ▼
   Manual review              Deploy to PRODUCTION
   & approval                     (rolling restart)
```

### Cron Setup
```bash
# Check versions every 6 hours
0 */6 * * * /root/xdc-gateway/scripts/xdc-node-check.sh --notify 2>&1 | logger -t xdc-node-check

# Full health report daily at 6 AM
0 6 * * * /root/xdc-gateway/scripts/xdc-node-check.sh --full --notify 2>&1 | logger -t xdc-node-check
```

---

## 6. Security Scorecard

Each server is scored on a 100-point scale:

| Check | Points | How to Verify |
|-------|--------|---------------|
| SSH key-only auth | 10 | `sshd_config: PasswordAuthentication no` |
| Non-standard SSH port | 5 | `sshd_config: Port != 22` |
| Firewall active (UFW) | 10 | `ufw status: active` |
| Fail2ban running | 5 | `systemctl is-active fail2ban` |
| Unattended upgrades | 5 | `dpkg -l unattended-upgrades` |
| OS patches current | 10 | `apt list --upgradable` count = 0 |
| Client version current | 15 | `current == latest` in versions.json |
| Monitoring active | 10 | Prometheus/node_exporter running |
| Backup configured | 10 | Backup cron exists + recent backup file |
| Audit logging | 10 | `auditd` running |
| Disk encryption (LUKS) | 10 | `lsblk -f` shows LUKS volumes |
| **Total** | **100** | |

### Score Interpretation
| Score | Rating | Action |
|-------|--------|--------|
| 90-100 | 🟢 Excellent | Production ready |
| 70-89 | 🟡 Good | Minor improvements needed |
| 50-69 | 🟠 Fair | Significant gaps, prioritize fixes |
| <50 | 🔴 Poor | Not suitable for production |

---

## 7. XDC-Specific Requirements

### XDPoS Consensus
- **Masternode requirements**: 10M XDC stake for validator
- **Block time**: ~2 seconds
- **Epoch**: 900 blocks (~30 minutes)
- **Protocol versions**: eth/62, eth/63, eth/100 (NOT eth/66+)

### Network Ports
| Port | Protocol | Purpose |
|------|----------|---------|
| 30303 | TCP/UDP | P2P networking |
| 8545 | TCP | HTTP RPC (internal only) |
| 8546 | TCP | WebSocket RPC (internal only) |
| 8989 | TCP | Production RPC (internal only) |

### Data Directory Structure
```
/root/xdcchain/
├── XDC/
│   ├── chaindata/       # Block + state data (~500GB+)
│   ├── lightchaindata/  # Light client data
│   └── nodes/           # Peer database
├── keystore/            # Account keys (backup!)
└── genesis.json         # Network genesis
```

### Recommended Hardware
| Role | CPU | RAM | Disk | Network |
|------|-----|-----|------|---------|
| Full Node | 8+ cores | 32GB | 1TB NVMe SSD | 1 Gbps |
| Archive Node | 16+ cores | 64GB | 4TB+ NVMe SSD | 1 Gbps |
| RPC Node | 8+ cores | 32GB | 1TB NVMe SSD | 10 Gbps |

---

## 8. Quick Start

### Deploy a New XDC Node
```bash
# One-line setup
curl -sSL https://raw.githubusercontent.com/AnilChinchawale/XDC-Node-Setup/main/setup.sh | bash
```

### Run Health Check
```bash
cd /root/xdc-gateway
./scripts/xdc-node-check.sh --full --notify
```

### View Dashboard
Open [cloud.xdcrpc.com/admin/nodes](https://cloud.xdcrpc.com/admin/nodes) (requires admin login).

### Check Security Score
```bash
./scripts/xdc-node-check.sh --security-only
```

---

## References

- [XDC Network Docs](https://docs.xdc.community/)
- [XDPoSChain GitHub](https://github.com/XinFinOrg/XDPoSChain)
- [eRPC Documentation](https://docs.erpc.cloud/)
- [CIS Benchmarks for Ubuntu](https://www.cisecurity.org/benchmark/ubuntu_linux)
- [SOC 2 Compliance Guide](https://www.aicpa.org/soc2)

---

*Last updated: February 11, 2026*
*Maintained by: XDC Gateway Team*
