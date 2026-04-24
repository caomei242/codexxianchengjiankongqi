#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESKTOP_DIR="$HOME/Desktop"
APP_NAME="codex线程监控器"
SOURCE_APP="$ROOT_DIR/dist/$APP_NAME.app"
TARGET_APP="$DESKTOP_DIR/$APP_NAME.app"

"$ROOT_DIR/script/build_thread_radar.sh" --verify
pkill -x CodexThreadRadar >/dev/null 2>&1 || true

rm -rf "$TARGET_APP"
cp -R "$SOURCE_APP" "$TARGET_APP"

echo "Installed to: $TARGET_APP"
