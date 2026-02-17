'use client';
import { getNetworkName, getNetworkInfo } from '@/lib/network';

import { useEffect, useState, useCallback } from 'react';
import { 
  BarChart3, 
  Activity, 
  Clock,
  RefreshCw,
  TrendingUp,
  Hash,
  Zap,
  Server,
  Globe
} from 'lucide-react';
import DashboardLayout from '@/components/DashboardLayout';
import { LineChart } from '@/components/charts/LineChart';

interface MetricsData {
  blockchain: {
    blockHeight: number;
    highestBlock: number;
    syncPercent: number;
    isSyncing: boolean;
    peers: number;
    chainId: string;
  };
  consensus: {
    epoch: number;
    epochProgress: number;
  };
  txpool: {
    pending: number;
    queued: number;
  };
  timestamp: string;
}

interface MetricsHistory {
  timestamps: string[];
  blockHeight: number[];
  peers: number[];
  cpu: number[];
  memory: number[];
  disk: number[];
  syncPercent: number[];
  txPoolPending: number[];
}

export default function NetworkPage() {
  const [metrics, setMetrics] = useState<MetricsData | null>(null);
  const [history, setHistory] = useState<MetricsHistory | null>(null);
  const [loading, setLoading] = useState(true);

  const fetchData = useCallback(async () => {
    try {
      const [metricsRes, historyRes] = await Promise.all([
        fetch('/api/metrics', { cache: 'no-store' }),
        fetch('/api/metrics/history', { cache: 'no-store' }),
      ]);
      
      if (metricsRes.ok) {
        const data = await metricsRes.json();
        setMetrics(data);
      }
      
      if (historyRes.ok) {
        const historyData = await historyRes.json();
        setHistory(historyData);
      }
    } catch (err) {
      console.error('Failed to fetch metrics:', err);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchData();
    const interval = setInterval(fetchData, 30000);
    return () => clearInterval(interval);
  }, [fetchData]);

  const blocksBehind = metrics 
    ? Math.max(0, metrics.blockchain.highestBlock - metrics.blockchain.blockHeight)
    : 0;

  const avgBlockTime = 2; // XDC mainnet ~2s block time

  return (
    <DashboardLayout>
      <div className="space-y-6">
        {/* Header */}
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-lg bg-gradient-to-br from-[var(--accent-blue)]/20 to-[var(--success)]/20 flex items-center justify-center border border-[var(--accent-blue)]/30">
              <BarChart3 className="w-5 h-5 text-[var(--accent-blue)]" />
            </div>
            <div>
              <h1 className="text-xl font-bold text-[var(--text-primary)]">Network Status</h1>
              <p className="text-sm text-[var(--text-tertiary)]">XDC Mainnet statistics and comparison</p>
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

        {/* Network Overview */}
        <div className="bg-gradient-to-r from-[var(--bg-card)] to-[var(--bg-body)] rounded-xl p-6 border border-[var(--border-subtle)]">
          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
            {/* Mainnet Block */}
            <div className="flex items-center gap-3">
              <div className="p-2 rounded-lg bg-[var(--accent-blue)]/10">
                <Hash className="w-4 h-4 text-[var(--accent-blue)]" />
              </div>
              <div>
                <p className="text-[10px] text-[var(--text-tertiary)] uppercase tracking-wider">Mainnet Block</p>
                <p className="text-base font-bold text-[var(--text-primary)] font-mono-nums">
                  {metrics?.blockchain.highestBlock.toLocaleString() || '—'}
                </p>
              </div>
            </div>

            {/* Local Block */}
            <div className="flex items-center gap-3">
              <div className="p-2 rounded-lg bg-[var(--success)]/10">
                <Server className="w-4 h-4 text-[var(--success)]" />
              </div>
              <div>
                <p className="text-[10px] text-[var(--text-tertiary)] uppercase tracking-wider">Local Block</p>
                <p className="text-base font-bold text-[var(--text-primary)] font-mono-nums">
                  {metrics?.blockchain.blockHeight.toLocaleString() || '—'}
                </p>
              </div>
            </div>

            {/* Avg Block Time */}
            <div className="flex items-center gap-3">
              <div className="p-2 rounded-lg bg-[var(--success)]/10">
                <Clock className="w-4 h-4 text-[var(--success)]" />
              </div>
              <div>
                <p className="text-[10px] text-[var(--text-tertiary)] uppercase tracking-wider">Avg Block Time</p>
                <p className="text-base font-bold text-[var(--text-primary)] font-mono-nums">
                  {avgBlockTime.toFixed(1)}s
                </p>
              </div>
            </div>

            {/* Sync Progress */}
            <div className="flex items-center gap-3">
              <div className="p-2 rounded-lg bg-[var(--purple)]/10">
                <TrendingUp className="w-4 h-4 text-[var(--purple)]" />
              </div>
              <div>
                <p className="text-[10px] text-[var(--text-tertiary)] uppercase tracking-wider">Sync Progress</p>
                <p className="text-base font-bold text-[var(--text-primary)] font-mono-nums">
                  {metrics?.blockchain.syncPercent.toFixed(1)}%
                </p>
              </div>
            </div>

            {/* Peers */}
            <div className="flex items-center gap-3">
              <div className="p-2 rounded-lg bg-[var(--accent-blue)]/10">
                <Globe className="w-4 h-4 text-[var(--accent-blue)]" />
              </div>
              <div>
                <p className="text-[10px] text-[var(--text-tertiary)] uppercase tracking-wider">Connected Peers</p>
                <p className="text-base font-bold text-[var(--text-primary)] font-mono-nums">
                  {metrics?.blockchain.peers || 0}
                </p>
              </div>
            </div>

            {/* Pending TXs */}
            <div className="flex items-center gap-3">
              <div className="p-2 rounded-lg bg-[var(--warning)]/10">
                <Zap className="w-4 h-4 text-[var(--warning)]" />
              </div>
              <div>
                <p className="text-[10px] text-[var(--text-tertiary)] uppercase tracking-wider">Pending</p>
                <p className="text-base font-bold text-[var(--text-primary)] font-mono-nums">
                  {metrics?.txpool.pending || 0}
                </p>
              </div>
            </div>
          </div>

          {/* Epoch Progress */}
          <div className="flex flex-wrap items-center gap-4 pt-4 mt-4 border-t border-[var(--border-subtle)]">
            <div className="flex items-center gap-2">
              <span className="text-xs text-[var(--text-tertiary)]">Epoch</span>
              <span className="text-sm font-bold text-[var(--accent-blue)] font-mono-nums">
                {metrics?.consensus.epoch.toLocaleString() || '—'}
              </span>
            </div>
            
            <div className="flex items-center gap-2 flex-1 max-w-[200px]">
              <span className="text-xs text-[var(--text-tertiary)]">Progress</span>
              <div className="flex-1 h-1.5 bg-[var(--bg-hover)] rounded-full overflow-hidden">
                <div 
                  className="h-full bg-[var(--accent-blue)] rounded-full transition-all duration-500"
                  style={{ width: `${metrics?.consensus.epochProgress || 0}%` }}
                />
              </div>
              <span className="text-xs text-[var(--text-primary)] font-mono-nums">
                {metrics?.consensus.epochProgress.toFixed(1)}%
              </span>
            </div>

            <div className="flex items-center gap-2">
              <span className="text-xs text-[var(--text-tertiary)]">Behind</span>
              <span className={`text-sm font-bold font-mono-nums ${blocksBehind > 100 ? 'text-[var(--warning)]' : 'text-[var(--success)]'}`}>
                {blocksBehind} blocks
              </span>
            </div>
          </div>
        </div>

        {/* Sync Status */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <div className="card-xdc">
            <div className="flex items-center gap-3 mb-4">
              <div className="w-10 h-10 rounded-xl bg-[rgba(30,144,255,0.1)] flex items-center justify-center text-[var(--accent-blue)]">
                <Activity className="w-5 h-5" />
              </div>
              <div>
                <h2 className="text-lg font-semibold text-[var(--text-primary)]">Sync Status</h2>
                <p className="text-xs text-[var(--text-tertiary)]">Real-time synchronization</p>
              </div>
            </div>

            <div className="space-y-4">
              <div className="flex justify-between items-center">
                <span className="text-sm text-[var(--text-tertiary)]">Status</span>
                <span className={`text-sm font-medium ${metrics?.blockchain.isSyncing ? 'text-[var(--warning)]' : 'text-[var(--success)]'}`}>
                  {metrics?.blockchain.isSyncing ? 'Syncing' : 'Synced'}
                </span>
              </div>

              <div className="flex justify-between items-center">
                <span className="text-sm text-[var(--text-tertiary)]">Local Block</span>
                <span className="text-sm font-medium font-mono-nums">
                  {metrics?.blockchain.blockHeight.toLocaleString() || '—'}
                </span>
              </div>

              <div className="flex justify-between items-center">
                <span className="text-sm text-[var(--text-tertiary)]">Mainnet Block</span>
                <span className="text-sm font-medium font-mono-nums">
                  {metrics?.blockchain.highestBlock.toLocaleString() || '—'}
                </span>
              </div>

              <div className="flex justify-between items-center">
                <span className="text-sm text-[var(--text-tertiary)]">Blocks Behind</span>
                <span className={`text-sm font-medium font-mono-nums ${blocksBehind > 100 ? 'text-[var(--warning)]' : 'text-[var(--success)]'}`}>
                  {blocksBehind}
                </span>
              </div>

              <div className="pt-3 border-t border-[var(--border-subtle)]">
                <div className="flex justify-between items-center mb-2">
                  <span className="text-sm text-[var(--text-tertiary)]">Sync Progress</span>
                  <span className="text-sm font-medium font-mono-nums">
                    {metrics?.blockchain.syncPercent.toFixed(2)}%
                  </span>
                </div>
                <div className="w-full h-2 bg-[var(--bg-hover)] rounded-full overflow-hidden">
                  <div 
                    className="h-full bg-gradient-to-r from-[var(--accent-blue)] to-[var(--success)] rounded-full transition-all duration-500"
                    style={{ width: `${metrics?.blockchain.syncPercent || 0}%` }}
                  />
                </div>
              </div>
            </div>
          </div>

          <div className="card-xdc">
            <div className="flex items-center gap-3 mb-4">
              <div className="w-10 h-10 rounded-xl bg-[rgba(16,185,129,0.1)] flex items-center justify-center text-[var(--success)]">
                <BarChart3 className="w-5 h-5" />
              </div>
              <div>
                <h2 className="text-lg font-semibold text-[var(--text-primary)]">Network Info</h2>
                <p className="text-xs text-[var(--text-tertiary)]">XDC Mainnet details</p>
              </div>
            </div>

            <div className="space-y-4">
              <div className="flex justify-between items-center">
                <span className="text-sm text-[var(--text-tertiary)]">Chain ID</span>
                <span className="text-sm font-medium font-mono-nums">
                  {metrics?.blockchain.chainId || '50'}
                </span>
              </div>

              <div className="flex justify-between items-center">
                <span className="text-sm text-[var(--text-tertiary)]">Network</span>
                <span className="text-sm font-medium">
                  XDC Mainnet
                </span>
              </div>

              <div className="flex justify-between items-center">
                <span className="text-sm text-[var(--text-tertiary)]">Avg Block Time</span>
                <span className="text-sm font-medium font-mono-nums">
                  ~{avgBlockTime}s
                </span>
              </div>

              <div className="flex justify-between items-center">
                <span className="text-sm text-[var(--text-tertiary)]">Epoch Length</span>
                <span className="text-sm font-medium font-mono-nums">
                  900 blocks
                </span>
              </div>

              <div className="flex justify-between items-center">
                <span className="text-sm text-[var(--text-tertiary)]">Current Epoch</span>
                <span className="text-sm font-medium font-mono-nums">
                  {metrics?.consensus.epoch.toLocaleString() || '—'}
                </span>
              </div>
            </div>
          </div>
        </div>

        {/* Transaction Pool */}
        <div className="card-xdc">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-10 h-10 rounded-xl bg-[rgba(245,158,11,0.1)] flex items-center justify-center text-[var(--warning)]">
              <Zap className="w-5 h-5" />
            </div>
            <div>
              <h2 className="text-lg font-semibold text-[var(--text-primary)]">Transaction Pool</h2>
              <p className="text-xs text-[var(--text-tertiary)]">Pending transaction status</p>
            </div>
          </div>

          <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
            <div className="p-4 rounded-xl bg-[var(--bg-hover)]">
              <p className="text-xs text-[var(--text-tertiary)] mb-1">Pending</p>
              <p className="text-2xl font-bold font-mono-nums">{metrics?.txpool.pending || 0}</p>
            </div>
            <div className="p-4 rounded-xl bg-[var(--bg-hover)]">
              <p className="text-xs text-[var(--text-tertiary)] mb-1">Queued</p>
              <p className="text-2xl font-bold font-mono-nums">{metrics?.txpool.queued || 0}</p>
            </div>
            <div className="p-4 rounded-xl bg-[var(--bg-hover)]">
              <p className="text-xs text-[var(--text-tertiary)] mb-1">Total</p>
              <p className="text-2xl font-bold font-mono-nums">
                {(metrics?.txpool.pending || 0) + (metrics?.txpool.queued || 0)}
              </p>
            </div>
            <div className="p-4 rounded-xl bg-[var(--bg-hover)]">
              <p className="text-xs text-[var(--text-tertiary)] mb-1">Status</p>
              <p className={`text-lg font-bold ${(metrics?.txpool.pending || 0) < 100 ? 'text-[var(--success)]' : 'text-[var(--warning)]'}`}>
                {(metrics?.txpool.pending || 0) < 100 ? 'Normal' : 'High'}
              </p>
            </div>
          </div>
        </div>

        {/* Historical Charts */}
        {history && history.timestamps.length > 0 && (
          <>
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              {/* Block Height History */}
              <div className="card-xdc">
                <div className="flex items-center gap-3 mb-4">
                  <div className="w-10 h-10 rounded-xl bg-[rgba(30,144,255,0.1)] flex items-center justify-center text-[var(--accent-blue)]">
                    <Hash className="w-5 h-5" />
                  </div>
                  <div>
                    <h2 className="text-lg font-semibold text-[var(--text-primary)]">Block Height History</h2>
                    <p className="text-xs text-[var(--text-tertiary)]">Last 30 minutes</p>
                  </div>
                </div>
                <LineChart
                  data={history.blockHeight}
                  color="#1E90FF"
                  height={250}
                  width={600}
                  showArea={true}
                  unit=""
                  labels={history.timestamps.map((ts) => {
                    const date = new Date(ts);
                    return `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`;
                  })}
                />
              </div>

              {/* Peers History */}
              <div className="card-xdc">
                <div className="flex items-center gap-3 mb-4">
                  <div className="w-10 h-10 rounded-xl bg-[rgba(16,185,129,0.1)] flex items-center justify-center text-[var(--success)]">
                    <Globe className="w-5 h-5" />
                  </div>
                  <div>
                    <h2 className="text-lg font-semibold text-[var(--text-primary)]">Connected Peers</h2>
                    <p className="text-xs text-[var(--text-tertiary)]">Last 30 minutes</p>
                  </div>
                </div>
                <LineChart
                  data={history.peers}
                  color="#10B981"
                  height={250}
                  width={600}
                  showArea={true}
                  unit=""
                  labels={history.timestamps.map((ts) => {
                    const date = new Date(ts);
                    return `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`;
                  })}
                />
              </div>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              {/* CPU Usage History */}
              <div className="card-xdc">
                <div className="flex items-center gap-3 mb-4">
                  <div className="w-10 h-10 rounded-xl bg-[rgba(239,68,68,0.1)] flex items-center justify-center text-[var(--error)]">
                    <Activity className="w-5 h-5" />
                  </div>
                  <div>
                    <h2 className="text-lg font-semibold text-[var(--text-primary)]">CPU Usage</h2>
                    <p className="text-xs text-[var(--text-tertiary)]">Last 30 minutes</p>
                  </div>
                </div>
                <LineChart
                  data={history.cpu}
                  color="#EF4444"
                  height={250}
                  width={600}
                  showArea={true}
                  unit="%"
                  labels={history.timestamps.map((ts) => {
                    const date = new Date(ts);
                    return `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`;
                  })}
                />
              </div>

              {/* Memory Usage History */}
              <div className="card-xdc">
                <div className="flex items-center gap-3 mb-4">
                  <div className="w-10 h-10 rounded-xl bg-[rgba(245,158,11,0.1)] flex items-center justify-center text-[var(--warning)]">
                    <Server className="w-5 h-5" />
                  </div>
                  <div>
                    <h2 className="text-lg font-semibold text-[var(--text-primary)]">Memory Usage</h2>
                    <p className="text-xs text-[var(--text-tertiary)]">Last 30 minutes</p>
                  </div>
                </div>
                <LineChart
                  data={history.memory}
                  color="#F59E0B"
                  height={250}
                  width={600}
                  showArea={true}
                  unit="%"
                  labels={history.timestamps.map((ts) => {
                    const date = new Date(ts);
                    return `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`;
                  })}
                />
              </div>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              {/* Sync Progress History */}
              <div className="card-xdc">
                <div className="flex items-center gap-3 mb-4">
                  <div className="w-10 h-10 rounded-xl bg-[rgba(139,92,246,0.1)] flex items-center justify-center text-[var(--purple)]">
                    <TrendingUp className="w-5 h-5" />
                  </div>
                  <div>
                    <h2 className="text-lg font-semibold text-[var(--text-primary)]">Sync Progress</h2>
                    <p className="text-xs text-[var(--text-tertiary)]">Last 30 minutes</p>
                  </div>
                </div>
                <LineChart
                  data={history.syncPercent}
                  color="#8B5CF6"
                  height={250}
                  width={600}
                  showArea={true}
                  unit="%"
                  labels={history.timestamps.map((ts) => {
                    const date = new Date(ts);
                    return `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`;
                  })}
                />
              </div>

              {/* TX Pool Pending History */}
              <div className="card-xdc">
                <div className="flex items-center gap-3 mb-4">
                  <div className="w-10 h-10 rounded-xl bg-[rgba(30,144,255,0.1)] flex items-center justify-center text-[var(--accent-blue)]">
                    <Zap className="w-5 h-5" />
                  </div>
                  <div>
                    <h2 className="text-lg font-semibold text-[var(--text-primary)]">Pending Transactions</h2>
                    <p className="text-xs text-[var(--text-tertiary)]">Last 30 minutes</p>
                  </div>
                </div>
                <LineChart
                  data={history.txPoolPending}
                  color="#1E90FF"
                  height={250}
                  width={600}
                  showArea={true}
                  unit=""
                  labels={history.timestamps.map((ts) => {
                    const date = new Date(ts);
                    return `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`;
                  })}
                />
              </div>
            </div>
          </>
        )}
      </div>
    </DashboardLayout>
  );
}
