#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_DIR"

DISK_MB="${DISK_MB:-1024}"
CHAOS_DIR="$PROJECT_DIR/.chaos"
TARGET_FILE="$CHAOS_DIR/disk-fill.img"

echo "[chaos:disk] This will create a removable ${DISK_MB}MB file at $TARGET_FILE."
echo "[chaos:disk] It is designed to be recoverable by scripts/chaos/recover.sh."
read -r -p "Continue? [y/N] " answer
if [[ ! "$answer" =~ ^[Yy]$ ]]; then
  echo "Cancelled."
  exit 0
fi

mkdir -p "$CHAOS_DIR"
dd if=/dev/zero of="$TARGET_FILE" bs=1M count="$DISK_MB" conv=fsync status=progress
echo "[chaos:disk] Disk fill file created. Watch HighDiskUsage if the filesystem crosses 85%."

