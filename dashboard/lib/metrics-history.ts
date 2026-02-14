/**
 * Metrics History Storage
 * In-memory rolling buffer for historical metrics data
 * Max 60 entries (30 minutes at 30s intervals)
 */

export interface MetricsSnapshot {
  timestamp: string;
  blockHeight: number;
  peers: number;
  cpu: number;
  memory: number;
  disk: number;
  syncPercent: number;
  txPoolPending: number;
}

export interface MetricsHistory {
  timestamps: string[];
  blockHeight: number[];
  peers: number[];
  cpu: number[];
  memory: number[];
  disk: number[];
  syncPercent: number[];
  txPoolPending: number[];
}

// Module-level storage (persists across requests in the same Node.js process)
const MAX_ENTRIES = 60;
const metricsHistory: MetricsSnapshot[] = [];

/**
 * Add a new metrics snapshot to the history buffer
 * Automatically maintains max size by removing oldest entries
 */
export function addSnapshot(metrics: {
  timestamp: string;
  blockHeight: number;
  peers: number;
  cpu: number;
  memory: number;
  disk: number;
  syncPercent: number;
  txPoolPending: number;
}): void {
  metricsHistory.push({
    timestamp: metrics.timestamp,
    blockHeight: metrics.blockHeight,
    peers: metrics.peers,
    cpu: metrics.cpu,
    memory: metrics.memory,
    disk: metrics.disk,
    syncPercent: metrics.syncPercent,
    txPoolPending: metrics.txPoolPending,
  });

  // Keep only the last MAX_ENTRIES
  while (metricsHistory.length > MAX_ENTRIES) {
    metricsHistory.shift();
  }
}

/**
 * Get the full history in array format (suitable for charts)
 */
export function getHistory(): MetricsHistory {
  return {
    timestamps: metricsHistory.map(s => s.timestamp),
    blockHeight: metricsHistory.map(s => s.blockHeight),
    peers: metricsHistory.map(s => s.peers),
    cpu: metricsHistory.map(s => s.cpu),
    memory: metricsHistory.map(s => s.memory),
    disk: metricsHistory.map(s => s.disk),
    syncPercent: metricsHistory.map(s => s.syncPercent),
    txPoolPending: metricsHistory.map(s => s.txPoolPending),
  };
}

/**
 * Get the raw snapshot array (for inspection/debugging)
 */
export function getRawHistory(): MetricsSnapshot[] {
  return [...metricsHistory];
}

/**
 * Clear all history (useful for testing)
 */
export function clearHistory(): void {
  metricsHistory.length = 0;
}
