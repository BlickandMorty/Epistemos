#!/bin/bash
set -euo pipefail

if [ -z "${TARGET_BUILD_DIR:-}" ] || [ -z "${UNLOCALIZED_RESOURCES_FOLDER_PATH:-}" ]; then
    exit 0
fi

RESOURCES_DIR="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH"
KNOWLEDGE_FUSION_DIR="$RESOURCES_DIR/KnowledgeFusion"
AGENT_RUNTIME_DIR="$RESOURCES_DIR/AgentRuntime"
HERMES_RUNTIME_DIR="$AGENT_RUNTIME_DIR/hermes-agent"
EDITOR_SOURCE_DIR="$SRCROOT/Epistemos/Resources/Editor"
EDITOR_BUNDLE_DIR="$RESOURCES_DIR/Editor"

is_app_store_build() {
    [[ "${TARGET_NAME:-}" == "Epistemos-AppStore" ]] ||
        [[ "${PRODUCT_BUNDLE_IDENTIFIER:-}" == "com.epistemos.appstore" ]] ||
        [[ " ${SWIFT_ACTIVE_COMPILATION_CONDITIONS:-} " == *" EPISTEMOS_APP_STORE "* ]]
}

sanitize_app_store_resources() {
    rm -rf "$KNOWLEDGE_FUSION_DIR/Training/scripts"
    rm -rf "$KNOWLEDGE_FUSION_DIR/Alignment/scripts"
    rm -rf "$KNOWLEDGE_FUSION_DIR/MoLoRA"
    rm -rf "$KNOWLEDGE_FUSION_DIR/MOHAWK"
    rm -rf "$AGENT_RUNTIME_DIR"

    find "$RESOURCES_DIR" -type f \( \
        -name '*.py' -o \
        -name '*.pyc' -o \
        -name '*.pyo' \
    \) -delete

    find "$RESOURCES_DIR" -type d \( \
        -name '__pycache__' -o \
        -name '.pytest_cache' \
    \) -prune -exec rm -rf {} +

    find "$KNOWLEDGE_FUSION_DIR" -depth -type d -empty -delete 2>/dev/null || true
}

bundle_editor_resources() {
    if [ ! -d "$EDITOR_SOURCE_DIR" ]; then
        return
    fi

    mkdir -p "$EDITOR_BUNDLE_DIR"
    rsync -a --delete "$EDITOR_SOURCE_DIR/" "$EDITOR_BUNDLE_DIR/"

    # Xcode's synchronized resource groups flatten generated editor files
    # into Contents/Resources. Keep the canonical Resources/Editor tree and
    # remove the duplicate root-level copies so the bundle stays small.
    while IFS= read -r -d '' source_file; do
        rm -f "$RESOURCES_DIR/$(basename "$source_file")"
    done < <(find "$EDITOR_SOURCE_DIR" -type f -print0)
}

rm -rf "$KNOWLEDGE_FUSION_DIR/Training/scripts"
rm -rf "$KNOWLEDGE_FUSION_DIR/Alignment/scripts"
rm -rf "$KNOWLEDGE_FUSION_DIR/MoLoRA"
rm -rf "$KNOWLEDGE_FUSION_DIR/MOHAWK"

mkdir -p "$KNOWLEDGE_FUSION_DIR/Training/scripts"
mkdir -p "$KNOWLEDGE_FUSION_DIR/Alignment/scripts"
mkdir -p "$KNOWLEDGE_FUSION_DIR/MoLoRA"
mkdir -p "$KNOWLEDGE_FUSION_DIR/MOHAWK/embodied_data"
mkdir -p "$AGENT_RUNTIME_DIR"

cp "$SRCROOT/config/model_manifest.json" \
    "$RESOURCES_DIR/model_manifest.json"

bundle_editor_resources

if is_app_store_build; then
    sanitize_app_store_resources
    exit 0
fi

cp "$SRCROOT/Epistemos/KnowledgeFusion/Training/scripts/train_knowledge.py" \
    "$KNOWLEDGE_FUSION_DIR/Training/scripts/train_knowledge.py"
cp "$SRCROOT/Epistemos/KnowledgeFusion/Training/scripts/train_style.py" \
    "$KNOWLEDGE_FUSION_DIR/Training/scripts/train_style.py"
cp "$SRCROOT/Epistemos/KnowledgeFusion/Alignment/scripts/train_kto.py" \
    "$KNOWLEDGE_FUSION_DIR/Alignment/scripts/train_kto.py"
cp "$SRCROOT/Epistemos/KnowledgeFusion/MoLoRA/molora_inference.py" \
    "$KNOWLEDGE_FUSION_DIR/MoLoRA/molora_inference.py"
cp "$SRCROOT/Epistemos/KnowledgeFusion/MoLoRA/sgmm_kernel.py" \
    "$KNOWLEDGE_FUSION_DIR/MoLoRA/sgmm_kernel.py"
cp "$SRCROOT/Epistemos/KnowledgeFusion/MOHAWK/eval_bfcl.py" \
    "$KNOWLEDGE_FUSION_DIR/MOHAWK/eval_bfcl.py"
cp "$SRCROOT/Epistemos/KnowledgeFusion/MOHAWK/embodied_data/bfcl_eval_macos.jsonl" \
    "$KNOWLEDGE_FUSION_DIR/MOHAWK/embodied_data/bfcl_eval_macos.jsonl"

if [ -d "$SRCROOT/hermes-agent" ]; then
    rm -rf "$HERMES_RUNTIME_DIR"
    rsync -a \
        --delete \
        --exclude '.git' \
        --exclude '.venv' \
        --exclude '__pycache__' \
        --exclude 'tests' \
        --exclude 'website' \
        --exclude 'node_modules' \
        --exclude '.plans' \
        "$SRCROOT/hermes-agent/" \
        "$HERMES_RUNTIME_DIR/"
fi
