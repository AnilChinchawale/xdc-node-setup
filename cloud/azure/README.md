# Azure XDC Node Deployment

ARM templates for deploying XDC Network nodes on Microsoft Azure.

## Quick Start

### Option 1: Azure Portal (One-Click)

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FXDC-Node-Setup%2Fmain%2Fcloud%2Fazure%2Fazuredeploy.json)

1. Click the button above
2. Fill in the parameters
3. Review and create

### Option 2: Azure CLI

```bash
# Login
az login

# Set subscription
az account set --subscription "Your Subscription"

# Create resource group
az group create \
  --name xdc-nodes \
  --location eastus

# Deploy template
az deployment group create \
  --resource-group xdc-nodes \
  --template-file azuredeploy.json \
  --parameters azuredeploy.parameters.json \
  --parameters adminPasswordOrKey="$(cat ~/.ssh/id_rsa.pub)"
```

### Option 3: PowerShell

```powershell
# Connect
Connect-AzAccount

# Set subscription
Set-AzContext -Subscription "Your Subscription"

# Create resource group
New-AzResourceGroup -Name xdc-nodes -Location eastus

# Deploy
New-AzResourceGroupDeployment `
  -ResourceGroupName xdc-nodes `
  -TemplateFile .\azuredeploy.json `
  -TemplateParameterFile .\azuredeploy.parameters.json
```

## Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `vmName` | Name of the VM | `xdc-node` |
| `adminUsername` | Admin username | `xdcadmin` |
| `authenticationType` | `sshPublicKey` or `password` | `sshPublicKey` |
| `adminPasswordOrKey` | SSH public key or password | Required |
| `vmSize` | Azure VM size | `Standard_D4s_v3` |
| `nodeType` | XDC node type | `fullnode` |
| `network` | XDC network | `mainnet` |
| `dataDiskSize` | Data disk size (GB) | `512` |
| `dataDiskType` | Disk type | `Premium_LRS` |

## Recommended VM Sizes

| Node Type | VM Size | vCPUs | RAM | Data Disk | Monthly Cost* |
|-----------|---------|-------|-----|-----------|---------------|
| Full Node | Standard_D4s_v3 | 4 | 16 GB | 512 GB Premium | ~$150 |
| Full Node | Standard_D8s_v3 | 8 | 32 GB | 1024 GB Premium | ~$280 |
| Archive | Standard_E16s_v3 | 16 | 128 GB | 2048 GB Premium | ~$600 |
| Masternode | Standard_D8s_v3 | 8 | 32 GB | 1024 GB Premium | ~$280 |
| RPC Node | Standard_F8s_v2 | 8 | 16 GB | 768 GB Premium | ~$200 |

*Estimated costs in East US region

## Network Security

The template creates an NSG with these rules:

| Port | Protocol | Purpose |
|------|----------|---------|
| 22 | TCP | SSH |
| 30303 | TCP/UDP | XDC P2P |
| 8545 | TCP | RPC HTTP |
| 8546 | TCP | RPC WebSocket |
| 3000 | TCP | Grafana |

**⚠️ Security Note**: Restrict RPC ports to your IP in production:

```bash
# Update NSG rule
az network nsg rule update \
  --resource-group xdc-nodes \
  --nsg-name xdc-nsg \
  --name RPC_HTTP \
  --source-address-prefixes YOUR_IP/32
```

## Post-Deployment

### Connect via SSH

```bash
# Get FQDN
FQDN=$(az deployment group show \
  --resource-group xdc-nodes \
  --name azuredeploy \
  --query properties.outputs.publicDNS.value \
  --output tsv)

# SSH
ssh xdcadmin@$FQDN
```

### Check Node Status

```bash
# On the VM
xdc-status

# Or from local
az vm run-command invoke \
  --resource-group xdc-nodes \
  --name xdc-node \
  --command-id RunShellScript \
  --scripts "xdc-status"
```

### Access Grafana

```bash
# Get public IP
az network public-ip show \
  --resource-group xdc-nodes \
  --name xdc-public-ip \
  --query ipAddress \
  --output tsv

