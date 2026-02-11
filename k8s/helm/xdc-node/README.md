# XDC Node Helm Chart

Enterprise-grade Helm chart for deploying XDC Network nodes on Kubernetes.

## Features

- StatefulSet deployment with persistent storage
- Configurable RPC, WebSocket, and P2P services
- Prometheus ServiceMonitor integration
- Ingress support for RPC endpoints
- Security contexts and resource limits
- Support for multiple node types

## Prerequisites

- Kubernetes 1.23+
- Helm 3.8+
- PV provisioner for persistent storage

## Installation

```bash
# Add the repository
helm repo add xdc https://charts.xdc.dev

# Install with default values
helm install xdc-node xdc/xdc-node

# Install with custom values
helm install xdc-node xdc/xdc-node -f values.yaml

# Install in specific namespace
helm install xdc-node xdc/xdc-node -n xdc --create-namespace
```

## Configuration

See `values.yaml` for all configuration options.

### Common configurations:

#### Validator Node
```yaml
nodeType: validator
network: mainnet
xdc:
  rpcEnabled: false
  wsEnabled: false
```

#### RPC Node
```yaml
nodeType: rpc
network: mainnet
xdc:
  rpcEnabled: true
  wsEnabled: true
service:
  rpc:
    enabled: true
ingress:
  enabled: true
```

#### Archive Node
```yaml
nodeType: archive
xdc:
  syncMode: archive
persistence:
  size: 2000Gi
```

## Upgrading

```bash
helm upgrade xdc-node xdc/xdc-node -f values.yaml
```

## Uninstalling

```bash
helm uninstall xdc-node
```

**Note**: PVCs are not deleted automatically. Delete manually if needed.
