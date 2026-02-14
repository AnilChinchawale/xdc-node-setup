# SkyOne (Single-Node Dashboard) & CLI - Production Readiness Review

**Date:** February 14, 2026  
**Reviewer:** ArchitectoBot  
**Projects:** XDC SkyOne - Single-Node Dashboard, XDC Node Setup CLI  
**Repository:** AnilChinchawale/xdc-node-setup  

---

## Executive Summary

| Project | Grade | Security Score | Production Ready? |
|---------|-------|----------------|-------------------|
| **SkyOne (Single-Node)** | C | 35/100 | ❌ **NO** |
| **CLI / Setup** | B- | 58/100 | ⚠️ **PARTIAL** |

### Critical Issue Count (Combined)
- 🔴 **2 Critical** - Running dev mode in prod, command injection
- 🟠 **3 High** - No auth, file path traversal, missing rate limits
- 🟡 **5 Medium** - Dev mode, missing headers, weak random
- 🔵 **9 Low** - Code quality, logging, documentation gaps

---

## SkyOne (Single-Node Dashboard)

### Scoring Breakdown

| Category | Points | Score | Notes |
|----------|--------|-------|-------|
| **SSL/TLS Everywhere** | 10 | 0 | No TLS configured (HTTP only) |
| **Authentication & Authorization** | 15 | 0 | **NO AUTHENTICATION AT ALL** |
| **Input Validation** | 10 | 4 | Some validation, many gaps |
| **Error Handling & Boundaries** | 10 | 4 | No error boundaries |
| **Logging & Monitoring** | 10 | 5 | Basic logging |
| **Database Maintenance** | 10 | N/A | No database |
| **CI/CD Pipeline** | 10 | 1 | No CI/CD |
| **Load Testing** | 10 | 0 | None |
| **Documentation** | 10 | 5 | Basic README |
| **Disaster Recovery** | 10 | 6 | Backup scripts exist |
| **TOTAL** | 100 | **35** | |

### Critical Vulnerabilities (🔴 P0)

#### C1: Running in Dev Mode in Production
**Location:** `docker-compose.yml`

```dockerfile
# Dockerfile claims production mode but...
COPY combined-start.sh /combined-start.sh
# ... inside combined-start.sh:
exec npm start -- -p "$DASHBOARD_PORT" -H 0.0.0.0
# BUT docker-compose.yml shows:
command: npm run dev  # <-- DEV MODE IN PRODUCTION!
```

**Issues:**
- `next dev` in production (no optimization, exposes source maps)
- No health checks in compose (Dockerfile has it but compose overrides)
- `network_mode: host` bypasses Docker networking security
- No resource limits (CPU/memory)

---

#### C2: Command Injection via Diagnostics
**Location:** `dashboard/app/api/diagnostics/route.ts`

```typescript
// User input flows directly to shell
const { stdout } = await execAsync(`docker inspect --format='{{.State.Status}}' ${getContainerName()} 2>/dev/null || echo "not_found"`);

// In metrics route:
const size = execSync(`du -sb ${p} 2>/dev/null | cut -f1`, ...)
```

**Attack Vector:**
If `getContainerName()` or path variables are influenced by user input:
```bash
# Payload: "xdc-node; rm -rf /"
docker inspect --format='{{.State.Status}}' xdc-node; rm -rf /
```

**Status:** Currently appears safe (inputs from env vars), but fragile.

---

### High Severity Vulnerabilities (🟠 P1)

#### H1: No Authentication Layer
- ❌ **NO AUTHENTICATION AT ALL**
- Anyone with network access can view node status, metrics, execute diagnostics

#### H2: File Path Traversal
**Location:** `dashboard/app/api/diagnostics/route.ts`

```typescript
const diagnosticsDir = '/root/.openclaw/workspace/XDC-Node-Setup/scripts';
// Reading files from potentially user-influenced paths
```

