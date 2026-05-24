#!/usr/bin/env bash
# Generate aLaunchpad/Resources/AppIcon.icns from a programmatic Swift drawing.
set -euo pipefail

ICONSET_DIR="build/AppIcon.iconset"
OUT_DIR="aLaunchpad/Resources"
OUT_ICNS="$OUT_DIR/AppIcon.icns"

mkdir -p "$ICONSET_DIR" "$OUT_DIR"

echo "==> Drawing PNGs"
swift Scripts/MakeIcon.swift "$ICONSET_DIR"

echo "==> Packing $OUT_ICNS"
iconutil -c icns "$ICONSET_DIR" -o "$OUT_ICNS"

echo "==> Done"
