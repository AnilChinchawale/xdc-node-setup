import { NextResponse } from 'next/server';
import { execSync } from 'child_process';
import { Reward, RewardSummary } from '@/lib/types';

// Get reward data
export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url);
    const days = parseInt(searchParams.get('days') || '30');
    const type = searchParams.get('type') || 'all';

    let rewards: Reward[] = [];
    let summary: RewardSummary = {
      totalRewards: 0,
      rewardCount: 0,
      avgReward: 0,
      missedCount: 0
    };

    try {
      // Query rewards from database via script
      const output = execSync(
        `/opt/xdc-node/scripts/masternode-rewards.sh --history --days ${days} --export json`,
        { encoding: 'utf-8', timeout: 30000 }
      );
      
      // Parse JSON output
      const lines = output.trim().split('\n');
      const jsonLine = lines.find(line => line.startsWith('[') || line.startsWith('{'));
      if (jsonLine) {
        rewards = JSON.parse(jsonLine);
      }
    } catch (error) {
      console.error('Failed to fetch rewards:', error);
      // Return mock data for development
      rewards = generateMockRewards(days);
    }

    // Calculate summary
    if (rewards.length > 0) {
      summary.totalRewards = rewards.reduce((sum, r) => sum + r.amount, 0);
      summary.rewardCount = rewards.length;
      summary.avgReward = summary.totalRewards / rewards.length;
    }

    // Filter by type if specified
    if (type !== 'all') {
      rewards = rewards.filter(r => r.rewardType === type);
    }

    return NextResponse.json({
      rewards,
      summary,
      period: days,
      generatedAt: new Date().toISOString()
    });
  } catch (error) {
    console.error('Error fetching rewards:', error);
    return NextResponse.json(
      { error: 'Failed to fetch reward data' },
      { status: 500 }
    );
  }
}

// Post new reward or trigger actions
export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { action } = body;

    switch (action) {
      case 'init':
        // Initialize rewards database
        execSync('/opt/xdc-node/scripts/masternode-rewards.sh --init-db', {
          encoding: 'utf-8',
          timeout: 10000
        });
        return NextResponse.json({ success: true, message: 'Database initialized' });

      case 'export':
        const { format = 'json' } = body;
        const output = execSync(
          `/opt/xdc-node/scripts/masternode-rewards.sh --export ${format}`,
          { encoding: 'utf-8', timeout: 30000 }
        );
        return NextResponse.json({ 
          success: true, 
          file: output.trim(),
          format 
        });

      default:
        return NextResponse.json(
          { error: 'Unknown action' },
          { status: 400 }
        );
    }
  } catch (error) {
    console.error('Error processing reward action:', error);
    return NextResponse.json(
      { error: 'Failed to process action' },
      { status: 500 }
    );
  }
}

// Generate mock rewards for development
function generateMockRewards(days: number): Reward[] {
  const rewards: Reward[] = [];
  const now = new Date();
  
  for (let i = 0; i < days * 24; i++) {
    const timestamp = new Date(now.getTime() - i * 3600000);
    if (Math.random() > 0.3) { // 70% chance of reward per hour
      rewards.push({
        id: i,
        timestamp: timestamp.toISOString(),
        blockNumber: 50000000 + i * 1800,
        amount: 0.8 + Math.random() * 0.4,
        rewardType: 'block',
        masternodeAddress: 'xdc' + '0'.repeat(39)
      });
    }
  }
  
  return rewards;
}
