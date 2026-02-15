/**
 * Alert type definitions
 */

export type AlertSeverity = 'critical' | 'warning' | 'info';

export type AlertType =
  | 'node_offline'
  | 'node_sync_stalled'
  | 'node_low_peers'
  | 'node_high_cpu'
  | 'node_high_memory'
  | 'node_disk_full'
  | 'masternode_slashed'
  | 'masternode_inactive'
  | 'network_fork'
  | 'version_outdated'
  | 'custom';

export interface Alert {
  id: string;
  nodeId: string;
  nodeName: string;
  type: AlertType;
  severity: AlertSeverity;
  title: string;
  message: string;
  timestamp: string;
  dismissed: boolean;
  dismissedAt?: string;
  actionable: boolean;
  actionType?: 'restart' | 'add_peer' | 'upgrade' | 'investigate';
  metadata?: Record<string, unknown>;
}

export interface AlertRule {
  id: string;
  name: string;
  type: AlertType;
  enabled: boolean;
  severity: AlertSeverity;
  condition: AlertCondition;
  cooldownMinutes: number;
  notifyPush: boolean;
  notifyEmail: boolean;
}

export interface AlertCondition {
  metric: string;
  operator: 'gt' | 'lt' | 'eq' | 'ne' | 'gte' | 'lte';
  threshold: number;
  durationSeconds?: number;
}

export interface AlertStats {
  total: number;
  critical: number;
  warning: number;
  info: number;
  dismissed: number;
}
