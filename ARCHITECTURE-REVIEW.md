# Architecture Review — XDC-Node-Setup
> Authored by ArchitectoBot 🏗️ | 2026-02-12

---

## 1. Code Architecture

### Project Structure
```
XDC-Node-Setup/
├── setup.sh              # Main CLI entry point (v2.1.0, ~1300 lines bash)
├── cli/                  # `xdc` CLI wrapper + shell completions
├── docker/               # Docker Compose + mainnet/testnet configs
├── scripts/              # 25+ operational scripts (monitoring, security, backup, etc.)
├── dashboard/            # Next.js 14 single-node dashboard
├── ansible/              # Ansible roles for fleet deployment
├── terraform/            # IaC for AWS, DigitalOcean, Hetzner
├── k8s/                  # Helm chart + raw manifests for Kubernetes
├── monitoring/           # Prometheus rules, Grafana dashboards
├── configs/              # RPC profiles, bootnodes, env templates
├── systemd/              # Systemd service units + timers
├── templates/email/      # HTML email templates for alerts
├── cron/                 # Cron job setup
└── docs/                 # Extensive documentation (15+ docs)
```

**Assessment:** Well-organized, modular structure. The separation of concerns (docker, scripts, monitoring, IaC) is clean. The project has grown organically with good discipline.

### Component Organization
- **CLI Layer:** `setup.sh` (one-line install) + `cli/xdc` (operational commands) — solid UX pattern
- **Container Layer:** Docker Compose with XDC node, Prometheus, Grafana, Node Exporter, cAdvisor, Alertmanager, and a NetOwn agent sidecar
- **Script Library:** `scripts/lib/` for shared functions (notify.sh, rewards-db.sh, xdc-contracts.sh) — good DRY approach
- **IaC:** Terraform modules for 3 cloud providers + Ansible roles for 5 concerns (node, security, monitoring, backup, common)

### API Design Patterns
- Dashboard exposes 3 API routes: `/api/health`, `/api/metrics`, `/api/peers` — lightweight, read-only
- All metrics fetched from Prometheus via PromQL — good separation
- No persistent state in the dashboard itself — stateless design

### State Management
- Node state: Docker volumes (xdcchain data)
- Monitoring state: Prometheus TSDB + Grafana SQLite
- Config state: `.env` files + netown.conf
- Agent state: `/var/lib/xdc-node/netown.json` (node ID, API key)

### Error Handling
- `setup.sh`: Uses `set -euo pipefail` ✅, has structured logging (log/info/warn/error), spinner for UX
- Scripts generally follow `set -euo pipefail` pattern — good
- Dashboard: Try/catch in API routes, returns JSON error responses

---

## 2. Security Audit

### 🔴 Critical Issues

| # | Issue | Location | Risk |
|---|-------|----------|------|
| S1 | **Hardcoded credentials in .env committed to git** | `docker/mainnet/.env` | Grafana default password "changeme", empty API keys checked into repo |
| S2 | **RPC CORS wildcard** | `docker/mainnet/.env` → `RPC_CORS_DOMAIN=*`, `RPC_VHOSTS=*`, `WS_ORIGINS=*` | Any domain can call node RPC — remote fund theft if wallet unlocked |
| S3 | **RPC bound to 0.0.0.0** | `docker/mainnet/.env` → `RPC_ADDR=0.0.0.0` | Exposes RPC to internet unless firewall configured separately |
| S4 | **pprof exposed on 0.0.0.0** | `docker/mainnet/.env` → `PPROF_ADDR=0.0.0.0` | Go profiler endpoint exposed — information disclosure + potential DoS |
| S5 | **Docker socket mounted in containers** | `docker/docker-compose.yml` → netown-agent, cAdvisor | Container escape risk — docker.sock = root on host |
| S6 | **cAdvisor runs privileged** | `docker/docker-compose.yml` → `privileged: true` | Full host access, container escape |
| S7 | **netown-agent uses network_mode: host** | `docker/docker-compose.yml` | No network isolation, can access all host ports |
| S8 | **Password file committed** | `docker/mainnet/.pwd` | Keystore password in git |

### 🟡 Important Issues

