#!/bin/bash
set -euo pipefail

echo "[docker-mirror] This script configures Docker daemon registry mirrors."
echo "[docker-mirror] Recommended on Alibaba Cloud ECS when Docker Hub pull fails."
echo "[docker-mirror] Use your Alibaba Cloud ACR accelerator URL if possible."

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run as root: sudo $0" >&2
  exit 1
fi

ACR_MIRROR="${ACR_MIRROR:-}"

if [ -z "$ACR_MIRROR" ]; then
  cat <<'MSG'

ACR_MIRROR is not set.

Open Alibaba Cloud Container Registry -> Image Tools -> Image Accelerator,
copy your accelerator URL, then run for example:

  ACR_MIRROR=https://YOUR_ACR_ACCELERATOR_ID.mirror.aliyuncs.com sudo -E scripts/configure_docker_mirror.sh

The script also keeps public fallback mirrors, but a personal ACR accelerator is more stable.
MSG
  read -r -p "Continue with public fallback mirrors only? [y/N] " answer
  if [[ ! "$answer" =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
  fi
fi

mkdir -p /etc/docker

tmp_file="$(mktemp)"
if [ -n "$ACR_MIRROR" ]; then
  cat > "$tmp_file" <<EOF
{
  "registry-mirrors": [
    "$ACR_MIRROR",
    "https://docker.m.daocloud.io"
  ]
}
EOF
else
  cat > "$tmp_file" <<'EOF'
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io"
  ]
}
EOF
fi

install -m 0644 "$tmp_file" /etc/docker/daemon.json
rm -f "$tmp_file"

echo "[docker-mirror] Restarting Docker"
systemctl daemon-reload
systemctl restart docker

echo "[docker-mirror] Docker mirror configuration:"
docker info 2>/dev/null | sed -n '/Registry Mirrors:/,/Live Restore Enabled:/p' || true

echo "[docker-mirror] Done. Now run: docker compose pull"
