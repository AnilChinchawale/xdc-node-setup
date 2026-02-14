'use client';

import { useEffect, useState, useCallback, useMemo } from 'react';
import { 
  Bell, 
  CheckCircle, 
  AlertTriangle, 
  AlertCircle,
  RefreshCw,
  Clock,
  Server,
  Cpu,
  HardDrive,
  Wifi,
  Activity
} from 'lucide-react';
import DashboardLayout from '@/components/DashboardLayout';

interface MetricsData {
  blockchain: {
    blockHeight: number;
    isSyncing: boolean;
    peers: number;
  };
  server: {
    cpuUsage: number;
    memoryUsed: number;
    memoryTotal: number;
    diskUsed: number;
    diskTotal: number;
  };
  timestamp: string;
}

interface Alert {
  id: string;
  severity: 'critical' | 'warning' | 'info';
  title: string;
  description: string;
  timestamp: string;
  metric?: string;
  value?: string;
  threshold?: string;
}

const ALERT_RULES = [
  { id: 'sync_stalled', label: 'Sync Stalled', icon: Clock, threshold: '5 min', severity: 'critical' as const },
  { id: 'low_peers', label: 'Low Peer Count', icon: Wifi, threshold: '<10 peers', severity: 'warning' as const },
  { id: 'high_cpu', label: 'High CPU Usage', icon: Cpu, threshold: '>80%', severity: 'warning' as const },
  { id: 'high_memory', label: 'High Memory Usage', icon: Server, threshold: '>80%', severity: 'warning' as const },
  { id: 'high_disk', label: 'High Disk Usage', icon: HardDrive, threshold: '>90%', severity: 'critical' as const },
];

