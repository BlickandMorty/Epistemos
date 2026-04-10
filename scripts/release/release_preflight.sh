#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass() { echo -e "${GREEN}PASS${NC}: $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC}: $1"; FAIL=$((FAIL + 1)); }
warn() { echo -e "${YELLOW}WARN${NC}: $1"; WARN=$((WARN + 1)); }

require_file() {
    local path="$1"
    local label="$2"
    if [ -f "$path" ]; then
        pass "$label"
    else
        fail "$label missing at $path"
    fi
}

APP_PATH="${1:-build/Epistemos.app}"
FRAMEWORKS="$APP_PATH/Contents/Frameworks"
RESOURCES="$APP_PATH/Contents/Resources"
PLIST="$APP_PATH/Contents/Info.plist"
EXEC="$APP_PATH/Contents/MacOS/Epistemos"

echo "======================================="
echo "Epistemos Release Preflight"
echo "======================================="
echo "App: $APP_PATH"
echo ""

if [ ! -d "$APP_PATH" ]; then
    fail "App bundle not found at $APP_PATH"
    echo -e "\n${RED}Cannot continue. Build the app first.${NC}"
    exit 1
fi
pass "App bundle exists"

if [ -f "$PLIST" ]; then
    pass "Info.plist exists"
    VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$PLIST" 2>/dev/null || echo "")
    BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$PLIST" 2>/dev/null || echo "")
    MIN_OS=$(/usr/libexec/PlistBuddy -c "Print LSMinimumSystemVersion" "$PLIST" 2>/dev/null || echo "unknown")
    echo "     Version: $VERSION ($BUILD)"
    echo "     Minimum macOS: $MIN_OS"
else
    fail "Info.plist missing"
fi

if [ -x "$EXEC" ]; then
    pass "Main executable exists and is executable"
    ARCH=$(file "$EXEC" | grep -o "arm64\|x86_64" | sort -u | tr '\n' '+' | sed 's/+$//')
    echo "     Architecture: $ARCH"
else
    fail "Main executable missing or not executable"
fi

require_file "$FRAMEWORKS/libepistemos_core.dylib" "Rust dylib: libepistemos_core.dylib"
require_file "$FRAMEWORKS/libagent_core.dylib" "Rust dylib: libagent_core.dylib"
require_file "$FRAMEWORKS/libomega_mcp.dylib" "Rust dylib: libomega_mcp.dylib"
require_file "$FRAMEWORKS/libomega_ax.dylib" "Rust dylib: libomega_ax.dylib"

for lib in libgraph_engine.a libomega_ax.a; do
    if [ -f "$FRAMEWORKS/$lib" ]; then
        warn "Static lib in Frameworks (should be linked, not shipped): $lib"
    fi
done

require_file "$RESOURCES/model_manifest.json" "Resource: model_manifest.json"
require_file "$RESOURCES/RetroGaming.ttf" "Resource: RetroGaming.ttf"
require_file "$RESOURCES/PrivacyInfo.xcprivacy" "Resource: PrivacyInfo.xcprivacy"
require_file "$RESOURCES/KnowledgeFusion/Training/scripts/train_knowledge.py" "Knowledge Fusion training script: train_knowledge.py"
require_file "$RESOURCES/KnowledgeFusion/Training/scripts/train_style.py" "Knowledge Fusion training script: train_style.py"
require_file "$RESOURCES/KnowledgeFusion/Alignment/scripts/train_kto.py" "Knowledge Fusion alignment script: train_kto.py"
require_file "$RESOURCES/KnowledgeFusion/MoLoRA/molora_inference.py" "Knowledge Fusion MoLoRA runtime: molora_inference.py"
require_file "$RESOURCES/KnowledgeFusion/MoLoRA/sgmm_kernel.py" "Knowledge Fusion MoLoRA runtime: sgmm_kernel.py"
require_file "$RESOURCES/KnowledgeFusion/MOHAWK/eval_bfcl.py" "Knowledge Fusion MOHAWK eval: eval_bfcl.py"
require_file "$RESOURCES/KnowledgeFusion/MOHAWK/embodied_data/bfcl_eval_macos.jsonl" "Knowledge Fusion embodied eval data: bfcl_eval_macos.jsonl"

if [ -d "$APP_PATH/Contents/PlugIns" ]; then
    fail "Unexpected Contents/PlugIns directory present"
else
    pass "No unexpected Contents/PlugIns directory"
fi

codesign_details="$(codesign -dv --verbose=4 "$APP_PATH" 2>&1 || true)"
signature_kind="$(printf '%s\n' "$codesign_details" | awk -F= '/^Signature=/{print $2; exit}')"
team_identifier="$(printf '%s\n' "$codesign_details" | awk -F= '/^TeamIdentifier=/{print $2; exit}')"

if [ -n "$signature_kind" ]; then
    if codesign --verify --deep --strict --verbose=4 "$APP_PATH" >/dev/null 2>&1; then
        pass "App signature verifies with codesign --verify --deep --strict"
    elif [ "$signature_kind" = "adhoc" ] || [ "$team_identifier" = "not set" ]; then
        warn "App uses an ad-hoc/local signature only; deep codesign verification is expected to fail until distribution signing runs"
    else
        fail "App bundle is signed but codesign verification failed"
    fi
else
    warn "App is not codesigned (acceptable for local verification, required for distribution)"
fi

if [ -d "$APP_PATH.dSYM" ] || find "$APP_PATH" -name "*.dSYM" -print -quit 2>/dev/null | grep -q .; then
    pass "dSYM debug symbols found"
else
    warn "No dSYM symbols found (crash reports will be unsymbolicated)"
fi

MODEL_FILES=$(find "$APP_PATH" \( -name "*.gguf" -o -name "*.safetensors" -o -name "*.mlx" \) 2>/dev/null | wc -l | tr -d ' ')
if [ "$MODEL_FILES" -eq 0 ]; then
    pass "No model files in bundle"
else
    fail "Found $MODEL_FILES model file(s) in bundle (should not be shipped)"
fi

SECRETS=$(find "$APP_PATH" \( -name ".env" -o -name "credentials*" -o -name "*.key" \) 2>/dev/null | wc -l | tr -d ' ')
if [ "$SECRETS" -eq 0 ]; then
    pass "No secret files in bundle"
else
    fail "Found $SECRETS secret file(s) in bundle"
fi

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
fi

echo -e "${GREEN}PREFLIGHT PASSED — ready for DMG packaging.${NC}"
