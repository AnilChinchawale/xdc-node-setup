import { NextRequest, NextResponse } from 'next/server';
import { getLatestReport } from '@/lib/reports';
import { exec } from 'child_process';
import { promisify } from 'util';
import path from 'path';

const execAsync = promisify(exec);

export async function GET() {
  try {
    const report = await getLatestReport();
    
    if (!report) {
      return NextResponse.json({
        nodes: [],
        avgScore: 0,
      });
    }
    
    const avgScore = report.nodes.length > 0
      ? report.nodes.reduce((sum, n) => sum + n.securityScore, 0) / report.nodes.length
      : 0;
    
    return NextResponse.json({
      nodes: report.nodes.map(node => ({
        id: node.id,
        hostname: node.hostname,
        ip: node.ip,
        securityScore: node.securityScore,
        securityChecks: node.securityChecks,
      })),
      avgScore,
    });
  } catch (error) {
    console.error('Error fetching security data:', error);
    return NextResponse.json({ error: 'Failed to fetch security data' }, { status: 500 });
  }
}

export async function POST(request: NextRequest) {
  try {
    const apiKey = request.headers.get('x-api-key');
    if (process.env.API_KEY && apiKey !== process.env.API_KEY) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const scriptPath = path.join(process.cwd(), '..', 'scripts', 'security', 'security-harden.sh');
    
    try {
      const { stdout, stderr } = await execAsync(`bash ${scriptPath} --audit-only`, {
        timeout: 300000, // 5 minutes
        cwd: path.join(process.cwd(), '..'),
      });
      
      return NextResponse.json({
        success: true,
        message: 'Security audit completed',
        output: stdout,
        errors: stderr || null,
      });
    } catch (execError: any) {
      return NextResponse.json({
        success: false,
        message: 'Security audit script error',
        error: execError.message,
      }, { status: 500 });
    }
  } catch (error) {
    console.error('Error running security audit:', error);
    return NextResponse.json({ error: 'Failed to run security audit' }, { status: 500 });
  }
}
