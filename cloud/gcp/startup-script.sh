#!/bin/bash
#==============================================================================
# GCP Startup Script for XDC Node
# Runs on first boot to configure and start XDC node
#==============================================================================

set -euo pipefail

# Configuration
LOG_FILE="/var/log/xdc-node-startup.log"
exec >> "$LOG_FILE" 2>> "$LOG_FILE"

# Get metadata
NODE_TYPE=$(curl -fsSL "http://metadata.google.internal/computeMetadata/v1/instance/attributes/node-type" -H "Metadata-Flavor: Google" 2>/dev/null || echo "fullnode")
NETWORK=$(curl -fsSL "http://metadata.google.internal/computeMetadata/v1/instance/attributes/network" -H "Metadata-Flavor: Google" 2>/dev/null || echo "mainnet")
XDC_VERSION="${XDC_VERSION:-v2.6.8}"

echo "==============================================="
echo "XDC Node GCP Startup: $(date)"
echo "Node Type: $NODE_TYPE"
echo "Network: $NETWORK"
echo "==============================================="

#==============================================================================
# System Update and Dependencies
#==============================================================================
echo "[1/8] Updating system..."
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y -qq \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    jq \
    git \
    htop \
    iotop \
    google-cloud-sdk \
    google-cloud-sdk-logging \
    fail2ban \
    ufw

#==============================================================================
# Install Docker
#==============================================================================
echo "[2/8] Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
    systemctl enable docker
    systemctl start docker
fi

# Install Docker Compose
if ! command -v docker-compose &> /dev/null; then
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
fi

#==============================================================================
# Data Disk Setup
#==============================================================================
echo "[3/8] Setting up data disk..."

# Find data disk (usually /dev/sdb)
DATA_DEVICE=""
for device in /dev/sdb /dev/disk/by-id/google-*data*; do
    if [ -e "$device" ]; then
        DATA_DEVICE=$(readlink -f "$device")
        break
    fi
done

if [[ -n "$DATA_DEVICE" && -b "$DATA_DEVICE" ]]; then
    echo "Found data device: $DATA_DEVICE"
    
    # Check if already formatted
    if ! file -s "$DATA_DEVICE" | grep -q filesystem; then
        echo "Formatting $DATA_DEVICE as ext4..."
        mkfs.ext4 -F "$DATA_DEVICE"
    fi
    
    # Mount
    mkdir -p /opt/xdc-node
    mount "$DATA_DEVICE" /opt/xdc-node || true
    
    # Add to fstab
    UUID=$(blkid -s UUID -o value "$DATA_DEVICE")
    if ! grep -q "$UUID" /etc/fstab; then
        echo "UUID=$UUID /opt/xdc-node ext4 defaults,nofail 0 2" >> /etc/fstab
    fi
    
    echo "Data disk mounted at /opt/xdc-node"
else
    echo "Warning: Data disk not found, using root partition"
    mkdir -p /opt/xdc-node
fi

# Create directory structure
mkdir -p /opt/xdc-node/{configs,scripts,monitoring,reports,mainnet,testnet}
mkdir -p /var/lib/xdc-node/logs
mkdir -p /var/lib/node_exporter/textfile_collector

#==============================================================================
# Download XDC Configuration
#==============================================================================
echo "[4/8] Downloading XDC configuration..."

XDC_REPO_URL="https://raw.githubusercontent.com/XDC-Node-Setup/main"

# Download docker-compose.yml
curl -fsSL "${XDC_REPO_URL}/docker/docker-compose.yml" -o /opt/xdc-node/docker-compose.yml

# Download network-specific files
mkdir -p /opt/xdc-node/${NETWORK}
for file in genesis.json start-node.sh bootnodes.list .env .pwd; do
    curl -fsSL "${XDC_REPO_URL}/docker/${NETWORK}/$file" -o "/opt/xdc-node/${NETWORK}/$file" 2>/dev/null || true
done

