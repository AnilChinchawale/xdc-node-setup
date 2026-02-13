#!/bin/bash
#==============================================================================
# AWS EC2 User Data Script for XDC Node
# Auto-configures and starts XDC node on first boot
#==============================================================================

set -euo pipefail

# Configuration from environment or defaults
XDC_NODE_TYPE="${XDC_NODE_TYPE:-fullnode}"
XDC_NETWORK="${XDC_NETWORK:-mainnet}"
XDC_DATA_VOLUME="${XDC_DATA_VOLUME:-/dev/nvme1n1}"
XDC_VERSION="${XDC_VERSION:-v2.6.8}"

# Logging
LOG_FILE="/var/log/xdc-node-setup.log"
exec >> "$LOG_FILE" 2>> "$LOG_FILE"

echo "==============================================="
echo "XDC Node Setup Started: $(date)"
echo "Node Type: $XDC_NODE_TYPE"
echo "Network: $XDC_NETWORK"
echo "==============================================="

#==============================================================================
# System Preparation
#==============================================================================

# Update system
echo "[1/10] Updating system packages..."
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y -qq apt-transport-https ca-certificates curl gnupg lsb-release software-properties-common jq git htop iotop awscli nvme-cli

#==============================================================================
# Install Docker (if not pre-installed)
#==============================================================================
echo "[2/10] Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
    systemctl enable docker
    systemctl start docker
fi

# Install Docker Compose if not present
if ! command -v docker-compose &> /dev/null; then
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
fi

usermod -aG docker ubuntu

#==============================================================================
# Data Volume Setup
#==============================================================================
echo "[3/10] Setting up data volume..."

# Find the data volume (might be nvme1n1 or xvdf)
DATA_DEVICE=""
for device in /dev/nvme1n1 /dev/xvdf /dev/sdf; do
    if lsblk "$device" > /dev/null 2>&1; then
        DATA_DEVICE="$device"
        break
    fi
done

if [[ -z "$DATA_DEVICE" ]]; then
    echo "Warning: Data volume not found, using root volume"
    XDC_DATA_DIR="/opt/xdc-node/xdcchain"
else
    echo "Found data device: $DATA_DEVICE"
    
    # Check if already formatted
    if ! file -s "$DATA_DEVICE" | grep -q filesystem; then
        echo "Formatting $DATA_DEVICE as ext4..."
        mkfs.ext4 -F "$DATA_DEVICE"
    fi
    
    # Mount the volume
    mkdir -p /opt/xdc-node
    mount "$DATA_DEVICE" /opt/xdc-node
    
    # Add to fstab
    UUID=$(blkid -s UUID -o value "$DATA_DEVICE")
    if ! grep -q "$UUID" /etc/fstab; then
        echo "UUID=$UUID /opt/xdc-node ext4 defaults,nofail 0 2" >> /etc/fstab
    fi
    
    XDC_DATA_DIR="/opt/xdc-node/xdcchain"
fi

# Create directory structure
mkdir -p "$XDC_DATA_DIR"
mkdir -p /opt/xdc-node/{configs,scripts,monitoring/grafana,docker}
mkdir -p /var/lib/xdc-node/logs
mkdir -p /var/lib/node_exporter/textfile_collector

#==============================================================================
# Download XDC Node Setup Files
#==============================================================================
echo "[4/10] Downloading XDC Node configuration..."

XDC_REPO_URL="https://raw.githubusercontent.com/XDC-Node-Setup/main"

# Download docker-compose.yml
curl -fsSL "${XDC_REPO_URL}/docker/docker-compose.yml" -o /opt/xdc-node/docker-compose.yml

# Download network-specific files
mkdir -p /opt/xdc-node/${XDC_NETWORK}
for file in genesis.json start-node.sh bootnodes.list .env .pwd; do
    curl -fsSL "${XDC_REPO_URL}/docker/${XDC_NETWORK}/$file" -o "/opt/xdc-node/${XDC_NETWORK}/$file" || true
done

# Set correct permissions
chown -R ubuntu:ubuntu /opt/xdc-node /var/lib/xdc-node
chmod -R 755 /opt/xdc-node

#==============================================================================
# Environment Configuration
#==============================================================================
echo "[5/10] Configuring environment..."

# Create environment file
cat > /opt/xdc-node/.env << EOF
# XDC Node Configuration
NETWORK=${XDC_NETWORK}
NODE_TYPE=${XDC_NODE_TYPE}

# Node Identity (generate if not exists)
$(if [[ "$XDC_NODE_TYPE" == "masternode" ]]; then
    echo "COINBASE_ADDR=${COINBASE_ADDR:-}"
    echo "PRIVATE_KEY=${PRIVATE_KEY:-}"
fi)

# RPC Configuration
RPC_API=${RPC_API:-eth,net,web3,xdpos}
WS_API=${WS_API:-eth,net,web3,xdpos}

# Resource Limits
CPU_LIMIT=${CPU_LIMIT:-4}
MEMORY_LIMIT=${MEMORY_LIMIT:-8G}

# Monitoring
GRAFANA_ADMIN_USER=${GRAFANA_ADMIN_USER:-admin}
GRAFANA_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:-$(openssl rand -base64 24)}
GRAFANA_SECRET_KEY=${GRAFANA_SECRET_KEY:-$(openssl rand -base64 32)}
EOF

