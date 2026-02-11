'use client';

import { useState, useEffect } from 'react';
import NodeCard from '@/components/NodeCard';
import type { NodeReport, HealthReport } from '@/lib/types';

export default function NodesPage() {
  const [nodes, setNodes] = useState<NodeReport[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState({
    status: 'all',
    clientType: 'all',
    network: 'all',
  });
  const [sortBy, setSortBy] = useState<'hostname' | 'blockHeight' | 'peerCount' | 'securityScore'>('hostname');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('asc');

  useEffect(() => {
    async function fetchNodes() {
      try {
        const res = await fetch('/api/nodes');
        const data: HealthReport = await res.json();
        setNodes(data.nodes || []);
      } catch (error) {
        console.error('Failed to fetch nodes:', error);
      } finally {
        setLoading(false);
      }
    }
    fetchNodes();
  }, []);

  const filteredNodes = nodes.filter((node) => {
    if (filter.status !== 'all' && node.status !== filter.status) return false;
    if (filter.clientType !== 'all' && node.clientType !== filter.clientType) return false;
    if (filter.network !== 'all' && node.network !== filter.network) return false;
    return true;
  });

  const sortedNodes = [...filteredNodes].sort((a, b) => {
    let comparison = 0;
    switch (sortBy) {
      case 'hostname':
        comparison = a.hostname.localeCompare(b.hostname);
        break;
      case 'blockHeight':
        comparison = a.metrics.blockHeight - b.metrics.blockHeight;
        break;
      case 'peerCount':
        comparison = a.metrics.peerCount - b.metrics.peerCount;
        break;
      case 'securityScore':
        comparison = a.securityScore - b.securityScore;
        break;
    }
    return sortOrder === 'asc' ? comparison : -comparison;
  });

  const uniqueClientTypes = [...new Set(nodes.map(n => n.clientType))];
  const uniqueNetworks = [...new Set(nodes.map(n => n.network))];

  if (loading) {
    return (
      <div className="flex items-center justify-center h-96">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-xdc-primary mx-auto"></div>
          <p className="text-gray-400 mt-4">Loading nodes...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="animate-fadeIn">
      <div className="flex justify-between items-center mb-8">
        <div>
          <h1 className="text-3xl font-bold text-white">Nodes</h1>
          <p className="text-gray-400 mt-1">{nodes.length} nodes registered</p>
        </div>
      </div>

      {/* Filters */}
      <div className="bg-xdc-card border border-xdc-border rounded-xl p-4 mb-6">
        <div className="flex flex-wrap gap-4">
          <div>
            <label className="block text-sm text-gray-400 mb-1">Status</label>
            <select
              value={filter.status}
              onChange={(e) => setFilter({ ...filter, status: e.target.value })}
              className="bg-xdc-dark border border-xdc-border rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:border-xdc-primary"
            >
              <option value="all">All Statuses</option>
              <option value="healthy">Healthy</option>
              <option value="syncing">Syncing</option>
              <option value="degraded">Degraded</option>
              <option value="offline">Offline</option>
            </select>
          </div>
          
          <div>
            <label className="block text-sm text-gray-400 mb-1">Client Type</label>
            <select
              value={filter.clientType}
              onChange={(e) => setFilter({ ...filter, clientType: e.target.value })}
              className="bg-xdc-dark border border-xdc-border rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:border-xdc-primary"
            >
              <option value="all">All Clients</option>
              {uniqueClientTypes.map(type => (
                <option key={type} value={type}>{type}</option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-sm text-gray-400 mb-1">Network</label>
            <select
              value={filter.network}
              onChange={(e) => setFilter({ ...filter, network: e.target.value })}
              className="bg-xdc-dark border border-xdc-border rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:border-xdc-primary"
            >
              <option value="all">All Networks</option>
              {uniqueNetworks.map(net => (
                <option key={net} value={net}>{net}</option>
              ))}
            </select>
          </div>

          <div className="ml-auto flex gap-2">
            <div>
              <label className="block text-sm text-gray-400 mb-1">Sort By</label>
              <select
                value={sortBy}
                onChange={(e) => setSortBy(e.target.value as any)}
                className="bg-xdc-dark border border-xdc-border rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:border-xdc-primary"
              >
                <option value="hostname">Hostname</option>
                <option value="blockHeight">Block Height</option>
                <option value="peerCount">Peer Count</option>
                <option value="securityScore">Security Score</option>
              </select>
            </div>
            <div>
              <label className="block text-sm text-gray-400 mb-1">Order</label>
              <button
                onClick={() => setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc')}
                className="bg-xdc-dark border border-xdc-border rounded-lg px-3 py-2 text-white text-sm hover:bg-xdc-border"
              >
                {sortOrder === 'asc' ? '↑ Asc' : '↓ Desc'}
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Node Grid */}
      {sortedNodes.length === 0 ? (
        <div className="text-center py-12">
          <p className="text-gray-400">No nodes match the current filters.</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
          {sortedNodes.map((node) => (
            <NodeCard key={node.id} node={node} />
          ))}
        </div>
      )}
    </div>
  );
}
