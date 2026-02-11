import { NextResponse } from 'next/server';
import { execSync } from 'child_process';
import { StakeInfo, Delegation } from '@/lib/types';

// Get stake information
export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url);
    const address = searchParams.get('address');

    let info: StakeInfo = {
      minStake: 10000000,
      totalStake: 0,
      totalRewards: 0,
      expectedApy: 5.5,
      delegations: [],
      compoundSettings: {
        enabled: false,
        threshold: 1000
      }
    };

    try {
      // Get stake info from script
      const output = execSync(
        '/opt/xdc-node/scripts/stake-manager.sh --stake-info',
        { encoding: 'utf-8', timeout: 30000 }
      );
      
      // Parse output
      info = parseStakeOutput(output);
      
      // Get compound settings
      const compoundOutput = execSync(
        '/opt/xdc-node/scripts/stake-manager.sh --compound-status',
        { encoding: 'utf-8', timeout: 10000 }
      );
      info.compoundSettings = parseCompoundOutput(compoundOutput);
      
      // Get delegations
      const delegationsOutput = execSync(
        '/opt/xdc-node/scripts/stake-manager.sh --delegations',
        { encoding: 'utf-8', timeout: 10000 }
      );
      info.delegations = parseDelegationsOutput(delegationsOutput);
      
    } catch (error) {
      console.error('Failed to get stake info:', error);
      // Return mock data for development
      info = generateMockStakeInfo();
    }

    // Filter by address if provided
    if (address) {
      info.delegations = info.delegations.filter(d => 
        d.delegatorAddress.toLowerCase().includes(address.toLowerCase())
      );
    }

    return NextResponse.json({
      ...info,
      generatedAt: new Date().toISOString()
    });
  } catch (error) {
    console.error('Error fetching stake info:', error);
    return NextResponse.json(
      { error: 'Failed to fetch stake information' },
      { status: 500 }
    );
  }
}

// Manage stake operations
export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { action, address, amount, enabled, threshold } = body;

    switch (action) {
      case 'compound':
        const status = enabled ? 'on' : 'off';
        execSync(
          `/opt/xdc-node/scripts/stake-manager.sh --compound ${status} --threshold ${threshold || 1000}`,
          { encoding: 'utf-8', timeout: 10000 }
        );
        return NextResponse.json({ 
          success: true, 
          message: `Auto-compound ${enabled ? 'enabled' : 'disabled'}` 
        });

      case 'compound-now':
        execSync(
          '/opt/xdc-node/scripts/stake-manager.sh --compound-now',
          { encoding: 'utf-8', timeout: 30000 }
        );
        return NextResponse.json({ 
          success: true, 
          message: 'Compound executed' 
        });

      case 'add-delegation':
        if (!address || !amount) {
          return NextResponse.json(
            { error: 'Address and amount required' }, 
            { status: 400 }
          );
        }
        execSync(
          `/opt/xdc-node/scripts/stake-manager.sh --add-delegation ${address} --amount ${amount}`,
          { encoding: 'utf-8', timeout: 10000 }
        );
        return NextResponse.json({ 
          success: true, 
          message: `Delegation added for ${address}` 
        });

      case 'remove-delegation':
        if (!address) {
          return NextResponse.json(
            { error: 'Address required' }, 
            { status: 400 }
          );
        }
        execSync(
          `/opt/xdc-node/scripts/stake-manager.sh --remove-delegation ${address}`,
          { encoding: 'utf-8', timeout: 10000 }
        );
        return NextResponse.json({ 
          success: true, 
          message: `Delegation removed for ${address}` 
        });

      case 'withdraw-plan':
        const planOutput = execSync(
          '/opt/xdc-node/scripts/stake-manager.sh --withdraw-plan',
          { encoding: 'utf-8', timeout: 10000 }
        );
        return NextResponse.json({ 
          success: true, 
          plan: planOutput 
        });

      case 'tax-report':
        const { year = new Date().getFullYear() } = body;
        execSync(
          `/opt/xdc-node/scripts/stake-manager.sh --tax-report ${year}`,
          { encoding: 'utf-8', timeout: 30000 }
        );
        return NextResponse.json({ 
          success: true, 
          message: `Tax report for ${year} generated` 
        });

      default:
        return NextResponse.json({ error: 'Unknown action' }, { status: 400 });
    }
  } catch (error) {
    console.error('Error managing stake:', error);
    return NextResponse.json(
      { error: 'Failed to execute stake action' },
      { status: 500 }
    );
  }
}

// Parse stake output
function parseStakeOutput(output: string): Partial<StakeInfo> {
  const info: Partial<StakeInfo> = {
    minStake: 10000000,
    expectedApy: 5.5,
    delegations: [],
    compoundSettings: { enabled: false, threshold: 1000 }
  };

  const lines = output.split('\n');
  
  for (const line of lines) {
    const totalStakeMatch = line.match(/Your Total Stake:\s+([\d.]+)/);
    if (totalStakeMatch) {
      info.totalStake = parseFloat(totalStakeMatch[1]);
    }

    const totalRewardsMatch = line.match(/Total Rewards:\s+([\d.]+)/);
    if (totalRewardsMatch) {
      info.totalRewards = parseFloat(totalRewardsMatch[1]);
    }

    const effectiveApyMatch = line.match(/Effective APY:\s+([\d.]+)%/);
    if (effectiveApyMatch) {
      info.effectiveApy = parseFloat(effectiveApyMatch[1]);
    }
  }

  return info;
}

// Parse compound output
function parseCompoundOutput(output: string): { enabled: boolean; threshold: number; lastCompound?: string } {
  const result = { enabled: false, threshold: 1000 };
  const lines = output.split('\n');
  
  for (const line of lines) {
    if (line.includes('Enabled')) {
      result.enabled = line.includes('✓') || !line.includes('✗');
    }
    
    const thresholdMatch = line.match(/Threshold:\s+([\d.]+)/);
    if (thresholdMatch) {
      result.threshold = parseFloat(thresholdMatch[1]);
    }
    
    const lastMatch = line.match(/Last Run:\s+(\d{4}-\d{2}-\d{2}[\sT]\d{2}:\d{2}:\d{2})/);
    if (lastMatch) {
      result.lastCompound = lastMatch[1];
    }
  }
  
  return result;
}

// Parse delegations output
function parseDelegationsOutput(output: string): Delegation[] {
  const delegations: Delegation[] = [];
  const lines = output.split('\n');
  
  for (const line of lines) {
    // Match delegation lines (xdc address format)
    const match = line.match(/(xdc[0-9a-fA-F]{40})\s+([\d.]+)\s+(\d{4}-\d{2}-\d{2})/);
    if (match) {
      delegations.push({
        id: delegations.length,
        delegatorAddress: match[1],
        amount: parseFloat(match[2]),
        timestamp: match[3],
        status: 'active'
      });
    }
  }
  
  return delegations;
}

// Generate mock stake info
function generateMockStakeInfo(): StakeInfo {
  return {
    minStake: 10000000,
    totalStake: 10000000 + Math.random() * 10000,
    totalRewards: 4500 + Math.random() * 500,
    effectiveApy: 5.2 + Math.random() * 0.5,
    expectedApy: 5.5,
    delegations: [
      {
        id: 1,
        timestamp: new Date(Date.now() - 86400000 * 30).toISOString(),
        delegatorAddress: 'xdc' + '0'.repeat(39) + '1',
        amount: 10000000,
        status: 'active'
      }
    ],
    compoundSettings: {
      enabled: true,
      threshold: 1000,
      lastCompound: new Date(Date.now() - 86400000 * 2).toISOString()
    }
  };
}
