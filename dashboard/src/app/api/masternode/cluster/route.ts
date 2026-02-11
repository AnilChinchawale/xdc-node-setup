import { NextResponse } from 'next/server';
import { execSync } from 'child_process';
import { ClusterConfig, ClusterNode } from '@/lib/types';

// Get cluster status
export async function GET(request: Request) {
  try {
    let config: ClusterConfig = {
      clusterId: '',
      nodes: [],
      primaryNode: '',
      failoverEnabled: true,
      failoverThreshold: 3
    };

    try {
      // Get cluster status from script
      const output = execSync(
        '/opt/xdc-node/scripts/masternode-cluster.sh status',
        { encoding: 'utf-8', timeout: 30000 }
      );
      
      // Parse cluster info from output
      config = parseClusterOutput(output);
    } catch (error) {
      console.error('Failed to get cluster status:', error);
      // Return mock data for development
      config = generateMockCluster();
    }

    return NextResponse.json({
      ...config,
      generatedAt: new Date().toISOString()
    });
  } catch (error) {
    console.error('Error fetching cluster status:', error);
    return NextResponse.json(
      { error: 'Failed to fetch cluster status' },
      { status: 500 }
    );
  }
}

// Manage cluster operations
export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { action, node, force = false } = body;

    switch (action) {
      case 'init':
        const { clusterId } = body;
        execSync(
          `/opt/xdc-node/scripts/masternode-cluster.sh init${clusterId ? ` --cluster-id ${clusterId}` : ''}`,
          { encoding: 'utf-8', timeout: 30000 }
        );
        return NextResponse.json({ success: true, message: 'Cluster initialized' });

      case 'add-node':
        if (!node) {
          return NextResponse.json({ error: 'Node address required' }, { status: 400 });
        }
        execSync(
          `/opt/xdc-node/scripts/masternode-cluster.sh add-node ${node}`,
          { encoding: 'utf-8', timeout: 60000 }
        );
        return NextResponse.json({ success: true, message: `Node ${node} added` });

      case 'remove-node':
        if (!node) {
          return NextResponse.json({ error: 'Node address required' }, { status: 400 });
        }
        execSync(
          `/opt/xdc-node/scripts/masternode-cluster.sh remove-node ${node}${force ? ' --force' : ''}`,
          { encoding: 'utf-8', timeout: 30000 }
        );
        return NextResponse.json({ success: true, message: `Node ${node} removed` });

      case 'failover':
        execSync(
          `/opt/xdc-node/scripts/masternode-cluster.sh failover ${node || ''}${force ? ' --force' : ''}`,
          { encoding: 'utf-8', timeout: 60000 }
        );
        return NextResponse.json({ success: true, message: 'Failover initiated' });

      case 'promote':
        if (!node) {
          return NextResponse.json({ error: 'Node address required' }, { status: 400 });
        }
        execSync(
          `/opt/xdc-node/scripts/masternode-cluster.sh promote ${node}`,
          { encoding: 'utf-8', timeout: 30000 }
        );
        return NextResponse.json({ success: true, message: `Node ${node} promoted to primary` });

      case 'sync-keys':
        execSync(
          '/opt/xdc-node/scripts/masternode-cluster.sh sync-keys',
          { encoding: 'utf-8', timeout: 60000 }
        );
        return NextResponse.json({ success: true, message: 'Keys synced to all nodes' });

      default:
        return NextResponse.json({ error: 'Unknown action' }, { status: 400 });
    }
  } catch (error) {
    console.error('Error managing cluster:', error);
    return NextResponse.json(
      { error: 'Failed to execute cluster action' },
      { status: 500 }
    );
  }
}

// Parse cluster script output
function parseClusterOutput(output: string): ClusterConfig {
  const config: ClusterConfig = {
    clusterId: '',
    nodes: [],
    primaryNode: '',
    failoverEnabled: true,
    failoverThreshold: 3
  };

  const lines = output.split('\n');
  let inNodesSection = false;

  for (const line of lines) {
    // Parse cluster ID
    const clusterMatch = line.match(/Cluster ID:\s+(\S+)/);
    if (clusterMatch) {
      config.clusterId = clusterMatch[1];
    }

    // Parse primary node
    const primaryMatch = line.match(/Primary Node:\s+(\S+)/);
    if (primaryMatch) {
      config.primaryNode = primaryMatch[1];
    }

    // Parse failover settings
    const thresholdMatch = line.match(/Failover Threshold:\s+(\d+)/);
    if (thresholdMatch) {
      config.failoverThreshold = parseInt(thresholdMatch[1]);
    }

    // Check for nodes section
    if (line.includes('Cluster Nodes:')) {
      inNodesSection = true;
      continue;
    }

    // Parse node lines
    if (inNodesSection && line.includes('xdc')) {
      const nodeMatch = line.match(/([\d.]+)\s+\[([\w]+)\]\s+([✓✗])/);
      if (nodeMatch) {
        const host = nodeMatch[1];
        const role = nodeMatch[2] as 'primary' | 'backup';
        const status = nodeMatch[3] === '✓' ? 'online' : 'offline';
        
        config.nodes.push({
          host,
          role,
          status,
          ip: host
        });
      }
    }
  }

  return config;
}

// Generate mock cluster for development
function generateMockCluster(): ClusterConfig {
  return {
    clusterId: 'xdc-mn-test-001',
    nodes: [
      {
        host: '192.168.1.10',
        ip: '192.168.1.10',
        role: 'primary',
        status: 'online',
        xdcStatus: 'running',
        syncStatus: 'synced',
        peers: 25
      },
      {
        host: '192.168.1.11',
        ip: '192.168.1.11',
        role: 'backup',
        status: 'online',
        xdcStatus: 'running',
        syncStatus: 'synced',
        peers: 23
      },
      {
        host: '192.168.1.12',
        ip: '192.168.1.12',
        role: 'backup',
        status: 'offline',
        xdcStatus: 'stopped',
        syncStatus: 'unknown',
        peers: 0
      }
    ],
    primaryNode: '192.168.1.10',
    failoverEnabled: true,
    failoverThreshold: 3,
    leader: '192.168.1.10'
  };
}
