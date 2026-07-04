#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_DIR"

echo "[chaos:recover] Stopping temporary chaos containers"
docker rm -f chaos-cpu chaos-memory >/dev/null 2>&1 || true

echo "[chaos:recover] Removing disk fill file"
rm -f "$PROJECT_DIR/.chaos/disk-fill.img"
rmdir "$PROJECT_DIR/.chaos" 2>/dev/null || true

echo "[chaos:recover] Restoring docker compose services"
docker compose up -d nginx-demo

echo "[chaos:recover] Recovery completed"

