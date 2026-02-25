# Troubleshooting Docker Health Checks

## Common Issues

### "wget: not found" in Nethermind Container

**Symptom**: Container shows as "unhealthy" with error message `/bin/sh: 1: wget: not found`

**Cause**: Nethermind uses Ubuntu Noble base image which doesn't include wget by default

**Solution**: Update health check to use `curl` instead:

```yaml
healthcheck:
  test: ["CMD-SHELL", "curl -sf http://localhost:8557 || exit 1"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 60s
```

### Health Check Fails on Erigon

**Symptom**: Health check returns exit code 1 with no output

**Cause**: RPC endpoint may not be responding on expected port

**Debug Steps**:
1. Check if Erigon is running: `docker logs xdc-node-erigon --tail 50`
2. Verify RPC port: `docker port xdc-node-erigon`
3. Test RPC manually: 
   ```bash
   curl -X POST http://localhost:8547 \
     -H "Content-Type: application/json" \
     -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
   ```

**Solution**: Update health check with correct RPC port and longer timeout:
```yaml
healthcheck:
  test: ["CMD-SHELL", "curl -sf http://localhost:8547 -X POST -H 'Content-Type: application/json' -d '{\"jsonrpc\":\"2.0\",\"method\":\"eth_blockNumber\",\"params\":[],\"id\":1}' || exit 1"]
  interval: 60s
  timeout: 30s
  retries: 5
  start_period: 300s
```

## Best Practices

1. **Use `curl` instead of `wget`**: More universally available
2. **Set appropriate timeouts**: Give sync time with `start_period`
3. **Don't rely on `--health-cmd`**: Always use YAML healthcheck syntax
4. **Test health checks manually** before deploying

## Fixing Existing Deployments

### Update Running Container
```bash
# Stop container
docker stop xdc-node

# Update docker-compose.yml with fixed healthcheck

# Recreate container
docker-compose up -d
```

### Force Health Check
```bash
# Manually run health check command
docker exec xdc-node curl -sf http://localhost:8545

# Check health status
docker inspect xdc-node --format='{{json .State.Health}}' | jq
```

