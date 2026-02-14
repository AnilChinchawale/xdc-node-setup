import { NextRequest, NextResponse } from 'next/server';

/**
 * XDC SkyOne Dashboard - Authentication Middleware
 * Provides basic auth protection for production deployments
 */

// Routes that don't require authentication
const PUBLIC_PATHS = ['/api/health', '/api/health/live', '/_next', '/static', '/favicon.ico'];

function isPublicPath(path: string): boolean {
  return PUBLIC_PATHS.some(publicPath => 
    path === publicPath || 
    path.startsWith(publicPath + '/') ||
    path.startsWith('/_next/') ||
    path.startsWith('/static/')
  );
}

function parseBasicAuth(header: string): { username: string; password: string } | null {
  try {
    const base64 = header.replace('Basic ', '');
    const decoded = atob(base64);
    const [username, password] = decoded.split(':');
    if (!username || !password) return null;
    return { username, password };
  } catch {
    return null;
  }
}

function validateCredentials(username: string, password: string): boolean {
  const expectedUser = process.env.DASHBOARD_USER;
  const expectedPass = process.env.DASHBOARD_PASSWORD;
  
  // If credentials not configured, allow access (backwards compatible for local use)
  if (!expectedUser || !expectedPass) {
    return true;
  }
  
  return username === expectedUser && password === expectedPass;
}

export function middleware(req: NextRequest) {
  const { pathname } = req.nextUrl;
  
  // Allow public paths without authentication
  if (isPublicPath(pathname)) {
    return NextResponse.next();
  }
  
  // Check if auth is configured
  const expectedUser = process.env.DASHBOARD_USER;
  const expectedPass = process.env.DASHBOARD_PASSWORD;
  
  // If credentials not set, allow access (backwards compatible for local use)
  if (!expectedUser || !expectedPass) {
    const response = NextResponse.next();
    // Add security headers even when auth is disabled
    response.headers.set('X-Frame-Options', 'DENY');
    response.headers.set('X-Content-Type-Options', 'nosniff');
    response.headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');
    response.headers.set('X-DNS-Prefetch-Control', 'on');
    return response;
  }
  
  // Check for authorization header
  const authHeader = req.headers.get('authorization');
  
  if (!authHeader || !authHeader.startsWith('Basic ')) {
    const response = new NextResponse('Authentication required', {
      status: 401,
      headers: {
        'WWW-Authenticate': 'Basic realm="XDC SkyOne Dashboard"',
        'Content-Type': 'text/plain',
      },
    });
    return response;
  }
  
  // Parse and validate credentials
  const credentials = parseBasicAuth(authHeader);
  
  if (!credentials || !validateCredentials(credentials.username, credentials.password)) {
    const response = new NextResponse('Invalid credentials', {
      status: 401,
      headers: {
        'WWW-Authenticate': 'Basic realm="XDC SkyOne Dashboard"',
        'Content-Type': 'text/plain',
      },
    });
    return response;
  }
  
  // Authentication successful - add security headers
  const response = NextResponse.next();
  response.headers.set('X-Frame-Options', 'DENY');
  response.headers.set('X-Content-Type-Options', 'nosniff');
  response.headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');
  response.headers.set('X-DNS-Prefetch-Control', 'on');
  
  return response;
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico).*)'],
};
