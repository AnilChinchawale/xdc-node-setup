import { NextResponse } from 'next/server';
import { getLatestReport } from '@/lib/reports';

export async function GET() {
  try {
    const report = await getLatestReport();
    
    if (!report) {
      return NextResponse.json({
        timestamp: new Date().toISOString(),
        version: '2.0.0',
        networkBlockHeight: 0,
        nodes: [],
        summary: { total: 0, healthy: 0, warning: 0, critical: 0, avgSyncProgress: 0 }
      });
    }
    
    return NextResponse.json(report);
  } catch (error) {
    console.error('Error fetching nodes:', error);
    return NextResponse.json({ error: 'Failed to fetch nodes' }, { status: 500 });
  }
}
