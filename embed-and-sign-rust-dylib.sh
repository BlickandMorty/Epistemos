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
    exit 0
fi

SIGNING_IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY:--}"
/usr/bin/codesign --force --sign "$SIGNING_IDENTITY" --timestamp=none --generate-entitlement-der "$DEST_DYLIB"
