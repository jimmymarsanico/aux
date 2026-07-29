#!/usr/bin/env bash
#
# Packages build/Aux.app into dist/Aux-<version>.dmg with an /Applications
# symlink for drag-and-drop install.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Aux.app"
if [ ! -d "$APP" ]; then
  echo "error: $APP not found — run Scripts/build_app.sh first" >&2
  exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Support/Info.plist)
DMG="dist/Aux-$VERSION.dmg"

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

mkdir -p dist
rm -f "$DMG"
hdiutil create -volname "Aux" -srcfolder "$STAGE" -ov -format UDZO "$DMG"

echo "==> Done: $DMG"