| # | Issue | Location |
|---|-------|----------|
| S9 | Grafana exposed on 0.0.0.0:3000 with default creds | docker-compose.yml |
| S10 | No rate limiting on RPC endpoints | docker-compose.yml |
| S11 | No TLS on any endpoints (RPC, WS, Dashboard, Grafana) | All services |
| S12 | `curl | sudo bash` install pattern | README.md quick start |
| S13 | No input validation in `setup.sh` for user-provided values | setup.sh |
| S14 | Shell script sources config files without sanitization | netown-agent.sh → `source "$CONF_FILE"` |

### ✅ Good Security Practices
- Docker security: `no-new-privileges`, `cap_drop: ALL`, minimal `cap_add`
- Prometheus/Alertmanager bound to localhost (127.0.0.1)
- Monitoring network is `internal: true`
- Comprehensive security hardening script (`security-harden.sh`)
- Fail2ban, SSH hardening, audit logging included
- Log rotation configured on all containers

---

## 3. Scalability Analysis

### Current Design
- **Single-node focused:** The entire toolkit is designed for deploying and managing one XDC node per host
- **Monitoring:** Prometheus (30d retention, 10GB cap) — appropriate for single node
- **Dashboard:** Stateless Next.js app, reads from Prometheus — lightweight

### Bottlenecks
- **No horizontal scaling path for the dashboard** — reads directly from local Prometheus
- **Scripts are SSH/local only** — no remote orchestration built-in (Ansible fills this gap)
- **NetOwn agent is the bridge to fleet management** — depends on external XDCNetOwn platform

### Scaling Path
The architecture correctly delegates fleet-scale concerns to XDCNetOwn via the agent sidecar. For single-node operations, the current design is appropriate. Kubernetes Helm chart + Terraform modules provide multi-instance deployment capability.

---

## 4. Code Quality

### Strengths
- Extensive documentation (15+ docs covering operations, troubleshooting, compliance)
- GitHub CI/CD workflows (ci.yml, release.yml)
- Shell scripts are well-structured with clear sections, comments, and proper error handling
- CIS benchmark script for compliance auditing
- Comprehensive Grafana dashboards (node, consensus, owner)

### Weaknesses
- **No automated tests** for bash scripts (test-setup.sh exists but is manual)
- **Dashboard has no tests** — no Jest, no Playwright, no test files
- **TypeScript types** are well-defined in `lib/types.ts` ✅
- **No linting** for bash scripts (shellcheck not in CI)
- `.next/` build artifacts committed to git
- `dashboard/!` — stray file in repo

### Dependency Health
- Next.js 14.2.x — recent and maintained
- Docker images use specific version tags ✅
- XDC node image: `xinfinorg/xdposchain:v2.6.8` — pinned ✅

---

## 5. Improvement Recommendations

### P0 — Critical (Fix Now)
1. **Remove committed secrets** from `docker/mainnet/.env`, `docker/mainnet/.pwd` — use `.env.example` only
2. **Restrict RPC CORS** — change `*` to specific origins
3. **Bind RPC to localhost** by default (`127.0.0.1`), expose via nginx reverse proxy
4. **Remove pprof from production** or bind to localhost
5. **Don't mount docker.sock** unless absolutely necessary — use Docker API over TCP with TLS
6. **Remove cAdvisor privileged mode** — use `--privileged=false` with specific volume mounts
7. **Add `.env` and `.pwd` to `.gitignore`**

### P1 — Important (Next Quarter)
1. Add ShellCheck linting to CI pipeline
2. Add integration tests for `setup.sh` (Docker-based test matrix)
3. Remove `.next/` from git, add to `.gitignore`
4. Implement TLS for Grafana and Dashboard (nginx + Let's Encrypt)
5. Add rate limiting to RPC proxy (nginx)
6. Sanitize config file sourcing in scripts (validate before `source`)
7. Replace `curl | sudo bash` with proper package manager (APT repo or Homebrew tap)

### P2 — Nice-to-Have (Later)
1. Add Prometheus recording rules for common queries
2. Dashboard SSR for SEO/sharing
3. Automated chaos testing (scripts/chaos-test.sh → CI)
4. Multi-arch Docker builds (ARM64 for Raspberry Pi)
5. Declarative node configuration (YAML-based, not interactive prompts)
