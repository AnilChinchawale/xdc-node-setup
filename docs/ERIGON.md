# Erigon XDC Client + SkyOne Dashboard

Run the XDC Network using the Erigon execution client with the SkyOne monitoring dashboard.

> **Status**: Erigon-XDC is experimental. It connects to XDC mainnet peers via `eth/63` protocol and syncs blocks. Multi-client diversity is the goal.

## Prerequisites

- Linux x86_64 (Ubuntu 22.04+ recommended)
- Go 1.22+ installed
- 500GB+ SSD storage
- 8GB+ RAM
- Docker (for SkyOne dashboard)
- Ports: 30304 (P2P eth/63), 30311 (P2P eth/68), 8547 (HTTP RPC)

## 1. Build Erigon-XDC

```bash
git clone https://github.com/AnilChinchawale/erigon-xdc.git
cd erigon-xdc
make erigon
```

Binary will be at `./build/bin/erigon`.

## 2. Create Start Script

```bash
cat > start-erigon.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"

# XDC Mainnet bootnodes
BOOTNODES="enode://e1a69a7d766576e694adc3fc78d801a8a66926cbe8f4fe95b85f3b481444700a5d1b6d440b2715b5bb7cf4824df6a6702740afc8c52b20c72bc8c16f1ccde1f3@149.102.140.32:30303"
BOOTNODES="$BOOTNODES,enode://874589626a2b4fd7c57202533315885815eba51dbc434db88bbbebcec9b22cf2a01eafad2fd61651306fe85321669a30b3f41112eca230137ded24b86e064ba8@5.189.144.192:30303"
BOOTNODES="$BOOTNODES,enode://ccdef92053c8b9622180d02a63edffb3e143e7627737ea812b930eacea6c51f0c93a5da3397f59408c3d3d1a9a381f7e0b07440eae47314685b649a03408cfdd@37.60.243.5:30303"
BOOTNODES="$BOOTNODES,enode://12711126475d7924af98d359e178f71c5d9607de32d2c5b4ab1afff4b86e064ba8@89.117.49.48:30303"
BOOTNODES="$BOOTNODES,enode://81edfecc3df6994679daf67858ae34c0ae91aac944a84b09171532b45ad0f5d0c896eb8c023df04eaa2db743f5fccdf18cf7e2d12120d37a2c142a3be0a348cd@38.102.87.174:30303"
BOOTNODES="$BOOTNODES,enode://053ba696174e7f115e38f0e3963d0035ac20dc18e9a5c5873f9e90fe338d777f726d68d053c987416ec0bd97d4d818c59a8a23bc9ea854069ea2310846e27e7d@162.250.189.221:30303"

# Replace YOUR_PUBLIC_IP with your server's public IP
PUBLIC_IP="${PUBLIC_IP:-$(curl -s ifconfig.me)}"

exec ./build/bin/erigon \
  --chain=xdc \
  --datadir=./datadir \
  --http --http.addr=0.0.0.0 --http.port=8547 \
  --http.api=eth,net,web3,admin \
  --port=30311 \
  --private.api.addr=127.0.0.1:9092 \
  --bootnodes="$BOOTNODES" \
  --nat=extip:$PUBLIC_IP \
  --p2p.protocol=63,62 \
  --discovery.v4 \
  --discovery.xdc \
  --verbosity=3
EOF
chmod +x start-erigon.sh
```

## 3. Start Erigon

```bash
# Using screen (survives SSH disconnects)
screen -dmS erigon ./start-erigon.sh

# Check logs
screen -r erigon    # Ctrl+A, D to detach

# Or with nohup
nohup ./start-erigon.sh > erigon.log 2>&1 &
```

## 4. Add Peers

Erigon starts two P2P sentries:
- **Port 30304** → eth/63 (compatible with XDC geth nodes) ← **use this one**
- **Port 30311** → eth/68 (standard Ethereum, not compatible with XDC)

XDC geth nodes only support eth/62, eth/63, eth/100. You **must** connect peers to the eth/63 port (30304).

```bash
# Get your erigon enode
ENODE=$(curl -s -X POST http://localhost:8547 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"admin_nodeInfo","params":[],"id":1}' \
  | jq -r '.result.enode' | sed "s/@\[::\]/@$(curl -s ifconfig.me)/")

# IMPORTANT: Change the port from 30311 to 30304 for eth/63
ENODE_63=$(echo $ENODE | sed 's/:30311/:30304/')
echo "Share this enode with XDC geth operators:"
echo "$ENODE_63"
```

### Adding a geth peer to erigon:

