'use client';

import { useState } from 'react';
import {
  Bell,
  AlertTriangle,
  AlertCircle,
  CheckCircle,
  Info,
  X,
  ChevronRight,
  Wrench,
  Clock,
  Brain,
  Shield,
  Cpu,
  Network,
  Zap,
  Filter,
  Settings,
} from 'lucide-react';

interface SmartAlert {
  id: string;
  severity: 'critical' | 'warning' | 'info';
  category: 'performance' | 'security' | 'network' | 'system';
  title: string;
  description: string;
  timestamp: Date;
  aiExplanation: string;
  suggestedAction: string;
  autoFixable: boolean;
  dismissed: boolean;
  resolved: boolean;
}

const mockAlerts: SmartAlert[] = [
  {
    id: '1',
    severity: 'critical',
    category: 'performance',
    title: 'High Memory Usage Detected',
    description: 'Memory usage has exceeded 85% for more than 10 minutes.',
    timestamp: new Date(Date.now() - 1000 * 60 * 15),
    aiExplanation: 'The node is processing a higher volume of RPC requests than usual, causing increased memory allocation. This pattern matches historical spikes during peak usage periods.',
    suggestedAction: 'Restart the node with increased memory allocation or enable request batching to reduce memory pressure.',
    autoFixable: true,
    dismissed: false,
    resolved: false,
  },
  {
    id: '2',
    severity: 'warning',
    category: 'network',
    title: 'Peer Connection Instability',
    description: '5 peers disconnected unexpectedly in the last hour.',
    timestamp: new Date(Date.now() - 1000 * 60 * 45),
    aiExplanation: 'Network analysis shows intermittent connectivity issues. The disconnections correlate with network latency spikes in the EU region where most of your peers are located.',
    suggestedAction: 'Add peers from different geographic regions to improve connection stability.',
    autoFixable: false,
    dismissed: false,
    resolved: false,
  },
  {
    id: '3',
    severity: 'warning',
    category: 'security',
    title: 'Unusual RPC Request Pattern',
    description: 'Detected potential replay attack pattern from 2 IP addresses.',
    timestamp: new Date(Date.now() - 1000 * 60 * 30),
    aiExplanation: 'AI model identified suspicious request patterns: repeated eth_call requests with identical parameters but different nonces, originating from 2 IPs with no prior connection history.',
    suggestedAction: 'Enable IP-based rate limiting and consider blocking the flagged addresses.',
    autoFixable: true,
    dismissed: false,
    resolved: false,
  },
  {
    id: '4',
    severity: 'info',
    category: 'system',
    title: 'New XDC Client Version Available',
    description: 'Version 2.4.1 is available with performance improvements.',
    timestamp: new Date(Date.now() - 1000 * 60 * 60 * 2),
    aiExplanation: 'The new version includes optimizations that could reduce your sync time by approximately 15% based on similar node configurations.',
    suggestedAction: 'Schedule an upgrade during low-traffic hours. Estimated downtime: 5 minutes.',
    autoFixable: false,
    dismissed: false,
    resolved: false,
  },
  {
    id: '5',
    severity: 'warning',
    category: 'performance',
    title: 'Sync Lag Increasing',
    description: 'Node is falling behind the network head by ~50 blocks.',
    timestamp: new Date(Date.now() - 1000 * 60 * 20),
    aiExplanation: 'Block processing speed has decreased due to increased state trie operations. This is typically temporary during state sync phases.',
    suggestedAction: 'Monitor for 30 minutes. If lag exceeds 100 blocks, consider increasing --cache value.',
    autoFixable: false,
    dismissed: false,
    resolved: false,
  },
];

const getSeverityIcon = (severity: string) => {
  switch (severity) {
    case 'critical': return <AlertTriangle className="w-5 h-5" />;
    case 'warning': return <AlertCircle className="w-5 h-5" />;
    case 'info': return <Info className="w-5 h-5" />;
    default: return <Info className="w-5 h-5" />;
  }
};

const getSeverityColor = (severity: string) => {
  switch (severity) {
    case 'critical': return 'var(--critical)';
    case 'warning': return 'var(--warning)';
    case 'info': return 'var(--accent-blue)';
    default: return 'var(--text-muted)';
  }
};

const getCategoryIcon = (category: string) => {
  switch (category) {
    case 'performance': return <Cpu className="w-4 h-4" />;
    case 'security': return <Shield className="w-4 h-4" />;
    case 'network': return <Network className="w-4 h-4" />;
    case 'system': return <Settings className="w-4 h-4" />;
    default: return <Info className="w-4 h-4" />;
  }
};

