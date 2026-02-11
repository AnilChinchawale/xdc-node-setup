'use client';

import { ClusterConfig, ClusterNode } from '@/lib/types';

interface ClusterStatusProps {
  config: ClusterConfig;
}

export default function ClusterStatus({ config }: ClusterStatusProps) {
  const onlineNodes = config.nodes?.filter(n => n.status === 'online').length || 0;
  const totalNodes = config.nodes?.length || 0;
  const quorum = Math.floor(totalNodes / 2) + 1;

  return (
    <div className="space-y-6">
      {/* Cluster Overview */}
      <div className="bg-xdc-card rounded-xl p-6">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
          <div>
            <p className="text-gray-400 text-sm mb-1">Total Nodes</p>
            <p className="text-2xl font-bold text-white">{totalNodes}</p>
          </div>
          <div>
            <p className="text-gray-400 text-sm mb-1">Online</p>
            <p className="text-2xl font-bold text-green-400">{onlineNodes}</p>
          </div>
          <div>
            <p className="text-gray-400 text-sm mb-1">Quorum</p>
            <p className="text-2xl font-bold text-white">{quorum}</p>
          </div>
          <div>
            <p className="text-gray-400 text-sm mb-1">Failover</p>
            <p className={`text-2xl font-bold ${config.failoverEnabled ? 'text-green-400' : 'text-gray-400'}`}>
              {config.failoverEnabled ? 'Enabled' : 'Disabled'}
            </p>
          </div>
        </div>
      </div>

      {/* Nodes Table */}
      <div className="bg-xdc-card rounded-xl p-6">
        <h3 className="text-lg font-semibold text-white mb-4">Cluster Nodes</h3>
        
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="text-gray-400 text-sm border-b border-xdc-border">
                <th className="text-left py-3">Host</th>
                <th className="text-left py-3">Role</th>
                <th className="text-left py-3">Status</th>
                <th className="text-left py-3">XDC Node</th>
                <th className="text-left py-3">Sync</th>
                <th className="text-left py-3">Peers</th>
                <th className="text-left py-3">Actions</th>
              </tr>
            </thead>
            <tbody>
              {config.nodes?.map((node, index) => (
                <tr key={index} className="text-gray-300 border-b border-xdc-border/50">
                  <td className="py-3">
                    <div>
                      <div className="font-mono text-sm">{node.host}</div>
                      {node.hostname && node.hostname !== node.host && (
                        <div className="text-xs text-gray-500">{node.hostname}</div>
                      )}
                    </div>
                  </td>
                  <td className="py-3">
                    <span className={`px-2 py-1 rounded text-xs font-medium ${
                      node.role === 'primary'
                        ? 'bg-yellow-500/20 text-yellow-400'
                        : 'bg-blue-500/20 text-blue-400'
                    }`}>
                      {node.role === 'primary' ? '⭐ Primary' : 'Backup'}
                    </span>
                  </td>
                  <td className="py-3">
                    <span className={`inline-flex items-center gap-1 ${
                      node.status === 'online' ? 'text-green-400' : 'text-red-400'
                    }`}>
                      <span className={`w-2 h-2 rounded-full ${
                        node.status === 'online' ? 'bg-green-400' : 'bg-red-400'
                      }`} />
                      {node.status === 'online' ? 'Online' : 'Offline'}
                    </span>
                  </td>
                  <td className="py-3">
                    <span className={
                      node.xdcStatus === 'running' ? 'text-green-400' : 'text-gray-400'
                    }>
                      {node.xdcStatus || 'Unknown'}
                    </span>
                  </td>
                  <td className="py-3">
                    <span className={
                      node.syncStatus === 'synced' ? 'text-green-400' : 'text-yellow-400'
                    }>
                      {node.syncStatus || 'Unknown'}
                    </span>
                  </td>
                  <td className="py-3">{node.peers || 0}</td>
                  <td className="py-3">
                    <div className="flex gap-2">
                      {node.role !== 'primary' && node.status === 'online' && (
                        <button
                          className="px-3 py-1 bg-xdc-primary hover:bg-xdc-secondary text-white text-xs rounded transition-colors"
                          onClick={() => {
                            if (confirm(`Promote ${node.host} to primary?`)) {
                              // Trigger promotion
                            }
                          }}
                        >
                          Promote
                        </button>
                      )}
                      <button
                        className="px-3 py-1 bg-xdc-border hover:bg-gray-600 text-gray-300 text-xs rounded transition-colors"
                        onClick={() => {
                          // Health check
                        }}
                      >
                        Health Check
                      </button>
                    </div>
                  </td>
                </tr>
              )) || (
                <tr>
                  <td colSpan={7} className="py-8 text-center text-gray-500">
                    No nodes configured. Add nodes to create a cluster.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Failover Settings */}
      <div className="bg-xdc-card rounded-xl p-6">
        <h3 className="text-lg font-semibold text-white mb-4">Failover Configuration</h3>
        
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div>
            <label className="block text-gray-400 text-sm mb-2">Failover Threshold</label>
            <div className="flex items-center gap-3">
              <input
                type="number"
                value={config.failoverThreshold}
                className="bg-xdc-background border border-xdc-border rounded px-3 py-2 text-white w-24"
                readOnly
              />
              <span className="text-gray-500 text-sm">failed checks</span>
            </div>
          </div>
          
          <div>
            <label className="block text-gray-400 text-sm mb-2">Current Leader</label>
            <div className="text-white font-mono">
              {config.leader || config.primaryNode || 'None'}
            </div>
          </div>
          
          <div>
            <label className="block text-gray-400 text-sm mb-2">Last Failover</label>
            <div className="text-gray-300">
              {config.lastFailover 
                ? new Date(config.lastFailover).toLocaleString() 
                : 'Never'
              }
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
