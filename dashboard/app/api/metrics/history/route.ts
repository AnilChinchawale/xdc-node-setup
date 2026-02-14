import { NextResponse } from 'next/server';
import { getHistory } from '@/lib/metrics-history';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

/**
 * GET /api/metrics/history
 * Returns rolling historical metrics data (max 60 entries = 30 minutes)
 */
export async function GET() {
  try {
    const history = getHistory();
    return NextResponse.json(history);
  } catch (error) {
    return NextResponse.json(
      {
        timestamps: [],
        blockHeight: [],
        peers: [],
        cpu: [],
        memory: [],
        disk: [],
        syncPercent: [],
        txPoolPending: [],
      },
      { status: 500 }
    );
  }
}
