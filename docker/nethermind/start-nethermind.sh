#!/bin/bash
# Security Fix (#492 #493 #508): Secure RPC defaults + error handling
set -euo pipefail
trap 'echo "ERROR at line $LINENO"' ERR

#==============================================================================
# XDC Nethermind Start Script
# Handles initialization and startup of Nethermind XDC client
# Security: RPC binds to 127.0.0.1 by default — set RPC_ADDR=0.0.0.0 for external access
#==============================================================================

# Security Fix (#492 #493): Secure defaults — localhost only
: "${NETWORK:=mainnet}"
: "${SYNC_MODE:=full}"
: "${RPC_PORT:=8545}"
: "${RPC_ADDR:=127.0.0.1}"  # Security: localhost only by default
: "${RPC_ALLOW_ORIGINS:=localhost}"  # Security: no CORS wildcard
: "${RPC_VHOSTS:=localhost}"  # Security: localhost vhosts only
: "${P2P_PORT:=30303}"
: "${INSTANCE_NAME:=Nethermind_XDC_Node}"

# Bug #517: Support for extra CLI arguments via environment variable
# Usage: NETHERMIND_EXTRA_ARGS="--Network.P2PPort=30305 --JsonRpc.Port=8546"
: "${NETHERMIND_EXTRA_ARGS:=}"

# Bug #515: Trusted peers for connecting to GP5 nodes (prevent 'Sleeping: All')
# Default XDC mainnet GP5 nodes - override with TRUSTED_PEERS env var
: "${TRUSTED_PEERS:=enode://e1a69a7d766576e694adc3fc78d801a8a66926cbe8f4fe95b85f3b481444700a5d1b6d440b2715b5bb7cf4824df6a6702740afc8c52b20c72bc8c16f1ccde1f3@95.217.112.125:30303,enode://874589626a2b4fd7c57202533315885815eba51dbc434db88bbbebcec9b22cf2a01eafad2fd61651306fe85321669a30b3f41112eca230137ded24b86e064ba8@135.181.117.109:30303,enode://ccdef92053c8b9622180d02a63edffb3e143e7627737ea812b930eacea6c51f0c93a5da3397f59408c3d3d1a9a381f7e0b07440eae47314685b649a03408cfdd@167.235.13.113:30303}"

# Network configuration
case "$NETWORK" in
    mainnet)
        CHAIN_ID=50
        NETWORK_NAME="XDC Mainnet"
        ;;
    testnet|apothem)
        CHAIN_ID=51
        NETWORK_NAME="XDC Apothem Testnet"
        ;;
    devnet)
        CHAIN_ID=551
        NETWORK_NAME="XDC Devnet"
        ;;
    *)
        CHAIN_ID=50
        NETWORK_NAME="XDC Mainnet"
        ;;
esac

echo "=== XDC Nethermind Node ==="
echo "Network: $NETWORK_NAME (Chain ID: $CHAIN_ID)"
echo "RPC Port: $RPC_PORT"
echo "P2P Port: $P2P_PORT"
echo "Instance: $INSTANCE_NAME"
echo ""

# Issue #71: Generate deterministic identity on first boot
DATADIR="/nethermind/data"
if [ ! -f "$DATADIR/.node-identity" ]; then
  echo "[SkyNet] First boot detected - generating node identity..."
  # Generate a deterministic private key using hostname and date
  # This ensures the same node gets the same identity on restart
  IDENTITY_SEED="${HOSTNAME:-nethermind}-$(date +%Y%m)"
  PRIVKEY=$(echo -n "$IDENTITY_SEED" | sha256sum | cut -d' ' -f1)
  echo "$PRIVKEY" > "$DATADIR/.node-privkey"
  echo "[SkyNet] Generated identity seed (coinbase will be read from RPC after start)"
fi

# Check if chainspec exists
if [[ ! -f /nethermind/chainspec/xdc.json ]]; then
    echo "ERROR: Chainspec file not found at /nethermind/chainspec/xdc.json"
    exit 1
fi

# Check if config exists
if [[ ! -f /nethermind/configs/xdc.json ]]; then
    echo "WARNING: Config file not found at /nethermind/configs/xdc.json, using defaults"
fi

# Parse bootnodes from bootnodes.list
BOOTNODES=""
if [[ -f /nethermind/bootnodes.list ]]; then
    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        if [[ -z "$BOOTNODES" ]]; then
            BOOTNODES="$line"
        else
            BOOTNODES="$BOOTNODES,$line"
        fi
    done < /nethermind/bootnodes.list
    echo "Loaded bootnodes from bootnodes.list"
fi

# Build Nethermind arguments
NETHERMIND_ARGS=(
    --datadir /nethermind/data
    --config xdc
    --JsonRpc.Enabled true
    --JsonRpc.Host "${RPC_ADDR}"
    --JsonRpc.Port "${RPC_PORT}"
    --JsonRpc.EnabledModules "${NETHERMIND_JSONRPCCONFIG_ENABLEDMODULES:-eth,net,web3,admin,debug}"
    --JsonRpc.CorsOrigins "${RPC_ALLOW_ORIGINS}"
    --Network.P2PPort "${P2P_PORT}"
    --Network.DiscoveryPort "${P2P_PORT}"
    --Network.ExternalIp "${EXTERNAL_IP:-}"
    --EthStats.Enabled true
    --EthStats.Name "${INSTANCE_NAME}"
    --EthStats.Secret "xdc-nethermind-stats"
    --EthStats.Server "wss://stats.xinfin.network/api"
    --Metrics.Enabled true
    --Metrics.ExposePort 6060
)

# Add bootnodes if available
if [[ -n "$BOOTNODES" ]]; then
    NETHERMIND_ARGS+=(--Discovery.Bootnodes "$BOOTNODES")
fi

# Set sync mode
if [[ "$SYNC_MODE" == "snap" ]]; then
    NETHERMIND_ARGS+=(--Sync.FastSync true)
else
    NETHERMIND_ARGS+=(--Sync.FastSync false)
fi

# Bug #517: Append extra CLI arguments from NETHERMIND_EXTRA_ARGS env var
if [ -n "$NETHERMIND_EXTRA_ARGS" ]; then
    read -ra EXTRA <<< "$NETHERMIND_EXTRA_ARGS"
    NETHERMIND_ARGS+=("${EXTRA[@]}")
    echo "Added extra arguments: $NETHERMIND_EXTRA_ARGS"
fi

# Bug #515: Add trusted peers to ensure connections to GP5 nodes
if [ -n "$TRUSTED_PEERS" ]; then
    NETHERMIND_ARGS+=(--Network.TrustedPeers "$TRUSTED_PEERS")
    echo "Added trusted peers for GP5 connectivity"
fi

echo "Starting Nethermind..."
echo "Command: /nethermind/nethermind ${NETHERMIND_ARGS[*]}"
echo ""

# Execute Nethermind (binary name is lowercase 'nethermind' in newer builds)
if [[ -x /nethermind/nethermind ]]; then
    exec /nethermind/nethermind "${NETHERMIND_ARGS[@]}" 2>&1 | tee -a /nethermind/logs/nethermind.log
elif [[ -x /nethermind/Nethermind.Runner ]]; then
    exec /nethermind/Nethermind.Runner "${NETHERMIND_ARGS[@]}" 2>&1 | tee -a /nethermind/logs/nethermind.log
else
    echo "ERROR: No Nethermind binary found!"
    ls -la /nethermind/
    exit 1
fi
