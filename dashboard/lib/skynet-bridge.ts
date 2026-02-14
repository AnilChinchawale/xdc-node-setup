/**
 * SkyNet Bridge - Push SkyOne metrics to SkyNet for real-time monitoring
 * 
 * This module sends heartbeat updates from SkyOne dashboard to the central
 * SkyNet monitoring system at net.xdc.network
 */

const SKYNET_API_URL = process.env.SKYNET_API_URL || 'https://net.xdc.network/api/v1';
const SKYNET_NODE_ID = process.env.SKYNET_NODE_ID || '';
const SKYNET_API_KEY = process.env.SKYNET_API_KEY || '';

/**
 * Push metrics to SkyNet heartbeat endpoint
 * Fires and forgets - doesn't block or throw on failure
 */
export async function pushToSkyNet(metrics: any): Promise<void> {
  // Skip if not configured
  if (!SKYNET_API_KEY || !SKYNET_NODE_ID) {
    return;
  }
  
  try {
    const payload = {
      nodeId: SKYNET_NODE_ID,
      blockHeight: metrics.blockchain?.blockHeight || 0,
      syncing: metrics.blockchain?.isSyncing || false,
      syncProgress: metrics.blockchain?.syncPercent || 0,
      peerCount: metrics.blockchain?.peers || 0,
      system: metrics.server || {},
      timestamp: new Date().toISOString(),
    };
    
    await fetch(`${SKYNET_API_URL}/nodes/heartbeat`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${SKYNET_API_KEY}`,
      },
      body: JSON.stringify(payload),
      signal: AbortSignal.timeout(5000),
    });
  } catch (e) {
    // Silent fail — don't break metrics if SkyNet is down
    // In production, you might want to log this to a monitoring service
  }
}
