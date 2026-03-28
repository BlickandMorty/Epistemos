#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
DERIVED_DATA_PATH="${1:-/tmp/epistemos-release-preflight}"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug/Epistemos.app"

if [ -f "$HOME/.cargo/env" ]; then
    # shellcheck disable=SC1090
    source "$HOME/.cargo/env"
fi

cd "$ROOT_DIR"

echo "== Release preflight =="
echo "Root: $ROOT_DIR"
echo "DerivedData: $DERIVED_DATA_PATH"

git diff --check

(
    cd epistemos-core
    cargo test
)

(
    cd graph-engine
    cargo test
)

(
    cd omega-mcp
    cargo test
)

(
    cd omega-ax
    cargo test
)

rm -rf "$DERIVED_DATA_PATH"

xcodebuild -quiet \
    -project Epistemos.xcodeproj \
    -scheme Epistemos \
    -configuration Debug \
    -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    build

xcodebuild -quiet \
    -project Epistemos.xcodeproj \
    -scheme Epistemos \
    -destination 'platform=macOS' \
    test \
    -only-testing:EpistemosTests/RuntimeValidationTests

codesign --verify --deep --strict --verbose=4 "$APP_PATH"

test -f "$APP_PATH/Contents/Frameworks/libepistemos_core.dylib"
test -f "$APP_PATH/Contents/Frameworks/libomega_mcp.dylib"
test -f "$APP_PATH/Contents/Frameworks/libomega_ax.dylib"
test -f "$APP_PATH/Contents/Resources/model_manifest.json"
test -f "$APP_PATH/Contents/Resources/RetroGaming.ttf"
test -f "$APP_PATH/Contents/Resources/PrivacyInfo.xcprivacy"
test -f "$APP_PATH/Contents/Resources/KnowledgeFusion/Training/scripts/train_knowledge.py"
test -f "$APP_PATH/Contents/Resources/KnowledgeFusion/Training/scripts/train_style.py"
test -f "$APP_PATH/Contents/Resources/KnowledgeFusion/Alignment/scripts/train_kto.py"
test -f "$APP_PATH/Contents/Resources/KnowledgeFusion/MoLoRA/molora_inference.py"
test -f "$APP_PATH/Contents/Resources/KnowledgeFusion/MoLoRA/sgmm_kernel.py"
test -f "$APP_PATH/Contents/Resources/KnowledgeFusion/MOHAWK/eval_bfcl.py"
test -f "$APP_PATH/Contents/Resources/KnowledgeFusion/MOHAWK/embodied_data/bfcl_eval_macos.jsonl"

if [ -d "$APP_PATH/Contents/PlugIns" ]; then
    echo "FAIL: unexpected PlugIns directory in app bundle" >&2
    exit 1
fi

echo "PASS: release preflight complete"
echo "App: $APP_PATH"
