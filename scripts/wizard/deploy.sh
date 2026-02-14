#!/bin/bash
#==============================================================================
# XDC Node Deployment Script
# Executes deployment based on wizard configuration
#==============================================================================

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_FILE="${WIZARD_CONFIG_FILE:-/tmp/xdc-wizard-config.json}"

# Colors
if [[ -t 1 ]]; then
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m'
else
    GREEN=''
    YELLOW=''
    RED=''
    BLUE=''
    CYAN=''
    NC=''
fi

#==============================================================================
# Progress Display
#==============================================================================

TOTAL_STEPS=7
CURRENT_STEP=0

progress() {
    local message="$1"
    ((CURRENT_STEP++))
    local percentage=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    local filled=$((CURRENT_STEP * 40 / TOTAL_STEPS))
    local empty=$((40 - filled))
    
    printf "\r${CYAN}["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "]${NC} %3d%% %s" "$percentage" "$message"
}

progress_done() {
    progress "Complete!"
    echo ""
}

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

#==============================================================================
# Load Configuration
#==============================================================================

load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
    
    NETWORK=$(jq -r '.network' "$CONFIG_FILE")
    ROLE=$(jq -r '.role' "$CONFIG_FILE")
    CLOUD=$(jq -r '.cloud' "$CONFIG_FILE")
    REGION=$(jq -r '.region // empty' "$CONFIG_FILE")
    
    log_info "Configuration loaded:"
    log_info "  Network: $NETWORK"
    log_info "  Role: $ROLE"
    log_info "  Cloud: $CLOUD"
    [[ -n "$REGION" ]] && log_info "  Region: $REGION"
}

#==============================================================================
# Deployment Methods
#==============================================================================

deploy_local() {
    log_info "Deploying locally with Docker Compose..."
    
    progress "Setting up directories..."
    mkdir -p /opt/xdc-node/{configs,scripts,monitoring}
    mkdir -p /root/xdcchain
    mkdir -p /var/lib/node_exporter/textfile_collector
    
    sleep 1
    
    progress "Downloading configuration files..."
    
    local repo_url="https://raw.githubusercontent.com/XDC-Node-Setup/main"
    
    # Download docker-compose
    curl -fsSL "${repo_url}/docker/docker-compose.yml" -o /opt/xdc-node/docker-compose.yml 2>/dev/null || {
        # Fallback to local copy
        cp "${SCRIPT_DIR}/../../docker/docker-compose.yml" /opt/xdc-node/docker-compose.yml
    }
    
    # Download network files
    mkdir -p /opt/xdc-node/${NETWORK}
    for file in genesis.json start-node.sh bootnodes.list .env .pwd; do
        curl -fsSL "${repo_url}/docker/${NETWORK}/$file" -o "/opt/xdc-node/${NETWORK}/$file" 2>/dev/null || true
    done
    
    sleep 1
    
    progress "Installing Docker if needed..."
    if ! command -v docker &> /dev/null; then
        curl -fsSL https://get.docker.com | sh
        systemctl enable docker
        systemctl start docker
    fi
    
    sleep 1
    
    progress "Creating environment configuration..."
    cat > /opt/xdc-node/.env << EOF
NETWORK=${NETWORK}
NODE_TYPE=${ROLE}
RPC_API=eth,net,web3,xdpos
WS_API=eth,net,web3,xdpos
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 24)
GRAFANA_SECRET_KEY=$(openssl rand -base64 32)
EOF
    
    progress "Creating systemd service..."
    cat > /etc/systemd/system/xdc-node.service << 'EOF'
[Unit]
Description=XDC Node Docker Compose
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/xdc-node
EnvironmentFile=-/opt/xdc-node/.env
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
ExecReload=/usr/local/bin/docker-compose restart

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable xdc-node.service
    
    sleep 1
    
    progress "Pulling Docker images..."
    cd /opt/xdc-node
    docker-compose pull 2>&1 | while read -r line; do
        echo -n "."
    done
    echo ""
    
    sleep 1
    
    progress "Starting services..."
    docker-compose up -d
    
    sleep 5
    
    progress "Running health checks..."
    local retries=0
    while [[ $retries -lt 12 ]]; do
        if curl -s http://localhost:8545 -X POST \
            -H "Content-Type: application/json" \
            -d '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' 2>/dev/null | grep -q "result"; then
            break
        fi
        sleep 5
        ((retries++))
    done
    
    progress_done
    
    if [[ $retries -lt 12 ]]; then
        log_success "Node is running and responding to RPC"
    else
        log_warning "Node started but health check timed out"
    fi
}

