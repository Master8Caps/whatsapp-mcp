#!/bin/bash
set -e

echo "=== WhatsApp MCP Server Starting ==="

# The Go bridge hardcodes 'store/' relative to its working directory.
# We run it from /data so all session data lands in /data/store/
# Mount a Railway Volume at /data to persist across restarts.
mkdir -p /data/store

# Start the Python MCP SSE server FIRST so Railway's port check passes
echo "Starting Python MCP server on port 3000..."
cd /app/whatsapp-mcp-server
uv run main.py &
MCP_PID=$!

# Wait for the Python MCP server to be ready on port 3000
echo "Waiting for MCP server to be ready..."
for i in $(seq 1 30); do
    if curl -s --max-time 2 http://localhost:3000/sse > /dev/null 2>&1; then
        echo "MCP server is ready!"
        break
    fi
    sleep 1
done

echo "Starting WhatsApp Go bridge restart loop..."
# Run the Go bridge in a restart loop so it keeps generating fresh QR codes
# until the user scans one, then stays connected permanently
while true; do
    echo "--- Starting Go bridge ---"
    cd /data
    /app/whatsapp-bridge &
    BRIDGE_PID=$!
    wait $BRIDGE_PID
    EXIT_CODE=$?
    echo "--- Go bridge exited (code: $EXIT_CODE). Restarting in 5 seconds... ---"
    sleep 5
done
