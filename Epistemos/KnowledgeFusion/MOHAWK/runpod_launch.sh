#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# RunPod Launch Script — Epistemos MOHAWK Distillation
# ═══════════════════════════════════════════════════════════════
#
# Usage:
#   1. Create a RunPod account at https://runpod.io
#   2. Install runpodctl: brew install runpod/runpodctl/runpodctl
#   3. Set API key: runpodctl config --apiKey YOUR_KEY
#   4. Run: ./runpod_launch.sh nano    (for Nano 1B tier)
#           ./runpod_launch.sh base    (for Base 3B tier)
#           ./runpod_launch.sh pro     (for Pro 8B tier)
#
# Cost estimates (March 2026 RunPod pricing):
#   Nano: ~$100-300  (8B tokens, A100 80GB, ~40-120 hours)
#   Base: ~$800-1500 (12B tokens, A100 80GB, ~160-300 hours)
#   Pro:  ~$2000-3500 (12B tokens, H100 80GB, ~200-350 hours)

set -euo pipefail

TIER="${1:-nano}"
TIMESTAMP=$(date +%Y%m%d_%H%M)
POD_NAME="epistemos-mohawk-${TIER}-${TIMESTAMP}"

# ─── GPU Selection ──────────────────────────────────────────

case "$TIER" in
    nano)
        GPU_ID="NVIDIA A100 80GB PCIe"
        GPU_COUNT=1
        DISK_SIZE=100  # GB
        VOLUME_SIZE=200 # GB for checkpoints + data
        ;;
    base)
        GPU_ID="NVIDIA A100 80GB PCIe"
        GPU_COUNT=1
        DISK_SIZE=200
        VOLUME_SIZE=500
        ;;
    pro)
        GPU_ID="NVIDIA H100 80GB HBM3"
        GPU_COUNT=2   # 70B teacher needs 2 GPUs
        DISK_SIZE=200
        VOLUME_SIZE=1000
        ;;
    *)
        echo "Unknown tier: $TIER (use: nano, base, pro)"
        exit 1
        ;;
esac

echo "═══════════════════════════════════════════════════════"
echo "  Epistemos MOHAWK — Launching RunPod"
echo "═══════════════════════════════════════════════════════"
echo "  Tier:     $TIER"
echo "  GPU:      $GPU_COUNT × $GPU_TYPE"
echo "  Disk:     ${DISK_SIZE}GB container + ${VOLUME_SIZE}GB volume"
echo "  Pod name: $POD_NAME"
echo "═══════════════════════════════════════════════════════"
echo ""

# ─── Create Pod ────────────────────────────────────────────

echo "Creating pod..."
runpodctl pod create \
    --name "$POD_NAME" \
    --gpu-id "$GPU_ID" \
    --gpu-count "$GPU_COUNT" \
    --container-disk-in-gb "$DISK_SIZE" \
    --volume-in-gb "$VOLUME_SIZE" \
    --volume-mount-path "/workspace" \
    --image "runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04" \
    --ports "8888/http,22/tcp" \
    --env "{\"TIER\":\"$TIER\",\"HF_HOME\":\"/workspace/huggingface\",\"WANDB_PROJECT\":\"epistemos-mohawk\"}"

echo ""
echo "Pod created. Once it's running, SSH in and run:"
echo ""
echo "  # 1. Install dependencies"
echo "  pip install torch transformers datasets wandb mamba-ssm causal-conv1d"
echo "  pip install flash-attn --no-build-isolation"
echo ""
echo "  # 2. Upload training script"
echo "  # (or git clone your repo)"
echo ""
echo "  # 3. Dry run to verify config"
echo "  python mohawk_train.py --stage all --tier $TIER --dry-run"
echo ""
echo "  # 4. Start training"
echo "  python mohawk_train.py --stage all --tier $TIER --output-dir /workspace/mohawk_$TIER"
echo ""
echo "  # 5. After training, convert for on-device"
echo "  python mohawk_train.py --stage all --tier $TIER --convert-mlx --convert-coreml"
echo ""
echo "═══════════════════════════════════════════════════════"
