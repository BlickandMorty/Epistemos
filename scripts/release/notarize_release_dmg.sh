#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
DMG_PATH="${1:-}"
LOG_DIR="${2:-${LOG_DIR:-$ROOT_DIR/build/notary-logs}}"
NOTARY_PROFILE="${EPISTEMOS_NOTARY_PROFILE:-${NOTARYTOOL_PROFILE:-}}"
APPLE_ID="${EPISTEMOS_NOTARY_APPLE_ID:-${APPLE_ID:-}}"
TEAM_ID="${EPISTEMOS_NOTARY_TEAM_ID:-${TEAM_ID:-}}"
PASSWORD="${EPISTEMOS_NOTARY_PASSWORD:-${APPLE_APP_SPECIFIC_PASSWORD:-}}"

if [ -z "$DMG_PATH" ]; then
    echo "Usage: $0 /absolute/path/to/Epistemos.dmg [log-dir]" >&2
    exit 1
fi

if [ ! -f "$DMG_PATH" ]; then
    echo "DMG not found at $DMG_PATH" >&2
    exit 1
fi

mkdir -p "$LOG_DIR"

notary_args() {
    if [ -n "$NOTARY_PROFILE" ]; then
        AUTH_ARGS=(--keychain-profile "$NOTARY_PROFILE")
        return
    fi

    if [ -n "$APPLE_ID" ] && [ -n "$TEAM_ID" ] && [ -n "$PASSWORD" ]; then
        AUTH_ARGS=(--apple-id "$APPLE_ID" --team-id "$TEAM_ID" --password "$PASSWORD")
        return
    fi

    echo "Provide EPISTEMOS_NOTARY_PROFILE or EPISTEMOS_NOTARY_APPLE_ID/EPISTEMOS_NOTARY_TEAM_ID/EPISTEMOS_NOTARY_PASSWORD." >&2
    exit 1
}

AUTH_ARGS=()
notary_args

echo "Submitting DMG for notarization: $DMG_PATH"
SUBMISSION_OUTPUT="$(
    xcrun notarytool submit "$DMG_PATH" \
        "${AUTH_ARGS[@]}" \
        --wait \
        --output-format json
)"

echo "$SUBMISSION_OUTPUT"

SUBMISSION_ID="$(
    printf '%s' "$SUBMISSION_OUTPUT" | plutil -extract id raw -o - - 2>/dev/null || true
)"

if [ -n "$SUBMISSION_ID" ]; then
    xcrun notarytool log "$SUBMISSION_ID" "${AUTH_ARGS[@]}" "$LOG_DIR/${SUBMISSION_ID}.json"
    echo "Notary log saved at: $LOG_DIR/${SUBMISSION_ID}.json"
fi

xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
spctl -a -vv -t open "$DMG_PATH"

echo "Notarized DMG ready at: $DMG_PATH"