deploy_aws() {
    log_info "Deploying to AWS..."
    
    progress "Checking AWS CLI..."
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI not installed. Please install it first."
        exit 1
    fi
    
    progress "Validating credentials..."
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        log_error "AWS credentials not configured. Run 'aws configure'."
        exit 1
    fi
    
    progress "Creating CloudFormation stack..."
    
    local stack_name="xdc-${NETWORK}-${ROLE}-$(date +%s)"
    local template_url="https://raw.githubusercontent.com/XDC-Node-Setup/main/cloud/aws/cloudformation.yaml"
    
    # Get key pair
    local key_pair
    key_pair=$(aws ec2 describe-key-pairs --query 'KeyPairs[0].KeyName' --output text 2>/dev/null || echo "")
    
    if [[ -z "$key_pair" || "$key_pair" == "None" ]]; then
        log_error "No EC2 key pair found. Please create one in the AWS console."
        exit 1
    fi
    
    # Determine instance type based on role
    local instance_type="t3.xlarge"
    local data_disk_size=500
    
    case "$ROLE" in
        archive)
            instance_type="m6i.4xlarge"
            data_disk_size=2048
            ;;
        masternode)
            instance_type="m6i.2xlarge"
            data_disk_size=1024
            ;;
        rpc)
            instance_type="c6i.2xlarge"
            data_disk_size=750
            ;;
    esac
    
    aws cloudformation create-stack \
        --stack-name "$stack_name" \
        --template-url "$template_url" \
        --parameters \
            ParameterKey=KeyPairName,ParameterValue="$key_pair" \
            ParameterKey=NodeType,ParameterValue="$ROLE" \
            ParameterKey=Network,ParameterValue="$NETWORK" \
            ParameterKey=InstanceType,ParameterValue="$instance_type" \
            ParameterKey=DataVolumeSize,ParameterValue="$data_disk_size" \
        --capabilities CAPABILITY_IAM \
        >/dev/null 2>&1
    
    progress "Waiting for stack creation..."
    
    aws cloudformation wait stack-create-complete --stack-name "$stack_name"
    
    progress_done
    
    # Get outputs
    local outputs
    outputs=$(aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --query 'Stacks[0].Outputs' \
        --output table)
    
    log_success "AWS deployment complete!"
    echo ""
    echo "Stack Outputs:"
    echo "$outputs"
}

deploy_digitalocean() {
    log_info "Deploying to DigitalOcean..."
    
    progress "Checking doctl..."
    if ! command -v doctl &> /dev/null; then
        log_error "doctl not installed. Please install it first."
        exit 1
    fi
    
    progress "Validating authentication..."
    if ! doctl account get >/dev/null 2>&1; then
        log_error "Not authenticated with DigitalOcean. Run 'doctl auth init'."
        exit 1
    fi
    
    progress "Determining droplet size..."
    local droplet_size="s-4vcpu-8gb"
    local volume_size=500
    
    case "$ROLE" in
        archive)
            droplet_size="s-8vcpu-16gb"
            volume_size=2048
            ;;
        masternode)
            droplet_size="s-8vcpu-16gb"
            volume_size=1024
            ;;
        rpc)
            droplet_size="c-4"
            volume_size=750
            ;;
    esac
    
    local region="${REGION:-nyc3}"
    local droplet_name="xdc-${NETWORK}-${ROLE}"
    
    # Get SSH key fingerprint
    local ssh_key
    ssh_key=$(doctl compute ssh-key list --format ID --no-header | head -1)
    
    if [[ -z "$ssh_key" ]]; then
        log_error "No SSH key found in DigitalOcean. Please add one first."
        exit 1
    fi
    
    progress "Creating droplet..."
    
    doctl compute droplet create "$droplet_name" \
        --image ubuntu-22-04-x64 \
        --size "$droplet_size" \
        --region "$region" \
        --ssh-keys "$ssh_key" \
        --user-data-file "${SCRIPT_DIR}/../../cloud/digitalocean/cloudinit.yaml" \
        --wait \
        >/dev/null
    
    local droplet_id
    droplet_id=$(doctl compute droplet list --format ID,Name --no-header | grep "$droplet_name" | awk '{print $1}')
    
    progress "Creating data volume..."
    
    doctl compute volume create xdc-data-"$droplet_id" \
        --region "$region" \
        --size "$volume_size" \
        --fs-type ext4 \
        >/dev/null
    
    local volume_id
    volume_id=$(doctl compute volume list --format ID,Name --no-header | grep "xdc-data-$droplet_id" | awk '{print $1}')
    
    doctl compute volume-action attach "$volume_id" "$droplet_id" >/dev/null
    
    progress "Waiting for cloud-init..."
    
    local public_ip
    public_ip=$(doctl compute droplet get "$droplet_id" --format PublicIPv4 --no-header)
    
    # Wait for SSH to be available
    local retries=0
    while [[ $retries -lt 30 ]]; do
        if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "root@$public_ip" "echo ok" 2>/dev/null | grep -q "ok"; then
            break
        fi
        sleep 10
        ((retries++))
        echo -n "."
    done
    
    progress_done
    
    log_success "DigitalOcean deployment complete!"
    echo ""
    echo "Droplet: $droplet_name"
    echo "IP: $public_ip"
    echo ""
    echo "Connect: ssh root@$public_ip"
}

