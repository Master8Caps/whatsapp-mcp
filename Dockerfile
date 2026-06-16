# ──────────────────────────────────────────────
# Stage 1: Build the Go WhatsApp bridge
# ──────────────────────────────────────────────
FROM golang:1.25-bookworm AS go-builder

WORKDIR /app/whatsapp-bridge

# Install build dependencies for go-sqlite3 (requires CGO)
RUN apt-get update && apt-get install -y gcc libc6-dev && rm -rf /var/lib/apt/lists/*

COPY whatsapp-bridge/go.mod whatsapp-bridge/go.sum ./
RUN go mod download

COPY whatsapp-bridge/ ./
RUN CGO_ENABLED=1 GOOS=linux go build -o /whatsapp-bridge .

# ──────────────────────────────────────────────
# Stage 2: Final image with Python MCP server
# ──────────────────────────────────────────────
FROM python:3.12-slim-bookworm

# Install curl only (no ffmpeg - avoids OOM during build)
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.cargo/bin:/root/.local/bin:$PATH"

WORKDIR /app

# Copy Go bridge binary from build stage
COPY --from=go-builder /whatsapp-bridge /app/whatsapp-bridge

# Copy dependency files first (separate layer - only re-runs when deps change)
COPY whatsapp-mcp-server/pyproject.toml whatsapp-mcp-server/uv.lock /app/whatsapp-mcp-server/

# Install Python dependencies
WORKDIR /app/whatsapp-mcp-server
RUN uv sync --frozen --no-cache

# Copy rest of Python MCP server code
COPY whatsapp-mcp-server/ /app/whatsapp-mcp-server/

# Create persistent storage directory for WhatsApp session data
RUN mkdir -p /data/store

# Copy startup script
COPY docker-entrypoint.sh /app/docker-entrypoint.sh
RUN chmod +x /app/docker-entrypoint.sh

# Port 8080: Go bridge REST API (WhatsApp send/receive)
# Port 3000: Python MCP server (Manus Custom MCP endpoint)
EXPOSE 8080 3000

ENTRYPOINT ["/app/docker-entrypoint.sh"]
