# XDC Node Setup - Troubleshooting Guide

**Version:** 1.0  
**Date:** March 4, 2026

---

## Table of Contents

1. [Quick Diagnostics](#quick-diagnostics)
2. [Installation Issues](#installation-issues)
3. [Sync Issues](#sync-issues)
4. [Connection Issues](#connection-issues)
5. [Performance Issues](#performance-issues)
6. [Client-Specific Issues](#client-specific-issues)
7. [Security Issues](#security-issues)
8. [Advanced Debugging](#advanced-debugging)

---

## Quick Diagnostics

### Status Check

```bash
# Check node status
xdc status

# Full system info
xdc info

# Check sync progress
xdc sync

# List connected peers
xdc peers
```

### Health Check

```bash
# Run comprehensive health check
xdc health --full

# Check specific components
xdc health --rpc
xdc health --p2p
xdc health --disk
```

---

## Installation Issues

### Docker Not Found

**Error:**
```
ERROR: Docker is not installed
```

**Solution:**
```bash
# Install Docker
sudo apt-get update
sudo apt-get install -y docker.io docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Verify installation
docker --version
docker compose version
```

### Permission Denied

**Error:**
```
Permission denied: /var/lib/xdc
```

**Solution:**
```bash
# Use configurable state directory
export XDC_STATE_DIR=$HOME/.xdc-node

# Or fix permissions
sudo chown -R $USER:$USER /var/lib/xdc
```

### Port Already in Use

**Error:**
```
Bind for 0.0.0.0:8545 failed: port is already allocated
```

**Solution:**
```bash
# Find process using port
sudo lsof -i :8545

# Kill process or use different port
xdc config set RPC_PORT 8546
xdc restart
```

---

## Sync Issues

### Node Won't Sync

**Symptoms:**
- Block height not increasing
- Peer count is 0 or very low
- Sync progress stuck

**Diagnostics:**
```bash
# Check peer count
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}'

# Check sync status
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}'
```

**Solutions:**

1. **Reset peer discovery:**
```bash
xdc stop
rm -rf mainnet/.xdc-node/geth/nodes
xdc start
```

2. **Add bootnodes manually:**
```bash
# Get current bootnodes
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "admin_addPeer",
    "params": ["enode://..."],
    "id": 1
  }'
```

3. **Download snapshot for fast sync:**
```bash
xdc snapshot download --network mainnet
xdc snapshot apply
xdc start
```

### Sync Stalled at Specific Block

**Symptoms:**
- Block height stuck at specific number
- Error messages about "BAD BLOCK"

**Solution:**
```bash
# Check for bad block
xdc logs | grep -i "bad block"

# If bad block detected, resync from snapshot
xdc stop
rm -rf mainnet/xdcchain/XDC/chaindata
xdc snapshot download --network mainnet
xdc snapshot apply
xdc start
```

### Slow Sync Speed

**Symptoms:**
- Very slow block import rate
- High CPU/disk usage

**Solutions:**

1. **Increase cache size:**
```bash
xdc config set cache 8192  # Increase to 8GB
xdc restart
```

2. **Check disk performance:**
```bash
# Test disk I/O
fio --name=randread --ioengine=libaio --iodepth=32 --rw=randread --bs=4k --direct=1 --size=1G

# If using HDD, consider SSD upgrade
```

3. **Use snap sync mode:**
```bash
xdc config set SYNC_MODE snap
xdc restart
```

---

## Connection Issues

### RPC Connection Refused

**Error:**
```
Connection refused: localhost:8545
```

**Diagnostics:**
```bash
# Check if RPC is enabled
xdc config get rpc_enabled

# Check if port is listening
netstat -tlnp | grep 8545

# Check Docker port mapping
docker ps | grep xdc
```

**Solutions:**

1. **Enable RPC:**
```bash
xdc config set rpc_enabled true
xdc restart
```

2. **Check firewall:**
```bash
sudo ufw status
sudo ufw allow 8545/tcp
```

3. **Verify Docker network:**
```bash
docker network ls
docker network inspect xdc-network
```

### WebSocket Connection Issues

**Error:**
```
WebSocket connection failed
```

**Solution:**
```bash
# Check WebSocket configuration
xdc config get ws_enabled
xdc config get ws_port

# Test WebSocket
curl -i -N \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Host: localhost:8546" \
  http://localhost:8546
```

### Peer Connection Issues

**Symptoms:**
- Low peer count
- "p2p dial timeout" errors

**Solutions:**

1. **Check P2P port:**
```bash
# Verify port is open
sudo ufw allow 30303/tcp
sudo ufw allow 30303/udp

# Check port forwarding (if behind NAT)
```

2. **Add trusted peers:**
```bash
# Get peer enode from another node
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "admin_addTrustedPeer",
    "params": ["enode://..."],
    "id": 1
  }'
```

3. **Check network connectivity:**
```bash
# Test connectivity to bootnodes
telnet bootnode.xinfin.network 30303

# Check NAT traversal
curl ifconfig.me
```

---

## Performance Issues

### High CPU Usage

**Symptoms:**
- CPU usage consistently above 80%
- Slow response times

**Solutions:**

1. **Check sync status:**
```bash
# High CPU during sync is normal
xdc sync
```

2. **Reduce cache size:**
```bash
xdc config set cache 2048
xdc restart
```

3. **Limit peers:**
```bash
xdc config set max_peers 25
xdc restart
```

### High Memory Usage

**Symptoms:**
- Out of memory errors
- System swapping

**Solutions:**

1. **Check current usage:**
```bash
free -h
xdc info | grep memory
```

2. **Reduce memory cache:**
```bash
xdc config set cache 1024
xdc restart
```

3. **Enable swap (if not already):**
```bash
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### Disk Space Issues

**Symptoms:**
- "No space left on device" errors
- Disk usage > 90%

**Solutions:**

1. **Check disk usage:**
```bash
df -h
xdc info | grep disk
```

2. **Enable pruning:**
```bash
xdc config set prune_mode full
xdc restart
```

3. **Clean up old logs:**
```bash
# Rotate logs
sudo logrotate -f /etc/logrotate.d/xdc

# Clean Docker logs
docker system prune -a
```

4. **Move data to larger disk:**
```bash
# Mount new disk
sudo mount /dev/sdb1 /mnt/xdc-data

# Move data
xdc stop
sudo rsync -av mainnet/xdcchain/ /mnt/xdc-data/

# Update configuration
xdc config set DATA_DIR /mnt/xdc-data
xdc start
```

---

## Client-Specific Issues

### Erigon-XDC Issues

#### Build Fails

**Solution:**
```bash
# Clean and rebuild
cd docker/erigon
docker build --no-cache -t erigon-xdc:latest .

# Check build logs
docker build -t erigon-xdc:latest . 2>&1 | tee build.log
```

#### Port Conflicts

**Solution:**
```bash
# Check port usage
sudo ss -tlnp | grep -E '30304|30311|8547'

# Use different ports
export ERIGON_P2P_PORT=30305
export ERIGON_RPC_PORT=8548
xdc start --client erigon
```

#### Peer Connection Issues

**Important:** Always use port 30304 (eth/63) for XDC peers, NOT 30311 (eth/68).

```bash
# Check peer count
curl -X POST http://localhost:8547 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}'

# Add trusted peer on correct port
curl -X POST http://localhost:8547 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "admin_addTrustedPeer",
    "params": ["enode://...:30304"],
    "id": 1
  }'
```

### Nethermind-XDC Issues

#### High Memory Usage

**Solution:**
```bash
# Nethermind requires more memory
# Minimum 12GB recommended
# Reduce pruning cache
export NETHERMIND_PRUNINGCONFIG_CACHEMB=1024
```

#### Sync Issues

**Solution:**
```bash
# Check Nethermind-specific logs
docker logs xdc-nethermind

# Reset sync
docker exec xdc-nethermind rm -rf /xdcchain/nethermind_db
```

### Reth-XDC Issues

#### Requires debug.tip

**Solution:**
```bash
# Get latest block hash from explorer
# Add to startup flags
xdc start --client reth -- --debug.tip 0x...
```

#### Alpha Status Limitations

**Note:** Reth-XDC is in early alpha. Known issues:
- Requires more memory (16GB+)
- Manual sync tip hash required
- Limited XDPoS method support

---

## Security Issues

### Unauthorized RPC Access

**Symptoms:**
- Unknown transactions
- Configuration changes

**Solution:**
```bash
# Check current RPC settings
xdc config get rpc_addr
xdc config get rpc_cors

# Secure RPC
xdc config set rpc_addr 127.0.0.1
xdc config set rpc_cors localhost
xdc restart

# Check firewall
sudo ufw status
sudo ufw deny 8545/tcp  # Block external access
```

### Failed SSH Login Attempts

**Solution:**
```bash
# Check fail2ban status
sudo fail2ban-client status

# Review logs
sudo tail -f /var/log/fail2ban.log

# Add IP to whitelist (if needed)
sudo fail2ban-client set sshd addignoreip YOUR_IP
```

### Suspicious Container Activity

**Solution:**
```bash
# Check running containers
docker ps

# Inspect container
docker inspect xdc-node

# Check container logs
docker logs xdc-node

# Remove and recreate if compromised
xdc stop
xdc remove
curl -fsSL https://raw.githubusercontent.com/AnilChinchawale/XDC-Node-Setup/main/install.sh | sudo bash
```

---

## Advanced Debugging

### Enable Debug Logging

```bash
# Set log level
xdc config set log_level 5  # Debug
xdc restart

# View debug logs
xdc logs --follow | grep -i debug
```

### RPC Debugging

```bash
# Test RPC with verbose output
curl -v -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "eth_blockNumber",
    "params": [],
    "id": 1
  }'
```

### Network Debugging

```bash
# Capture P2P traffic
sudo tcpdump -i any port 30303 -w xdc-p2p.pcap

# Analyze with Wireshark
# Filter: eth.protocol

# Check network connections
sudo netstat -tulpn | grep xdc
```

### Database Debugging

```bash
# Check chaindata integrity
docker exec xdc-node ls -la /xdcchain/XDC/chaindata

# Get database stats
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "debug_chaindbProperty",
    "params": ["leveldb.stats"],
    "id": 1
  }'
```

### Performance Profiling

```bash
# Enable pprof
curl http://localhost:6060/debug/pprof/goroutine?debug=1

# Get heap profile
curl http://localhost:6060/debug/pprof/heap > heap.prof

# Analyze with go tool
go tool pprof heap.prof
```

---

## Getting Help

### Community Resources

- [GitHub Issues](https://github.com/AnilChinchawale/xdc-node-setup/issues)
- [XDC Community Discord](https://discord.gg/xdc)
- [XDC Network Docs](https://docs.xdc.community/)

### Diagnostic Information to Include

When reporting issues, include:

```bash
# System info
xdc info > diagnostic.txt

# Recent logs
xdc logs --tail 100 >> diagnostic.txt

# Docker info
docker ps >> diagnostic.txt
docker logs xdc-node --tail 50 >> diagnostic.txt

# System resources
free -h >> diagnostic.txt
df -h >> diagnostic.txt
```

---

## Related Documentation

- [Architecture Overview](ARCHITECTURE.md)
- [Configuration Guide](CONFIGURATION.md)
- [API Reference](API.md)
- [Security Audit](SECURITY_AUDIT.md)
