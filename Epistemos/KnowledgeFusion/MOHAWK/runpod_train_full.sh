#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# RunPod Full Training Automation — Epistemos MOHAWK
# ═══════════════════════════════════════════════════════════════
# One command: creates pod, uploads code, runs all 3 stages.
#
# Usage: ./runpod_train_full.sh nano
#        ./runpod_train_full.sh base
#
# Prerequisites:
#   - runpodctl configured (runpodctl config --apiKey YOUR_KEY)
#   - HF_TOKEN env var set (for Llama gated models)
#   - RunPod account with funds ($150+ nano, $1500+ base)
set -euo pipefail

TIER="${1:-nano}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TIMESTAMP=$(date +%Y%m%d_%H%M)
POD_NAME="mohawk-${TIER}-${TIMESTAMP}"

case "$TIER" in
    nano) GPU_ID="NVIDIA A100 80GB PCIe"; GPU_COUNT=1; DISK=100; VOL=200 ;;
    base) GPU_ID="NVIDIA A100 80GB PCIe"; GPU_COUNT=1; DISK=200; VOL=500 ;;
    pro)  GPU_ID="NVIDIA H100 80GB HBM3"; GPU_COUNT=2; DISK=200; VOL=1000 ;;
    *)    echo "Usage: $0 {nano|base|pro}"; exit 1 ;;
esac

echo "═══════════════════════════════════════════════════════"
echo "  MOHAWK Full Training — ${TIER}"
echo "  GPU: ${GPU_COUNT}× ${GPU_ID}"
echo "═══════════════════════════════════════════════════════"

# 1. Create pod
echo "[1/5] Creating RunPod..."
POD_JSON=$(runpodctl pod create \
    --name "$POD_NAME" \
    --gpu-id "$GPU_ID" \
    --gpu-count "$GPU_COUNT" \
    --container-disk-in-gb "$DISK" \
    --volume-in-gb "$VOL" \
    --volume-mount-path "/workspace" \
    --image "runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04" \
    --ports "8888/http,22/tcp" \
    --env "{\"TIER\":\"$TIER\",\"HF_HOME\":\"/workspace/huggingface\"}" \
    -o json 2>/dev/null || echo "{}")

POD_ID=$(echo "$POD_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || echo "")
if [ -z "$POD_ID" ]; then
    echo "ERROR: Pod creation failed. Check funds/availability."
    echo "$POD_JSON"
    exit 1
fi
echo "  Pod: $POD_ID"
echo "$POD_ID" > "${SCRIPT_DIR}/.last_pod_id"

# 2. Wait for running
echo "[2/5] Waiting for pod..."
for i in $(seq 1 60); do
    ST=$(runpodctl pod list -o json 2>/dev/null | python3 -c "
import sys,json
for p in json.load(sys.stdin):
    if p.get('id')=='$POD_ID': print(p.get('desiredStatus','?')); break
" 2>/dev/null || echo "?")
    [ "$ST" = "RUNNING" ] && break
    printf "  %s (%d/60)\r" "$ST" "$i"
    sleep 10
done
echo "  Running!"
sleep 10  # Settle

# 3. Install deps + upload
echo "[3/5] Installing deps..."
runpodctl pod ssh "$POD_ID" --command "pip install -q torch transformers datasets wandb 2>&1 | tail -1" || true
runpodctl pod ssh "$POD_ID" --command "pip install -q mamba-ssm causal-conv1d 2>&1 | tail -1" || true
runpodctl pod ssh "$POD_ID" --command "pip install -q flash-attn --no-build-isolation 2>&1 | tail -1" || true

if [ -n "${HF_TOKEN:-}" ]; then
    runpodctl pod ssh "$POD_ID" --command "huggingface-cli login --token $HF_TOKEN" || true
fi

echo "[4/5] Uploading training script..."
runpodctl pod ssh "$POD_ID" --command "mkdir -p /workspace/mohawk"
cat "${SCRIPT_DIR}/mohawk_train.py" | runpodctl pod ssh "$POD_ID" --command "cat > /workspace/mohawk/mohawk_train.py"

# 5. Launch training in tmux
echo "[5/5] Launching training..."
runpodctl pod ssh "$POD_ID" --command "tmux new-session -d -s train 'cd /workspace/mohawk && python mohawk_train.py --stage all --tier ${TIER} --output-dir /workspace/mohawk_${TIER} --convert-mlx 2>&1 | tee /workspace/train.log'"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Training running in tmux session 'train'"
echo "  Pod ID: $POD_ID"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "  Monitor:  runpodctl pod ssh $POD_ID --command 'tail -20 /workspace/train.log'"
echo "  Attach:   runpodctl pod ssh $POD_ID --command 'tmux attach -t train'"
echo "  Status:   runpodctl pod ssh $POD_ID --command 'cat /workspace/mohawk_${TIER}/stage*/training_metadata.json'"
echo ""
echo "  When done, download the MLX model:"
echo "    runpodctl pod ssh $POD_ID --command 'cd /workspace/mohawk_${TIER} && tar czf /workspace/model.tar.gz mlx_model/'"
echo "    # Then use runpodctl send/receive to transfer"
echo ""
echo "  Stop pod: runpodctl pod stop $POD_ID"
