import { NextResponse } from 'next/server';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

export async function GET() {
  try {
    // Run the network stats script
    const { stdout } = await execAsync(
      '/root/.openclaw/workspace/XDC-Node-Setup/scripts/network-stats.sh --all --json',
      { timeout: 15000 }
    );
    
    const data = JSON.parse(stdout);
    
    // Add mock rankings data
    data.rankings = [
      { address: 'xdcf2e2468f0e2287472b0c2e0a32d6b93b85289d1b', blocksSigned: 895, uptime: 99.9, rewards: 52.34 },
      { address: 'xdc1234567890123456789012345678901234567890', blocksSigned: 892, uptime: 99.8, rewards: 52.12 },
      { address: 'xdcabcdefabcdefabcdefabcdefabcdefabcdefabcd', blocksSigned: 890, uptime: 99.7, rewards: 51.98 },
      { address: 'xdc1111111111111111111111111111111111111111', blocksSigned: 888, uptime: 99.6, rewards: 51.76 },
      { address: 'xdc2222222222222222222222222222222222222222', blocksSigned: 885, uptime: 99.5, rewards: 51.54 }
    ];
    
    // Add mock geographic distribution
    data.geoDistribution = {
      'Asia': 38,
      'North America': 30,
      'Europe': 25,
      'South America': 5,
      'Oceania': 3,
      'Africa': 2
    };
    
    // Add mock client diversity
    data.clientDiversity = {
      'XDPoSChain': 85,
      'Erigon-XDC': 15,
      'Other': 8
    };
    
    return NextResponse.json(data);
  } catch (error) {
    console.error('Error fetching network data:', error);
    
    // Return mock data if script fails
    return NextResponse.json({
      timestamp: new Date().toISOString(),
      network: {
        blockHeight: 99222839,
        totalValidators: 108,
        connectedPeers: 25,
        estimatedStake: 1080000000
      },
      validators: [],
      rankings: [
        { address: 'xdcf2e2468f0e2287472b0c2e0a32d6b93b85289d1b', blocksSigned: 895, uptime: 99.9, rewards: 52.34 },
        { address: 'xdc1234567890123456789012345678901234567890', blocksSigned: 892, uptime: 99.8, rewards: 52.12 }
      ],
      geoDistribution: {
        'Asia': 38,
        'North America': 30,
        'Europe': 25,
        'South America': 5,
        'Other': 2
      },
      clientDiversity: {
        'XDPoSChain': 85,
        'Erigon-XDC': 15
      }
    });
  }
}
