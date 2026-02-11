import { NextRequest, NextResponse } from 'next/server';
import { exec } from 'child_process';
import { promisify } from 'util';
import path from 'path';

const execAsync = promisify(exec);

export async function POST(request: NextRequest) {
  try {
    // Check for API key in production
    const apiKey = request.headers.get('x-api-key');
    if (process.env.API_KEY && apiKey !== process.env.API_KEY) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const scriptPath = path.join(process.cwd(), '..', 'scripts', 'node-health-check.sh');
    
    try {
      const { stdout, stderr } = await execAsync(`bash ${scriptPath}`, {
        timeout: 300000, // 5 minutes
        cwd: path.join(process.cwd(), '..'),
      });
      
      return NextResponse.json({
        success: true,
        message: 'Health check completed',
        output: stdout,
        errors: stderr || null,
      });
    } catch (execError: any) {
      return NextResponse.json({
        success: false,
        message: 'Health check script error',
        error: execError.message,
      }, { status: 500 });
    }
  } catch (error) {
    console.error('Error running health check:', error);
    return NextResponse.json({ error: 'Failed to run health check' }, { status: 500 });
  }
}

export async function GET() {
  return NextResponse.json({
    status: 'ok',
    message: 'Health check API is available. Use POST to trigger a health check.',
  });
}
