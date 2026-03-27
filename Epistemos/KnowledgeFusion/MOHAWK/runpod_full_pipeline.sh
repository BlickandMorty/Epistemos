#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#  Epistemos Full Training Pipeline — MOHAWK + SFT + MLX Convert
# ═══════════════════════════════════════════════════════════════
#
# This script runs the COMPLETE training pipeline:
#   Phase 1: Generate training data locally (run on Mac BEFORE uploading)
#   Phase 2: MOHAWK 3-stage distillation (RunPod GPU)
#   Phase 3: Post-MOHAWK SFT specialization (RunPod GPU)
#   Phase 4: Convert to MLX format (RunPod)
#   Phase 5: Download to Mac
#
# Usage:
#   # Step 1: Generate data locally
#   cd Epistemos/KnowledgeFusion/MOHAWK
#   python generate_epistemos_training_data.py --output ./epistemos_training_data_validated
#
#   # Step 2: Run full pipeline on RunPod
#   ./runpod_full_pipeline.sh nano
#
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

TIER="${1:-nano}"
SSH_KEY="${SSH_KEY:-$HOME/.runpod/ssh/RunPod-Key-Go}"
LOCAL_DATA_DIR="./epistemos_training_data_validated"

echo "═══════════════════════════════════════════════════════════"
echo "  Epistemos Full Pipeline — Tier: $TIER"
echo "═══════════════════════════════════════════════════════════"

# ─── Step 0: Generate training data if not present ──────────
if [ ! -f "$LOCAL_DATA_DIR/train.jsonl" ]; then
    echo ""
    echo "Phase 0: Generating Epistemos training data..."
    python3 generate_epistemos_training_data.py --output "$LOCAL_DATA_DIR"
    echo "  Data generated: $(wc -l < "$LOCAL_DATA_DIR/train.jsonl") training examples"
else
    echo "  Training data exists: $(wc -l < "$LOCAL_DATA_DIR/train.jsonl") examples"
fi

# ─── Step 1: Find or create RunPod ─────────────────────────
echo ""
echo "Phase 1: RunPod setup..."

# Check for existing pod
POD_ID=$(runpodctl pod list -o json 2>/dev/null | python3 -c "
import json,sys
pods = json.load(sys.stdin)
for p in pods if isinstance(pods, list) else []:
    if p.get('desiredStatus') == 'RUNNING':
        print(p['id']); break
" 2>/dev/null || echo "")

if [ -z "$POD_ID" ]; then
    echo "  No running pod found. Create one on runpod.io and re-run."
    echo "  Recommended: A100 80GB or H100 80GB"
    echo "  Template: RunPod PyTorch 2.1"
    exit 1
fi

echo "  Using pod: $POD_ID"

# Get SSH info
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

# ─── Step 2: Upload everything ─────────────────────────────
echo ""
echo "Phase 2: Uploading scripts and data..."

# Upload training scripts
$SCP_CMD mohawk_train.py root@$SSH_HOST:/workspace/mohawk_train.py
$SCP_CMD sft_macos_agent.py root@$SSH_HOST:/workspace/sft_macos_agent.py
echo "  Scripts uploaded"

# Upload training data
$SSH_CMD "mkdir -p /workspace/epistemos_training_data"
$SCP_CMD -r "$LOCAL_DATA_DIR"/*.jsonl root@$SSH_HOST:/workspace/epistemos_training_data/
echo "  Training data uploaded ($(ls "$LOCAL_DATA_DIR"/*.jsonl | wc -l) files)"

# ─── Step 3: Install deps on pod ───────────────────────────
echo ""
echo "Phase 3: Installing dependencies..."

$SSH_CMD 'pip install -q transformers datasets accelerate wandb tokenizers sentencepiece 2>&1 | tail -1'
$SSH_CMD 'pip install -q mamba-ssm causal-conv1d 2>&1 | tail -1 || echo "mamba_ssm: using pure-PyTorch fallback"'
echo "  Dependencies ready"

# ─── Step 4: Run MOHAWK distillation ───────────────────────
echo ""
echo "Phase 4: MOHAWK 3-stage distillation (this takes ~50 hours for nano)..."

$SSH_CMD "tmux new-session -d -s mohawk 'cd /workspace && python mohawk_train.py --stage all --tier $TIER --output-dir /workspace/mohawk_output 2>&1 | tee /workspace/mohawk.log'"
echo "  MOHAWK training started in tmux session 'mohawk'"
echo "  Monitor: $SSH_CMD 'tail -f /workspace/mohawk.log'"
echo ""
echo "  When MOHAWK completes, run Phase 5 manually:"
echo "  $SSH_CMD 'cd /workspace && python sft_macos_agent.py \\"
echo "    --base-model /workspace/mohawk_output/stage3/checkpoint-final \\"
echo "    --data-dir /workspace/epistemos_training_data \\"
echo "    --output /workspace/sft_output --lora --lora-rank 16 --tier $TIER'"
echo ""
echo "  Or run it all in sequence:"
echo "  $SSH_CMD 'tmux send-keys -t mohawk \"cd /workspace && python sft_macos_agent.py --base-model /workspace/mohawk_output/stage3/checkpoint-final --data-dir /workspace/epistemos_training_data --output /workspace/sft_output --lora --lora-rank 16 --tier $TIER\" Enter'"


# ─── Print monitoring commands ──────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  MONITORING COMMANDS"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "  # Check MOHAWK progress:"
echo "  $SSH_CMD 'grep -E \"^  [0-9]|Stage|Saved:|COMPLETE\" /workspace/mohawk.log | tail -20'"
echo ""
echo "  # Check GPU usage:"
echo "  $SSH_CMD 'nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total --format=csv,noheader'"
echo ""
echo "  # Attach to training tmux:"
echo "  $SSH_CMD -t 'tmux attach -t mohawk'"
echo ""
echo "  # Stop pod when done:"
echo "  runpodctl pod stop $POD_ID"
echo ""
echo "  # Download final model:"
echo "  mkdir -p ~/Downloads/epistemos-models"
echo "  $SCP_CMD -r root@$SSH_HOST:/workspace/sft_output ~/Downloads/epistemos-models/"
echo "═══════════════════════════════════════════════════════════"