```bash
# From the geth node, add erigon as trusted peer (port 30304!)
curl -X POST http://GETH_RPC:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"admin_addTrustedPeer","params":["enode://ERIGON_PUBKEY@ERIGON_IP:30304"],"id":1}'
```

### Adding a geth peer from erigon side:

```bash
curl -X POST http://localhost:8547 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"admin_addPeer","params":["enode://GETH_PUBKEY@GETH_IP:30303"],"id":1}'
```

> **Tip**: Use `admin_addTrustedPeer` on the geth side — it bypasses the maxpeers limit.

## 5. Verify Sync

```bash
# Block height
curl -s -X POST http://localhost:8547 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Peer count
curl -s -X POST http://localhost:8547 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}'

# Peer details
curl -s -X POST http://localhost:8547 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"admin_peers","params":[],"id":1}' | jq '.result[] | {name, caps, addr: .network.remoteAddress}'
```

## 6. SkyOne Dashboard

Deploy the SkyOne monitoring dashboard pointing to erigon's RPC:

```bash
cd xdc-node-setup/dashboard

# Build
docker build -t xdc-skyone .

# Run (pointing to erigon RPC)
docker run -d \
  --name xdc-skyone \
  -p 7070:7070 \
  -e RPC_URL=http://host.docker.internal:8547 \
  --restart unless-stopped \
  xdc-skyone
```

> If `host.docker.internal` doesn't work on Linux, use `--network=host` or the Docker bridge IP (`172.17.0.1`).

Dashboard will be at `http://YOUR_IP:7070`

## 7. Register with SkyNet

Register your erigon node on the XDC SkyNet network dashboard:

```bash
# Register
curl -X POST "https://net.xdc.network/api/v1/nodes/register" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_SKYNET_API_KEY" \
  -d '{
    "name": "my-erigon-node",
    "host": "http://YOUR_IP:8547",
    "role": "fullnode",
    "tags": ["erigon", "multi-client"]
  }'

# Save the returned nodeId and apiKey!
```

Set up the heartbeat (every minute via cron):

```bash
cat > /root/erigon-heartbeat.sh << 'SCRIPT'
#!/bin/bash
NODE_ID="YOUR_NODE_ID"
API_KEY="YOUR_SKYNET_API_KEY"
RPC="http://127.0.0.1:8547"
API="https://net.xdc.network/api/v1"

BLOCK_HEX=$(curl -s -m 5 -X POST "$RPC" -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | jq -r '.result // "0x0"')
BLOCK=$((16#${BLOCK_HEX#0x}))
PEERS_HEX=$(curl -s -m 5 -X POST "$RPC" -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' | jq -r '.result // "0x0"')
PEERS=$((16#${PEERS_HEX#0x}))

curl -s -m 10 -X POST "$API/nodes/heartbeat" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d "{\"nodeId\":\"$NODE_ID\",\"blockHeight\":$BLOCK,\"syncing\":true,\"peerCount\":$PEERS,\"clientType\":\"erigon\"}"
SCRIPT
chmod +x /root/erigon-heartbeat.sh

# Add to cron
(crontab -l 2>/dev/null; echo "* * * * * /root/erigon-heartbeat.sh >> /var/log/erigon-heartbeat.log 2>&1") | crontab -
```

## Known Issues

| Issue | Status | Workaround |
|-------|--------|------------|
| eth/68 vs eth/62 mismatch | Partial fix | Use port 30304 (eth/63 sentry), not 30311 |
| "too many peers" rejections | Expected | Use `admin_addTrustedPeer` on geth side |
| Slow peer discovery | Known | Manually add peers, erigon can't discover XDC nodes via discv4 |
| State root mismatch | Possible | May occur at consensus-critical blocks — clear datadir and resync |

## Port Reference

| Port | Protocol | Purpose |
|------|----------|---------|
| 8547 | HTTP | JSON-RPC API |
| 30304 | TCP/UDP | P2P eth/63 (XDC compatible) ✅ |
| 30311 | TCP/UDP | P2P eth/68 (standard Ethereum) |
| 9092 | gRPC | Erigon internal API |
| 7070 | HTTP | SkyOne Dashboard |

## Architecture

```
┌─────────────┐     eth/63      ┌─────────────┐
│  Erigon-XDC │◄───────────────►│  XDC Geth   │
│  :30304     │                 │  :30303     │
└──────┬──────┘                 └─────────────┘
       │ RPC :8547
       ▼
┌──────────────┐    heartbeat    ┌─────────────┐
│  SkyOne      │───────────────►│  SkyNet     │
│  :7070       │                │  Dashboard  │
└──────────────┘                └─────────────┘
```
