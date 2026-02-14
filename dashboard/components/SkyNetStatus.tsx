'use client';

import { useEffect, useState } from 'react';
import { Radio, AlertCircle, Clock, Globe } from 'lucide-react';

interface HeartbeatData {
  enabled: boolean;
  connected: boolean;
  lastHeartbeat: string | null;
  lastHeartbeatSeconds: number | null;
  statusText: string;
  nodeId: string | null;
  nodeName: string | null;
  skynetUrl: string | null;
  error: string | null;
}

function formatTimeAgo(seconds: number): string {
  if (seconds < 60) return `${seconds}s ago`;
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`;
  return `${Math.floor(seconds / 86400)}d ago`;
}

export default function SkyNetStatus() {
  const [heartbeat, setHeartbeat] = useState<HeartbeatData | null>(null);
  const [loading, setLoading] = useState(true);

  const fetchHeartbeat = async () => {
    try {
      const res = await fetch('/api/heartbeat', { cache: 'no-store' });
      if (res.ok) {
        const data = await res.json();
        setHeartbeat(data);
      }
    } catch (err) {
      console.error('Failed to fetch heartbeat:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchHeartbeat();
    const interval = setInterval(fetchHeartbeat, 10000); // Update every 10s
    return () => clearInterval(interval);
  }, []);

  if (loading) {
    return (
      <div className="card-xdc animate-pulse">
        <div className="flex items-center gap-3 mb-4">
          <div className="w-10 h-10 rounded-xl bg-[var(--bg-hover)]" />
          <div>
            <div className="w-32 h-5 bg-[var(--bg-hover)] rounded mb-1" />
            <div className="w-24 h-4 bg-[var(--bg-hover)] rounded" />
          </div>
        </div>
        <div className="space-y-2">
          <div className="w-full h-4 bg-[var(--bg-hover)] rounded" />
          <div className="w-2/3 h-4 bg-[var(--bg-hover)] rounded" />
        </div>
      </div>
    );
  }

  if (!heartbeat?.enabled) {
    return (
      <div className="card-xdc border-[var(--border-subtle)] border-dashed opacity-60">
        <div className="flex items-center gap-3 mb-3">
          <div className="w-10 h-10 rounded-xl bg-gray-500/20 flex items-center justify-center">
            <Radio className="w-5 h-5 text-gray-500" />
          </div>
          <div>
            <h3 className="text-sm font-semibold text-[var(--text-primary)]">SkyNet Status</h3>
            <p className="text-xs text-[var(--text-tertiary)]">Not configured</p>
          </div>
        </div>
        <p className="text-xs text-[var(--text-tertiary)]">
          Enable SkyNet monitoring to track your node&apos;s health and receive alerts.
        </p>
      </div>
    );
  }

  const getStatusColor = () => {
    switch (heartbeat.statusText) {
      case 'connected': return 'var(--success)';
      case 'pending': return '#eab308'; // yellow-500
      case 'offline': return 'var(--critical)';
      case 'error': return '#f97316'; // orange-500
      default: return '#6b7280'; // gray-500
    }
  };

  const getStatusLabel = () => {
    switch (heartbeat.statusText) {
      case 'connected': return 'Connected';
      case 'pending': return 'Pending';
      case 'offline': return 'Offline';
      case 'error': return 'Error';
      default: return 'Unknown';
    }
  };

  return (
    <div className="card-xdc">
      <div className="flex items-center gap-3 mb-4">
        <div className="w-10 h-10 rounded-xl bg-[var(--accent-blue)]/10 flex items-center justify-center">
          <Radio 
            className="w-5 h-5" 
            style={{ color: getStatusColor() }}
          />
        </div>
        <div className="flex-1">
          <h3 className="text-sm font-semibold text-[var(--text-primary)]">SkyNet Status</h3>
          <p className="text-xs text-[var(--text-tertiary)]">Network monitoring</p>
        </div>
        <div className="flex items-center gap-2">
          <span 
            className={`w-2.5 h-2.5 rounded-full ${heartbeat.statusText === 'connected' ? 'animate-pulse' : ''}`}
            style={{ backgroundColor: getStatusColor() }}
          />
          <span 
            className="text-xs font-medium"
            style={{ color: getStatusColor() }}
          >
            {getStatusLabel()}
          </span>
        </div>
      </div>

      <div className="space-y-3">
        {/* Last Heartbeat */}
        {heartbeat.lastHeartbeat && heartbeat.lastHeartbeatSeconds !== null && (
          <div className="flex items-center gap-2 text-xs">
            <Clock className="w-4 h-4 text-[var(--text-tertiary)]" />
            <span className="text-[var(--text-secondary)]">Last heartbeat:</span>
            <span className="text-[var(--text-primary)] font-medium">
              {formatTimeAgo(heartbeat.lastHeartbeatSeconds)}
            </span>
          </div>
        )}

        {/* Node ID */}
        {heartbeat.nodeId && (
          <div className="flex items-center gap-2 text-xs">
            <Globe className="w-4 h-4 text-[var(--text-tertiary)]" />
            <span className="text-[var(--text-secondary)]">Node ID:</span>
            <code className="text-[var(--text-primary)] font-mono text-[10px] bg-[var(--bg-hover)] px-2 py-0.5 rounded">
              {heartbeat.nodeId.substring(0, 16)}...
            </code>
          </div>
        )}

        {/* Error message */}
        {heartbeat.error && heartbeat.statusText === 'error' && (
          <div className="flex items-start gap-2 text-xs p-2 rounded-lg bg-orange-500/10 border border-orange-500/20">
            <AlertCircle className="w-4 h-4 text-orange-500 mt-0.5 flex-shrink-0" />
            <span className="text-orange-500">{heartbeat.error}</span>
          </div>
        )}

        {/* SkyNet URL */}
        {heartbeat.skynetUrl && (
          <div className="pt-2 border-t border-[var(--border-subtle)]">
            <a 
              href={heartbeat.skynetUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="text-xs text-[var(--accent-blue)] hover:underline"
            >
              View on SkyNet →
            </a>
          </div>
        )}
      </div>
    </div>
  );
}