deploy_azure() {
    log_info "Deploying to Azure..."
    
    progress "Checking Azure CLI..."
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI not installed. Please install it first."
        exit 1
    fi
    
    progress "Validating login..."
    if ! az account show >/dev/null 2>&1; then
        log_error "Not logged in to Azure. Run 'az login'."
        exit 1
    fi
    
    local resource_group="xdc-${NETWORK}-${ROLE}-$(date +%s)"
    local region="${REGION:-eastus}"
    
    progress "Creating resource group..."
    az group create --name "$resource_group" --location "$region" >/dev/null
    
    progress "Deploying ARM template..."
    
    local template_uri="https://raw.githubusercontent.com/XDC-Node-Setup/main/cloud/azure/azuredeploy.json"
    
    # Get SSH key
    local ssh_key
    ssh_key=$(cat ~/.ssh/id_rsa.pub 2>/dev/null || echo "")
    
    if [[ -z "$ssh_key" ]]; then
        log_error "No SSH public key found at ~/.ssh/id_rsa.pub"
        exit 1
    fi
    
    az deployment group create \
        --resource-group "$resource_group" \
        --template-uri "$template_uri" \
        --parameters \
            nodeType="$ROLE" \
            network="$NETWORK" \
            adminPasswordOrKey="$ssh_key" \
        >/dev/null
    
    progress_done
    
    log_success "Azure deployment complete!"
    echo ""
    echo "Resource Group: $resource_group"
    
    # Get outputs
    az deployment group show \
        --resource-group "$resource_group" \
        --name azuredeploy \
        --query properties.outputs
}

deploy_gcp() {
    log_info "Deploying to Google Cloud Platform..."
    
    progress "Checking gcloud..."
    if ! command -v gcloud &> /dev/null; then
        log_error "gcloud not installed. Please install Google Cloud SDK."
        exit 1
    fi
    
    progress "Validating authentication..."
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
        log_error "Not authenticated with GCP. Run 'gcloud auth login'."
        exit 1
    fi
    
    local deployment_name="xdc-${NETWORK}-${ROLE}-$(date +%s)"
    local zone="${REGION:-us-central1-a}"
    
    progress "Creating deployment..."
    
    local machine_type="n2-standard-4"
    local data_disk_size=500
    
    case "$ROLE" in
        archive)
            machine_type="n2-highmem-8"
            data_disk_size=2048
            ;;
        masternode)
            machine_type="n2-standard-8"
            data_disk_size=1024
            ;;
        rpc)
            machine_type="c2-standard-4"
            data_disk_size=750
            ;;
    esac
    
    gcloud deployment-manager deployments create "$deployment_name" \
        --config "${SCRIPT_DIR}/../../cloud/gcp/deployment.yaml" \
        --properties "zone=${zone},machineType=${machine_type},dataDiskSize=${data_disk_size},nodeType=${ROLE},network=${NETWORK}" \
        >/dev/null 2>&1
    
    progress "Waiting for deployment..."
    
    sleep 30
    
    progress_done
    
    log_success "GCP deployment complete!"
    echo ""
    echo "Deployment: $deployment_name"
    
    # Get outputs
    gcloud deployment-manager deployments describe "$deployment_name" --format "value(outputs)"
}

deploy_existing() {
    log_info "Preparing configuration for existing server..."
    
    progress "Generating setup instructions..."
    
    local output_dir="/tmp/xdc-deploy-${NETWORK}-${ROLE}"
    mkdir -p "$output_dir"
    
    # Create setup script
    cat > "$output_dir/setup.sh" << EOF
#!/bin/bash
# XDC Node Setup Script for ${NETWORK} ${ROLE}
# Generated by XDC Node Wizard

set -e

# Download and run official setup
curl -fsSL https://raw.githubusercontent.com/XDC-Node-Setup/main/setup.sh | bash -s -- --simple

# Configuration will be set for:
#   Network: ${NETWORK}
#   Role: ${ROLE}
EOF
    
    # Create instructions
    cat > "$output_dir/README.txt" << EOF
XDC Node Deployment Package
============================

Network: ${NETWORK}
Role: ${ROLE}

Setup Instructions:
1. Upload setup.sh to your server
2. Run: bash setup.sh
3. Monitor logs: tail -f /var/log/xdc-node-setup.log

Requirements:
- Ubuntu 20.04/22.04/24.04 or Debian 11/12
- 4+ CPU cores
- 8+ GB RAM
- 500+ GB storage

Configuration files are in:
- /opt/xdc-node/
- /root/xdcchain/ (blockchain data)
EOF
    
    progress_done
    
    log_success "Deployment package created: $output_dir"
    echo ""
    echo "Files:"
    ls -la "$output_dir"
    echo ""
    echo "Upload setup.sh to your server and run it."
}

#==============================================================================
# Main
#==============================================================================

main() {
    load_config
    
    case "$CLOUD" in
        local)
            deploy_local
            ;;
        aws)
            deploy_aws
            ;;
        digitalocean)
            deploy_digitalocean
            ;;
        azure)
            deploy_azure
            ;;
        gcp)
            deploy_gcp
            ;;
        existing)
            deploy_existing
            ;;
        *)
            log_error "Unknown deployment method: $CLOUD"
            exit 1
            ;;
    esac
}

main "$@"
