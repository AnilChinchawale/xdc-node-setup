#!/bin/bash
set -e

echo "[INFO] Starting XDC Testnet (Apothem) Node..."

# Load bootnodes
BOOTNODES=$(grep -v "^#" /work/bootnodes.list | grep -v "^$" | tr "\n" "," | sed "s/,$//")

echo "[INFO] Loaded $(echo "$BOOTNODES" | tr "," "\n" | wc -l) bootnodes"

# Start XDC with proper flags
exec XDC \
  --testnet \
  --datadir /work/xdcchain \
  --rpc \
  --rpcaddr 0.0.0.0 \
  --rpcport 8545 \
  --rpcvhosts "*" \
  --rpccorsdomain "*" \
  --ws \
  --wsaddr 0.0.0.0 \
  --wsport 8546 \
  --wsorigins "*" \
  --rpcapi eth,net,web3,txpool,debug,XDPoS \
  --port 30303 \
  --syncmode full \
  --gcmode full \
  --bootnodes "$BOOTNODES"
