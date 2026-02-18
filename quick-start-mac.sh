#!/bin/bash
# XDC Multi-Client Quick Start for macOS
# Sets up all 4 XDC clients (Geth v2.6.8 + Geth PR5 + Erigon + Nethermind)
# on Apothem testnet using Docker Hub images

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKER_DIR="$SCRIPT_DIR/docker"

echo "🔷 XDC Multi-Client Quick Start (macOS)"
echo "========================================"
echo ""

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Install Docker Desktop for Mac first."
    echo "   https://docs.docker.com/desktop/install/mac-install/"
    exit 1
fi

if ! docker info &> /dev/null 2>&1; then
    echo "❌ Docker daemon not running. Start Docker Desktop first."
    exit 1
fi

echo "✅ Docker is running"

# Check compose
if docker compose version &> /dev/null 2>&1; then
    COMPOSE="docker compose"
elif command -v docker-compose &> /dev/null; then
    COMPOSE="docker-compose"
else
    echo "❌ Docker Compose not found."
    exit 1
fi

echo "✅ Using: $COMPOSE"
echo ""

# Pull images first (faster than building)
echo "📦 Pulling Docker Hub images..."
docker pull xinfinorg/xdposchain:v2.6.8
docker pull anilchinchawale/gx:latest
docker pull anilchinchawale/erix:latest
docker pull anilchinchawale/nmx:latest
echo ""

# Choose network
echo "Select network:"
echo "  1) Apothem Testnet (recommended)"
echo "  2) XDC Mainnet"
read -p "Choice [1]: " NETWORK_CHOICE
NETWORK_CHOICE=${NETWORK_CHOICE:-1}

if [ "$NETWORK_CHOICE" = "1" ]; then
    COMPOSE_FILE="docker-compose.apothem-full.yml"
    NETWORK="apothem"
else
    COMPOSE_FILE="docker-compose.yml"
    NETWORK="mainnet"
fi

echo ""
echo "🚀 Starting $NETWORK with all 4 clients..."
cd "$DOCKER_DIR"
$COMPOSE -f "$COMPOSE_FILE" up -d

echo ""
echo "✅ All clients starting!"
echo ""
echo "📊 RPC Endpoints:"
echo "   Geth v2.6.8:  http://localhost:8545"
echo "   Geth PR5:     http://localhost:8557"
echo "   Erigon:       http://localhost:8556"
echo "   Nethermind:   http://localhost:8558"
echo ""
echo "📋 Check status:"
echo "   docker compose -f $COMPOSE_FILE ps"
echo "   docker compose -f $COMPOSE_FILE logs -f"
echo ""
echo "🔍 Check sync:"
echo '   curl -s -X POST http://localhost:8545 -H "Content-Type: application/json" -d '"'"'{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'"'"' | jq'
echo ""
echo "🛑 Stop all:"
echo "   docker compose -f $COMPOSE_FILE down"
