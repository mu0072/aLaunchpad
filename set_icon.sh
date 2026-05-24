#!/usr/bin/env bash
# Pack a user-supplied PNG into aLaunchpad/Resources/AppIcon.icns at all
# 10 macOS-required iconset sizes. Use this instead of make_icon.sh when
# you want a custom designed icon rather than the programmatic one.
#
# Usage: ./set_icon.sh path/to/icon.png
#
# The source PNG should ideally be 1024×1024 square and already contain
# whatever shape / rounded corners you want (macOS does NOT auto-mask).
set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 path/to/icon.png" >&2
    exit 1
fi

SRC="$1"
if [ ! -f "$SRC" ]; then
    echo "File not found: $SRC" >&2
    exit 1
fi

# Sanity-check: it's actually a PNG
if ! file "$SRC" | grep -qi 'PNG image'; then
    echo "Not a PNG: $SRC" >&2
    exit 1
fi

# Warn if smaller than 1024 — upscaling will look soft
W=$(sips -g pixelWidth "$SRC" | tail -1 | awk '{print $2}')
H=$(sips -g pixelHeight "$SRC" | tail -1 | awk '{print $2}')
if [ "$W" != "$H" ]; then
    echo "Warning: source is ${W}×${H}, not square — sips will stretch." >&2
fi
if [ "$W" -lt 1024 ] || [ "$H" -lt 1024 ]; then
    echo "Warning: source is ${W}×${H}; 1024+ recommended for crisp Retina." >&2
fi

ICONSET_DIR="build/AppIcon.iconset"
OUT_DIR="aLaunchpad/Resources"
OUT_ICNS="$OUT_DIR/AppIcon.icns"
mkdir -p "$ICONSET_DIR" "$OUT_DIR"
rm -f "$ICONSET_DIR"/*.png

# Apple's required iconset filenames + pixel sizes
declare -a SIZES=(
    "16:icon_16x16"
    "32:icon_16x16@2x"
    "32:icon_32x32"
    "64:icon_32x32@2x"
    "128:icon_128x128"
    "256:icon_128x128@2x"
    "256:icon_256x256"
    "512:icon_256x256@2x"
    "512:icon_512x512"
    "1024:icon_512x512@2x"
)

echo "==> Resizing $SRC into 10 PNGs"
for entry in "${SIZES[@]}"; do
    px=${entry%%:*}
    name=${entry#*:}
    sips -z "$px" "$px" "$SRC" --out "$ICONSET_DIR/${name}.png" >/dev/null
done

echo "==> Packing $OUT_ICNS"
iconutil -c icns "$ICONSET_DIR" -o "$OUT_ICNS"

echo "==> Done"
echo "Now rebuild + install:  ./build.sh && cp -R build/aLaunchpad.app /Applications/"
