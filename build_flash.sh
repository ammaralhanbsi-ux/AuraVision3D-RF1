#!/usr/bin/env bash
set -euo pipefail
TARGET="${1:-esp32c6}"
PORT="${2:-}"
source "${IDF_PATH}/export.sh"
idf.py set-target "$TARGET"
idf.py build
if [[ -n "$PORT" ]]; then
  idf.py -p "$PORT" flash monitor
else
  echo "Build complete. Flash with: idf.py -p PORT flash monitor"
fi
