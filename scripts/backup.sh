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

PROJECT_NAME="${COMPOSE_PROJECT_NAME:-monitoring-platform}"
BACKUP_DIR="${BACKUP_DIR:-$PROJECT_DIR/backups/$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$BACKUP_DIR"

echo "[backup] Backing up compose config and monitoring rules"
tar -czf "$BACKUP_DIR/config-files.tar.gz" prometheus alertmanager grafana/provisioning blackbox docker-compose.yml .env.example

echo "[backup] Backing up Prometheus volume"
docker run --rm -v "${PROJECT_NAME}_prometheus_data:/data:ro" -v "$BACKUP_DIR:/backup" alpine:3.20 tar -czf /backup/prometheus-data.tar.gz -C /data .

echo "[backup] Backing up Grafana volume"
docker run --rm -v "${PROJECT_NAME}_grafana_data:/data:ro" -v "$BACKUP_DIR:/backup" alpine:3.20 tar -czf /backup/grafana-data.tar.gz -C /data .

echo "[backup] Backup saved to $BACKUP_DIR"

