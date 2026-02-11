# XDC Node Dashboard

A lightweight web dashboard for monitoring and managing XDC Network nodes.

![Dashboard Screenshot](../docs/images/dashboard-overview.png)

## Features

- **Overview Dashboard** — Summary cards, network stats, and recent alerts
- **Node Management** — View all nodes with real-time status, metrics, and filtering
- **Node Details** — Historical charts, security checklist, and node-specific actions
- **Security Dashboard** — Fleet security score, per-node audits, and recommendations
- **Version Management** — Track client versions across all nodes with auto-update support
- **Alert System** — Timeline view of all alerts with acknowledge/dismiss functionality
- **Settings** — Notification channels, node registration, API keys, and theme

## Quick Start

### Prerequisites

- Node.js 18+ or Bun
- XDC Node Setup toolkit installed

### Installation

```bash
cd dashboard
npm install
```

### Development

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

### Production Build

```bash
npm run build
npm start
```

### Docker

```bash
docker build -t xdc-dashboard .
docker run -p 3000:3000 -v $(pwd)/../reports:/app/reports:ro xdc-dashboard
```

Or use docker-compose from the parent directory:

```bash
cd ..
docker-compose up dashboard
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `API_KEY` | API key for write operations | (none) |
| `PORT` | Server port | 3000 |
| `REPORTS_DIR` | Path to health reports | `../reports` |
| `CONFIGS_DIR` | Path to configuration files | `../configs` |

### API Authentication

Read operations (GET) are public by default. Write operations (POST, PUT) require an API key:

```bash
# Set in environment
export API_KEY=your-secret-key

# Or in .env.local
echo "API_KEY=your-secret-key" >> .env.local
```

Include the key in requests:

```bash
curl -X POST http://localhost:3000/api/health \
  -H "x-api-key: your-secret-key"
```

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/nodes` | GET | List all nodes with current status |
| `/api/nodes/[id]` | GET | Get single node details |
| `/api/health` | POST | Trigger health check |
| `/api/versions` | GET | Get version configuration |
| `/api/versions` | POST | Trigger version check |
| `/api/alerts` | GET | Get all alerts |
| `/api/alerts` | POST | Acknowledge/dismiss alert |
| `/api/security` | GET | Get security scores |
| `/api/security` | POST | Run security audit |
| `/api/settings` | GET/PUT | Read/write settings |

## Directory Structure

```
dashboard/
├── src/
│   ├── app/
│   │   ├── api/          # REST API routes
│   │   ├── nodes/        # Node pages
│   │   ├── security/     # Security dashboard
│   │   ├── versions/     # Version management
│   │   ├── alerts/       # Alert history
│   │   ├── settings/     # Settings page
│   │   ├── layout.tsx    # Root layout
│   │   ├── page.tsx      # Overview dashboard
│   │   └── globals.css   # Global styles
│   ├── components/       # Reusable UI components
│   └── lib/              # Utility functions and types
├── public/               # Static assets
├── package.json
├── tailwind.config.js
└── tsconfig.json
```

## Tech Stack

- **Framework:** Next.js 14 (App Router)
- **Styling:** Tailwind CSS
- **Charts:** Recharts
- **Language:** TypeScript

## Design

- **Dark Theme** — `#0a0a0f` background, `#1a1a2e` cards
- **XDC Branding** — Primary blue `#1F4CED`
- **Status Colors:**
  - Healthy: `#10B981` (green)
  - Warning: `#F59E0B` (yellow)
  - Critical: `#EF4444` (red)
- **Typography:** Fira Sans

## License

MIT — See [LICENSE](../LICENSE)
