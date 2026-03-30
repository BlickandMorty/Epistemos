#!/bin/bash
set -euo pipefail

if [ -z "${TARGET_BUILD_DIR:-}" ] || [ -z "${UNLOCALIZED_RESOURCES_FOLDER_PATH:-}" ]; then
    exit 0
fi

RESOURCES_DIR="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH"
KNOWLEDGE_FUSION_DIR="$RESOURCES_DIR/KnowledgeFusion"
AGENT_RUNTIME_DIR="$RESOURCES_DIR/AgentRuntime"
HERMES_RUNTIME_DIR="$AGENT_RUNTIME_DIR/hermes-agent"

rm -rf "$KNOWLEDGE_FUSION_DIR/Training/scripts"
rm -rf "$KNOWLEDGE_FUSION_DIR/Alignment/scripts"
rm -rf "$KNOWLEDGE_FUSION_DIR/MoLoRA"
rm -rf "$KNOWLEDGE_FUSION_DIR/MOHAWK"

mkdir -p "$KNOWLEDGE_FUSION_DIR/Training/scripts"
mkdir -p "$KNOWLEDGE_FUSION_DIR/Alignment/scripts"
mkdir -p "$KNOWLEDGE_FUSION_DIR/MoLoRA"
mkdir -p "$KNOWLEDGE_FUSION_DIR/MOHAWK/embodied_data"
mkdir -p "$AGENT_RUNTIME_DIR"

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
