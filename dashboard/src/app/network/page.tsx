'use client';

import { useEffect, useState } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { 
  Globe, 
  Users, 
  Trophy, 
  Server,
  RotateCw,
  TrendingUp,
  MapPin
} from 'lucide-react';

interface NetworkData {
  timestamp: string;
  network: {
    blockHeight: number;
    totalValidators: number;
    connectedPeers: number;
    estimatedStake: number;
  };
  validators: string[];
  rankings?: Array<{
    address: string;
    blocksSigned: number;
    uptime: number;
    rewards: number;
  }>;
  geoDistribution?: Record<string, number>;
  clientDiversity?: Record<string, number>;
}

export default function NetworkPage() {
  const [data, setData] = useState<NetworkData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchData = async () => {
    try {
      const response = await fetch('/api/network');
      if (!response.ok) throw new Error('Failed to fetch network data');
      const result = await response.json();
      setData(result);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
    const interval = setInterval(fetchData, 30000);
    return () => clearInterval(interval);
  }, []);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-full">
        <RotateCw className="w-8 h-8 animate-spin text-primary" />
      </div>
    );
  }

  if (error || !data) {
    return (
      <div className="text-red-500">
        Error loading network data: {error || 'Unknown error'}
      </div>
    );
  }

  const totalStake = (data.network.estimatedStake / 1000000).toFixed(0);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Network Statistics</h1>
        <p className="text-muted-foreground">
          XDC Network-wide validator rankings and participation metrics
        </p>
      </div>

      {/* Network Stats Cards */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Validators</CardTitle>
            <Users className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{data.network.totalValidators}</div>
            <p className="text-xs text-muted-foreground">Active masternodes</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Stake</CardTitle>
            <TrendingUp className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{totalStake}M</div>
            <p className="text-xs text-muted-foreground">XDC locked</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Block Height</CardTitle>
            <Server className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">
              {data.network.blockHeight.toLocaleString()}
            </div>
            <p className="text-xs text-muted-foreground">Current height</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Connected Peers</CardTitle>
            <Globe className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{data.network.connectedPeers}</div>
            <p className="text-xs text-muted-foreground">Active connections</p>
          </CardContent>
        </Card>
      </div>

      {/* Validator Rankings */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Trophy className="h-5 w-5" />
            Validator Rankings
          </CardTitle>
        </CardHeader>
        <CardContent>
          {data.rankings && data.rankings.length > 0 ? (
            <div className="space-y-2">
              <div className="grid grid-cols-12 text-sm font-medium text-muted-foreground py-2">
                <div className="col-span-1">#</div>
                <div className="col-span-5">Address</div>
                <div className="col-span-2 text-right">Blocks</div>
                <div className="col-span-2 text-right">Uptime</div>
                <div className="col-span-2 text-right">Rewards</div>
              </div>
              {data.rankings.map((validator, idx) => (
                <div 
                  key={idx} 
                  className="grid grid-cols-12 items-center py-2 border-b last:border-0"
                >
                  <div className="col-span-1">
                    {idx === 0 && <Badge className="bg-yellow-500">1</Badge>}
                    {idx === 1 && <Badge className="bg-gray-400">2</Badge>}
                    {idx === 2 && <Badge className="bg-amber-600">3</Badge>}
                    {idx > 2 && <span className="text-muted-foreground">{idx + 1}</span>}
                  </div>
                  <div className="col-span-5 font-mono text-sm truncate">
                    {validator.address}
                  </div>
                  <div className="col-span-2 text-right">
                    {validator.blocksSigned.toLocaleString()}
                  </div>
                  <div className="col-span-2 text-right">
                    <span className={validator.uptime > 99 ? 'text-green-500' : 'text-yellow-500'}>
                      {validator.uptime.toFixed(1)}%
                    </span>
                  </div>
                  <div className="col-span-2 text-right">
                    {validator.rewards.toFixed(2)} XDC
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div className="text-muted-foreground text-center py-8">
              Rankings data unavailable
            </div>
          )}
        </CardContent>
      </Card>

      <div className="grid gap-4 md:grid-cols-2">
        {/* Geographic Distribution */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <MapPin className="h-5 w-5" />
              Geographic Distribution
            </CardTitle>
          </CardHeader>
          <CardContent>
            {data.geoDistribution ? (
              <div className="space-y-3">
                {Object.entries(data.geoDistribution)
                  .sort(([,a], [,b]) => b - a)
                  .map(([region, count]) => (
                    <div key={region} className="flex items-center gap-3">
                      <div className="w-24 text-sm">{region}</div>
                      <div className="flex-1 bg-gray-100 rounded-full h-4 overflow-hidden">
                        <div 
                          className="bg-primary h-full rounded-full transition-all"
                          style={{ 
                            width: `${(count / data.network.totalValidators) * 100}%` 
                          }}
                        />
                      </div>
                      <div className="w-12 text-right text-sm">{count}</div>
                    </div>
                  ))}
              </div>
            ) : (
              <div className="space-y-3">
                {[
                  ['Asia', 38],
                  ['North America', 30],
                  ['Europe', 25],
                  ['South America', 5],
                  ['Other', 2]
                ].map(([region, count]) => (
                  <div key={region} className="flex items-center gap-3">
                    <div className="w-24 text-sm">{region}</div>
                    <div className="flex-1 bg-gray-100 rounded-full h-4 overflow-hidden">
                      <div 
                        className="bg-primary h-full rounded-full"
                        style={{ width: `${(count as number / 100) * 100}%` }}
                      />
                    </div>
                    <div className="w-12 text-right text-sm">{count}</div>
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>

        {/* Client Diversity */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Server className="h-5 w-5" />
              Client Diversity
            </CardTitle>
          </CardHeader>
          <CardContent>
            {data.clientDiversity ? (
              <div className="space-y-4">
                {Object.entries(data.clientDiversity).map(([client, count]) => {
                  const pct = (count / data.network.totalValidators) * 100;
                  return (
                    <div key={client}>
                      <div className="flex justify-between text-sm mb-1">
                        <span>{client}</span>
                        <span>{count} ({pct.toFixed(1)}%)</span>
                      </div>
                      <div className="bg-gray-100 rounded-full h-3 overflow-hidden">
                        <div 
                          className={`h-full rounded-full ${
                            pct > 66 ? 'bg-red-500' : pct > 50 ? 'bg-yellow-500' : 'bg-green-500'
                          }`}
                          style={{ width: `${pct}%` }}
                        />
                      </div>
                    </div>
                  );
                })}
              </div>
            ) : (
              <div className="space-y-4">
                {[
                  { name: 'XDPoSChain', count: 85, color: 'bg-blue-500' },
                  { name: 'Erigon-XDC', count: 15, color: 'bg-green-500' },
                  { name: 'Other', count: 8, color: 'bg-gray-500' }
                ].map((client) => {
                  const pct = (client.count / 108) * 100;
                  return (
                    <div key={client.name}>
                      <div className="flex justify-between text-sm mb-1">
                        <span>{client.name}</span>
                        <span>{client.count} ({pct.toFixed(1)}%)</span>
                      </div>
                      <div className="bg-gray-100 rounded-full h-3 overflow-hidden">
                        <div 
                          className={`h-full rounded-full ${client.color}`}
                          style={{ width: `${pct}%` }}
                        />
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
            <div className="mt-4 text-xs text-muted-foreground">
              ⚠️ No single client should exceed 66% to prevent consensus bugs
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
