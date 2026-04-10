#!/bin/bash
set -euo pipefail

if [ $# -ne 2 ]; then
    echo "usage: $0 <source-dylib> <destination-dylib>" >&2
    exit 64
fi

SOURCE_DYLIB="$1"
DEST_DYLIB="$2"

mkdir -p "$(dirname "$DEST_DYLIB")"
cp "$SOURCE_DYLIB" "$DEST_DYLIB"

if [ "${CODE_SIGNING_ALLOWED:-NO}" != "YES" ]; then
    /usr/bin/codesign --remove-signature "$DEST_DYLIB" 2>/dev/null || true
    /usr/bin/codesign --force --sign - --timestamp=none "$DEST_DYLIB"
    exit 0
fi

SIGNING_IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY:--}"

# Strip existing signature first to avoid "slice already exists" errors on re-sign
/usr/bin/codesign --remove-signature "$DEST_DYLIB" 2>/dev/null || true

# Use the same entitlements as the parent app so the dylib's cdhash
# matches what TCC/AMFI expect for sandbox inheritance.
ENTITLEMENTS_FLAG=""
if [ -n "${CODE_SIGN_ENTITLEMENTS:-}" ] && [ -f "${CODE_SIGN_ENTITLEMENTS}" ]; then
    ENTITLEMENTS_FLAG="--entitlements ${CODE_SIGN_ENTITLEMENTS}"
fi

/usr/bin/codesign --force --sign "$SIGNING_IDENTITY" \
    --timestamp=none \
    --generate-entitlement-der \
    --options runtime \
    $ENTITLEMENTS_FLAG \
    "$DEST_DYLIB"
