'use client';

import { useState, useEffect } from 'react';
import { useParams } from 'next/navigation';
import Link from 'next/link';
import type { NodeReport } from '@/lib/types';
import StatusIndicator from '@/components/StatusIndicator';
import MetricGauge from '@/components/MetricGauge';
import SecurityScore from '@/components/SecurityScore';
import VersionBadge from '@/components/VersionBadge';
import AlertBadge from '@/components/AlertBadge';
import BlockHeightChart from '@/components/BlockHeightChart';

export default function NodeDetailPage() {
  const params = useParams();
  const [node, setNode] = useState<NodeReport | null>(null);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState<'metrics' | 'security' | 'logs'>('metrics');
  const [logs, setLogs] = useState<string[]>([]);

  useEffect(() => {
    async function fetchNode() {
      try {
        const res = await fetch(`/api/nodes/${params.id}`);
        if (res.ok) {
          const data = await res.json();
          setNode(data);
        }
      } catch (error) {
        console.error('Failed to fetch node:', error);
      } finally {
        setLoading(false);
      }
    }
    fetchNode();
  }, [params.id]);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-96">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-xdc-primary"></div>
      </div>
    );
  }

  if (!node) {
    return (
      <div className="text-center py-12">
        <h2 className="text-xl text-white mb-2">Node Not Found</h2>
        <p className="text-gray-400 mb-4">The requested node could not be found.</p>
        <Link href="/nodes" className="text-xdc-primary hover:underline">
          ← Back to Nodes
        </Link>
      </div>
    );
  }

  const formatUptime = (seconds: number): string => {
    const days = Math.floor(seconds / 86400);
    const hours = Math.floor((seconds % 86400) / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    return `${days}d ${hours}h ${minutes}m`;
  };

  return (
    <div className="animate-fadeIn">
      {/* Header */}
      <div className="flex items-start justify-between mb-8">
        <div>
          <div className="flex items-center gap-3 mb-2">
            <Link href="/nodes" className="text-gray-400 hover:text-white">
              ← Nodes
            </Link>
          </div>
          <h1 className="text-3xl font-bold text-white">{node.hostname}</h1>
          <p className="text-gray-400 mt-1">{node.ip}</p>
        </div>
        <div className="flex items-center gap-4">
          <StatusIndicator status={node.status} size="lg" />
          <div className="flex gap-2">
            <button className="px-4 py-2 bg-xdc-border text-white rounded-lg hover:bg-xdc-primary transition-colors">
              🔄 Restart
            </button>
            <button className="px-4 py-2 bg-xdc-border text-white rounded-lg hover:bg-xdc-primary transition-colors">
              📦 Update
            </button>
            <button className="px-4 py-2 bg-xdc-border text-white rounded-lg hover:bg-xdc-primary transition-colors">
              💾 Backup
            </button>
          </div>
        </div>
      </div>

      {/* Info Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
        <div className="bg-xdc-card border border-xdc-border rounded-xl p-4">
          <p className="text-gray-400 text-sm">Role</p>
          <p className="text-white font-semibold capitalize">{node.role}</p>
        </div>
        <div className="bg-xdc-card border border-xdc-border rounded-xl p-4">
          <p className="text-gray-400 text-sm">Client</p>
          <p className="text-white font-semibold">{node.clientType}</p>
        </div>
        <div className="bg-xdc-card border border-xdc-border rounded-xl p-4">
          <p className="text-gray-400 text-sm">Network</p>
          <p className="text-white font-semibold capitalize">{node.network}</p>
        </div>
        <div className="bg-xdc-card border border-xdc-border rounded-xl p-4">
          <p className="text-gray-400 text-sm">Uptime</p>
          <p className="text-white font-semibold">{formatUptime(node.uptime)}</p>
        </div>
      </div>

      {/* Main Content */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">
        {/* Metrics */}
        <div className="lg:col-span-2 bg-xdc-card border border-xdc-border rounded-xl p-6">
          <h2 className="text-lg font-semibold text-white mb-4">Current Metrics</h2>
          
          <div className="grid grid-cols-2 gap-6 mb-6">
            <div>
              <p className="text-gray-400 text-sm mb-1">Block Height</p>
              <p className="text-2xl font-bold text-white font-mono">
                {node.metrics.blockHeight.toLocaleString()}
              </p>
              <div className="mt-2 h-2 bg-xdc-border rounded-full overflow-hidden">
                <div 
                  className="h-full bg-xdc-primary rounded-full"
                  style={{ width: `${node.metrics.syncProgress}%` }}
                />
              </div>
              <p className="text-xs text-gray-500 mt-1">{node.metrics.syncProgress.toFixed(1)}% synced</p>
            </div>
            <div>
              <p className="text-gray-400 text-sm mb-1">Peer Count</p>
              <p className={`text-2xl font-bold ${
                node.metrics.peerCount > 5 ? 'text-status-healthy' :
                node.metrics.peerCount > 0 ? 'text-status-warning' : 'text-status-critical'
              }`}>
                {node.metrics.peerCount}
              </p>
            </div>
          </div>

          <div className="grid grid-cols-3 gap-6">
            <div className="flex flex-col items-center">
              <MetricGauge label="CPU" value={node.metrics.cpuUsage} />
            </div>
            <div className="flex flex-col items-center">
              <MetricGauge label="RAM" value={node.metrics.ramUsage} />
            </div>
            <div className="flex flex-col items-center">
              <MetricGauge label="Disk" value={node.metrics.diskUsage} />
            </div>
          </div>
        </div>

        {/* Security & Version */}
        <div className="space-y-6">
          <div className="bg-xdc-card border border-xdc-border rounded-xl p-6">
            <h2 className="text-lg font-semibold text-white mb-4">Security</h2>
            <div className="flex justify-center mb-4">
              <SecurityScore score={node.securityScore} size="lg" />
            </div>
            <Link href="/security" className="block text-center text-xdc-primary text-sm hover:underline">
              View Security Details →
            </Link>
          </div>

          <div className="bg-xdc-card border border-xdc-border rounded-xl p-6">
            <h2 className="text-lg font-semibold text-white mb-4">Version</h2>
            <div className="flex justify-center">
              <VersionBadge current={node.clientVersion} latest={node.latestVersion} />
            </div>
            <p className="text-center text-sm text-gray-400 mt-2">
              Last seen: {new Date(node.lastSeen).toLocaleString()}
            </p>
          </div>
        </div>
      </div>

      {/* Tabs */}
      <div className="border-b border-xdc-border mb-6">
        <div className="flex gap-4">
          {(['metrics', 'security', 'logs'] as const).map((tab) => (
            <button
              key={tab}
              onClick={() => setActiveTab(tab)}
              className={`px-4 py-3 font-medium capitalize transition-colors ${
                activeTab === tab
                  ? 'text-xdc-primary border-b-2 border-xdc-primary'
                  : 'text-gray-400 hover:text-white'
              }`}
            >
              {tab}
            </button>
          ))}
        </div>
      </div>

      {/* Tab Content */}
      {activeTab === 'metrics' && node.historicalMetrics && (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <BlockHeightChart 
            data={node.historicalMetrics} 
            metric="blockHeight" 
            title="Block Height (24h)"
            color="#1F4CED"
          />
          <BlockHeightChart 
            data={node.historicalMetrics} 
            metric="peerCount" 
            title="Peer Count (24h)"
            color="#10B981"
          />
          <BlockHeightChart 
            data={node.historicalMetrics} 
            metric="cpuUsage" 
            title="CPU Usage (24h)"
            color="#F59E0B"
          />
          <BlockHeightChart 
            data={node.historicalMetrics} 
            metric="ramUsage" 
            title="RAM Usage (24h)"
            color="#EF4444"
          />
        </div>
      )}

      {activeTab === 'security' && (
        <div className="bg-xdc-card border border-xdc-border rounded-xl p-6">
          <h3 className="text-lg font-semibold text-white mb-4">Security Checklist</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            {node.securityChecks.map((check, i) => (
              <div
                key={i}
                className="flex items-center gap-3 p-3 bg-xdc-dark rounded-lg"
              >
                <span className={check.passed ? 'text-status-healthy' : 'text-status-critical'}>
                  {check.passed ? '✓' : '✗'}
                </span>
                <div>
                  <p className="text-white text-sm">{check.name}</p>
                  <p className="text-gray-500 text-xs">{check.description}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {activeTab === 'logs' && (
        <div className="bg-xdc-card border border-xdc-border rounded-xl p-6">
          <h3 className="text-lg font-semibold text-white mb-4">Recent Logs</h3>
          <div className="bg-black rounded-lg p-4 font-mono text-sm text-gray-300 h-96 overflow-auto">
            <p className="text-gray-500">// Log viewer - Connect to node for live logs</p>
            <p className="text-gray-500">// ssh {node.ip} "docker logs xdc-node --tail 100"</p>
            <p className="mt-4">...</p>
          </div>
        </div>
      )}

      {/* Recent Alerts */}
      {node.alerts.length > 0 && (
        <div className="mt-8 bg-xdc-card border border-xdc-border rounded-xl p-6">
          <h3 className="text-lg font-semibold text-white mb-4">Recent Alerts</h3>
          <div className="space-y-3">
            {node.alerts.map((alert) => (
              <div
                key={alert.id}
                className="flex items-center justify-between p-3 bg-xdc-dark rounded-lg"
              >
                <div className="flex items-center gap-3">
                  <AlertBadge level={alert.level} size="sm" />
                  <p className="text-sm text-white">{alert.message}</p>
                </div>
                <span className="text-xs text-gray-500">
                  {new Date(alert.timestamp).toLocaleString()}
                </span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