# Download scripts
mkdir -p /opt/xdc-node/scripts
curl -fsSL "${XDC_REPO_URL}/scripts/node-health-check.sh" -o /opt/xdc-node/scripts/node-health-check.sh 2>/dev/null || true
curl -fsSL "${XDC_REPO_URL}/scripts/auto-update.sh" -o /opt/xdc-node/scripts/auto-update.sh 2>/dev/null || true
chmod +x /opt/xdc-node/scripts/*.sh 2>/dev/null || true

# Set permissions
chmod -R 755 /opt/xdc-node

#==============================================================================
# Environment Configuration
#==============================================================================
echo "[5/8] Configuring environment..."

# Create environment file
cat > /opt/xdc-node/.env << EOF
# XDC Node Configuration
NETWORK=${NETWORK}
NODE_TYPE=${NODE_TYPE}

# RPC Configuration
RPC_API=eth,net,web3,xdpos
WS_API=eth,net,web3,xdpos

# Monitoring
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 24)
GRAFANA_SECRET_KEY=$(openssl rand -base64 32)

# Resource Limits
CPU_LIMIT=4
MEMORY_LIMIT=8G
EOF

# Create systemd service
cat > /etc/systemd/system/xdc-node.service << 'EOF'
[Unit]
Description=XDC Node Docker Compose
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/xdc-node
Environment="NETWORK=mainnet"
EnvironmentFile=-/opt/xdc-node/.env
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
ExecReload=/usr/local/bin/docker-compose restart
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable xdc-node.service

#==============================================================================
# Firewall Configuration
#==============================================================================
echo "[6/8] Configuring firewall..."

ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw allow 30303/tcp comment 'XDC P2P TCP'
ufw allow 30303/udp comment 'XDC P2P UDP'
ufw allow 8545/tcp comment 'RPC HTTP'
ufw allow 8546/tcp comment 'RPC WebSocket'
ufw allow 3000/tcp comment 'Grafana'
ufw allow from 127.0.0.1 to any port 9090 comment 'Prometheus local'
echo "y" | ufw enable

# Configure fail2ban
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
EOF

systemctl enable fail2ban
systemctl start fail2ban

#==============================================================================
# Pull and Start Containers
#==============================================================================
echo "[7/8] Starting XDC node..."

cd /opt/xdc-node

# Pull images
docker pull xinfinorg/xdposchain:${XDC_VERSION}
docker pull prom/prometheus:v2.48.0
docker pull prom/node-exporter:v1.7.0
docker pull gcr.io/cadvisor/cadvisor:v0.47.2
docker pull grafana/grafana:10.2.3

# Start services
systemctl start xdc-node.service

# Wait for startup
sleep 30

#==============================================================================
# Setup Convenience Commands
#==============================================================================
echo "[8/8] Setting up convenience commands..."

cat > /usr/local/bin/xdc-status << 'EOF'
#!/bin/bash
echo "=== XDC Node Status ==="
echo "Date: $(date)"
echo ""
echo "Docker Containers:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | grep -E "(NAME|xdc)" || echo "No containers running"
echo ""
echo "Block Height:"
curl -s -X POST http://localhost:8545 \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' 2>/dev/null | jq -r '.result // "unavailable"'
echo ""
echo "Peer Count:"
curl -s -X POST http://localhost:8545 \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' 2>/dev/null | jq -r '.result // "unavailable"'
echo ""
echo "Disk Usage:"
df -h /opt/xdc-node 2>/dev/null | tail -1 || df -h / | tail -1
echo ""
echo "Memory Usage:"
free -h | grep Mem
echo ""
echo "Service Status:"
systemctl is-active xdc-node.service
EOF

cat > /usr/local/bin/xdc-logs << 'EOF'
#!/bin/bash
SERVICE="${1:-xdc-node}"
docker logs -f --tail 100 "$SERVICE"
EOF

chmod +x /usr/local/bin/xdc-*

#==============================================================================
# Completion
#==============================================================================

# Get instance info
INSTANCE_NAME=$(curl -fsSL "http://metadata.google.internal/computeMetadata/v1/instance/name" -H "Metadata-Flavor: Google" 2>/dev/null)
EXTERNAL_IP=$(curl -fsSL "http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip" -H "Metadata-Flavor: Google" 2>/dev/null)
ZONE=$(curl -fsSL "http://metadata.google.internal/computeMetadata/v1/instance/zone" -H "Metadata-Flavor: Google" 2>/dev/null | cut -d/ -f4)

echo ""
echo "==============================================="
echo "XDC Node Setup Complete!"
echo "==============================================="
echo "Instance: $INSTANCE_NAME"
echo "Zone: $ZONE"
echo "External IP: $EXTERNAL_IP"
echo "Node Type: $NODE_TYPE"
echo "Network: $NETWORK"
echo ""
echo "Endpoints:"
echo "  RPC HTTP:   http://$EXTERNAL_IP:8545"
echo "  RPC WS:     ws://$EXTERNAL_IP:8546"
echo "  Grafana:    http://$EXTERNAL_IP:3000"
echo "  P2P:        enode://...@$EXTERNAL_IP:30303"
echo ""
echo "Useful Commands:"
echo "  xdc-status     - Check node status"
echo "  xdc-logs       - View node logs"
echo "  gcloud compute ssh $INSTANCE_NAME --zone=$ZONE"
echo ""
echo "Data Directory: /opt/xdc-node"
echo "Log File: $LOG_FILE"
echo "==============================================="

# Write to serial port for visibility
echo "XDC Node startup complete. IP: $EXTERNAL_IP" > /dev/ttyS0

# Mark completion
touch /opt/xdc-node/.startup-complete
