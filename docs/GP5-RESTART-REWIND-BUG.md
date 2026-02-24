# GP5 Restart Rewind Bug — Root Cause & Fix

## Issue

When GP5 (go-ethereum PR5 fork for XDC) restarts, it rewinds all the way back to genesis instead of resuming from its last synced block.

**Symptoms:**
- Node was at block 2.5M before restart
- After restart, loads block 2,493,525 but immediately rewinds to genesis
- Logs show: `"Head state missing, repairing"` → `"Rewinding limit reached, resetting to genesis"`
- All sync progress lost on every container restart

**Affected:** All GP5 nodes on XDC mainnet (chainId 50) and Apothem (chainId 51)

## Root Cause

GP5 computes **different state roots** than XDC v2.6.8 due to `uint256`/`BigBalance` differences. It stores state under its own computed root but block headers contain v2.6.8's root. On restart:

1. GP5 loads the head block from DB (e.g., block 2,493,525)
2. Checks if state exists for the header's root → **fails** (state is stored under GP5's own root)
3. Looks up `XdcStateRootCache` for a remote→local root mapping → **fails** (cache entries not found on disk)
4. Triggers `setHeadBeyondRoot` with empty root → **unlimited rewind to genesis**

### Why Cache Entries Were Missing

The `XdcStateRootCache` has disk persistence (`persistToDisk`, `persistBlockRootToDisk`) that writes to the chain DB. However:

- **Block-number lookups** (`XdcGetCachedStateRoot`) were not used during the backward scan
- **Remote-root lookups** (`XdcFindCachedRootForRemote`) rely on the header's root matching a persisted entry
- If a BAD BLOCK event triggers a rewind before the node restarts, the head pointer moves to a low block whose cache entry may not exist

### The BAD BLOCK Trigger

XDC v2.6.8 peers send block announcements at the chain tip (~99.6M). GP5 at block 2.5M receives block 99,609,705, can't validate it (missing ancestors), and marks it as a BAD BLOCK with "unknown ancestor". This is **normal behavior** but can trigger chain head confusion.

## Fix (Commit `b52397626`)

Added a **backward scan** in `core/blockchain.go` that runs on startup when no cached root is found for the head block. It scans up to 10,000 blocks backwards using three methods:

```
Method 1: Block-number → local root (disk-persisted via XdcGetCachedStateRoot)
Method 2: Remote root → local root (disk-persisted via XdcFindCachedRootForRemote)  
Method 3: Native HasState check (block's header root exists in trie DB)
```

If any method finds valid state, it sets the head to that block instead of rewinding to genesis.

### Code Changes

**File:** `core/blockchain.go` (in the head state validation section, after `initXdcCache`)

```go
// If still no cached root, scan backwards through recent blocks
if !xdcHeadStateOk && head.Number.Uint64() > 0 {
    scanLimit := uint64(10000)
    startBlock := head.Number.Uint64()
    if startBlock < scanLimit {
        scanLimit = startBlock
    }
    log.Info("XDC: Scanning backwards for valid cached state root", 
        "from", startBlock, "scanLimit", scanLimit)
    
    for i := uint64(1); i <= scanLimit; i++ {
        checkBlock := startBlock - i
        
        // Method 1: block-number → local root (disk-persisted)
        if cachedRoot, ok := XdcGetCachedStateRoot(checkBlock); ok {
            if _, err := bc.statedb.OpenTrie(cachedRoot); err == nil {
                // Found! Set head here instead of rewinding to genesis
                bc.setHeadBeyondRoot(checkBlock, 0, cachedRoot, true)
                break
            }
        }
        
        // Method 2: remote→local lookup
        // Method 3: native HasState check
        // ... (see full implementation in blockchain.go)
    }
}
```

### Log Output (Successful Recovery)

```
INFO  XDC state root cache initialized         size=10,000,000
INFO  Loaded most recent local block           number=1950
WARN  XDC: No cached root for head block on disk block=1950
INFO  XDC: Scanning backwards for valid cached state root from=1950 scanLimit=1950
INFO  XDC: Found valid native state via backward scan, setting head targetBlock=1949
INFO  Enabled full-sync                        head=1950
```

## Prevention: Snapshot Best Practices

### When to Take Snapshots

- **Always take snapshots BEFORE known roadblocks** (not after issues occur)
- Stop the container cleanly (`docker stop`) before snapshotting
- Verify the snapshot by checking `"Loaded most recent local block"` in logs after restore

### How to Take a Clean Snapshot

```bash
# 1. Check current block
curl -s -X POST http://localhost:8557 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# 2. Stop container (allows DB flush)
docker stop xdc-gp5-213-mainnet

# 3. Create snapshot
mkdir -p /mnt/data/snapshots
cd /mnt/data/mainnet
tar czf /mnt/data/snapshots/gp5-mainnet-<BLOCK>-$(date +%Y%m%d).tar.gz gx/

# 4. Restart
docker start xdc-gp5-213-mainnet

# 5. Clean old snapshots (keep 3 days)
find /mnt/data/snapshots -name "gp5-*.tar.gz" -mtime +3 -delete
```

### How to Restore a Snapshot

```bash
# 1. Stop container
docker stop xdc-gp5-213-mainnet

# 2. Wipe current data
rm -rf /mnt/data/mainnet/gx/XDC /mnt/data/mainnet/gx/geth /mnt/data/mainnet/gx/keystore

# 3. Extract snapshot (note: tar creates gx/ subdir)
cd /mnt/data
tar xzf /mnt/data/snapshots/gp5-mainnet-<BLOCK>-<DATE>.tar.gz
mv /mnt/data/gx/* /mnt/data/mainnet/gx/
rm -rf /mnt/data/gx

# 4. Re-init genesis (required if geth/ dir was wiped)
docker run --rm -v /mnt/data/mainnet/gx:/data/xdc \
  anilchinchawale/gx:latest \
  --datadir /data/xdc init /data/xdc/genesis.json

# 5. Start container
docker start xdc-gp5-213-mainnet

# 6. Verify block height
sleep 15
curl -s -X POST http://localhost:8557 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

### Snapshot Gotcha: Post-Rewind Data

⚠️ **A snapshot taken after a rewind contains rewound data.** The on-disk size may look large (4-5GB) because trie data persists, but the head pointer is at the rewound block. Always check the block number before and after restore.

## Related Issues

- **go-ethereum #16**: BAD BLOCK "unknown ancestor" — normal behavior when receiving tip blocks during sync
- **XdcStateRootCache**: Disk persistence implemented but entries can be lost if rewind happens before flush
- **Docker compose**: Must include `--bootnodes` flag with valid 128-hex-char enode public keys

## Commits

| Commit | Description |
|--------|-------------|
| `c0f66e8fb` | Initial backward scan implementation |
| `b52397626` | Add block-number cache lookup (Method 1) to backward scan |

## Docker Image

- `anilchinchawale/gx:latest` — includes the fix
- SHA: `302e9c0db51ffe739575bd2cef45a2de10e3e0cacea50ad95a1febfd56308881`
