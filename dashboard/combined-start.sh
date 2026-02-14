#!/bin/bash
# Combined startup script for XDC Agent (Dashboard + SkyNet)

# Start SkyNet Agent in background
echo "Starting SkyNet Agent..."
(
  sleep 10  # wait for node to be ready
  while true; do
    /agent.sh 2>/dev/null
    sleep 60
  done
) &

# Start Dashboard (dev mode — no build step needed)
# Use PORT env var if set, otherwise default to 3000
DASHBOARD_PORT=${PORT:-3000}
echo "Starting XDC Dashboard on port $DASHBOARD_PORT..."
cd /app
exec npx next dev -p "$DASHBOARD_PORT" -H 0.0.0.0
