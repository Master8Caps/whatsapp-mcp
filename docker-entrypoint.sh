#!/bin/bash
set -e

echo "=== WhatsApp MCP Server Starting ==="

# The Go bridge hardcodes 'store/' relative to its working directory.
# We run it from /data so all session data lands in /data/store/
# Mount a Railway Volume at /data to persist across restarts.
mkdir -p /data/store

# Start the Python MCP SSE server in the background (stays alive permanently)
echo "Starting Python MCP server on port 3000..."
cd /app/whatsapp-mcp-server
uv run main.py &
MCP_PID=$!
echo "MCP server started (PID: $MCP_PID)"

# Run the Go bridge in a restart loop
# It will exit after QR timeout if not scanned, then restart to show a fresh QR
echo "Starting WhatsApp Go bridge restart loop..."
while true; do
    echo "--- Starting Go bridge ---"
    cd /data
    /app/whatsapp-bridge &
    BRIDGE_PID=$!
    wait $BRIDGE_PID
    EXIT_CODE=$?
    echo "--- Go bridge exited (code: $EXIT_CODE). Restarting in 3 seconds... ---"
    sleep 3
done
