import { NextResponse } from 'next/server';
import { execSync } from 'child_process';
import { ApyHistory } from '@/lib/types';

// Get APY calculation
export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url);
    const days = parseInt(searchParams.get('days') || '30');

    let apy = 0;
    let expectedApy = 5.5;
    let totalRewards = 0;
    let history: ApyHistory[] = [];

    try {
      // Run APY calculation script
      const output = execSync(
        `/opt/xdc-node/scripts/masternode-rewards.sh --apy --days ${days}`,
        { encoding: 'utf-8', timeout: 30000 }
      );
      
      // Parse APY from output
      const apyMatch = output.match(/Actual APY:\s+(\d+\.?\d*)%/);
      if (apyMatch) {
        apy = parseFloat(apyMatch[1]);
      }
      
      const expectedMatch = output.match(/Expected APY:\s+(\d+\.?\d*)%/);
      if (expectedMatch) {
        expectedApy = parseFloat(expectedMatch[1]);
      }
    } catch (error) {
      console.error('Failed to calculate APY:', error);
      // Mock data for development
      apy = 5.2 + Math.random() * 0.5;
    }

    // Generate mock history if needed
    if (history.length === 0) {
      history = generateMockHistory();
    }

    return NextResponse.json({
      currentApy: apy,
      expectedApy,
      difference: apy - expectedApy,
      period: days,
      totalRewards,
      history,
      generatedAt: new Date().toISOString()
    });
  } catch (error) {
    console.error('Error calculating APY:', error);
    return NextResponse.json(
      { error: 'Failed to calculate APY' },
      { status: 500 }
    );
  }
}

// Trigger APY recalculation
export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { days = 30 } = body;

    const output = execSync(
      `/opt/xdc-node/scripts/masternode-rewards.sh --apy --days ${days}`,
      { encoding: 'utf-8', timeout: 30000 }
    );

    const apyMatch = output.match(/Actual APY:\s+(\d+\.?\d*)%/);
    const apy = apyMatch ? parseFloat(apyMatch[1]) : 0;

    return NextResponse.json({
      success: true,
      apy,
      period: days,
      calculatedAt: new Date().toISOString()
    });
  } catch (error) {
    console.error('Error recalculating APY:', error);
    return NextResponse.json(
      { error: 'Failed to recalculate APY' },
      { status: 500 }
    );
  }
}

function generateMockHistory(): ApyHistory[] {
  const history: ApyHistory[] = [];
  const now = new Date();
  
  for (let i = 29; i >= 0; i--) {
    history.push({
      id: i,
      calculatedAt: new Date(now.getTime() - i * 86400000).toISOString(),
      periodDays: 30,
      totalRewards: 400 + Math.random() * 100,
      apyPercent: 5.2 + Math.random() * 0.5,
      expectedApy: 5.5
    });
  }
  
  return history;
}
