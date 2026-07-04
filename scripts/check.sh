#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

if ! docker compose version >/dev/null 2>&1; then
  echo "docker compose is not available." >&2
  exit 1
fi

echo "[check] Validating Docker Compose syntax"
docker compose config -q

echo "[check] Checking required files"
required_files=(
  "prometheus/prometheus.yml"
  "prometheus/rules/host_alerts.yml"
  "prometheus/rules/container_alerts.yml"
  "prometheus/rules/service_alerts.yml"
  "alertmanager/alertmanager.yml"
  "blackbox/blackbox.yml"
  "grafana/provisioning/datasources/datasource.yml"
  "grafana/provisioning/dashboards/dashboard.yml"
)

for file in "${required_files[@]}"; do
  if [ ! -f "$file" ]; then
    echo "Missing required file: $file" >&2
    exit 1
  fi
done

if docker compose ps --services --filter status=running | grep -q '^prometheus$'; then
  echo "[check] Validating Prometheus configuration with promtool"
  docker compose exec -T prometheus promtool check config /etc/prometheus/prometheus.yml
else
  echo "[check] Prometheus container is not running, skipping promtool runtime check"
fi

if docker compose ps --services --filter status=running | grep -q '^alertmanager$'; then
  echo "[check] Validating Alertmanager configuration with amtool"
  docker compose exec -T alertmanager amtool check-config /etc/alertmanager/alertmanager.yml
else
  echo "[check] Alertmanager container is not running, skipping amtool runtime check"
fi

if docker compose ps --services --filter status=running | grep -q '^blackbox-exporter$'; then
  echo "[check] Validating Blackbox Exporter configuration"
  docker compose exec -T blackbox-exporter /bin/blackbox_exporter --config.file=/etc/blackbox_exporter/config.yml --config.check
else
  echo "[check] Blackbox Exporter container is not running, skipping runtime check"
fi

echo "[check] Current container status"
docker compose ps

