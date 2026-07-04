#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_DIR"

DURATION="${DURATION:-300}"
MEMORY_MB="${MEMORY_MB:-512}"

echo "[chaos:memory] This will allocate about ${MEMORY_MB}MB memory in a temporary container for ${DURATION}s."
echo "[chaos:memory] Keep MEMORY_MB conservative on small ECS instances."
read -r -p "Continue? [y/N] " answer
if [[ ! "$answer" =~ ^[Yy]$ ]]; then
  echo "Cancelled."
  exit 0
fi

docker rm -f chaos-memory >/dev/null 2>&1 || true
docker run -d --name chaos-memory --restart no python:3.12-alpine python -c "import time; block=bytearray(${MEMORY_MB}*1024*1024); block[0]=1; time.sleep(${DURATION})"
echo "[chaos:memory] Started chaos-memory. Run scripts/chaos/recover.sh to stop it early."