# Create systemd service for XDC node
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
# CloudWatch Agent Configuration
#==============================================================================
echo "[6/10] Configuring CloudWatch agent..."

# Check if CloudWatch agent is installed
if command -v /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl &> /dev/null; then
    cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
  "metrics": {
    "namespace": "XDC/Node",
    "metrics_collected": {
      "cpu": {
        "measurement": ["cpu_usage_idle", "cpu_usage_iowait", "cpu_usage_user", "cpu_usage_system"],
        "metrics_collection_interval": 60,
        "totalcpu": true
      },
      "disk": {
        "measurement": ["used_percent", "inodes_free"],
        "metrics_collection_interval": 60,
        "resources": ["*"]
      },
      "diskio": {
        "measurement": ["io_time", "write_bytes", "read_bytes", "writes", "reads"],
        "metrics_collection_interval": 60,
        "resources": ["nvme0n1", "nvme1n1"]
      },
      "mem": {
        "measurement": ["mem_used_percent", "mem_available_percent", "mem_used", "mem_cached", "mem_buffered"],
        "metrics_collection_interval": 60
      },
      "netstat": {
        "measurement": ["tcp_established", "tcp_time_wait"],
        "metrics_collection_interval": 60
      },
      "swap": {
        "measurement": ["swap_used_percent"],
        "metrics_collection_interval": 60
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/xdc-node-setup.log",
            "log_group_name": "/xdc/setup",
            "log_stream_name": "{instance_id}",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/lib/xdc-node/logs/*.log",
            "log_group_name": "/xdc/node",
            "log_stream_name": "{instance_id}",
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}
EOF

    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
fi

#==============================================================================
# Security Hardening
#==============================================================================
echo "[7/10] Applying security hardening..."

# Configure UFW firewall
apt-get install -y -qq ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw allow 30303/tcp comment 'XDC P2P TCP'
ufw allow 30303/udp comment 'XDC P2P UDP'
ufw allow from 127.0.0.1 to any port 8545 comment 'RPC HTTP local only'
ufw allow from 127.0.0.1 to any port 8546 comment 'RPC WS local only'
ufw allow from 127.0.0.1 to any port 9090 comment 'Prometheus local only'
ufw --force enable

# Secure SSH
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd

#==============================================================================
# Pull Docker Images
#==============================================================================
echo "[8/10] Pulling Docker images..."

cd /opt/xdc-node

# Pull XDC image
docker pull xinfinorg/xdposchain:${XDC_VERSION}

# Pull monitoring images
docker pull prom/prometheus:v2.48.0
docker pull prom/node-exporter:v1.7.0
docker pull gcr.io/cadvisor/cadvisor:v0.47.2
docker pull grafana/grafana:10.2.3

#==============================================================================
# Start XDC Node
#==============================================================================
echo "[9/10] Starting XDC node..."

# Start the node
systemctl start xdc-node.service

# Wait for containers to start
sleep 30

# Check if node is running
if docker ps | grep -q xdc-node; then
    echo "✓ XDC node container is running"
else
    echo "✗ XDC node container failed to start"
    docker-compose logs >> "$LOG_FILE" 2>&1 || true
fi

#==============================================================================
# Final Setup
#==============================================================================
echo "[10/10] Finalizing setup..."

# Create status check script
cat > /usr/local/bin/xdc-status << 'EOF'
#!/bin/bash
# Quick status check for XDC node

echo "=== XDC Node Status ==="
echo "Date: $(date)"
echo ""

echo "Docker Containers:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(NAME|xdc)"
echo ""

echo "Block Height:"
curl -s -X POST http://localhost:8545 \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | jq -r '.result // "unavailable"'
echo ""

echo "Peer Count:"
curl -s -X POST http://localhost:8545 \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' | jq -r '.result // "unavailable"'
echo ""

echo "Disk Usage:"
df -h /opt/xdc-node | tail -1
echo ""

echo "Memory Usage:"
free -h | grep Mem
echo ""

echo "Services:"
systemctl is-active xdc-node.service
echo ""
EOF

chmod +x /usr/local/bin/xdc-status

# Create log viewer
cat > /usr/local/bin/xdc-logs << 'EOF'
#!/bin/bash
# View XDC node logs
SERVICE="${1:-xdc-node}"
docker logs -f --tail 100 "$SERVICE"
EOF

chmod +x /usr/local/bin/xdc-logs

#==============================================================================
# Completion
#==============================================================================

PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

echo ""
echo "==============================================="
echo "XDC Node Setup Complete!"
echo "==============================================="
echo "Instance ID: $INSTANCE_ID"
echo "Public IP: $PUBLIC_IP"
echo "Node Type: $XDC_NODE_TYPE"
echo "Network: $XDC_NETWORK"
echo ""
echo "Endpoints:"
echo "  RPC HTTP:   http://$PUBLIC_IP:8545"
echo "  RPC WS:     ws://$PUBLIC_IP:8546"
echo "  Grafana:    http://$PUBLIC_IP:3000"
echo "  P2P:        enode://...@$PUBLIC_IP:30303"
echo ""
echo "Useful Commands:"
echo "  xdc-status     - Check node status"
echo "  xdc-logs       - View node logs"
echo "  xdc-logs rpc   - View RPC logs"
echo ""
echo "Data Directory: /opt/xdc-node"
echo "Log File: $LOG_FILE"
echo "==============================================="
