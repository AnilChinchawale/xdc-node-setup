'use client';

import { useMemo } from 'react';
import { 
  Server, 
  Activity, 
  Globe, 
  Database,
  ArrowUpRight,
  ArrowDownRight,
  Minus
} from 'lucide-react';
import type { SkyNetNode } from '@/lib/types';

interface FleetOverviewProps {
  nodes: SkyNetNode[];
  maxBlockHeight: number;
  isLoading?: boolean;
}

// Client type colors
const CLIENT_COLORS = {
  erigon: '#1E90FF',
  nethermind: '#10B981',
  geth: '#8B5CF6',
  unknown: '#6B7280',
};

// Network colors
const NETWORK_COLORS = {
  mainnet: '#10B981',
  apothem: '#F59E0B',
  devnet: '#8B5CF6',
};

function formatBlockHeight(height: number): string {
  if (height >= 1_000_000) {
    return `${(height / 1_000_000).toFixed(2)}M`;
  }
  if (height >= 1_000) {
    return `${(height / 1_000).toFixed(1)}K`;
  }
  return height.toLocaleString();
}

function formatStorageSize(gb: number): string {
  if (gb >= 1000) {
    return `${(gb / 1000).toFixed(1)} TB`;
  }
  return `${gb.toFixed(1)} GB`;
}

function formatTimeAgo(dateString: string): string {
  const date = new Date(dateString);
  const now = new Date();
  const diff = Math.floor((now.getTime() - date.getTime()) / 1000);

  if (diff < 60) return `${diff}s ago`;
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return `${Math.floor(diff / 86400)}d ago`;
}

function NodeCard({ 
  node, 
  maxBlockHeight,
  index 
}: { 
  node: SkyNetNode; 
  maxBlockHeight: number;
  index: number;
}) {
  // Calculate "behind" percentage
  const behindPercent = useMemo(() => {
    if (maxBlockHeight <= 0 || node.blockHeight <= 0) return 0;
    const behind = maxBlockHeight - node.blockHeight;
    if (behind <= 0) return 0;
    return ((behind / maxBlockHeight) * 100);
  }, [maxBlockHeight, node.blockHeight]);

  const clientColor = CLIENT_COLORS[node.clientType] || CLIENT_COLORS.unknown;
  const networkColor = NETWORK_COLORS[node.network] || '#6B7280';

  // Determine status
  const getStatus = () => {
    if (!node.online) return { label: 'Offline', color: 'var(--critical)', bgColor: 'rgba(239, 68, 68, 0.1)' };
    if (node.syncing) return { label: 'Syncing', color: 'var(--warning)', bgColor: 'rgba(245, 158, 11, 0.1)' };
    if (behindPercent > 1) return { label: 'Behind', color: 'var(--warning)', bgColor: 'rgba(245, 158, 11, 0.1)' };
    return { label: 'Online', color: 'var(--success)', bgColor: 'rgba(16, 185, 129, 0.1)' };
  };

  const status = getStatus();

  return (
    <div 
      className="card-xdc p-4 animate-fade-in"
      style={{ animationDelay: `${index * 50}ms` }}
    >
      {/* Header */}
      <div className="flex items-start justify-between mb-3">
        <div className="flex items-center gap-2">
          <div 
            className="w-8 h-8 rounded-lg flex items-center justify-center"
            style={{ backgroundColor: `${clientColor}15` }}
          >
            <Server className="w-4 h-4" style={{ color: clientColor }} />
          </div>
          <div>
            <h4 className="text-sm font-semibold text-[var(--text-primary)] truncate max-w-[120px]">
              {node.name || node.id.slice(0, 8)}
            </h4>            <div className="flex items-center gap-1.5 text-xs">
              <span 
                className="px-1.5 py-0.5 rounded text-[10px] font-medium uppercase"
                style={{ 
                  backgroundColor: `${networkColor}20`,
                  color: networkColor 
                }}
              >
                {node.network}
              </span>
            </div>
          </div>
        </div>
        
        <div 
          className="px-2 py-1 rounded-full text-[10px] font-medium"
          style={{ 
            backgroundColor: status.bgColor,
            color: status.color 
          }}
        >
          {status.label}
        </div>
      </div>

      {/* Client Info */}
      <div className="mb-3 p-2 rounded-lg bg-[var(--bg-body)]">
        <div className="flex items-center justify-between">
          <span className="text-xs text-[var(--text-tertiary)]">Client</span>
          <span 
            className="text-xs font-medium capitalize"
            style={{ color: clientColor }}
          >
            {node.clientType}
          </span>
        </div>
        <div className="flex items-center justify-between mt-1">
          <span className="text-xs text-[var(--text-tertiary)]">Version</span>
          <span className="text-xs text-[var(--text-secondary)] font-mono truncate max-w-[120px]">
            {node.clientVersion || 'Unknown'}
          </span>
        </div>
      </div>

      {/* Block Height & Behind */}
      <div className="mb-3">
        <div className="flex items-center justify-between mb-1">
          <div className="flex items-center gap-1.5">
            <Activity className="w-3.5 h-3.5 text-[var(--text-tertiary)]" />
            <span className="text-xs text-[var(--text-tertiary)]">Block Height</span>
          </div>
          <span className="text-sm font-bold text-[var(--text-primary)] font-mono-nums">
            {formatBlockHeight(node.blockHeight)}
          </span>
        </div>
        
        {behindPercent > 0 && (
          <div className="flex items-center justify-between">
            <span className="text-xs text-[var(--text-tertiary)]">Behind</span>
            <span 
              className="text-xs font-medium font-mono-nums"
              style={{ 
                color: behindPercent > 5 ? 'var(--critical)' : 
                       behindPercent > 1 ? 'var(--warning)' : 'var(--success)' 
              }}
            >
              {behindPercent.toFixed(1)}%
            </span>
          </div>
        )}
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-2 gap-2 mb-3">
        <div className="p-2 rounded-lg bg-[var(--bg-body)]">
          <div className="flex items-center gap-1 mb-1">
            <Globe className="w-3 h-3 text-[var(--text-tertiary)]" />
            <span className="text-[10px] text-[var(--text-tertiary)]">Peers</span>
          </div>
          <span className="text-sm font-medium text-[var(--text-primary)] font-mono-nums">
            {node.peerCount}
          </span>
        </div>
        
        <div className="p-2 rounded-lg bg-[var(--bg-body)]">
          <div className="flex items-center gap-1 mb-1">
            <Database className="w-3 h-3 text-[var(--text-tertiary)]" />
            <span className="text-[10px] text-[var(--text-tertiary)]">Storage</span>
          </div>
          <span className="text-sm font-medium text-[var(--text-primary)] font-mono-nums">
            {formatStorageSize(node.chainDataSize + node.databaseSize)}
          </span>
        </div>
      </div>

      {/* Footer */}
      <div className="pt-2 border-t border-[var(--border-subtle)]">
        <div className="flex items-center justify-between text-[10px]">
          <span className="text-[var(--text-tertiary)]">
            {node.country || 'Unknown location'}
          </span>
          <span className="text-[var(--text-muted)]">
            {formatTimeAgo(node.lastHeartbeat)}
          </span>
        </div>
      </div>
    </div>
  );
}