function formatTimeAgo(date: Date): string {
  const seconds = Math.floor((Date.now() - date.getTime()) / 1000);
  if (seconds < 60) return 'Just now';
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`;
  return `${Math.floor(seconds / 86400)}d ago`;
}

export default function SmartAlerts() {
  const [alerts, setAlerts] = useState<SmartAlert[]>(mockAlerts);
  const [filter, setFilter] = useState<'all' | 'critical' | 'warning' | 'info'>('all');
  const [expandedAlert, setExpandedAlert] = useState<string | null>(null);
  const [applyingFix, setApplyingFix] = useState<string | null>(null);

  const filteredAlerts = alerts.filter(
    (alert) => filter === 'all' || alert.severity === filter
  );

  const activeAlerts = alerts.filter((a) => !a.dismissed && !a.resolved).length;
  const criticalCount = alerts.filter((a) => a.severity === 'critical' && !a.dismissed && !a.resolved).length;

  const dismissAlert = (id: string) => {
    setAlerts((prev) =>
      prev.map((a) => (a.id === id ? { ...a, dismissed: true } : a))
    );
  };

  const applyFix = async (id: string) => {
    setApplyingFix(id);
    await new Promise((resolve) => setTimeout(resolve, 2000));
    setAlerts((prev) =>
      prev.map((a) => (a.id === id ? { ...a, resolved: true } : a))
    );
    setApplyingFix(null);
  };

  return (
    <div className="card-xdc">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-[var(--warning)]/10 flex items-center justify-center relative">
            <Bell className="w-5 h-5 text-[var(--warning)]" />
            {criticalCount > 0 && (
              <span className="absolute -top-1 -right-1 w-5 h-5 rounded-full bg-[var(--critical)] text-white text-[10px] font-bold flex items-center justify-center">
                {criticalCount}
              </span>
            )}
          </div>
          <div>
            <h3 className="text-sm font-semibold text-[var(--text-primary)]">Smart Alerts</h3>
            <p className="text-xs text-[var(--text-tertiary)]">AI-detected anomalies with recommendations</p>
          </div>
        </div>
        
        <div className="flex items-center gap-2">
          <Filter className="w-4 h-4 text-[var(--text-muted)]" />
          <select
            value={filter}
            onChange={(e) => setFilter(e.target.value as any)}
            className="bg-[var(--bg-body)] border border-[var(--border-subtle)] rounded-lg px-3 py-1.5 text-xs text-[var(--text-secondary)] focus:outline-none focus:border-[var(--accent-blue)]"
          >
            <option value="all">All ({activeAlerts})</option>
            <option value="critical">Critical</option>
            <option value="warning">Warning</option>
            <option value="info">Info</option>
          </select>
        </div>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-4 gap-3 mb-6">
        {['critical', 'warning', 'info', 'resolved'].map((type) => {
          const count = type === 'resolved'
            ? alerts.filter((a) => a.resolved).length
            : alerts.filter((a) => a.severity === type && !a.dismissed && !a.resolved).length;
          
          return (
            <div
              key={type}
              className="p-2 rounded-lg bg-[var(--bg-body)] border border-[var(--border-subtle)] text-center"
            >
              <p
                className="text-lg font-semibold"
                style={{
                  color: type === 'resolved' ? 'var(--success)' : getSeverityColor(type),
                }}
              >
                {count}
              </p>
              <p className="text-[10px] text-[var(--text-muted)] capitalize">{type}</p>
            </div>
          );
        })}
      </div>

      {/* Alerts List */}
      <div className="space-y-3">
        {filteredAlerts.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-8 text-center">
            <CheckCircle className="w-12 h-12 text-[var(--success)] mb-3" />
            <p className="text-sm font-medium text-[var(--text-primary)]">No active alerts</p>
            <p className="text-xs text-[var(--text-muted)]">All systems operating normally</p>
          </div>
        ) : (
          filteredAlerts.map((alert) => {
            const isExpanded = expandedAlert === alert.id;
            const severityColor = getSeverityColor(alert.severity);
            
            return (
              <div
                key={alert.id}
                className={`rounded-xl border transition-all ${
                  alert.resolved
                    ? 'bg-[var(--bg-body)]/50 border-[var(--border-subtle)] opacity-60'
                    : 'bg-[var(--bg-body)] border-[var(--border-subtle)] hover:border-[var(--border-blue-glow)]'
                }`}
              >
                <div className="p-4">
                  <div className="flex items-start gap-3">
                    <div
                      className="w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0"
                      style={{
                        backgroundColor: `${severityColor}15`,
                        color: severityColor,
                      }}
                    >
                      {getSeverityIcon(alert.severity)}
                    </div>

                    <div className="flex-1 min-w-0">
                      <div className="flex items-start justify-between gap-2">
                        <div>
                          <div className="flex items-center gap-2 mb-1">
                            <span
                              className="text-[10px] px-1.5 py-0.5 rounded font-medium uppercase"
                              style={{
                                backgroundColor: `${severityColor}15`,
                                color: severityColor,
                              }}
                            >
                              {alert.severity}
                            </span>
                            <span className="flex items-center gap-1 text-[10px] text-[var(--text-muted)]">
                              {getCategoryIcon(alert.category)}
                              {alert.category}
                            </span>
                          </div>
                          <h4 className={`text-sm font-medium ${alert.resolved ? 'line-through text-[var(--text-muted)]' : 'text-[var(--text-primary)]'}`}>
                            {alert.title}
                          </h4>
                          <p className="text-xs text-[var(--text-secondary)] mt-1">{alert.description}</p>
                        </div>
                        
                        <div className="flex items-center gap-1">
                          <span className="text-[10px] text-[var(--text-muted)] whitespace-nowrap">
                            {formatTimeAgo(alert.timestamp)}
                          </span>
                          {!alert.resolved && (
                            <button
                              onClick={() => dismissAlert(alert.id)}
                              className="p-1 rounded hover:bg-[var(--bg-hover)] text-[var(--text-muted)]"
                            >
                              <X className="w-4 h-4" />
                            </button>
                          )}
                        </div>
                      </div>

                      {/* AI Analysis Preview */}
                      {!alert.resolved && (
                        <div className="mt-3 flex items-center gap-2">
                          <div className="flex items-center gap-1.5 px-2 py-1 rounded-full bg-[var(--accent-blue)]/10">
                            <Brain className="w-3 h-3 text-[var(--accent-blue)]" />
                            <span className="text-[10px] text-[var(--accent-blue)]">AI Analysis</span>
                          </div>
                          <button
                            onClick={() => setExpandedAlert(isExpanded ? null : alert.id)}
                            className="flex items-center gap-1 text-[10px] text-[var(--text-secondary)] hover:text-[var(--accent-blue)] transition-colors"
                          >
                            {isExpanded ? 'Hide details' : 'View details'}
                            <ChevronRight className={`w-3 h-3 transition-transform ${isExpanded ? 'rotate-90' : ''}`} />
                          </button>
                        </div>
                      )}

                      {alert.resolved && (
                        <div className="mt-2 flex items-center gap-1.5">
                          <CheckCircle className="w-3.5 h-3.5 text-[var(--success)]" />
                          <span className="text-[10px] text-[var(--success)]">Resolved</span>
                        </div>
                      )}
                    </div>
                  </div>

                  {/* Expanded Details */}
                  {isExpanded && !alert.resolved && (
                    <div className="mt-4 pt-4 border-t border-[var(--border-subtle)]">
                      <div className="space-y-3">
                        <div>
                          <p className="text-[10px] text-[var(--text-muted)] uppercase tracking-wider mb-1">AI Explanation</p>
                          <p className="text-xs text-[var(--text-secondary)] leading-relaxed">{alert.aiExplanation}</p>
                        </div>
                        
                        <div className="flex items-start gap-2 p-3 rounded-lg bg-[var(--bg-card)]">
                          <Zap className="w-4 h-4 text-[var(--accent-blue)] flex-shrink-0 mt-0.5" />
                          <div>
                            <p className="text-[10px] text-[var(--text-muted)] uppercase tracking-wider mb-1">Suggested Action</p>
                            <p className="text-xs text-[var(--text-secondary)]">{alert.suggestedAction}</p>
                          </div>
                        </div>

                        {alert.autoFixable && (
                          <button
                            onClick={() => applyFix(alert.id)}
                            disabled={applyingFix === alert.id}
                            className="flex items-center gap-2 px-4 py-2 rounded-lg bg-[var(--accent-blue)] text-white text-xs font-medium hover:bg-[var(--accent-blue)]/90 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                          >
                            {applyingFix === alert.id ? (
                              <>
                                <Clock className="w-3.5 h-3.5 animate-spin" />
                                Applying fix...
                              </>
                            ) : (
                              <>
                                <Wrench className="w-3.5 h-3.5" />
                                Auto-Fix Issue
                              </>
                            )}
                          </button>
                        )}
                      </div>
                    </div>
                  )}
                </div>
              </div>
            );
          })
        )}
      </div>

      {/* Footer */}
      <div className="flex items-center justify-between mt-6 pt-4 border-t border-[var(--border-subtle)]">
        <p className="text-[10px] text-[var(--text-muted)]">
          AI monitors your node 24/7 • Last scan: 2 minutes ago
        </p>
        <button className="flex items-center gap-1.5 text-xs text-[var(--accent-blue)] hover:underline">
          Configure alert rules
          <ChevronRight className="w-3 h-3" />
        </button>
      </div>
    </div>
  );
}
