#!/bin/bash
set -e

NETWORK="${NETWORK:-mainnet}"
NETWORK_ID="${NETWORK_ID:-50}"

echo "[Erigon] Starting for network: $NETWORK (ID: $NETWORK_ID)"

# Load bootnodes if file exists
BOOTNODES=""
if [ -f /work/bootnodes.list ]; then
    BOOTNODES=$(grep -v "^#" /work/bootnodes.list | grep -v "^$" | tr "\n" "," | sed "s/,$//" || echo "")
    if [ -n "$BOOTNODES" ]; then
        echo "[Erigon] Loaded $(echo "$BOOTNODES" | tr "," "\n" | wc -l) bootnodes"
    fi
fi

# Determine chain name based on network ID
CHAIN="mainnet"
case "$NETWORK_ID" in
    50) CHAIN="mainnet" ;;
    51) CHAIN="apothem" ;;
    551) CHAIN="devnet" ;;
    *) CHAIN="mainnet" ;;
esac

echo "[Erigon] Chain: $CHAIN"

# Build erigon command
ERIGON_ARGS=(
    "--datadir=/home/erigon/.local/share/erigon"
    "--chain=$CHAIN"
    "--networkid=$NETWORK_ID"
    "--port=30304"
    "--http"
    "--http.addr=0.0.0.0"
    "--http.port=8555"
    "--http.vhosts=*"
    "--http.corsdomain=*"
    "--http.api=eth,net,web3,txpool,debug,erigon"
    "--ws"
    "--private.api.addr=0.0.0.0:9090"
    "--metrics"
    "--metrics.addr=0.0.0.0"
    "--metrics.port=6060"
)

# Add bootnodes if available
if [ -n "$BOOTNODES" ]; then
    ERIGON_ARGS+=("--bootnodes=$BOOTNODES")
fi

echo "[Erigon] Starting with args: ${ERIGON_ARGS[@]}"

# Note: Erigon may not have XDC-specific chain configs yet
# This is a placeholder for when XDC Erigon support is available
echo "[Erigon] WARNING: XDC Erigon support may require custom chain configuration"
echo "[Erigon] For now, this will attempt to run with standard Erigon"

# Execute erigon (if binary exists)
if command -v erigon >/dev/null 2>&1; then
    exec erigon "${ERIGON_ARGS[@]}"
else
    echo "[Erigon] ERROR: erigon binary not found in container"
    echo "[Erigon] XDC Erigon client may not be available yet"
    exit 1
fi