function SkeletonCard() {
  return (
    <div className="card-xdc p-4">
      <div className="flex items-start justify-between mb-3">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-lg bg-[var(--bg-hover)] animate-pulse" />
          <div>
            <div className="w-20 h-4 bg-[var(--bg-hover)] rounded mb-1 animate-pulse" />
            <div className="w-12 h-3 bg-[var(--bg-hover)] rounded animate-pulse" />
          </div>
        </div>
        <div className="w-14 h-5 bg-[var(--bg-hover)] rounded-full animate-pulse" />
      </div>
      
      <div className="mb-3 p-2 rounded-lg bg-[var(--bg-hover)] animate-pulse h-14" />
      <div className="mb-3 h-10 bg-[var(--bg-hover)] rounded animate-pulse" />
      <div className="grid grid-cols-2 gap-2 mb-3">
        <div className="h-10 bg-[var(--bg-hover)] rounded animate-pulse" />
        <div className="h-10 bg-[var(--bg-hover)] rounded animate-pulse" />
      </div>
      <div className="pt-2 border-t border-[var(--border-subtle)] h-4 bg-[var(--bg-hover)] rounded animate-pulse" />
    </div>
  );
}

export default function FleetOverview({ 
  nodes, 
  maxBlockHeight, 
  isLoading = false 
}: FleetOverviewProps) {
  if (isLoading) {
    return (
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
        {Array.from({ length: 8 }).map((_, i) => (
          <SkeletonCard key={i} />
        ))}
      </div>
    );
  }

  if (nodes.length === 0) {
    return (
      <div className="card-xdc py-12 text-center">
        <div className="w-16 h-16 mx-auto mb-4 rounded-full bg-[var(--bg-hover)] flex items-center justify-center">
          <Server className="w-8 h-8 text-[var(--text-tertiary)]" />
        </div>
        <h3 className="text-lg font-semibold text-[var(--text-primary)] mb-2">No nodes found</h3>
        <p className="text-sm text-[var(--text-secondary)]">
          No nodes match the current filter criteria.
        </p>
      </div>
    );
  }

  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
      {nodes.map((node, index) => (
        <NodeCard 
          key={node.id} 
          node={node} 
          maxBlockHeight={maxBlockHeight}
          index={index}
        />
      ))}
    </div>
  );
}
