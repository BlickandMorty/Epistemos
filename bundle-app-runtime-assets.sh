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
DEFAULT_SKILLS_SOURCE_DIR="$SRCROOT/.agents/skills"
DEFAULT_SKILLS_DIR="$RESOURCES_DIR/DefaultSkills"

is_app_store_build() {
    [[ "${TARGET_NAME:-}" == "Epistemos-AppStore" ]] ||
        [[ "${PRODUCT_BUNDLE_IDENTIFIER:-}" == "com.epistemos.appstore" ]] ||
        [[ " ${SWIFT_ACTIVE_COMPILATION_CONDITIONS:-} " == *" EPISTEMOS_APP_STORE "* ]]
}

is_no_sign_build() {
    [[ "${CODE_SIGNING_ALLOWED:-}" == "NO" ]]
}

sanitize_app_store_resources() {
    rm -rf "$KNOWLEDGE_FUSION_DIR/Training/scripts"
    rm -rf "$KNOWLEDGE_FUSION_DIR/Alignment/scripts"
    rm -rf "$KNOWLEDGE_FUSION_DIR/MoLoRA"
    rm -rf "$KNOWLEDGE_FUSION_DIR/MOHAWK"
    rm -rf "$AGENT_RUNTIME_DIR"
    prune_nightbrain_launchagent

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

bundle_default_skills() {
    if [ ! -d "$DEFAULT_SKILLS_SOURCE_DIR" ]; then
        rm -rf "$DEFAULT_SKILLS_DIR"
        return
    fi

    mkdir -p "$DEFAULT_SKILLS_DIR"
    rsync -a --delete --prune-empty-dirs \
        --include='*/' \
        --include='SKILL.md' \
        --exclude='*' \
        "$DEFAULT_SKILLS_SOURCE_DIR/" \
        "$DEFAULT_SKILLS_DIR/"
}

prune_nightbrain_launchagent() {
    local plist_name="com.epistemos.nightbrain.plist"
    local contents_dir="${TARGET_BUILD_DIR}/${CONTENTS_FOLDER_PATH:-${WRAPPER_NAME:-}/Contents}"

    if [ -n "$contents_dir" ]; then
        rm -f "$contents_dir/Library/LaunchAgents/$plist_name"
        rmdir "$contents_dir/Library/LaunchAgents" 2>/dev/null || true
    fi

    rm -f "$RESOURCES_DIR/LaunchAgents/$plist_name"
    rmdir "$RESOURCES_DIR/LaunchAgents" 2>/dev/null || true
}

bundle_nightbrain_launchagent() {
    local plist_name="com.epistemos.nightbrain.plist"
    local source_plist="$SRCROOT/Epistemos/Resources/LaunchAgents/$plist_name"
    local contents_dir="${TARGET_BUILD_DIR}/${CONTENTS_FOLDER_PATH:-${WRAPPER_NAME:-}/Contents}"
    local launch_agents_dir="$contents_dir/Library/LaunchAgents"

    if [ ! -f "$source_plist" ] || [ -z "$contents_dir" ]; then
        return
    fi

    mkdir -p "$launch_agents_dir"
    cp "$source_plist" "$launch_agents_dir/$plist_name"
    rm -f "$RESOURCES_DIR/LaunchAgents/com.epistemos.nightbrain.plist"
    rmdir "$RESOURCES_DIR/LaunchAgents" 2>/dev/null || true
    echo "NightBrain LaunchAgent bundled at Contents/Library/LaunchAgents/$plist_name"
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
bundle_default_skills

if is_app_store_build; then
    sanitize_app_store_resources
    exit 0
fi

if is_no_sign_build; then
    prune_nightbrain_launchagent
    echo "NightBrain LaunchAgent skipped for no-sign local build"
else
    bundle_nightbrain_launchagent
fi

# train_knowledge.py / train_style.py removed 2026-06-18: QLoRA training is now
# in-process native (NativeLoRATrainer / MLXLLM.LoRATrain) — no Python script.
cp "$SRCROOT/Epistemos/KnowledgeFusion/Alignment/scripts/train_kto.py" \
    "$KNOWLEDGE_FUSION_DIR/Alignment/scripts/train_kto.py"
# molora_inference.py / sgmm_kernel.py removed 2026-06-18: the MoLoRA inference
# subprocess is gone (native NativeAdapterApply via LoRAContainer replaces it).
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
