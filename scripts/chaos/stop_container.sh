#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_DIR"

TARGET_SERVICE="${1:-nginx-demo}"

echo "[chaos:container] This will stop Docker Compose service: $TARGET_SERVICE"
echo "[chaos:container] Use scripts/chaos/recover.sh or docker compose up -d $TARGET_SERVICE to restore it."
read -r -p "Continue? [y/N] " answer
if [[ ! "$answer" =~ ^[Yy]$ ]]; then
  echo "Cancelled."
  exit 0
fi

docker compose stop "$TARGET_SERVICE"
echo "[chaos:container] $TARGET_SERVICE stopped."

