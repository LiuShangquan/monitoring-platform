#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_DIR"

DURATION="${DURATION:-300}"
WORKERS="${WORKERS:-2}"

echo "[chaos:cpu] This will start a temporary container that consumes CPU for ${DURATION}s."
echo "[chaos:cpu] Observe Prometheus alert HighCPUUsage and Grafana Linux host dashboard."
read -r -p "Continue? [y/N] " answer
if [[ ! "$answer" =~ ^[Yy]$ ]]; then
  echo "Cancelled."
  exit 0
fi

docker rm -f chaos-cpu >/dev/null 2>&1 || true
docker run -d --name chaos-cpu --restart no alpine:3.20 sh -c "i=0; while [ \$i -lt ${WORKERS} ]; do yes > /dev/null & i=\$((i+1)); done; sleep ${DURATION}"
echo "[chaos:cpu] Started chaos-cpu. Run scripts/chaos/recover.sh to stop it early."

