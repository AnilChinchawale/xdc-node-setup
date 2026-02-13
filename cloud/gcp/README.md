# GCP XDC Node Deployment

Google Cloud Deployment Manager templates for XDC Network nodes.

## Quick Start

### Prerequisites

```bash
# Install gcloud CLI
https://cloud.google.com/sdk/docs/install

# Authenticate
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
```

### Option 1: gcloud Deployment Manager

```bash
# Set variables
export PROJECT_ID="your-project-id"
export DEPLOYMENT_NAME="xdc-mainnet-node"
export ZONE="us-central1-a"

# Create deployment
gcloud deployment-manager deployments create $DEPLOYMENT_NAME \
  --config deployment.yaml \
  --properties "zone=${ZONE},machineType=n2-standard-4,dataDiskSize=512"

# Check deployment status
gcloud deployment-manager deployments describe $DEPLOYMENT_NAME

# Get outputs
gcloud deployment-manager deployments describe $DEPLOYMENT_NAME --format "value(outputs)"
```

### Option 2: Using Properties File

Create `properties.yaml`:

```yaml
zone: us-central1-a
region: us-central1
machineType: n2-standard-4
nodeType: fullnode
network: mainnet
dataDiskSize: 512
dataDiskType: pd-ssd
preemptible: false
allowedSourceRanges:
  - "0.0.0.0/0"
```

Deploy:
```bash
gcloud deployment-manager deployments create xdc-node \
  --template deployment.yaml \
  --properties-from-file properties.yaml
```

### Option 3: Terraform Alternative

See `terraform/gcp/` directory for Terraform-based deployment.

## Machine Types

| Node Type | Machine Type | vCPUs | RAM | Data Disk | Monthly Cost* |
|-----------|-------------|-------|-----|-----------|---------------|
| Full Node | n2-standard-4 | 4 | 16 GB | 512 GB SSD | ~$140 |
| Full Node | n2-standard-8 | 8 | 32 GB | 1024 GB SSD | ~$270 |
| Archive | n2-highmem-8 | 8 | 64 GB | 2048 GB SSD | ~$450 |
| Masternode | n2-standard-8 | 8 | 32 GB | 1024 GB SSD | ~$270 |
| RPC Node | c2-standard-4 | 4 | 16 GB | 750 GB SSD | ~$160 |

*Estimated costs in us-central1, does not include egress

## Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `zone` | GCP zone | `us-central1-a` |
| `region` | GCP region | `us-central1` |
| `machineType` | Machine type | `n2-standard-4` |
| `nodeType` | XDC node type | `fullnode` |
| `network` | XDC network | `mainnet` |
| `dataDiskSize` | Data disk size (GB) | `512` |
| `dataDiskType` | Disk type | `pd-ssd` |
| `preemptible` | Use preemptible VM | `false` |
| `allowedSourceRanges` | CIDRs for RPC access | `["0.0.0.0/0"]` |

## Post-Deployment

### Connect to Instance

```bash
# Using gcloud
gcloud compute ssh $DEPLOYMENT_NAME-vm --zone=$ZONE

# Or using SSH directly
ssh $(gcloud compute instances describe $DEPLOYMENT_NAME-vm \
  --zone=$ZONE \
  --format='get(networkInterfaces[0].accessConfigs[0].natIP)')
```

### Check Node Status

```bash
# On the VM
xdc-status

# From local
gcloud compute ssh $DEPLOYMENT_NAME-vm --zone=$ZONE --command="xdc-status"
```

### Access Endpoints

```bash
# Get external IP
EXTERNAL_IP=$(gcloud compute instances describe $DEPLOYMENT_NAME-vm \
  --zone=$ZONE \
  --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

# RPC endpoint
echo "http://$EXTERNAL_IP:8545"

# Grafana
echo "http://$EXTERNAL_IP:3000"
```

## Updating the Node

```bash
# SSH to instance
gcloud compute ssh $DEPLOYMENT_NAME-vm --zone=$ZONE

# Update
cd /opt/xdc-node
docker-compose pull
docker-compose up -d
```

## Backup and Recovery

### Disk Snapshots

```bash
# Create snapshot
gcloud compute disks snapshot $DEPLOYMENT_NAME-data-disk \
  --zone=$ZONE \
  --snapshot-names=xdc-data-backup-$(date +%Y%m%d)

# List snapshots
gcloud compute snapshots list

# Restore from snapshot
gcloud compute disks create $DEPLOYMENT_NAME-data-disk-new \
  --zone=$ZONE \
  --source-snapshot=xdc-data-backup-20240115 \
  --type=pd-ssd
```

### Automated Backups

```bash
# Create scheduled snapshot using Cloud Scheduler
gcloud scheduler jobs create http xdc-backup \
  --schedule="0 2 * * *" \
  --uri="https://compute.googleapis.com/compute/v1/projects/$PROJECT_ID/zones/$ZONE/disks/$DEPLOYMENT_NAME-data-disk/createSnapshot" \
  --http-method=POST \
  --message-body='{"name":"xdc-daily-backup"}'
```

## Monitoring

### Cloud Monitoring