export default function AlertsPage() {
  const [metrics, setMetrics] = useState<MetricsData | null>(null);
  const [loading, setLoading] = useState(true);
  const [lastBlockUpdate, setLastBlockUpdate] = useState<number>(Date.now());
  const [previousBlockHeight, setPreviousBlockHeight] = useState<number>(0);

  const fetchData = useCallback(async () => {
    try {
      const res = await fetch('/api/metrics', { cache: 'no-store' });
      if (res.ok) {
        const data = await res.json();
        
        // Track block height changes
        if (data.blockchain.blockHeight > previousBlockHeight) {
          setLastBlockUpdate(Date.now());
          setPreviousBlockHeight(data.blockchain.blockHeight);
        }
        
        setMetrics(data);
      }
    } catch (err) {
      console.error('Failed to fetch metrics:', err);
    } finally {
      setLoading(false);
    }
  }, [previousBlockHeight]);

  useEffect(() => {
    fetchData();
    const interval = setInterval(fetchData, 30000);
    return () => clearInterval(interval);
  }, [fetchData]);

  // Generate alerts based on metrics
  const alerts = useMemo((): Alert[] => {
    if (!metrics) return [];
    
    const detected: Alert[] = [];
    const now = Date.now();
    const timeSinceLastBlock = (now - lastBlockUpdate) / 1000 / 60; // minutes
    
    // Sync stalled check
    if (timeSinceLastBlock > 5 && previousBlockHeight > 0) {
      detected.push({
        id: 'sync-stall-001',
        severity: 'critical',
        title: 'Node Sync Stalled',
        description: `Block height has not increased for ${Math.floor(timeSinceLastBlock)} minutes`,
        timestamp: new Date().toISOString(),
        metric: 'block_height',
        value: metrics.blockchain.blockHeight.toString(),
        threshold: '5 min without change',
      });
    }
    
    // Low peers check
    if (metrics.blockchain.peers < 10) {
      detected.push({
        id: 'low-peers-001',
        severity: 'warning',
        title: 'Low Peer Count',
        description: 'Node has fewer peers than recommended minimum',
        timestamp: new Date().toISOString(),
        metric: 'peer_count',
        value: metrics.blockchain.peers.toString(),
        threshold: '> 10',
      });
    }
    
    // High CPU check
    if (metrics.server.cpuUsage > 80) {
      detected.push({
        id: 'high-cpu-001',
        severity: 'warning',
        title: 'High CPU Usage',
        description: 'CPU usage is above recommended threshold',
        timestamp: new Date().toISOString(),
        metric: 'cpu_usage',
        value: `${metrics.server.cpuUsage}%`,
        threshold: '< 80%',
      });
    }
    
    // High memory check
    const memPercent = metrics.server.memoryTotal > 0 
      ? Math.round((metrics.server.memoryUsed / metrics.server.memoryTotal) * 100) 
      : 0;
    if (memPercent > 80) {
      detected.push({
        id: 'high-mem-001',
        severity: 'warning',
        title: 'High Memory Usage',
        description: 'Memory usage is approaching critical threshold',
        timestamp: new Date().toISOString(),
        metric: 'memory_usage',
        value: `${memPercent}%`,
        threshold: '< 80%',
      });
    }
    
    // High disk check
    const diskPercent = metrics.server.diskTotal > 0 
      ? Math.round((metrics.server.diskUsed / metrics.server.diskTotal) * 100) 
      : 0;
    if (diskPercent > 90) {
      detected.push({
        id: 'high-disk-001',
        severity: 'critical',
        title: 'High Disk Usage',
        description: 'Disk usage has exceeded critical threshold',
        timestamp: new Date().toISOString(),
        metric: 'disk_usage',
        value: `${diskPercent}%`,
        threshold: '< 90%',
      });
    }
    
    return detected;
  }, [metrics, lastBlockUpdate, previousBlockHeight]);

  const getSeverityConfig = (severity: 'critical' | 'warning' | 'info') => {
    switch (severity) {
      case 'critical':
        return { 
          icon: AlertTriangle, 
          color: 'text-[var(--critical)]', 
          bg: 'bg-[rgba(239,68,68,0.15)]',
          border: 'border-[rgba(239,68,68,0.3)]'
        };
      case 'warning':
        return { 
          icon: AlertCircle, 
          color: 'text-[var(--warning)]', 
          bg: 'bg-[rgba(245,158,11,0.15)]',
          border: 'border-[rgba(245,158,11,0.3)]'
        };
      case 'info':
        return { 
          icon: Bell, 
          color: 'text-[var(--accent-blue)]', 
          bg: 'bg-[rgba(30,144,255,0.15)]',
          border: 'border-[rgba(30,144,255,0.3)]'
        };
    }
  };

  return (
    <DashboardLayout>
      <div className="space-y-6">
        {/* Header */}
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-lg bg-gradient-to-br from-[var(--warning)]/20 to-[var(--critical)]/20 flex items-center justify-center border border-[var(--warning)]/30">
              <Bell className="w-5 h-5 text-[var(--warning)]" />
            </div>
            <div>
              <h1 className="text-xl font-bold text-[var(--text-primary)]">Alert Monitor</h1>
              <p className="text-sm text-[var(--text-tertiary)]">Real-time node health alerts</p>
            </div>
          </div>

          <button
            onClick={fetchData}
            className="p-2 hover:bg-[var(--bg-hover)] rounded-lg transition-colors"
            title="Refresh"
          >
            <RefreshCw className={`w-5 h-5 text-[var(--text-tertiary)] ${loading ? 'animate-spin' : ''}`} />
          </button>
        </div>

        {/* Alert Summary */}
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
          <div className="card-xdc">
            <div className="section-header mb-1">Active Alerts</div>
            <div className="text-2xl font-bold font-mono-nums">{alerts.length}</div>
          </div>
          <div className="card-xdc">
            <div className="section-header mb-1 text-[var(--critical)]">Critical</div>
            <div className="text-2xl font-bold font-mono-nums text-[var(--critical)]">
              {alerts.filter(a => a.severity === 'critical').length}
            </div>
          </div>
          <div className="card-xdc">
            <div className="section-header mb-1 text-[var(--warning)]">Warning</div>
            <div className="text-2xl font-bold font-mono-nums text-[var(--warning)]">
              {alerts.filter(a => a.severity === 'warning').length}
            </div>
          </div>
          <div className="card-xdc">
            <div className="section-header mb-1 text-[var(--accent-blue)]">Info</div>
            <div className="text-2xl font-bold font-mono-nums text-[var(--accent-blue)]">
              {alerts.filter(a => a.severity === 'info').length}
            </div>
          </div>
        </div>

        {/* Active Alerts */}
        <div className="card-xdc">
          <h2 className="text-lg font-semibold text-[var(--text-primary)] mb-4">Active Alerts</h2>
          
          {alerts.length === 0 ? (
            <div className="text-center py-12 text-[var(--text-tertiary)]">
              <CheckCircle className="w-12 h-12 mx-auto mb-4 text-[var(--success)]" />
              <p className="text-lg font-medium text-[var(--success)]">All Clear!</p>
              <p className="mt-2">No active alerts. Your node is healthy.</p>
            </div>
          ) : (
            <div className="space-y-3">
              {alerts.map((alert) => {
                const config = getSeverityConfig(alert.severity);
                const Icon = config.icon;
                
                return (
                  <div 
                    key={alert.id} 
                    className={`p-4 rounded-xl border ${config.border} ${config.bg}`}
                  >
                    <div className="flex items-start gap-3">
                      <Icon className={`w-5 h-5 ${config.color} mt-0.5`} />
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center justify-between gap-2 mb-1">
                          <h4 className="font-medium text-[var(--text-primary)]">{alert.title}</h4>
                          <span className="text-xs text-[var(--text-tertiary)]">
                            {new Date(alert.timestamp).toLocaleTimeString()}
                          </span>
                        </div>
                        <p className="text-sm text-[var(--text-secondary)] mb-2">{alert.description}</p>
                        
                        <div className="flex items-center gap-4 text-xs text-[var(--text-tertiary)]">
                          {alert.metric && (
                            <span>Metric: <span className="text-[var(--text-primary)]">{alert.metric}</span></span>
                          )}
                          {alert.value && (
                            <span>Value: <span className={config.color}>{alert.value}</span></span>
                          )}
                          {alert.threshold && (
                            <span>Threshold: <span className="text-[var(--text-primary)]">{alert.threshold}</span></span>
                          )}
                        </div>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>

        {/* Alert Rules Configuration */}
        <div className="card-xdc">
          <h2 className="text-lg font-semibold text-[var(--text-primary)] mb-4">Alert Rules</h2>
          
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {ALERT_RULES.map((rule) => {
              const Icon = rule.icon;
              const config = getSeverityConfig(rule.severity);
              
              return (
                <div 
                  key={rule.id}
                  className="p-4 rounded-xl border border-[var(--border-subtle)] bg-[var(--bg-card)]"
                >
                  <div className="flex items-start gap-3">
                    <div className={`p-2 rounded-lg ${config.bg}`}>
                      <Icon className={`w-4 h-4 ${config.color}`} />
                    </div>
                    <div className="flex-1">
                      <h4 className="font-medium text-[var(--text-primary)]">{rule.label}</h4>
                      <p className="text-xs text-[var(--text-tertiary)] mt-1">
                        Threshold: {rule.threshold}
                      </p>
                      <span className={`inline-block mt-2 px-2 py-0.5 text-[10px] font-medium rounded capitalize ${config.bg} ${config.color} border ${config.border}`}>
                        {rule.severity}
                      </span>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </DashboardLayout>
  );
}
