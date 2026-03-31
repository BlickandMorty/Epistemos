#!/bin/bash
set -euo pipefail

# Release Preflight Verification Script
# Validates the app bundle before DMG packaging and distribution.
# Usage: bash scripts/release/release_preflight.sh [path/to/Epistemos.app]

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass() { echo -e "${GREEN}PASS${NC}: $1"; ((PASS++)); }
fail() { echo -e "${RED}FAIL${NC}: $1"; ((FAIL++)); }
warn() { echo -e "${YELLOW}WARN${NC}: $1"; ((WARN++)); }

APP_PATH="${1:-build/Epistemos.app}"

echo "======================================="
echo "Epistemos Release Preflight"
echo "======================================="
echo "App: $APP_PATH"
echo ""

# 1. Check app bundle exists
if [ -d "$APP_PATH" ]; then
    pass "App bundle exists"
else
    fail "App bundle not found at $APP_PATH"
    echo -e "\n${RED}Cannot continue. Build the app first.${NC}"
    exit 1
fi

# 2. Check Info.plist
PLIST="$APP_PATH/Contents/Info.plist"
if [ -f "$PLIST" ]; then
    pass "Info.plist exists"
    VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$PLIST" 2>/dev/null || echo "")
    BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$PLIST" 2>/dev/null || echo "")
    echo "     Version: $VERSION ($BUILD)"
else
    fail "Info.plist missing"
fi

# 3. Check executable
EXEC="$APP_PATH/Contents/MacOS/Epistemos"
if [ -x "$EXEC" ]; then
    pass "Main executable exists and is executable"
    ARCH=$(file "$EXEC" | grep -o "arm64\|x86_64" | sort -u | tr '\n' '+' | sed 's/+$//')
    echo "     Architecture: $ARCH"
else
    fail "Main executable missing or not executable"
fi

# 4. Check Rust dylibs
FRAMEWORKS="$APP_PATH/Contents/Frameworks"
for dylib in libomega_mcp.dylib libepistemos_core.dylib; do
    if [ -f "$FRAMEWORKS/$dylib" ]; then
        pass "Rust dylib: $dylib"
    else
        fail "Missing Rust dylib: $dylib"
    fi
done

# 5. Check static libs are NOT in the bundle (they should be linked, not shipped)
for lib in libgraph_engine.a libomega_ax.a; do
    if [ -f "$FRAMEWORKS/$lib" ]; then
        warn "Static lib in Frameworks (should be linked, not shipped): $lib"
    fi
done

# 6. Check Privacy Manifest
PRIVACY="$APP_PATH/Contents/Resources/PrivacyInfo.xcprivacy"
if [ -f "$PRIVACY" ]; then
    pass "PrivacyInfo.xcprivacy exists"
else
    warn "PrivacyInfo.xcprivacy missing (required for App Store, optional for direct distribution)"
fi

# 7. Check entitlements (if signed)
if codesign -d --entitlements :- "$APP_PATH" 2>/dev/null | grep -q "com.apple"; then
    pass "App is codesigned with entitlements"
else
    warn "App is not codesigned (acceptable for dev builds, required for distribution)"
fi

# 8. Check for debug symbols
if [ -d "$APP_PATH.dSYM" ] || find "$APP_PATH" -name "*.dSYM" -print -quit 2>/dev/null | grep -q .; then
    pass "dSYM debug symbols found"
else
    warn "No dSYM symbols found (crash reports will be unsymbolicated)"
fi

# 9. Check minimum OS version
if [ -f "$PLIST" ]; then
    MIN_OS=$(/usr/libexec/PlistBuddy -c "Print LSMinimumSystemVersion" "$PLIST" 2>/dev/null || echo "unknown")
    echo "     Minimum macOS: $MIN_OS"
fi

# 10. Check no model files accidentally bundled
MODEL_FILES=$(find "$APP_PATH" -name "*.gguf" -o -name "*.safetensors" -o -name "*.mlx" 2>/dev/null | wc -l | tr -d ' ')
if [ "$MODEL_FILES" -eq 0 ]; then
    pass "No model files in bundle"
else
    fail "Found $MODEL_FILES model file(s) in bundle (should not be shipped)"
fi

# 11. Check no .env or credentials
SECRETS=$(find "$APP_PATH" -name ".env" -o -name "credentials*" -o -name "*.key" 2>/dev/null | wc -l | tr -d ' ')
if [ "$SECRETS" -eq 0 ]; then
    pass "No secret files in bundle"
else
    fail "Found $SECRETS secret file(s) in bundle"
fi

# 12. Bundle size check
BUNDLE_SIZE=$(du -sh "$APP_PATH" | awk '{print $1}')
echo ""
echo "     Bundle size: $BUNDLE_SIZE"

echo ""
echo "======================================="
echo "Results: ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC}, ${YELLOW}$WARN warnings${NC}"
echo "======================================="

if [ "$FAIL" -gt 0 ]; then
    echo -e "${RED}PREFLIGHT FAILED — fix the above issues before release.${NC}"
    exit 1
else
    echo -e "${GREEN}PREFLIGHT PASSED — ready for DMG packaging.${NC}"
    exit 0
fi
