#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#  Epistemos Full Training Pipeline — MOHAWK + SFT + MLX Convert
# ═══════════════════════════════════════════════════════════════
#
# This script runs the COMPLETE training pipeline:
#   Phase 0: Generate + validate training data locally
#   Phase 1: Find RunPod pod
#   Phase 2: Upload scripts and VALIDATED data
#   Phase 3: Install deps
#   Phase 4: Run MOHAWK 3-stage distillation
#   Phase 5: SFT specialization (auto or manual)
#
# Usage:
#   cd Epistemos/KnowledgeFusion/MOHAWK
#   ./runpod_full_pipeline.sh nano
#
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

TIER="${1:-nano}"
SSH_KEY="${SSH_KEY:-$HOME/.runpod/ssh/RunPod-Key-Go}"

# Raw and validated dirs are SEPARATE. Scripts always train on validated.
RAW_DATA_DIR="./epistemos_training_data"
VALIDATED_DATA_DIR="./epistemos_training_data_validated"
# Remote path on RunPod — receives ONLY validated data
REMOTE_DATA_DIR="/workspace/epistemos_validated"

echo "═══════════════════════════════════════════════════════════"
echo "  Epistemos Full Pipeline — Tier: $TIER"
echo "═══════════════════════════════════════════════════════════"

# ─── Phase 0: Generate + Validate training data ────────────
echo ""
echo "Phase 0: Training data generation + validation..."

# Step 0a: Generate raw data if needed
if [ ! -f "$RAW_DATA_DIR/train.jsonl" ]; then
    echo "  Generating raw training data..."
    python3 generate_epistemos_training_data.py --output "$RAW_DATA_DIR"
    python3 generate_advanced_training_data.py --output "$RAW_DATA_DIR"
    python3 fill_training_gaps.py --output "$RAW_DATA_DIR"
fi

# Step 0b: ALWAYS validate before upload — raw data is NEVER used directly
echo "  Running validation pipeline..."
python3 validate_training_data.py --input "$RAW_DATA_DIR" --output "$VALIDATED_DATA_DIR" --fix
python3 strict_validate_and_rebuild.py
python3 rebuild_symbol_qa.py --output "$VALIDATED_DATA_DIR"

# Step 0c: Verify validated data exists and is non-empty
if [ ! -f "$VALIDATED_DATA_DIR/train.jsonl" ]; then
    echo "  ERROR: Validation produced no train.jsonl. Aborting."
    exit 1
fi
TRAIN_COUNT=$(wc -l < "$VALIDATED_DATA_DIR/train.jsonl")
if [ "$TRAIN_COUNT" -lt 100 ]; then
    echo "  ERROR: Validated train.jsonl has only $TRAIN_COUNT examples (min 100). Aborting."
    exit 1
fi
echo "  Validated corpus: $TRAIN_COUNT train examples"

# ─── Phase 1: Find RunPod ──────────────────────────────────
echo ""
echo "Phase 1: RunPod setup..."

POD_ID=$(runpodctl pod list -o json 2>/dev/null | python3 -c "
import json,sys
pods = json.load(sys.stdin)
for p in pods if isinstance(pods, list) else []:
    if p.get('desiredStatus') == 'RUNNING':
        print(p['id']); break
" 2>/dev/null || echo "")

if [ -z "$POD_ID" ]; then
    echo "  No running pod found. Create one on runpod.io and re-run."
    exit 1
fi
echo "  Using pod: $POD_ID"

SSH_INFO=$(runpodctl pod list -o json | python3 -c "
import json,sys
pods = json.load(sys.stdin)
for p in pods if isinstance(pods, list) else []:
    if p.get('id') == '$POD_ID':
        for port in p.get('runtime',{}).get('ports',[]):
            if port.get('privatePort') == 22:
                print(f\"{port['ip']} {port['publicPort']}\")
                break
        break
")
SSH_HOST=$(echo $SSH_INFO | cut -d' ' -f1)
SSH_PORT=$(echo $SSH_INFO | cut -d' ' -f2)

SSH_CMD="ssh -i $SSH_KEY -p $SSH_PORT -o StrictHostKeyChecking=no root@$SSH_HOST"
SCP_CMD="scp -i $SSH_KEY -P $SSH_PORT -o StrictHostKeyChecking=no"
echo "  SSH: root@$SSH_HOST:$SSH_PORT"

# ─── Phase 2: Upload scripts + VALIDATED data ──────────────
echo ""
echo "Phase 2: Uploading scripts and validated data..."

$SCP_CMD mohawk_train.py root@$SSH_HOST:/workspace/mohawk_train.py
$SCP_CMD sft_macos_agent.py root@$SSH_HOST:/workspace/sft_macos_agent.py
echo "  Scripts uploaded"

# Upload ONLY validated data to the remote training dir
$SSH_CMD "mkdir -p $REMOTE_DATA_DIR"
$SCP_CMD -r "$VALIDATED_DATA_DIR"/*.jsonl root@$SSH_HOST:$REMOTE_DATA_DIR/
echo "  Validated data uploaded ($(ls "$VALIDATED_DATA_DIR"/*.jsonl | wc -l) files → $REMOTE_DATA_DIR)"

# ─── Phase 3: Install deps ─────────────────────────────────
echo ""
echo "Phase 3: Installing dependencies..."
$SSH_CMD 'pip install -q transformers datasets accelerate wandb tokenizers sentencepiece 2>&1 | tail -1'
$SSH_CMD 'pip install -q mamba-ssm causal-conv1d 2>&1 | tail -1 || echo "mamba_ssm: using pure-PyTorch fallback"'
echo "  Dependencies ready"

# ─── Phase 4: Run MOHAWK distillation ──────────────────────
echo ""
echo "Phase 4: MOHAWK 3-stage distillation..."

$SSH_CMD "tmux new-session -d -s mohawk 'cd /workspace && python mohawk_train.py --stage all --tier $TIER --output-dir /workspace/mohawk_output 2>&1 | tee /workspace/mohawk.log'"
echo "  MOHAWK training started in tmux session 'mohawk'"

# ─── Print monitoring + SFT commands (all use REMOTE_DATA_DIR) ──
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  COMMANDS"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "  # Monitor:"
echo "  $SSH_CMD 'grep -E \"^  [0-9]|Stage|Saved:|COMPLETE\" /workspace/mohawk.log | tail -20'"
echo ""
echo "  # Run SFT after MOHAWK completes:"
echo "  $SSH_CMD 'cd /workspace && python sft_macos_agent.py \\"
echo "    --base-model /workspace/mohawk_output/stage3/checkpoint-final \\"
echo "    --data-dir $REMOTE_DATA_DIR \\"
echo "    --output /workspace/sft_output --lora --lora-rank 16 --tier $TIER'"
echo ""
echo "  # Stop pod: runpodctl pod stop $POD_ID"
echo "  # Download:  $SCP_CMD -r root@$SSH_HOST:/workspace/sft_output ~/Downloads/epistemos-models/"
echo "═══════════════════════════════════════════════════════════"