# Access http://IP:3000
```

## Updating the Node

```bash
# SSH to VM
ssh xdcadmin@$FQDN

# Update
cd /opt/xdc-node
docker-compose pull
docker-compose up -d
```

## Backup and Recovery

### Azure Backup

Enable VM backup:

```bash
# Create Recovery Services vault
az backup vault create \
  --resource-group xdc-backup \
  --name xdc-backup-vault \
  --location eastus

# Enable backup for VM
az backup protection enable-for-vm \
  --resource-group xdc-nodes \
  --vault-name xdc-backup-vault \
  --vm xdc-node \
  --policy-name DefaultPolicy
```

### Disk Snapshots

```bash
# Create snapshot
az snapshot create \
  --resource-group xdc-nodes \
  --name xdc-data-snapshot \
  --source $(az disk list \
    --resource-group xdc-nodes \
    --query "[?contains(name,'datadisk')].id" \
    --output tsv)
```

## Monitoring

### Azure Monitor

Enable with `enableMonitoring: true`:

```bash
# View metrics
az monitor metrics list \
  --resource $(az vm show \
    --resource-group xdc-nodes \
    --name xdc-node \
    --query id \
    --output tsv) \
  --metric "Percentage CPU"
```

### Log Analytics

```bash
# Create workspace
az monitor log-analytics workspace create \
  --resource-group xdc-nodes \
  --name xdc-logs \
  --location eastus

# Query logs
az monitor log-analytics query \
  --workspace xdc-logs \
  --analytics-query "Heartbeat | where TimeGenerated > ago(1h)"
```

## Troubleshooting

### Deployment Failed

```bash
# View deployment logs
az deployment group show \
  --resource-group xdc-nodes \
  --name azuredeploy \
  --query properties.outputResources

# View VM logs
az vm boot-diagnostics get-boot-log \
  --resource-group xdc-nodes \
  --name xdc-node
```

### Node Not Syncing

```bash
# Check Docker
az vm run-command invoke \
  --resource-group xdc-nodes \
  --name xdc-node \
  --command-id RunShellScript \
  --scripts "docker ps && docker logs xdc-node --tail 50"
```

### Reset VM

```bash
# Redeploy to new hardware
az vm redeploy \
  --resource-group xdc-nodes \
  --name xdc-node
```

## Cost Optimization

### Reserved Instances

Save up to 72% with reserved capacity:

```bash
# Purchase reservation
az reservations reservation order purchase \
  --reservation-order-id "..." \
  --sku "Standard_D4s_v3" \
  --quantity 1 \
  --term "P1Y" \
  --billing-scope "..."
```

### Auto-shutdown

For dev/test nodes:

```bash
# Enable auto-shutdown
az vm auto-shutdown \
  --resource-group xdc-nodes \
  --name xdc-node \
  --time 1800 \
  --email "admin@example.com"
```

### Spot Instances

Not recommended for production nodes, but usable for testing:

```bash
# Deploy with spot (requires different template)
az deployment group create \
  --resource-group xdc-test \
  --template-file azuredeploy-spot.json \
  --parameters priority=Spot
```

## Multi-Region Deployment

Deploy to multiple regions for redundancy:

```bash
REGIONS=("eastus" "westeurope" "southeastasia")

for region in "${REGIONS[@]}"; do
  az group create --name "xdc-$region" --location "$region"
  az deployment group create \
    --resource-group "xdc-$region" \
    --template-file azuredeploy.json \
    --parameters location="$region" \
    --parameters vmName="xdc-node-$region"
done
```

## Deleting Resources

```bash
# Delete entire resource group
az group delete --name xdc-nodes --yes --no-wait
```

## Resources

- [Azure VM Sizes](https://docs.microsoft.com/azure/virtual-machines/sizes)
- [Azure Disk Types](https://docs.microsoft.com/azure/virtual-machines/disks-types)
- [ARM Template Reference](https://docs.microsoft.com/azure/azure-resource-manager/templates/)
- [XDC Network Documentation](https://docs.xdc.network)
