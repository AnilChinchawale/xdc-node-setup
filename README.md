# XDC-Node-Setup

<p align="center">
  <img src="https://www.xdc.dev/images/logos/site-logo.png" alt="XDC Network" width="200"/>
</p>

<p align="center">
  <strong>Enterprise-grade XDC Network node deployment toolkit</strong>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT"></a>
  <img src="https://img.shields.io/badge/Version-1.0.0-green.svg" alt="Version: 1.0.0">
  <img src="https://img.shields.io/badge/Ubuntu-20.04%2F22.04%2F24.04-orange.svg" alt="Ubuntu: 20.04/22.04/24.04">
  <img src="https://img.shields.io/badge/XDC-v2.6.0-blue.svg" alt="XDC: v2.6.0">
</p>

---

## Overview

**XDC-Node-Setup** is a comprehensive toolkit for deploying, securing, and managing XDC Network nodes. It provides a one-line installer, automated security hardening, continuous monitoring, and version management with optional auto-update capabilities.

### Features

- **One-Line Setup** — Deploy a production-ready XDC node in minutes
- **Security Hardening** — SSH hardening, firewall, fail2ban, audit logging, disk encryption
- **Monitoring Stack** — Prometheus + Grafana dashboards with pre-configured alerts
- **Version Management** — Automated version checking with optional auto-update
- **Health Monitoring** — Continuous health checks with Telegram notifications
- **Backup & Recovery** — Incremental backups with encryption and retention policies
- **Multi-Node Support** — Full Node, Archive Node, or RPC Node configurations

---

## Quick Start

```bash
# One-line installer
curl -sSL https://raw.githubusercontent.com/AnilChinchawale/XDC-Node-Setup/main/setup.sh | bash
```

Or clone and run locally:

```bash
git clone https://github.com/AnilChinchawale/XDC-Node-Setup.git
cd XDC-Node-Setup
sudo ./setup.sh
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        XDC Node Architecture                     │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Full Node     │    │  Archive Node   │    │    RPC Node     │
│  (SYNC_MODE=full)│    │ (SYNC_MODE=archive)│  │  (SYNC_MODE=full) │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │  XDC Client │ │    │ │  XDC Client │ │    │ │  XDC Client │ │
│ │  (P2P:30303)│ │    │ │  (P2P:30303)│ │    │ │  (P2P:30303)│ │
│ └──────┬──────┘ │    │ └──────┬──────┘ │    │ └──────┬──────┘ │
│        │        │    │        │        │    │        │        │
│ ┌──────▼──────┐ │    │ ┌──────▼──────┐ │    │ ┌──────▼──────┐ │
│ │ Chain Data  │ │    │ │ Chain Data  │ │    │ │ Chain Data  │ │
│ │ (~500GB)    │ │    │ │ (~4TB+)     │ │    │ │ (~500GB)    │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
└────────┬────────┘    └────────┬────────┘    └────────┬────────┘
         │                      │                      │
         └──────────────────────┼──────────────────────┘
                                │
┌───────────────────────────────▼───────────────────────────────┐
│                    Monitoring Stack                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐    │
│  │ Prometheus  │  │  Grafana    │  │  Telegram Alerts    │    │
│  │ (Metrics)   │  │(Dashboards) │  │  (Notifications)    │    │
│  └─────────────┘  └─────────────┘  └─────────────────────┘    │
└────────────────────────────────────────────────────────────────┘
```

---

## Documentation

| Document | Description |
|----------|-------------|
| [docs/XDC-NODE-STANDARDS.md](docs/XDC-NODE-STANDARDS.md) | XDC Node Infrastructure Standards |
| [docs/SECURITY.md](docs/SECURITY.md) | Security Best Practices & Hardening Guide |
| [docs/MONITORING.md](docs/MONITORING.md) | Monitoring Setup & Grafana Dashboards |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common Issues & Solutions |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Architecture Overview & Deployment Patterns |

---

## Scripts

| Script | Purpose |
|--------|---------|
| `setup.sh` | One-line installer for XDC node deployment |
| `scripts/security-harden.sh` | Server security hardening |
| `scripts/node-health-check.sh` | Node health monitoring with Telegram alerts |
| `scripts/version-check.sh` | Version management & auto-update |
| `scripts/backup.sh` | Backup chain data, keystore, and configs |
| `cron/setup-crons.sh` | Install all scheduled cron jobs |

---

## Directory Structure

```
XDC-Node-Setup/
├── configs/              # Configuration templates
│   ├── versions.json     # Version mapping
│   ├── mainnet.env       # Mainnet environment
│   ├── testnet.env       # Testnet environment
│   ├── firewall.rules    # UFW rules
│   ├── fail2ban.conf     # Fail2ban config
│   └── sshd_config.template  # Hardened SSH config
├── docker/               # Docker deployment
│   ├── docker-compose.yml
│   └── Dockerfile
├── docs/                 # Documentation
├── monitoring/           # Prometheus & Grafana
│   ├── prometheus.yml
│   ├── alerts.yml
│   └── grafana/dashboards/
├── scripts/              # Utility scripts
├── systemd/              # Systemd services
├── cron/                 # Cron job setup
├── setup.sh              # Main installer
├── LICENSE               # MIT License
└── README.md             # This file
```

---

## Requirements

- **OS**: Ubuntu 20.04, 22.04, or 24.04 LTS
- **CPU**: 8+ cores (16+ for archive nodes)
- **RAM**: 32GB minimum (64GB for archive nodes)
- **Disk**: 1TB NVMe SSD (4TB+ for archive nodes)
- **Network**: 1 Gbps (10 Gbps for RPC nodes)

---

## Security Scorecard

Each deployment is scored on a 100-point scale:

| Check | Points |
|-------|--------|
| SSH key-only auth | 10 |
| Non-standard SSH port | 5 |
| Firewall active (UFW) | 10 |
| Fail2ban running | 5 |
| Unattended upgrades | 5 |
| OS patches current | 10 |
| Client version current | 15 |
| Monitoring active | 10 |
| Backup configured | 10 |
| Audit logging | 10 |
| Disk encryption (LUKS) | 10 |

**Score Interpretation:**
- 🟢 90-100: Excellent (Production ready)
- 🟡 70-89: Good (Minor improvements needed)
- 🟠 50-69: Fair (Significant gaps)
- 🔴 <50: Poor (Not suitable for production)

---

## Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) for details.

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Support

- **XDC Network Documentation**: https://docs.xdc.community/
- **XDPoSChain GitHub**: https://github.com/XinFinOrg/XDPoSChain
- **Issues**: https://github.com/AnilChinchawale/XDC-Node-Setup/issues

---

<p align="center">
  Built with ❤️ for the XDC Network community
</p>
