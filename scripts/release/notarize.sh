#!/usr/bin/env bash
# Local notarization script for Epistemos.
# Usage: ./scripts/release/notarize.sh build/Epistemos.dmg
#
# Prerequisites:
#   export APPLE_ID="your@email.com"
#   export NOTARIZATION_PASSWORD="app-specific-password"
#   export TEAM_ID="XXXXXXXXXX"
#   export DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (XXXXXXXXXX)"

set -euo pipefail

DMG_PATH="${1:?Usage: notarize.sh <path-to-dmg>}"

if [ ! -f "$DMG_PATH" ]; then
    echo "Error: DMG not found at $DMG_PATH"
    exit 1
fi

echo "=== Epistemos Notarization ==="
echo "DMG: $DMG_PATH"

# Step 1: Codesign the app inside the DMG (if not already signed)
if [ -n "${DEVELOPER_ID_APPLICATION:-}" ]; then
    echo "Codesigning..."
    # Mount DMG, codesign, unmount
    MOUNT_POINT=$(hdiutil attach "$DMG_PATH" -nobrowse | tail -1 | awk '{print $3}')
    if [ -d "$MOUNT_POINT/Epistemos.app" ]; then
        codesign --deep --force --options runtime \
            --sign "$DEVELOPER_ID_APPLICATION" \
            --entitlements Epistemos/Epistemos.entitlements \
            "$MOUNT_POINT/Epistemos.app" || echo "Warning: codesign failed (may already be signed)"
    fi
    hdiutil detach "$MOUNT_POINT" -quiet || true
fi

# Step 2: Submit for notarization
echo "Submitting for notarization..."
xcrun notarytool submit "$DMG_PATH" \
    --apple-id "${APPLE_ID:?Set APPLE_ID}" \
    --password "${NOTARIZATION_PASSWORD:?Set NOTARIZATION_PASSWORD}" \
    --team-id "${TEAM_ID:?Set TEAM_ID}" \
    --wait

# Step 3: Staple the ticket
echo "Stapling notarization ticket..."
xcrun stapler staple "$DMG_PATH"

echo "=== Notarization complete ==="
echo "DMG is ready for distribution: $DMG_PATH"
