#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_ICON="$ROOT_DIR/Resources/ThreadRadarIcon.png"
OUTPUT_ICON="$ROOT_DIR/Resources/ThreadRadarIcon.icns"
TEMP_DIR="$(mktemp -d "$ROOT_DIR/.build/thread-radar-icon.XXXXXX")"
ICONSET_DIR="$TEMP_DIR/ThreadRadarIcon.iconset"

cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

if [ ! -f "$SOURCE_ICON" ]; then
  echo "Missing icon source: $SOURCE_ICON" >&2
  exit 1
fi

mkdir -p "$ICONSET_DIR"

for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$SOURCE_ICON" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null
  double_size=$((size * 2))
  sips -z "$double_size" "$double_size" "$SOURCE_ICON" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_ICON"
echo "Built icon: $OUTPUT_ICON"
