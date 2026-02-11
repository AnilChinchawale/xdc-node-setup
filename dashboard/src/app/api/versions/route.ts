import { NextRequest, NextResponse } from 'next/server';
import { getVersionConfig, saveVersionConfig } from '@/lib/config';
import { exec } from 'child_process';
import { promisify } from 'util';
import path from 'path';
import type { VersionConfig } from '@/lib/types';

const execAsync = promisify(exec);

export async function GET() {
  try {
    const config = await getVersionConfig();
    
    if (!config) {
      // Return default config
      return NextResponse.json({
        clients: [
          {
            client: 'XDC',
            current: 'v2.6.0',
            latest: 'v2.6.0',
            releaseDate: '2026-01-15T00:00:00Z',
            changelogUrl: 'https://github.com/XinFinOrg/XDPoSChain/releases/tag/v2.6.0',
            nodeCount: 5,
            autoUpdate: false,
          },
          {
            client: 'XDC2',
            current: 'v2.6.0',
            latest: 'v2.6.0',
            releaseDate: '2026-01-15T00:00:00Z',
            changelogUrl: 'https://github.com/XinFinOrg/XDC2/releases/tag/v2.6.0',
            nodeCount: 2,
            autoUpdate: false,
          }
        ],
        lastChecked: new Date().toISOString(),
        updateHistory: [],
      });
    }
    
    return NextResponse.json(config);
  } catch (error) {
    console.error('Error fetching versions:', error);
    return NextResponse.json({ error: 'Failed to fetch versions' }, { status: 500 });
  }
}

export async function POST(request: NextRequest) {
  try {
    const apiKey = request.headers.get('x-api-key');
    if (process.env.API_KEY && apiKey !== process.env.API_KEY) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const scriptPath = path.join(process.cwd(), '..', 'scripts', 'version-check.sh');
    
    try {
      const { stdout, stderr } = await execAsync(`bash ${scriptPath}`, {
        timeout: 120000, // 2 minutes
        cwd: path.join(process.cwd(), '..'),
      });
      
      return NextResponse.json({
        success: true,
        message: 'Version check completed',
        output: stdout,
        errors: stderr || null,
      });
    } catch (execError: any) {
      return NextResponse.json({
        success: false,
        message: 'Version check script error',
        error: execError.message,
      }, { status: 500 });
    }
  } catch (error) {
    console.error('Error running version check:', error);
    return NextResponse.json({ error: 'Failed to run version check' }, { status: 500 });
  }
}

export async function PUT(request: NextRequest) {
  try {
    const apiKey = request.headers.get('x-api-key');
    if (process.env.API_KEY && apiKey !== process.env.API_KEY) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const config: VersionConfig = await request.json();
    const success = await saveVersionConfig(config);
    
    if (success) {
      return NextResponse.json({ success: true, message: 'Version config saved' });
    } else {
      return NextResponse.json({ error: 'Failed to save config' }, { status: 500 });
    }
  } catch (error) {
    console.error('Error saving version config:', error);
    return NextResponse.json({ error: 'Failed to save version config' }, { status: 500 });
  }
}