```bash
# Install monitoring agent (already installed via startup script)
# View metrics in Cloud Console > Monitoring > Metrics Explorer

# Create custom dashboard
gcloud monitoring dashboards create --config='{
  "displayName": "XDC Node Dashboard",
  "gridLayout": {
    "columns": "2",
    "widgets": [
      {
        "title": "CPU Utilization",
        "xyChart": {
          "dataSets": [{
            "timeSeriesQuery": {
              "timeSeriesFilter": {
                "filter": "resource.type=\"gce_instance\" AND metric.type=\"compute.googleapis.com/instance/cpu/utilization\"",
                "aggregation": {"alignmentPeriod": {"seconds": 60}}
              }
            }
          }]
        }
      }
    ]
  }
}'
```

### Cloud Logging

```bash
# View logs
gcloud logging read "resource.type=gce_instance AND jsonPayload.message=~\"XDC\""

# Create log-based metric
gcloud logging metrics create xdc-errors \
  --description="XDC Node Error Count" \
  --log-filter="resource.type=gce_instance AND severity>=ERROR"
```

## Security

### Firewall Rules

The template creates these firewall rules:

| Name | Ports | Source | Purpose |
|------|-------|--------|---------|
| allow-ssh | 22 | 0.0.0.0/0 | SSH access |
| allow-xdc-p2p | 30303 | 0.0.0.0/0 | XDC P2P |
| allow-rpc | 8545,8546,3000 | Configurable | RPC & Grafana |
| allow-internal | All | 10.0.0.0/24 | Internal traffic |

Restrict RPC access:

```bash
# Update firewall rule
gcloud compute firewall-rules update $DEPLOYMENT_NAME-allow-rpc \
  --source-ranges=YOUR_IP/32
```

### OS Login

OS Login is enabled by default. Manage access with IAM:

```bash
# Grant access
gcloud compute os-login ssh-keys add \
  --key-file=~/.ssh/id_rsa.pub \
  --project=$PROJECT_ID

# Or use IAM
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="user:user@example.com" \
  --role="roles/compute.osLogin"
```

## Cost Optimization

### Committed Use Discounts

Save up to 57% with committed use:

```bash
# Purchase commitment
gcloud compute commitments create xdc-commitment \
  --region=us-central1 \
  --resources=vcpu=4,memory=16 \
  --plan=12-month
```

### Preemptible Instances

For non-critical nodes:

```bash
gcloud deployment-manager deployments create xdc-test \
  --template deployment.yaml \
  --properties "preemptible=true,machineType=n2-standard-4"
```

Note: Preemptible VMs may be terminated at any time. Not suitable for masternodes.

### Sustained Use Discounts

Automatic discounts for running instances:
- 25% discount for instances running >25% of month
- Applied automatically, no action needed

## Troubleshooting

### Deployment Failed

```bash
# View deployment errors
gcloud deployment-manager deployments describe $DEPLOYMENT_NAME

# Check instance logs
gcloud compute instances get-serial-port-output $DEPLOYMENT_NAME-vm --zone=$ZONE

# View startup script logs
ssh $DEPLOYMENT_NAME-vm --zone=$ZONE "sudo cat /var/log/xdc-node-startup.log"
```

### Node Not Syncing

```bash
# Check Docker
gcloud compute ssh $DEPLOYMENT_NAME-vm --zone=$ZONE --command="docker ps"

# Check logs
gcloud compute ssh $DEPLOYMENT_NAME-vm --zone=$ZONE --command="docker logs xdc-node --tail 50"
```

### Disk Full

```bash
# Check disk usage
gcloud compute ssh $DEPLOYMENT_NAME-vm --zone=$ZONE --command="df -h"

# Resize disk
gcloud compute disks resize $DEPLOYMENT_NAME-data-disk \
  --zone=$ZONE \
  --size=1024

# Then resize filesystem on VM
gcloud compute ssh $DEPLOYMENT_NAME-vm --zone=$ZONE --command="sudo resize2fs /dev/sdb"
```

## Deleting Resources

```bash
# Delete deployment (removes all resources)
gcloud deployment-manager deployments delete $DEPLOYMENT_NAME --delete-policy=DELETE

# Or delete individual resources
gcloud compute instances delete $DEPLOYMENT_NAME-vm --zone=$ZONE
gcloud compute disks delete $DEPLOYMENT_NAME-data-disk --zone=$ZONE
gcloud compute addresses delete $DEPLOYMENT_NAME-static-ip --region=$REGION
```

## Advanced Topics

### Load Balancing

For RPC endpoints behind a load balancer:

```bash
# Create health check
gcloud compute health-checks create http xdc-rpc-health \
  --port=8545 \
  --request-path=/

# Create backend service
gcloud compute backend-services create xdc-rpc-backend \
  --protocol=HTTP \
  --health-checks=xdc-rpc-health \
  --global

# Add instance to backend
gcloud compute backend-services add-backend xdc-rpc-backend \
  --instance-group=xdc-node-ig \
  --global
```

### Private Google Access

For nodes without external IPs:

```bash
# Enable private access on subnet
gcloud compute networks subnets update $DEPLOYMENT_NAME-subnet \
  --region=$REGION \
  --enable-private-ip-google-access
```

### VPC Peering

Connect to other networks:

```bash
# Create peering
gcloud compute networks peerings create xdc-peering \
  --network=$DEPLOYMENT_NAME-network \
  --peer-network=other-network \
  --peer-project=other-project
```

## Resources

- [GCP VM Instance Pricing](https://cloud.google.com/compute/pricing)
- [GCP Disk Types](https://cloud.google.com/compute/docs/disks)
- [Deployment Manager Documentation](https://cloud.google.com/deployment-manager/docs)
- [XDC Network Documentation](https://docs.xdc.network)
