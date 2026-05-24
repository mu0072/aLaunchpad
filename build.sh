#!/usr/bin/env bash
# Build aLaunchpad.app without needing an Xcode project.
# Compiles all Swift sources with swiftc and assembles a minimal .app bundle.
set -euo pipefail

APP_NAME="aLaunchpad"
SRC_DIR="aLaunchpad"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"
ICNS="$SRC_DIR/Resources/AppIcon.icns"
ICON_PNG="$SRC_DIR/Resources/AppIcon.png"

DEPLOYMENT_TARGET="macos13.0"

echo "==> Cleaning $BUILD_DIR/$APP_NAME.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

if [ ! -f "$ICNS" ]; then
    if [ -f "$ICON_PNG" ]; then
        echo "==> Packing $ICON_PNG into AppIcon.icns"
        ./set_icon.sh "$ICON_PNG"
    else
        echo "==> AppIcon.icns missing — generating programmatic icon"
        ./make_icon.sh
    fi
fi

echo "==> Collecting Swift sources"
SWIFT_FILES=()
while IFS= read -r f; do SWIFT_FILES+=("$f"); done < <(find "$SRC_DIR" -name "*.swift" -type f)

if [ ${#SWIFT_FILES[@]} -eq 0 ]; then
    echo "No Swift sources found under $SRC_DIR" >&2
    exit 1
fi

compile_arch() {
    local arch="$1"
    local out="$2"
    echo "==> Compiling for ${arch}-apple-${DEPLOYMENT_TARGET}"
    xcrun swiftc \
        -target "${arch}-apple-${DEPLOYMENT_TARGET}" \
        -O \
        -parse-as-library \
        -framework AppKit \
        -framework SwiftUI \
        -framework Carbon \
        -o "$out" \
        "${SWIFT_FILES[@]}"
}

if [ "${UNIVERSAL:-0}" = "1" ]; then
    TMP_ARM="$BUILD_DIR/.aLaunchpad-arm64"
    TMP_X86="$BUILD_DIR/.aLaunchpad-x86_64"
    compile_arch "arm64"  "$TMP_ARM"
    compile_arch "x86_64" "$TMP_X86"
    echo "==> lipo -create → universal binary"
    lipo -create "$TMP_ARM" "$TMP_X86" -output "$MACOS_DIR/$APP_NAME"
    rm -f "$TMP_ARM" "$TMP_X86"
    lipo -info "$MACOS_DIR/$APP_NAME"
else
    HOST_ARCH=$(uname -m)
    compile_arch "$HOST_ARCH" "$MACOS_DIR/$APP_NAME"
fi

echo "==> Copying Info.plist + AppIcon.icns"
cp "$SRC_DIR/Info.plist" "$CONTENTS/Info.plist"
cp "$ICNS" "$RESOURCES_DIR/AppIcon.icns"

# Ad-hoc sign so macOS doesn't quarantine on every launch in dev.
codesign --force --sign - "$APP_BUNDLE" >/dev/null 2>&1 || true

echo "==> Done: $APP_BUNDLE"
echo "Run: open $APP_BUNDLE"
