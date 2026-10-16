#!/usr/bin/env bash
# Refresh the files this project takes from the Mac app (the `main` branch):
# shared/icon.png, shared/adhkar.json, shared/QuranAssets/ and the UI strings.
#
#   tools/sync_from_mac.sh [path/to/mac/checkout]     (default: ../mac_os)
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
MAC="${1:-${SALAT_MAC_SOURCE:-$HERE/../mac_os}}"
[ -f "$MAC/main.swift" ] || { echo "No Mac checkout at $MAC"; exit 1; }

cp "$MAC/icon.png" "$MAC/adhkar.json" "$HERE/shared/"
rsync -a --delete --exclude '*.pdf' --exclude '.DS_Store' "$MAC/QuranAssets/" "$HERE/shared/QuranAssets/"
python3 "$HERE/tools/extract_strings.py" "$MAC"
echo "Synced from $MAC ($(git -C "$MAC" log -1 --format='%h %s' 2>/dev/null || echo 'not a git checkout'))"
echo "Review with: git status && git diff --stat"