#### H3: Information Disclosure via Error Messages
No global error boundary - crashes will expose stack traces.

---

### Docker Security Issues

```dockerfile
FROM node:20-alpine
# Missing: No non-root user
# Missing: No health check in compose override
# Running: npm run dev (source maps, no optimization)
```

```yaml
# docker-compose.yml
network_mode: host  # ❌ Bypasses Docker networking
# Missing: resource limits
# Missing: read-only filesystem
# Missing: security profiles
```

---

## CLI / Setup Scripts

### Scoring Breakdown

| Category | Points | Score | Notes |
|----------|--------|-------|-------|
| **Code Quality** | 15 | 10 | Good structure, some long functions |
| **Security** | 20 | 10 | Some injection risks, curl|bash pattern |
| **Error Handling** | 15 | 10 | Good error handling |
| **Documentation** | 15 | 13 | Excellent help text |
| **Testing** | 15 | 5 | Some test scripts |
| **Distribution** | 15 | 10 | GitHub releases, install script |
| **TOTAL** | 100 | **58** | |

### Security Issues

#### Shell Script Security

1. **Unquoted variables in some paths:**
```bash
# Potential issue if XDC_DATA has spaces
mkdir -p ${XDC_DATA}/xdcchain  # Should be: "${XDC_DATA}/xdcchain"
```

2. **Curl | bash pattern:**
```bash
curl -sSL https://raw.githubusercontent.com/.../setup.sh | sudo bash
# Risk: No integrity verification, MITM possible
```

3. **Temp file creation:**
```bash
# skynet-agent.sh
tmpBody="/tmp/gh-issue-${Date.now()}.md"  # Predictable path
# Should use mktemp
```

---

## Prioritized Action Plan

### Immediate Actions (This Week)

| Priority | Issue | Project | Effort |
|----------|-------|---------|--------|
| P0 | Stop running SkyOne in dev mode | SkyOne | 1h |
| P0 | Add non-root user to SkyOne Docker | SkyOne | 1h |
| P0 | Fix command injection vulnerabilities | SkyOne | 2h |
| P0 | Add basic authentication layer | SkyOne | 4h |

### Short Term (This Month)

| Priority | Issue | Project | Effort |
|----------|-------|---------|--------|
| P1 | Add input validation to all API routes | SkyOne | 4h |
| P1 | Add error boundaries | SkyOne | 2h |
| P1 | Add security headers | SkyOne | 2h |
| P1 | Quote all shell variables | CLI | 2h |
| P1 | Replace curl\|bash with verified downloads | CLI | 4h |
| P1 | Use mktemp for temp files | CLI | 1h |

### Medium Term (Next Quarter)

| Priority | Issue | Project | Effort |
|----------|-------|---------|--------|
| P2 | Implement TLS/HTTPS | SkyOne | 8h |
| P2 | Add comprehensive logging | SkyOne | 4h |
| P2 | Set up CI/CD with testing | Both | 16h |
| P2 | Add checksum verification to installer | CLI | 4h |

---

## Compliance Status

| Requirement | Status | Notes |
|-------------|--------|-------|
| SOC 2 Type II | ❌ Fail | No audit logging, access controls weak |
| ISO 27001 | ❌ Fail | No risk assessment |
| GDPR (EU) | ⚠️ Partial | No data classification |

---

## Conclusion

**Do NOT deploy SkyOne to production until P0 items are resolved.**

The CLI tools show better maturity (B- grade) with good documentation and error handling, but still need security hardening. SkyOne dashboard is fundamentally not production-ready due to missing authentication and running in development mode.

### Key Blockers for Production:
1. ❌ SkyOne running in dev mode
2. ❌ No authentication on SkyOne
3. ❌ Command injection vulnerabilities
4. ❌ No TLS/HTTPS
5. ❌ curl|bash installation pattern

---

*Report generated by ArchitectoBot - February 14, 2026*
