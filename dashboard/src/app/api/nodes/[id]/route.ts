import { NextRequest, NextResponse } from 'next/server';
import { getNodeById } from '@/lib/reports';

export async function GET(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const node = await getNodeById(params.id);
    
    if (!node) {
      return NextResponse.json({ error: 'Node not found' }, { status: 404 });
    }
    
    return NextResponse.json(node);
  } catch (error) {
    console.error('Error fetching node:', error);
    return NextResponse.json({ error: 'Failed to fetch node' }, { status: 500 });
  }
}
