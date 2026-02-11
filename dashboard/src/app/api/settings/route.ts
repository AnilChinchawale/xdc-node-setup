import { NextRequest, NextResponse } from 'next/server';
import { getSettings, saveSettings } from '@/lib/config';
import type { Settings } from '@/lib/types';

export async function GET() {
  try {
    const settings = await getSettings();
    return NextResponse.json(settings);
  } catch (error) {
    console.error('Error fetching settings:', error);
    return NextResponse.json({ error: 'Failed to fetch settings' }, { status: 500 });
  }
}

export async function PUT(request: NextRequest) {
  try {
    const apiKey = request.headers.get('x-api-key');
    if (process.env.API_KEY && apiKey !== process.env.API_KEY) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const settings: Settings = await request.json();
    
    // Validate settings structure
    if (!settings.notifications || !settings.theme) {
      return NextResponse.json({ error: 'Invalid settings format' }, { status: 400 });
    }
    
    const success = await saveSettings(settings);
    
    if (success) {
      return NextResponse.json({ success: true, message: 'Settings saved' });
    } else {
      return NextResponse.json({ error: 'Failed to save settings' }, { status: 500 });
    }
  } catch (error) {
    console.error('Error saving settings:', error);
    return NextResponse.json({ error: 'Failed to save settings' }, { status: 500 });
  }
}
