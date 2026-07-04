#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

if [ -f ".env" ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "docker compose is not available." >&2
  exit 1
fi

echo "[status] Docker Compose services"
docker compose ps

echo
echo "[status] Useful URLs"
echo "Prometheus:   http://localhost:9090"
echo "Grafana:      http://localhost:3000"
echo "Alertmanager: http://localhost:9093"
echo "Demo HTTP:    http://localhost:${DEMO_HTTP_PORT:-8080}"
