import { NextRequest, NextResponse } from 'next/server';
import { getAlertState, saveAlertState } from '@/lib/config';
import { getLatestReport } from '@/lib/reports';

export async function GET() {
  try {
    // Try to get alerts from both sources
    const alertState = await getAlertState();
    const report = await getLatestReport();
    
    // Merge alerts from report nodes
    const reportAlerts = report?.nodes.flatMap(node => 
      node.alerts.map(alert => ({
        ...alert,
        nodeName: node.hostname,
      }))
    ) || [];
    
    // Combine and deduplicate
    const allAlerts = [...(alertState?.alerts || []), ...reportAlerts];
    const uniqueAlerts = allAlerts.reduce((acc, alert) => {
      if (!acc.find(a => a.id === alert.id)) {
        acc.push(alert);
      }
      return acc;
    }, [] as typeof allAlerts);
    
    // Sort by timestamp descending
    uniqueAlerts.sort((a, b) => 
      new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime()
    );
    
    return NextResponse.json({
      alerts: uniqueAlerts,
      lastUpdated: alertState?.lastUpdated || new Date().toISOString(),
    });
  } catch (error) {
    console.error('Error fetching alerts:', error);
    return NextResponse.json({ error: 'Failed to fetch alerts' }, { status: 500 });
  }
}

export async function POST(request: NextRequest) {
  try {
    const apiKey = request.headers.get('x-api-key');
    if (process.env.API_KEY && apiKey !== process.env.API_KEY) {
      // Allow basic operations without API key for now
    }

    const { alertId, action } = await request.json();
    
    if (!alertId || !action) {
      return NextResponse.json({ error: 'alertId and action required' }, { status: 400 });
    }
    
    const alertState = await getAlertState();
    if (!alertState) {
      return NextResponse.json({ error: 'Alert state not found' }, { status: 404 });
    }
    
    if (action === 'acknowledge') {
      alertState.alerts = alertState.alerts.map(alert =>
        alert.id === alertId
          ? { ...alert, acknowledged: true, acknowledgedAt: new Date().toISOString() }
          : alert
      );
    } else if (action === 'dismiss') {
      alertState.alerts = alertState.alerts.filter(alert => alert.id !== alertId);
    } else {
      return NextResponse.json({ error: 'Invalid action' }, { status: 400 });
    }
    
    alertState.lastUpdated = new Date().toISOString();
    await saveAlertState(alertState);
    
    return NextResponse.json({ success: true, message: `Alert ${action}d` });
  } catch (error) {
    console.error('Error updating alert:', error);
    return NextResponse.json({ error: 'Failed to update alert' }, { status: 500 });
  }
}
