# XDPoS Consensus Monitoring Guide

**Version:** 1.0  
**Date:** February 25, 2026  
**Network:** XDC Network Mainnet

---

## Table of Contents

1. [XDPoS Consensus Overview](#1-xdpos-consensus-overview)
2. [Key Parameters](#2-key-parameters)
3. [Epoch and Gap Blocks](#3-epoch-and-gap-blocks)
4. [Monitoring Requirements](#4-monitoring-requirements)
5. [Alert Thresholds](#5-alert-thresholds)
6. [Troubleshooting](#6-troubleshooting)

---

## 1. XDPoS Consensus Overview

XDPoS (XinFin Delegated Proof of Stake) is the consensus mechanism used by the XDC Network. Version 2.0 introduces BFT (Byzantine Fault Tolerance) consensus with the following characteristics:

### Core Features

- **Delegated Proof of Stake**: Masternodes are elected based on stake
- **BFT Consensus**: 2/3+1 majority required for block finality
- **Hotstuff-inspired**: Reduced communication complexity
- **Double Validation**: Blocks signed by masternode and verified by validators

### Consensus Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    XDPoS Consensus Flow                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. Block Proposal                                           │
│     └── Masternode proposes block (round-robin)              │
│                                                              │
│  2. Vote Collection                                          │
│     └── Validators vote on block                             │
│                                                              │
│  3. Quorum Certificate (QC)                                  │
│     └── Formed when 2/3+1 votes received                     │
│                                                              │
│  4. Block Finalization                                       │
│     └── Block committed with QC                              │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Key Parameters

### Mainnet Configuration

| Parameter | Value | Description |
|-----------|-------|-------------|
| **Epoch** | 900 blocks | ~30 minutes at 2s block time |
| **Gap** | 450 blocks | Preparation phase for next epoch |
| **Masternodes** | 108 | Active block producers |
| **Standby Nodes** | Variable | Waiting to join active set |
| **Block Time** | 2 seconds | Target block interval |
| **Checkpoint** | Every epoch | Masternode set update |

### RPC Methods

```bash
# Get current masternode set
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "XDPoS_getMasternodesByNumber",
    "params": ["latest"],
    "id": 1
  }'

# Response:
# {
#   "result": {
#     "Number": 89234567,
#     "Round": 0,
#     "Masternodes": ["0x...", "0x..."],
#     "Standbynodes": ["0x..."]
#   }
# }
```

---

## 3. Epoch and Gap Blocks

### Epoch Structure

```
Epoch N (900 blocks total)
├─ Blocks 0-449: Normal operation
├─ Blocks 450-899: Gap phase (preparation)
└─ Block 900: Epoch boundary (checkpoint)

Epoch N+1 begins at block 900
```

### Gap Phase Activities

During gap blocks (450-899 of each epoch):

1. **Masternode Preparation**
   - Randomize contract stores secret
   - Candidates prepare for next epoch

2. **Penalty Calculation**
   - Missed blocks counted
   - Penalties applied at epoch end

3. **Stake Locking**
   - New stakes locked for next epoch
   - Unstakes processed

### Monitoring Script

```bash
#!/bin/bash
# consensus-monitor.sh

EPOCH_BLOCKS=900
GAP_BLOCKS=450
RPC_URL="http://localhost:8545"

check_consensus_health() {
    # Get current block
    BLOCK_HEX=$(curl -s -X POST "$RPC_URL" \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        | jq -r '.result')
    
    BLOCK_NUMBER=$((16#${BLOCK_HEX#0x}))
    EPOCH=$((BLOCK_NUMBER / EPOCH_BLOCKS))
    INTO_EPOCH=$((BLOCK_NUMBER % EPOCH_BLOCKS))
    
    # Get round info
    ROUND=$(curl -s -X POST "$RPC_URL" \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"XDPoS_getMasternodesByNumber","params":["latest"],"id":1}' \
        | jq -r '.result.Round // 0')
    
    echo "Block: $BLOCK_NUMBER | Epoch: $EPOCH | Into Epoch: $INTO_EPOCH | Round: $ROUND"
    
    # Gap phase detection
    if [ $INTO_EPOCH -ge $GAP_BLOCKS ]; then
        echo "⚠️  In GAP PHASE (blocks $GAP_BLOCKS-$EPOCH_BLOCKS)"
        echo "   Masternode preparation in progress"
    fi
    
    # Epoch boundary approaching
    if [ $INTO_EPOCH -gt $((EPOCH_BLOCKS - 10)) ]; then
        echo "⚠️  EPOCH BOUNDARY APPROACHING"
        echo "   Next epoch starts in $((EPOCH_BLOCKS - INTO_EPOCH)) blocks"
    fi
    
    # High round detection (QC issues)
    if [ "$ROUND" -gt 5 ]; then
        echo "🚨 HIGH ROUND: $ROUND - Possible QC formation issues"
    fi
}

check_consensus_health
```

---

## 4. Monitoring Requirements

### Essential Metrics

| Metric | Source | Alert Threshold |
|--------|--------|-----------------|
| Block Height | `eth_blockNumber` | Stalled for > 2 min |
| Round Number | `XDPoS_getMasternodesByNumber` | > 5 |
| Peer Count | `net_peerCount` | < 10 |
| Epoch Position | Calculated | Gap phase entry |
| Masternode Status | Validator contract | Status change |

### Dashboard Widgets

```typescript
// Epoch Progress Widget
interface EpochInfo {
  epoch: number;
  round: number;
  blockNumber: number;
  intoEpoch: number;
  isGapPhase: boolean;
  blocksToNextEpoch: number;
  estimatedNextEpochTime: Date;
}

// Masternode Participation Widget
interface MasternodeMetrics {
  address: string;
  status: 'active' | 'standby' | 'penalized';
  blocksProduced: number;
  blocksMissed: number;
  participationRate: number;
  lastEpochPenalty: number;
}
```

---

## 5. Alert Thresholds

### Critical Alerts (Immediate Action)

| Condition | Threshold | Action |
|-----------|-----------|--------|
| Consensus Stall | Round > 10 | Investigate network partition |
| Block Production Stop | No blocks for 60s | Check masternode status |
| Fork Detection | Divergent block hashes | Stop node, investigate |
| Mass Peer Drop | < 5 peers | Check network connectivity |

### Warning Alerts (Monitor Closely)

| Condition | Threshold | Action |
|-----------|-----------|--------|
| High Round | Round > 5 | Monitor QC formation |
| Low Participation | < 90% votes | Check masternode health |
| Epoch Boundary | Within 10 blocks | Prepare for transition |
| Gap Phase Entry | Block 450+ | Monitor preparation |

### Info Alerts (Awareness)

| Condition | Threshold | Action |
|-----------|-----------|--------|
| Epoch Transition | Every 900 blocks | Log for analysis |
| Masternode Set Change | At checkpoint | Update monitoring |
| Normal Round | Round 0-2 | Healthy consensus |

---

## 6. Troubleshooting

### High Round Numbers

**Symptoms:** Round > 5, slow block production

**Possible Causes:**
1. Network partition
2. Masternode offline
3. Vote message loss
4. QC formation timeout

**Resolution:**
```bash
# Check masternode connectivity
for mn in $(get_masternode_list); do
    ping -c 1 $mn
    check_port $mn 30303
done

# Restart if isolated
xdc restart
```

### Missed Blocks

**Symptoms:** Masternode not producing blocks when in-turn

**Possible Causes:**
1. Node out of sync
2. Insufficient peers
3. Resource exhaustion
4. Clock drift

**Resolution:**
```bash
# Check sync status
xdc sync

# Check peers
xdc peers

# Check resources
xdc info

# Sync system clock
ntpdate -s time.google.com
```

### Fork Detection

**Symptoms:** Different block hashes at same height

**Immediate Actions:**
1. Stop node immediately
2. Identify canonical chain
3. Resync from valid peer
4. Investigate root cause

---

## References

- [XDPoS Whitepaper](https://arxiv.org/pdf/2108.01420)
- [XDC Documentation](https://docs.xdc.network/xdcchain/xdpos/)
- [XDPoS 2.0 Block Structure](https://www.xdc.dev/gary/block-structure-in-xdc-20-2lo8)

---

*Document maintained by XDC EVM Expert Agent*
