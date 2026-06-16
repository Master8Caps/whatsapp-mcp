#!/bin/bash
set -e

echo "=== WhatsApp MCP Server Starting ==="

# The Go bridge hardcodes 'store/' relative to its working directory.
# We run it from /data so all session data lands in /data/store/
# Mount a Railway Volume at /data to persist across restarts.
mkdir -p /data/store

echo "Starting WhatsApp Go bridge (working dir: /data)..."
cd /data
/app/whatsapp-bridge &
BRIDGE_PID=$!

# Give the bridge time to initialise and print the QR code if needed
sleep 5

echo "Starting Python MCP server..."
cd /app/whatsapp-mcp-server
uv run main.py &
MCP_PID=$!

echo "Both services started. Bridge PID: $BRIDGE_PID, MCP PID: $MCP_PID"
echo "Check Deploy Logs in Railway for the QR code if this is first run."

# Wait for either process to exit
wait -n $BRIDGE_PID $MCP_PID
echo "A service exited. Shutting down..."
kill $BRIDGE_PID $MCP_PID 2>/dev/null || true
