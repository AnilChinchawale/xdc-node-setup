# AWS XDC Node Deployment

This directory contains AWS-specific deployment templates for XDC Network nodes.

## Overview

- **Packer Template**: Builds a pre-configured AMI with Docker and XDC node
- **CloudFormation**: Infrastructure as Code for complete node deployment
- **User Data Script**: Auto-configuration script for EC2 instances

## Quick Start

### Option 1: CloudFormation (Recommended)

Deploy a complete XDC node infrastructure with a single command:

```bash
# Set your key pair name
KEY_PAIR="my-key-pair"

# Create stack
aws cloudformation create-stack \
  --stack-name xdc-mainnet-node \
  --template-body file://cloudformation.yaml \
  --parameters \
    ParameterKey=KeyPairName,ParameterValue=$KEY_PAIR \
    ParameterKey=NodeType,ParameterValue=fullnode \
    ParameterKey=Network,ParameterValue=mainnet \
    ParameterKey=InstanceType,ParameterValue=t3.xlarge \
    ParameterKey=DataVolumeSize,ParameterValue=500 \
  --capabilities CAPABILITY_IAM

# Monitor stack creation
aws cloudformation describe-stacks \
  --stack-name xdc-mainnet-node \
  --query 'Stacks[0].StackStatus'

# Get outputs
aws cloudformation describe-stacks \
  --stack-name xdc-mainnet-node \
  --query 'Stacks[0].Outputs'
```

### Option 2: Custom AMI with Packer

Build a custom AMI with XDC pre-installed:

```bash
# Set AWS credentials
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="us-east-1"

# Build AMI
cd cloud/aws
packer build packer.json

# Get the AMI ID from output
# Then use it in CloudFormation:
aws cloudformation create-stack \
  --stack-name xdc-mainnet-node \
  --template-body file://cloudformation.yaml \
  --parameters \
    ParameterKey=KeyPairName,ParameterValue=$KEY_PAIR \
    ParameterKey=AmiId,ParameterValue=ami-xxxxxxxxxxxxxxxxx \
  --capabilities CAPABILITY_IAM
```

### Option 3: Manual EC2 Launch

Launch an EC2 instance using the user data script:

```bash
# Get latest Ubuntu 22.04 AMI
AMI_ID=$(aws ec2 describe-images \
  --owners 099720109477 \
  --filters 'Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*' \
  --query 'sort_by(Images,&CreationDate)[-1].ImageId' \
  --output text)

# Launch instance
aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.xlarge \
  --key-name $KEY_PAIR \
  --security-group-ids sg-xxxxxxxxx \
  --subnet-id subnet-xxxxxxxxx \
  --block-device-mappings '[{"DeviceName":"/dev/sdf","Ebs":{"VolumeSize":500,"VolumeType":"gp3"}}]' \
  --user-data file://userdata.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=xdc-node}]'
```

## Node Types & Instance Recommendations

| Node Type | Instance Type | Data Volume | Use Case |
|-----------|--------------|-------------|----------|
| Full Node | t3.xlarge | 500 GB | General participation |
| Archive | m6i.4xlarge | 2000+ GB | Historical data access |
| Masternode | m6i.2xlarge | 1000 GB | Block production |
| RPC | c6i.2xlarge | 750 GB | API endpoint |

## Security Groups

The CloudFormation template creates a security group with these ports:

| Port | Protocol | Source | Purpose |
|------|----------|--------|---------|
| 22 | TCP | Your IP | SSH access |
| 30303 | TCP/UDP | 0.0.0.0/0 | XDC P2P |
| 8545 | TCP | Your IP | RPC HTTP |
| 8546 | TCP | Your IP | RPC WebSocket |
| 3000 | TCP | Your IP | Grafana |

**⚠️ Security Note**: Restrict RPC ports (8545, 8546) to your IP only in production.

## Post-Deployment

### Connect to Instance

```bash
ssh -i my-key-pair.pem ubuntu@<PUBLIC_IP>
```

### Check Node Status

```bash
# View quick status
xdc-status

# View logs
xdc-logs

# Check sync status
curl -s -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' | jq
```

### Update Node

```bash
# Pull latest images
cd /opt/xdc-node
docker-compose pull
docker-compose up -d

# Or use the auto-update script
/opt/xdc-node/scripts/auto-update.sh
```

## Cost Optimization

### Reserved Instances

For long-running nodes, use Reserved Instances:

```bash
# Purchase 1-year reservation (approx 40% savings)
aws ec2 purchase-reserved-instances-offering \
  --instance-count 1 \
  --reserved-instances-offering-id <offering-id>
```

### Spot Instances

For non-critical nodes (not recommended for masternodes):

```bash
# Launch as spot instance
aws ec2 run-instances \
  --instance-market-options '{"MarketType":"spot","SpotOptions":{"SpotInstanceType":"one-time"}}' \
  ...
```

## Monitoring

### CloudWatch Dashboard

Create a CloudWatch dashboard for your node:

```bash
aws cloudwatch put-dashboard \
  --dashboard-name xdc-node-dashboard \
  --dashboard-body file://dashboard.json
```

### CloudWatch Alarms

The CloudFormation template automatically creates alarms for:
- High CPU usage (>90%)
- Disk full (>85%)

View alarms:
```bash
aws cloudwatch describe-alarms --alarm-name-prefix xdc-
```

## Backup & Recovery

### Automated Snapshots

Create automated EBS snapshots:

```bash
# Create snapshot
aws ec2 create-snapshot \
  --volume-id vol-xxxxxxxxx \
  --description "XDC Node Backup $(date +%Y%m%d)"

# Schedule with Data Lifecycle Manager
aws dlm create-lifecycle-policy \
  --execution-role-arn arn:aws:iam::account:role/dlm-role \
  --description "XDC Node Daily Backups" \
  --state ENABLED \
  --policy-details file://dlm-policy.json
```

## Troubleshooting

### View Setup Logs

```bash
sudo tail -f /var/log/xdc-node-setup.log
```

### Check CloudFormation Events

```bash
aws cloudformation describe-stack-events \
  --stack-name xdc-mainnet-node \
  --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`].[LogicalResourceId,ResourceStatusReason]'
```

### Common Issues

**Issue**: Instance fails to start
- Check security group rules
- Verify key pair exists in the region
- Check IAM instance profile permissions

**Issue**: Node not syncing
- Check internet connectivity
- Verify ports 30303 are open
- Check disk space: `df -h`

**Issue**: RPC not accessible
- Ensure security group allows your IP
- Check if node is fully synced
- Verify container is running: `docker ps`

## Cost Estimation

Use the cost estimator script:

```bash
../scripts/cost-estimator.sh aws us-east-1 t3.xlarge
```

Estimated monthly costs:

| Component | t3.xlarge | m6i.2xlarge |
|-----------|-----------|-------------|
| EC2 Instance | $120 | $280 |
| EBS (500GB gp3) | $40 | $40 |
| Data Transfer | $20 | $45 |
| **Total** | **~$180** | **~$365** |

## Resources

- [AWS EC2 Instance Types](https://aws.amazon.com/ec2/instance-types/)
- [AWS EBS Volume Types](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-volume-types.html)
- [XDC Network Documentation](https://docs.xdc.network)
