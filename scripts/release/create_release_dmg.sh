#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
APP_PATH="${1:-${APP_PATH:-$ROOT_DIR/build/release-derived-data/Build/Products/Release/Epistemos.app}}"
OUTPUT_DIR="${2:-${OUTPUT_DIR:-$ROOT_DIR/build/release-artifacts}}"
DMG_NAME="${DMG_NAME:-Epistemos}"
DMG_PATH="$OUTPUT_DIR/${DMG_NAME}.dmg"
TEMP_DMG="$OUTPUT_DIR/${DMG_NAME}-temp.dmg"
STAGING_DIR="$OUTPUT_DIR/${DMG_NAME}-staging"
SIGNING_IDENTITY="${EPISTEMOS_SIGNING_IDENTITY:-${SIGNING_IDENTITY:-}}"

mkdir -p "$OUTPUT_DIR"
rm -rf "$STAGING_DIR" "$TEMP_DMG" "$DMG_PATH"

bash "$ROOT_DIR/scripts/release/release_preflight.sh" "$APP_PATH"

mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
    -volname "Epistemos" \
    -srcfolder "$STAGING_DIR" \
    -fs HFS+ \
    -format UDRW \
    "$TEMP_DMG"

hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH"
rm -f "$TEMP_DMG"
rm -rf "$STAGING_DIR"

if [ -n "$SIGNING_IDENTITY" ]; then
    codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$DMG_PATH"
    spctl -a -vv -t open "$DMG_PATH"
else
    echo "DMG created unsigned at $DMG_PATH"
fi

shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"

echo "Release DMG ready at: $DMG_PATH"
echo "SHA-256 saved at: $DMG_PATH.sha256"
