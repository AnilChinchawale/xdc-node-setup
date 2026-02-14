import { NextResponse } from 'next/server';

// RPC_URL not needed for liveness check

export const dynamic = 'force-dynamic';

/**
 * Liveness probe endpoint
 * Returns 200 if the dashboard API process is running
 * Used by Kubernetes liveness probes
 */
export async function GET() {
  return NextResponse.json(
    {
      status: 'alive',
      timestamp: new Date().toISOString(),
      version: process.env.APP_VERSION || '1.0.0',
      uptime: process.uptime(),
    },
    { status: 200 }
  );
}
