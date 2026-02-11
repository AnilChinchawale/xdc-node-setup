'use client';

import { useEffect, useState } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Progress } from '@/components/ui/progress';
import { Badge } from '@/components/ui/badge';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { 
  Clock, 
  Users, 
  Shield, 
  AlertTriangle,
  CheckCircle,
  RotateCw,
  Vote
} from 'lucide-react';

interface ConsensusData {
  timestamp: string;
  consensus: {
    blockNumber: number;
    epoch: number;
    round: number;
    epochProgress: number;
    blocksToNextEpoch: number;
    secondsToNextEpoch?: number;
  };
  masternodes: {
    count: number;
    list: string[];
  };
  penalties: {
    count: number;
    list: Array<{
      address: string;
      reason: string;
      timestamp: string;
    }>;
  };
  votes?: Array<{
    block: number;
    hash: string;
    signer: string;
    voteCount: number;
  }>;
}

export default function ConsensusPage() {
  const [data, setData] = useState<ConsensusData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchData = async () => {
    try {
      const response = await fetch('/api/consensus');
      if (!response.ok) throw new Error('Failed to fetch consensus data');
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
    const interval = setInterval(fetchData, 5000);
    return () => clearInterval(interval);
  }, []);

  const formatTime = (seconds?: number) => {
    if (!seconds) return 'Calculating...';
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}m ${secs}s`;
  };

  const getStatusColor = (progress: number) => {
    if (progress < 30) return 'bg-green-500';
    if (progress < 70) return 'bg-yellow-500';
    return 'bg-blue-500';
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-full">
        <RotateCw className="w-8 h-8 animate-spin text-primary" />
      </div>
    );
  }

  if (error || !data) {
    return (
      <Alert variant="destructive">
        <AlertTriangle className="h-4 w-4" />
        <AlertTitle>Error</AlertTitle>
        <AlertDescription>{error || 'Failed to load consensus data'}</AlertDescription>
      </Alert>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">XDPoS Consensus</h1>
        <p className="text-muted-foreground">
          Real-time XDPoS v2 consensus monitoring and validator tracking
        </p>
      </div>

      {/* Epoch Status */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Current Epoch</CardTitle>
            <Clock className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{data.consensus.epoch}</div>
            <p className="text-xs text-muted-foreground">
              Block {data.consensus.blockNumber.toLocaleString()}
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Round</CardTitle>
            <RotateCw className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{data.consensus.round}</div>
            <p className="text-xs text-muted-foreground">
              of 900 blocks
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Active Validators</CardTitle>
            <Users className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{data.masternodes.count}</div>
            <p className="text-xs text-muted-foreground">
              Masternodes
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Penalties</CardTitle>
            <Shield className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className={`text-2xl font-bold ${data.penalties.count > 0 ? 'text-red-500' : 'text-green-500'}`}>
              {data.penalties.count}
            </div>
            <p className="text-xs text-muted-foreground">
              Active penalties
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Epoch Progress */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Clock className="h-5 w-5" />
            Epoch Progress
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex justify-between text-sm">
            <span className="text-muted-foreground">Progress</span>
            <span className="font-medium">{data.consensus.epochProgress}%</span>
          </div>
          <Progress 
            value={data.consensus.epochProgress} 
            className="h-3"
          />
          <div className="flex justify-between text-sm">
            <span className="text-muted-foreground">
              Blocks to next epoch: {data.consensus.blocksToNextEpoch}
            </span>
            <span className="font-medium">
              ~{formatTime(data.consensus.blocksToNextEpoch * 2)}
            </span>
          </div>
        </CardContent>
      </Card>

      <div className="grid gap-4 md:grid-cols-2">
        {/* Penalty Alerts */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <AlertTriangle className="h-5 w-5" />
              Penalty Alerts
            </CardTitle>
          </CardHeader>
          <CardContent>
            {data.penalties.count === 0 ? (
              <div className="flex items-center gap-2 text-green-600">
                <CheckCircle className="h-5 w-5" />
                <span>No active penalties</span>
              </div>
            ) : (
              <div className="space-y-2">
                {data.penalties.list.slice(0, 5).map((penalty, idx) => (
                  <Alert key={idx} variant="destructive" className="py-2">
                    <AlertTriangle className="h-4 w-4" />
                    <AlertTitle className="text-sm">{penalty.address.slice(0, 20)}...</AlertTitle>
                    <AlertDescription className="text-xs">
                      Reason: {penalty.reason || 'Unknown'}
                    </AlertDescription>
                  </Alert>
                ))}
              </div>
            )}
          </CardContent>
        </Card>

        {/* Vote Monitoring */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Vote className="h-5 w-5" />
              Recent Vote Counts
            </CardTitle>
          </CardHeader>
          <CardContent>
            {data.votes && data.votes.length > 0 ? (
              <div className="space-y-2">
                {data.votes.slice(0, 5).map((vote, idx) => (
                  <div key={idx} className="flex items-center justify-between py-1 border-b last:border-0">
                    <div className="text-sm">
                      <span className="font-medium">Block {vote.block}</span>
                      <span className="text-muted-foreground ml-2">{vote.hash.slice(0, 12)}...</span>
                    </div>
                    <Badge variant={vote.voteCount > 50 ? 'default' : 'secondary'}>
                      {vote.voteCount} votes
                    </Badge>
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-muted-foreground text-sm">Vote data unavailable</p>
            )}
          </CardContent>
        </Card>
      </div>

      {/* Masternode Rotation */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <RotateCw className="h-5 w-5" />
            Masternode Rotation Schedule
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-2">
            {data.masternodes.list.slice(0, 10).map((mn, idx) => (
              <div key={idx} className="flex items-center justify-between py-2 border-b last:border-0">
                <div className="flex items-center gap-3">
                  <Badge variant={idx === 0 ? 'default' : 'outline'} className="w-16 justify-center">
                    {idx === 0 ? 'Current' : `+${idx}`}
                  </Badge>
                  <span className="font-mono text-sm">{mn}</span>
                </div>
                {idx === 0 && (
                  <CheckCircle className="h-4 w-4 text-green-500" />
                )}
              </div>
            ))}
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
