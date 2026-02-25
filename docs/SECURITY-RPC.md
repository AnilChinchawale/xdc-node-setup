# RPC Security Best Practices

## Overview
XDC nodes expose JSON-RPC endpoints for blockchain interaction. Improper configuration can expose your node to attacks, fund theft, and resource exhaustion.

## Critical Security Rules

### 1. Default to Localhost Binding

**❌ UNSAFE (Current Default):**
```bash
RPC_ADDR=0.0.0.0  # Exposed to internet
RPC_CORS_DOMAIN=* # Any website can call your RPC
```

**✅ SAFE (Recommended):**
```bash
RPC_ADDR=127.0.0.1  # Only local access
RPC_CORS_DOMAIN="http://localhost:3000,https://yourdashboard.com"
WS_ORIGINS="ws://localhost:3000,wss://yourdashboard.com"
```

### 2. CORS Restriction

If you MUST expose RPC externally, restrict CORS to specific origins:

```bash
# Specific domains only
RPC_CORS_DOMAIN="https://mydapp.com,https://dashboard.example.com"

# NEVER use wildcards in production
RPC_CORS_DOMAIN=*  # ❌ DANGEROUS
```

### 3. Nginx Reverse Proxy (Recommended for External Access)

Instead of exposing RPC directly, use an nginx reverse proxy with:
- TLS/SSL encryption
- Rate limiting
- Authentication
- Request logging

**Example nginx.conf:**
```nginx
# Rate limiting zone
limit_req_zone $binary_remote_addr zone=rpc_limit:10m rate=10r/s;

server {
    listen 8545 ssl http2;
    server_name rpc.yourdomain.com;
    
    ssl_certificate /etc/ssl/certs/xdc.crt;
    ssl_certificate_key /etc/ssl/private/xdc.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    
    # Rate limiting
    limit_req zone=rpc_limit burst=20 nodelay;
    limit_req_status 429;
    
    # Logging
    access_log /var/log/nginx/rpc-access.log;
    error_log /var/log/nginx/rpc-error.log;
    
    location / {
        # Backend node (localhost only)
        proxy_pass http://127.0.0.1:8545;
        
        # CORS headers
        add_header Access-Control-Allow-Origin "https://trusted-domain.com" always;
        add_header Access-Control-Allow-Methods "POST, OPTIONS" always;
        add_header Access-Control-Allow-Headers "Content-Type" always;
        
        # Security headers
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-Frame-Options "DENY" always;
        
        # Proxy settings
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # OPTIONS preflight
    if ($request_method = OPTIONS) {
        add_header Access-Control-Allow-Origin "https://trusted-domain.com";
        add_header Access-Control-Allow-Methods "POST, OPTIONS";
        add_header Access-Control-Allow-Headers "Content-Type";
        add_header Content-Length 0;
        return 204;
    }
}
```

### 4. API Key Authentication (Advanced)

For production APIs, implement API key authentication in nginx:

```nginx
location / {
    # Check API key header
    if ($http_x_api_key = "") {
        return 401 "API key required";
    }
    
    # Validate against allowed keys (use Lua or external auth service)
    auth_request /auth;
    
    proxy_pass http://127.0.0.1:8545;
}

location = /auth {
    internal;
    proxy_pass http://auth-service:8080/validate;
    proxy_pass_request_body off;
    proxy_set_header Content-Length "";
    proxy_set_header X-API-Key $http_x_api_key;
}
```

### 5. Disable Dangerous RPC Methods

Some RPC methods should NEVER be exposed publicly:

```bash
# Start node with limited API
./XDC --http.api "eth,net,web3,xdpos" \
     --http.corsdomain "https://trusted-domain.com" \
     --http.addr "127.0.0.1"

# NEVER expose these APIs publicly:
# - personal (wallet management)
# - admin (node admin)
# - debug (debugging tools)
# - miner (mining control)
```

### 6. Monitoring and Alerts

Monitor for suspicious activity:

```bash
# Watch for unusual RPC patterns
tail -f /var/log/nginx/rpc-access.log | grep -E '(429|401|403)'

# Alert on rate limit hits
# Alert on failed auth attempts
# Alert on unusual geographic patterns
```

### 7. Firewall Configuration

Use UFW or iptables to restrict RPC access at the network level:

```bash
# Allow localhost only
ufw allow from 127.0.0.1 to any port 8545

# Allow specific IPs
ufw allow from 203.0.113.0/24 to any port 8545

# Deny all others
ufw deny 8545
```

## Attack Scenarios

### Scenario 1: Wallet Fund Theft
**Attack:** User visits malicious website while node RPC is exposed with unlocked wallet.
**Impact:** Website JavaScript calls `personal_sendTransaction` to drain funds.
**Prevention:** Never expose `personal` API, use localhost binding.

### Scenario 2: DoS via RPC Spam
**Attack:** Attacker floods RPC with expensive queries (e.g., `eth_getLogs` with wide range).
**Impact:** Node becomes unresponsive, legitimate requests fail.
**Prevention:** Rate limiting, query complexity limits.

### Scenario 3: Node Fingerprinting
**Attack:** Attacker calls `admin_nodeInfo` to identify client type/version for exploit targeting.
**Impact:** Node becomes target for known vulnerabilities.
**Prevention:** Disable admin API on public endpoints.

## Deployment Checklist

- [ ] RPC bound to `127.0.0.1` by default
- [ ] CORS restricted to specific domains
- [ ] Dangerous APIs disabled (`personal`, `admin`, `debug`)
- [ ] Nginx reverse proxy configured with TLS
- [ ] Rate limiting enabled (10-100 req/s)
- [ ] API key authentication (if public)
- [ ] Firewall rules configured
- [ ] Monitoring and alerting setup
- [ ] Regular security audits scheduled

## Testing Your Configuration

### Test 1: Localhost Binding
```bash
# From remote machine (should fail)
curl -X POST http://YOUR_NODE_IP:8545 \
     -H "Content-Type: application/json" \
     -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Expected: Connection refused or timeout
```

### Test 2: CORS Restriction
```bash
# Try from unauthorized origin (should fail)
curl -X POST http://YOUR_NODE_IP:8545 \
     -H "Content-Type: application/json" \
     -H "Origin: https://evil-site.com" \
     -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Expected: CORS error
```

### Test 3: Rate Limiting
```bash
# Rapid requests (should hit rate limit)
for i in {1..50}; do
  curl -X POST http://YOUR_NODE_IP:8545 \
       -H "Content-Type: application/json" \
       -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' &
done
wait

# Expected: Some requests return 429 Too Many Requests
```

## References

- [Ethereum JSON-RPC Security](https://geth.ethereum.org/docs/rpc/server)
- [OWASP API Security](https://owasp.org/www-project-api-security/)
- [Nginx Rate Limiting](https://www.nginx.com/blog/rate-limiting-nginx/)
- [XDC Network Documentation](https://docs.xdc.network)

## Support

For security issues, contact: security@xdc.network
For general questions: https://discord.gg/xdc-community
