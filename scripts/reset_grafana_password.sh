#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

if ! docker compose version >/dev/null 2>&1; then
  echo "docker compose is not available." >&2
  exit 1
fi

if [ -f ".env" ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

NEW_PASSWORD="${1:-${GF_SECURITY_ADMIN_PASSWORD:-}}"

if [ -z "$NEW_PASSWORD" ] || [ "$NEW_PASSWORD" = "YOUR_PASSWORD" ]; then
  echo "Usage: scripts/reset_grafana_password.sh 'NEW_PASSWORD'" >&2
  echo "Or set GF_SECURITY_ADMIN_PASSWORD in .env first." >&2
  exit 1
fi

echo "[grafana] Resetting Grafana admin password"
docker compose exec -T grafana grafana cli admin reset-admin-password "$NEW_PASSWORD"
echo "[grafana] Password reset completed. Login user: ${GF_SECURITY_ADMIN_USER:-admin}"

