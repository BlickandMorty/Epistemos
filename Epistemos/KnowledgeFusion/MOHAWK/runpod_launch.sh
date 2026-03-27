#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# RunPod Launch Script — Epistemos MOHAWK Distillation
# ═══════════════════════════════════════════════════════════════
#
# Usage:
#   1. runpodctl doctor   (set API key, verify setup)
#   2. runpodctl ssh add-key  (if no SSH key yet)
#   3. ./runpod_launch.sh nano [community|secure]
#
# For fully automated training: use runpod_train_full.sh instead.

set -euo pipefail

TIER="${1:-nano}"
CLOUD="${2:-community}"
TIMESTAMP=$(date +%Y%m%d_%H%M)
POD_NAME="epistemos-mohawk-${TIER}-${TIMESTAMP}"

case "$TIER" in
    nano) GPU_ID="NVIDIA A100 80GB PCIe"; GPU_COUNT=1; DISK=50; VOL=100 ;;
    base) GPU_ID="NVIDIA A100 80GB PCIe"; GPU_COUNT=1; DISK=100; VOL=200 ;;
    pro)  GPU_ID="NVIDIA H100 80GB HBM3"; GPU_COUNT=2; DISK=200; VOL=500 ;;
    *)    echo "Unknown tier: $TIER (use: nano, base, pro)"; exit 1 ;;
esac

CLOUD_FLAG="--cloud-type COMMUNITY"
[ "$CLOUD" = "secure" ] && CLOUD_FLAG="--cloud-type SECURE"

echo "═══════════════════════════════════════════════════════"
echo "  Epistemos MOHAWK — Launching RunPod"
echo "  Tier:     $TIER ($CLOUD cloud)"
echo "  GPU:      $GPU_COUNT × $GPU_ID"
echo "  Disk:     ${DISK}GB container + ${VOL}GB volume"
echo "  Pod name: $POD_NAME"
echo "═══════════════════════════════════════════════════════"

POD_JSON=$(runpodctl pod create \
    --name "$POD_NAME" \
    --gpu-id "$GPU_ID" \
    --gpu-count "$GPU_COUNT" \
    --container-disk-in-gb "$DISK" \
    --volume-in-gb "$VOL" \
    --volume-mount-path "/workspace" \
    --image "runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04" \
    --ports "8888/http,22/tcp" \
    $CLOUD_FLAG \
    -o json 2>&1)

echo "$POD_JSON"

POD_ID=$(echo "$POD_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || echo "")

echo ""
echo "═══════════════════════════════════════════════════════"
if [ -n "$POD_ID" ]; then
    echo "  Pod ID: $POD_ID"
    echo ""
    echo "  Wait for RUNNING, then:"
    echo "    runpodctl ssh info $POD_ID"
    echo ""
    echo "  Connect (use your SSH key):"
    echo "    ssh -i ~/.runpod/ssh/RunPod-Key-Go -p <PORT> root@<IP>"
    echo ""
    echo "  Once connected:"
    echo "    pip install torch transformers datasets wandb mamba-ssm causal-conv1d"
    echo "    pip install flash-attn --no-build-isolation"
    echo "    mkdir -p /workspace/mohawk"
    echo "    # Upload mohawk_train.py, then:"
    echo "    python /workspace/mohawk/mohawk_train.py --stage all --tier $TIER --dry-run"
    echo "    python /workspace/mohawk/mohawk_train.py --stage all --tier $TIER --output-dir /workspace/mohawk_$TIER"
    echo ""
    echo "  Stop pod: runpodctl pod stop $POD_ID"
else
    echo "  Pod creation failed. Check output above."
fi
echo "═══════════════════════════════════════════════════════"
