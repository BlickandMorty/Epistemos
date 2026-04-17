#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/build/release-derived-data}"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Release/Epistemos.app"
ENTITLEMENTS_PATH="${ENTITLEMENTS_PATH:-$ROOT_DIR/Epistemos/Epistemos.entitlements}"
SIGNING_IDENTITY="${EPISTEMOS_SIGNING_IDENTITY:-${SIGNING_IDENTITY:-}}"
SHARED_SOURCE_PACKAGES_PATH="${SHARED_SOURCE_PACKAGES_PATH:-}"
PACKAGE_CACHE_PATH="${PACKAGE_CACHE_PATH:-}"
PACKAGE_ARGS=()

echo "== Build Release App =="
echo "Root: $ROOT_DIR"
echo "DerivedData: $DERIVED_DATA_PATH"
echo "SourcePackages: ${SHARED_SOURCE_PACKAGES_PATH:-<xcode-managed default>}"
echo "PackageCache: ${PACKAGE_CACHE_PATH:-<xcode-managed default>}"

rm -rf "$DERIVED_DATA_PATH"

if [ -n "$SHARED_SOURCE_PACKAGES_PATH" ]; then
    mkdir -p "$SHARED_SOURCE_PACKAGES_PATH"
    PACKAGE_ARGS+=(-clonedSourcePackagesDirPath "$SHARED_SOURCE_PACKAGES_PATH")
fi

if [ -n "$PACKAGE_CACHE_PATH" ]; then
    mkdir -p "$PACKAGE_CACHE_PATH"
    PACKAGE_ARGS+=(-packageCachePath "$PACKAGE_CACHE_PATH")
fi

cd "$ROOT_DIR"

XCODEBUILD_ARGS=(
    -project Epistemos.xcodeproj
    -scheme Epistemos
    -configuration Release
    -destination 'platform=macOS'
    -derivedDataPath "$DERIVED_DATA_PATH"
)

if [ "${#PACKAGE_ARGS[@]}" -gt 0 ]; then
    XCODEBUILD_ARGS+=("${PACKAGE_ARGS[@]}")
fi

XCODEBUILD_ARGS+=(
    CODE_SIGNING_ALLOWED=NO
    build
)

"$ROOT_DIR/scripts/xcodebuild_epistemos.sh" "${XCODEBUILD_ARGS[@]}"

if [ ! -d "$APP_PATH" ]; then
    echo "Release app missing at $APP_PATH" >&2
    exit 1
fi

if [ -n "$SIGNING_IDENTITY" ]; then
    echo "Signing release app with Developer ID Application identity: $SIGNING_IDENTITY"
    while IFS= read -r -d '' dylib; do
        codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$dylib"
    done < <(find "$APP_PATH/Contents/Frameworks" -type f -name "*.dylib" -print0)

    codesign \
        --force \
        --options runtime \
        --timestamp \
        --entitlements "$ENTITLEMENTS_PATH" \
        --sign "$SIGNING_IDENTITY" \
        "$APP_PATH"

    codesign --verify --deep --strict --verbose=4 "$APP_PATH"
else
    echo "No signing identity provided. Export EPISTEMOS_SIGNING_IDENTITY='Developer ID Application: ...' for a distributable build."
fi

bash "$ROOT_DIR/scripts/release/release_preflight.sh" "$APP_PATH"

echo "Release app ready at: $APP_PATH"
