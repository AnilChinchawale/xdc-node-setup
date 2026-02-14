#!/bin/sh
# Combined startup script for Dashboard + SkyNet Agent

# Start SkyNet Agent in background
echo "Starting SkyNet Agent..."
(
  while true; do
    /agent.sh 2>/dev/null
    sleep 60
  done
) &
SKYNET_PID=$!

# Start Dashboard
echo "Starting Dashboard..."
cd /app
exec npm start
