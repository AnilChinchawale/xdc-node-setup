'use client';

import { useState, useEffect } from 'react';
import { 
  Reward, 
  RewardSummary, 
  ClusterConfig, 
  StakeInfo,
  MissedBlock,
  SlashingEvent 
} from '@/lib/types';
import RewardChart from '@/components/RewardChart';
import ApyGauge from '@/components/ApyGauge';
import ClusterStatus from '@/components/ClusterStatus';
import StakeComposition from '@/components/StakeComposition';

export default function MasternodePage() {
  const [activeTab, setActiveTab] = useState<'overview' | 'cluster' | 'stake'>('overview');
  const [rewards, setRewards] = useState<Reward[]>([]);
  const [rewardSummary, setRewardSummary] = useState<RewardSummary | null>(null);
  const [apyData, setApyData] = useState<{ currentApy: number; expectedApy: number; difference: number } | null>(null);
  const [clusterConfig, setClusterConfig] = useState<ClusterConfig | null>(null);
  const [stakeInfo, setStakeInfo] = useState<StakeInfo | null>(null);
  const [loading, setLoading] = useState(true);
  const [days, setDays] = useState(30);

  useEffect(() => {
    fetchData();
  }, [days]);

  const fetchData = async () => {
    setLoading(true);
    try {
      // Fetch rewards
      const rewardsRes = await fetch(`/api/masternode/rewards?days=${days}`);
      if (rewardsRes.ok) {
        const rewardsData = await rewardsRes.json();
        setRewards(rewardsData.rewards || []);
        setRewardSummary(rewardsData.summary || null);
      }

      // Fetch APY
      const apyRes = await fetch(`/api/masternode/apy?days=${days}`);
      if (apyRes.ok) {
        const apyData = await apyRes.json();
        setApyData(apyData);
      }

      // Fetch cluster status
      const clusterRes = await fetch('/api/masternode/cluster');
      if (clusterRes.ok) {
        const clusterData = await clusterRes.json();
        setClusterConfig(clusterData);
      }

      // Fetch stake info
      const stakeRes = await fetch('/api/masternode/stake');
      if (stakeRes.ok) {
        const stakeData = await stakeRes.json();
        setStakeInfo(stakeData);
      }
    } catch (error) {
      console.error('Error fetching masternode data:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleCompoundToggle = async () => {
    try {
      await fetch('/api/masternode/stake', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          action: 'compound',
          enabled: !stakeInfo?.compoundSettings?.enabled,
          threshold: stakeInfo?.compoundSettings?.threshold || 1000
        })
      });
      fetchData();
    } catch (error) {
      console.error('Error toggling compound:', error);
    }
  };

  const handleFailover = async () => {
    if (!confirm('Are you sure you want to initiate a failover?')) return;
    try {
      await fetch('/api/masternode/cluster', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'failover' })
      });
      fetchData();
    } catch (error) {
      console.error('Error initiating failover:', error);
    }
  };

  if (loading) {
    return (
      <div className="p-8">
        <div className="animate-pulse">
          <div className="h-8 bg-xdc-border rounded w-64 mb-4"></div>
          <div className="h-4 bg-xdc-border rounded w-96 mb-8"></div>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
            {[...Array(4)].map((_, i) => (
              <div key={i} className="h-32 bg-xdc-border rounded-xl"></div>
            ))}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="p-8">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-white mb-2">Masternode Dashboard</h1>
        <p className="text-gray-400">
          Monitor rewards, manage clustering, and optimize your XDC masternode performance
        </p>
      </div>

      {/* Tabs */}
      <div className="flex gap-2 mb-6">
        {(['overview', 'cluster', 'stake'] as const).map((tab) => (
          <button
            key={tab}
            onClick={() => setActiveTab(tab)}
            className={`px-6 py-3 rounded-lg font-medium transition-colors ${
              activeTab === tab
                ? 'bg-xdc-primary text-white'
                : 'bg-xdc-card text-gray-400 hover:text-white'
            }`}
          >
            {tab.charAt(0).toUpperCase() + tab.slice(1)}
          </button>
        ))}
      </div>

      {/* Overview Tab */}
      {activeTab === 'overview' && (
        <div className="space-y-6">
          {/* Stats Cards */}
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
            <StatCard
              title="Total Rewards"
              value={`${(rewardSummary?.totalRewards || 0).toFixed(4)} XDC`}
              subtitle={`${rewardSummary?.rewardCount || 0} events`}
              icon="🎁"
              trend="up"
            />
            <StatCard
              title="Current APY"
              value={`${(apyData?.currentApy || 0).toFixed(2)}%`}
              subtitle={`Expected: ${(apyData?.expectedApy || 5.5).toFixed(1)}%`}
              icon="📈"
              trend={apyData && apyData.difference >= 0 ? 'up' : 'down'}
            />
            <StatCard
              title="Missed Blocks (7d)"
              value={rewardSummary?.missedCount?.toString() || '0'}
              subtitle="Network healthy"
              icon="⚠️"
              trend={rewardSummary && (rewardSummary.missedCount || 0) > 5 ? 'down' : 'up'}
            />
            <StatCard
              title="Cluster Status"
              value={clusterConfig?.nodes?.filter(n => n.status === 'online').length || 0}
              subtitle={`${clusterConfig?.nodes?.length || 0} total nodes`}
              icon="🖥️"
              trend="up"
            />
          </div>

          {/* APY Gauge and Reward Chart */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <div className="bg-xdc-card rounded-xl p-6">
              <h3 className="text-lg font-semibold text-white mb-4">APY Performance</h3>
              <ApyGauge 
                currentApy={apyData?.currentApy || 0} 
                expectedApy={apyData?.expectedApy || 5.5} 
              />
            </div>
            <div className="bg-xdc-card rounded-xl p-6">
              <div className="flex justify-between items-center mb-4">
                <h3 className="text-lg font-semibold text-white">Reward History</h3>
                <select
                  value={days}
                  onChange={(e) => setDays(parseInt(e.target.value))}
                  className="bg-xdc-background border border-xdc-border rounded px-3 py-1 text-sm text-gray-300"
                >
                  <option value={7}>7 days</option>
                  <option value={30}>30 days</option>
                  <option value={90}>90 days</option>
                </select>
              </div>
              <RewardChart rewards={rewards} />
            </div>
          </div>

          {/* Slashing Events */}
          <div className="bg-xdc-card rounded-xl p-6">
            <h3 className="text-lg font-semibold text-white mb-4">Slashing Events</h3>
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="text-gray-400 text-sm border-b border-xdc-border">
                    <th className="text-left py-3">Date</th>
                    <th className="text-left py-3">Block</th>
                    <th className="text-left py-3">Amount (XDC)</th>
                    <th className="text-left py-3">Reason</th>
                  </tr>
                </thead>
                <tbody>
                  {/* Mock data - would be populated from API */}
                  <tr className="text-gray-300">
                    <td colSpan={4} className="py-8 text-center text-gray-500">
                      No slashing events recorded ✓
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}

      {/* Cluster Tab */}
      {activeTab === 'cluster' && clusterConfig && (
        <div className="space-y-6">
          <div className="flex justify-between items-center">
            <div>
              <h2 className="text-xl font-semibold text-white">Cluster Configuration</h2>
              <p className="text-gray-400 text-sm">Cluster ID: {clusterConfig.clusterId || 'Not configured'}</p>
            </div>
            <div className="flex gap-2">
              <button
                onClick={handleFailover}
                className="px-4 py-2 bg-yellow-600 hover:bg-yellow-700 text-white rounded-lg font-medium transition-colors"
              >
                Initiate Failover
              </button>
              <button
                onClick={() => fetchData()}
                className="px-4 py-2 bg-xdc-primary hover:bg-xdc-secondary text-white rounded-lg font-medium transition-colors"
              >
                Refresh
              </button>
            </div>
          </div>

          <ClusterStatus config={clusterConfig} />
        </div>
      )}

      {/* Stake Tab */}
      {activeTab === 'stake' && stakeInfo && (
        <div className="space-y-6">
          <div className="flex justify-between items-center">
            <div>
              <h2 className="text-xl font-semibold text-white">Stake Management</h2>
              <p className="text-gray-400 text-sm">
                Total Stake: {(stakeInfo.totalStake || 0).toLocaleString()} XDC
              </p>
            </div>
            <div className="flex gap-2">
              <button
                onClick={handleCompoundToggle}
                className={`px-4 py-2 rounded-lg font-medium transition-colors ${
                  stakeInfo.compoundSettings?.enabled
                    ? 'bg-green-600 hover:bg-green-700 text-white'
                    : 'bg-xdc-border hover:bg-gray-600 text-gray-300'
                }`}
              >
                {stakeInfo.compoundSettings?.enabled ? 'Auto-Compound: ON' : 'Auto-Compound: OFF'}
              </button>
            </div>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <div className="bg-xdc-card rounded-xl p-6">
              <h3 className="text-lg font-semibold text-white mb-4">Stake Composition</h3>
              <StakeComposition delegations={stakeInfo.delegations || []} />
            </div>

            <div className="bg-xdc-card rounded-xl p-6">
              <h3 className="text-lg font-semibold text-white mb-4">Compound Settings</h3>
              <div className="space-y-4">
                <div className="flex justify-between">
                  <span className="text-gray-400">Status</span>
                  <span className={stakeInfo.compoundSettings?.enabled ? 'text-green-400' : 'text-gray-300'}>
                    {stakeInfo.compoundSettings?.enabled ? 'Enabled' : 'Disabled'}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400">Threshold</span>
                  <span className="text-white">
                    {(stakeInfo.compoundSettings?.threshold || 1000).toLocaleString()} XDC
                  </span>
                </div>
                {stakeInfo.compoundSettings?.lastCompound && (
                  <div className="flex justify-between">
                    <span className="text-gray-400">Last Compound</span>
                    <span className="text-white">
                      {new Date(stakeInfo.compoundSettings.lastCompound).toLocaleDateString()}
                    </span>
                  </div>
                )}
                <div className="flex justify-between">
                  <span className="text-gray-400">Effective APY</span>
                  <span className="text-green-400">
                    {(stakeInfo.effectiveApy || 0).toFixed(2)}%
                  </span>
                </div>
              </div>
            </div>
          </div>

          {/* Delegations Table */}
          <div className="bg-xdc-card rounded-xl p-6">
            <h3 className="text-lg font-semibold text-white mb-4">Delegations</h3>
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="text-gray-400 text-sm border-b border-xdc-border">
                    <th className="text-left py-3">Address</th>
                    <th className="text-left py-3">Amount (XDC)</th>
                    <th className="text-left py-3">Status</th>
                    <th className="text-left py-3">Since</th>
                  </tr>
                </thead>
                <tbody>
                  {stakeInfo.delegations?.map((delegation) => (
                    <tr key={delegation.id} className="text-gray-300 border-b border-xdc-border/50">
                      <td className="py-3 font-mono text-sm">
                        {delegation.delegatorAddress.slice(0, 20)}...
                      </td>
                      <td className="py-3">{delegation.amount.toLocaleString()}</td>
                      <td className="py-3">
                        <span className={`px-2 py-1 rounded text-xs ${
                          delegation.status === 'active' 
                            ? 'bg-green-500/20 text-green-400' 
                            : 'bg-gray-500/20 text-gray-400'
                        }`}>
                          {delegation.status}
                        </span>
                      </td>
                      <td className="py-3">
                        {new Date(delegation.timestamp).toLocaleDateString()}
                      </td>
                    </tr>
                  )) || (
                    <tr className="text-gray-300">
                      <td colSpan={4} className="py-8 text-center text-gray-500">
                        No active delegations
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

// Stat Card Component
function StatCard({
  title,
  value,
  subtitle,
  icon,
  trend
}: {
  title: string;
  value: string;
  subtitle: string;
  icon: string;
  trend: 'up' | 'down' | 'neutral';
}) {
  const trendColors = {
    up: 'text-green-400',
    down: 'text-red-400',
    neutral: 'text-gray-400'
  };

  const trendIcons = {
    up: '↑',
    down: '↓',
    neutral: '→'
  };

  return (
    <div className="bg-xdc-card rounded-xl p-6">
      <div className="flex justify-between items-start mb-4">
        <span className="text-2xl">{icon}</span>
        <span className={`text-sm ${trendColors[trend]}`}>
          {trendIcons[trend]}
        </span>
      </div>
      <h3 className="text-gray-400 text-sm mb-1">{title}</h3>
      <p className="text-2xl font-bold text-white mb-1">{value}</p>
      <p className="text-xs text-gray-500">{subtitle}</p>
    </div>
  );
}
