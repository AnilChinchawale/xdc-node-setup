#!/bin/bash
set -e

echo "[INFO] Starting XDC Apothem Testnet Node (Network ID: 51)..."

# Load bootnodes
BOOTNODES=$(grep -v "^#" /work/bootnodes.list | grep -v "^$" | tr "\n" "," | sed "s/,$//")

echo "[INFO] Loaded $(echo "$BOOTNODES" | tr "," "\n" | wc -l) bootnodes"

# Start XDC with proper Apothem testnet flags
exec XDC \
  --datadir /work/xdcchain \
  --networkid 51 \
  --port 30303 \
  --syncmode full \
  --gcmode full \
  --verbosity 2 \
  --mine \
  --gasprice 1 \
  --targetgaslimit 420000000 \
  --ipcpath /tmp/XDC.ipc \
  --nat=any \
  --bootnodes "$BOOTNODES" \
  --ethstats xdc-node:xinfin_xdpos_hybrid_network_stats@stats.apothem.network:3001 \
  --XDCx.datadir /work/xdcchain/XDCx \
  --rpc \
  --rpcaddr 0.0.0.0 \
  --rpcport 8545 \
  --rpcapi admin,eth,net,web3,XDPoS \
  --rpccorsdomain "${RPC_CORS:-localhost,https://*.xdc.network,https://*.xinfin.org}" \
  --rpcvhosts "*" \
  --store-reward \
  --ws \
  --wsaddr 0.0.0.0 \
  --wsport 8546 \
  --wsapi eth,net,web3,txpool,debug,XDPoS \
  --wsorigins "*"
