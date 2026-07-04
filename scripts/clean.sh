#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "[clean] Removing recoverable chaos test files"
rm -f "$PROJECT_DIR/.chaos/disk-fill.img"
rmdir "$PROJECT_DIR/.chaos" 2>/dev/null || true

if docker compose version >/dev/null 2>&1; then
  echo "[clean] Removing stopped chaos containers if any"
  docker rm -f chaos-cpu chaos-memory >/dev/null 2>&1 || true
fi

if [ "${CLEAN_VOLUMES:-false}" = "true" ]; then
  echo "CLEAN_VOLUMES=true was set. This will remove Prometheus/Grafana/Alertmanager data volumes."
  read -r -p "Type DELETE_MONITORING_DATA to continue: " answer
  if [ "$answer" = "DELETE_MONITORING_DATA" ]; then
    docker compose down -v
  else
    echo "[clean] Volume cleanup cancelled"
  fi
else
  echo "[clean] Persistent volumes are kept. Set CLEAN_VOLUMES=true only when you intentionally want to reset all monitoring data."
fi

