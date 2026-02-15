/**
 * Dashboard type definitions
 */

export interface DashboardOverview {
  totalNodes: number;
  onlineNodes: number;
  syncingNodes: number;
  offlineNodes: number;
  totalPeers: number;
  latestBlock: number;
  avgSyncTime: string;
  networkHealth: 'healthy' | 'degraded' | 'critical';
  alertCount: number;
  criticalAlerts: number;
}

export interface NetworkHealth {
  status: 'healthy' | 'degraded' | 'critical';
  score: number; // 0-100
  issues: HealthIssue[];
}

export interface HealthIssue {
  type: string;
  severity: 'low' | 'medium' | 'high';
  message: string;
  affectedNodes: string[];
}

export interface ChartDataPoint {
  timestamp: string;
  value: number;
}

export interface DashboardCharts {
  blockHeight: ChartDataPoint[];
  peerCount: ChartDataPoint[];
  transactionVolume: ChartDataPoint[];
  resourceUsage: {
    cpu: ChartDataPoint[];
    memory: ChartDataPoint[];
    disk: ChartDataPoint[];
  };
}
