#!/usr/bin/env bash
#
# Builds Aux.app into build/. Tries a universal (arm64 + x86_64) build first
# and falls back to the native architecture when only the Command Line Tools
# are installed.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Aux"
APP="build/$APP_NAME.app"

echo "==> Compiling"
if swift build -c release --arch arm64 --arch x86_64 2>/dev/null; then
  BINARY=".build/apple/Products/Release/$APP_NAME"
else
  echo "==> Universal build unavailable; building for the native architecture"
  swift build -c release
  BINARY=".build/release/$APP_NAME"
fi

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/$APP_NAME"
cp Support/Info.plist "$APP/Contents/Info.plist"
cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "==> Signing (ad-hoc)"
codesign --force --sign - "$APP"

echo "==> Done: $APP"
