#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

log() {
  echo "[deploy] $*"
}

require_compose() {
  if ! docker compose version >/dev/null 2>&1; then
    echo "docker compose is not available. Please install Docker Compose plugin first." >&2
    exit 1
  fi
}

require_compose

if [ ! -f ".env" ]; then
  log ".env not found, creating it from .env.example"
  cp .env.example .env
fi

log "Validating docker-compose.yml"
docker compose config -q

log "Starting monitoring stack"
docker compose up -d

log "Container status"
docker compose ps

log "Done. Grafana: http://localhost:3000, Prometheus: http://localhost:9090, Alertmanager: http://localhost:9093"

