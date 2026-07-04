#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_DIR"

echo "[chaos:service] This will stop nginx-demo, the HTTP service monitored by Blackbox Exporter."
echo "[chaos:service] Observe HTTPServiceDown in Prometheus Alerts and Alertmanager."
read -r -p "Continue? [y/N] " answer
if [[ ! "$answer" =~ ^[Yy]$ ]]; then
  echo "Cancelled."
  exit 0
fi

docker compose stop nginx-demo
echo "[chaos:service] nginx-demo stopped. Run scripts/chaos/recover.sh to restore it."

