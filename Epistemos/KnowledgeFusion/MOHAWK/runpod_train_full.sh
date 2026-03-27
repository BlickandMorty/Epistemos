#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# RunPod Full Training Automation — Epistemos MOHAWK
# ═══════════════════════════════════════════════════════════════
# One command: creates pod, uploads code, runs all 3 stages.
#
# Usage: ./runpod_train_full.sh nano
#        ./runpod_train_full.sh base
#        ./runpod_train_full.sh nano community   # cheaper, community cloud
#
# Prerequisites:
#   - runpodctl configured (runpodctl doctor)
#   - SSH key added (runpodctl ssh add-key)
#   - RunPod account with funds (~$56+ nano community, $150+ nano secure)
set -euo pipefail

TIER="${1:-nano}"
CLOUD="${2:-community}"  # community (cheaper) or secure
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATUS_FILE="${SCRIPT_DIR}/.runpod_status.json"
TIMESTAMP=$(date +%Y%m%d_%H%M)
POD_NAME="mohawk-${TIER}-${TIMESTAMP}"

# ── Local status helpers ─────────────────────────────────────
# Writes a JSON status file so local handoffs can audit RunPod state
# without SSH-ing into the pod.
write_status() {
    local phase="$1"
    local detail="${2:-}"
    STATUS_PATH="$STATUS_FILE" \
    POD_VALUE="${POD_ID:-}" \
    POD_NAME_VALUE="${POD_NAME}" \
    TIER_VALUE="${TIER}" \
    CLOUD_VALUE="${CLOUD}" \
    PHASE_VALUE="${phase}" \
    DETAIL_VALUE="${detail}" \
    SSH_HOST_VALUE="${SSH_HOST:-}" \
    SSH_PORT_VALUE="${SSH_PORT:-}" \
    UPDATED_AT_VALUE="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    STARTED_AT_VALUE="${STARTED_AT:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}" \
    python3 - <<'PY'
import json
import os

payload = {
    "pod_id": os.environ.get("POD_VALUE", ""),
    "pod_name": os.environ.get("POD_NAME_VALUE", ""),
    "tier": os.environ.get("TIER_VALUE", ""),
    "cloud": os.environ.get("CLOUD_VALUE", ""),
    "phase": os.environ.get("PHASE_VALUE", ""),
    "detail": os.environ.get("DETAIL_VALUE", ""),
    "ssh_host": os.environ.get("SSH_HOST_VALUE", ""),
    "ssh_port": os.environ.get("SSH_PORT_VALUE", ""),
    "updated_at": os.environ.get("UPDATED_AT_VALUE", ""),
    "started_at": os.environ.get("STARTED_AT_VALUE", ""),
}

with open(os.environ["STATUS_PATH"], "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2)
    handle.write("\n")
PY
}

STARTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

case "$TIER" in
    nano) GPU_ID="NVIDIA A100 80GB PCIe"; GPU_COUNT=1; DISK=50; VOL=100 ;;
    base) GPU_ID="NVIDIA A100 80GB PCIe"; GPU_COUNT=1; DISK=100; VOL=200 ;;
    pro)  GPU_ID="NVIDIA H100 80GB HBM3"; GPU_COUNT=2; DISK=200; VOL=500 ;;
    *)    echo "Usage: $0 {nano|base|pro} [community|secure]"; exit 1 ;;
esac

CLOUD_FLAG="--cloud-type COMMUNITY"
[ "$CLOUD" = "secure" ] && CLOUD_FLAG="--cloud-type SECURE"

echo "═══════════════════════════════════════════════════════"
echo "  MOHAWK Full Training — ${TIER} (${CLOUD} cloud)"
echo "  GPU: ${GPU_COUNT}× ${GPU_ID}"
echo "═══════════════════════════════════════════════════════"

# ── Helper: run command on pod via SSH ──
pod_ssh() {
    local cmd="$1"
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
        -p "$SSH_PORT" "root@${SSH_HOST}" "$cmd"
}

pod_ssh_bg() {
    local cmd="$1"
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
        -p "$SSH_PORT" "root@${SSH_HOST}" "nohup bash -c '$cmd' > /dev/null 2>&1 &"
}

# ── 1. Create pod ──
echo "[1/6] Creating RunPod..."
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
    -o json 2>&1 || echo "{}")

POD_ID=$(echo "$POD_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null || echo "")
if [ -z "$POD_ID" ]; then
    echo "ERROR: Pod creation failed."
    echo "$POD_JSON"
    exit 1
fi
echo "  Pod ID: $POD_ID"
echo "$POD_ID" > "${SCRIPT_DIR}/.last_pod_id"
write_status "pod_created" "Waiting for pod to reach RUNNING state"

# ── 2. Wait for running ──
echo "[2/6] Waiting for pod to start..."
for i in $(seq 1 90); do
    POD_STATUS=$(runpodctl pod get "$POD_ID" -o json 2>/dev/null | python3 -c "
import sys,json
d = json.load(sys.stdin)
# Handle both dict and list response
if isinstance(d, list): d = d[0] if d else {}
print(d.get('desiredStatus', d.get('status', '?')))" 2>/dev/null || echo "?")
    if [ "$POD_STATUS" = "RUNNING" ]; then
        echo "  Pod is running!"
        break
    fi
    printf "  Status: %s (%d/90, waiting 10s)\r" "$POD_STATUS" "$i"
    sleep 10
done

if [ "$POD_STATUS" != "RUNNING" ]; then
    echo "ERROR: Pod didn't start after 15 minutes."
    echo "  Check: runpodctl pod get $POD_ID"
    exit 1
fi

# Wait for SSH to be ready
echo "  Waiting for SSH..."
sleep 15

# ── 3. Get SSH connection info ──
echo "[3/6] Getting SSH connection..."
SSH_JSON=$(runpodctl ssh info "$POD_ID" -o json 2>&1 || echo "{}")
echo "  SSH info: $SSH_JSON"

# Parse SSH host and port from the info
# Format is typically: ssh root@<ip> -p <port> -i ~/.runpod/ssh/id_ed25519
SSH_HOST=$(echo "$SSH_JSON" | python3 -c "
import sys, json
d = json.load(sys.stdin)
# Try different possible field names
host = d.get('publicIp') or d.get('ip') or d.get('host') or ''
print(host)" 2>/dev/null || echo "")

SSH_PORT=$(echo "$SSH_JSON" | python3 -c "
import sys, json
d = json.load(sys.stdin)
port = d.get('sshPort') or d.get('port') or d.get('publicPort') or '22'
print(port)" 2>/dev/null || echo "22")

SSH_KEY=$(echo "$SSH_JSON" | python3 -c "
import sys, json
d = json.load(sys.stdin)
key = d.get('keyPath') or d.get('privateKeyPath') or ''
print(key)" 2>/dev/null || echo "")

# If we got a command string instead, parse it
if [ -z "$SSH_HOST" ]; then
    SSH_CMD=$(echo "$SSH_JSON" | python3 -c "
import sys, json
d = json.load(sys.stdin)
cmd = d.get('sshCommand') or d.get('command') or d.get('ssh') or ''
print(cmd)" 2>/dev/null || echo "")
    if [ -n "$SSH_CMD" ]; then
        echo "  SSH command: $SSH_CMD"
        SSH_HOST=$(echo "$SSH_CMD" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "")
        SSH_PORT=$(echo "$SSH_CMD" | grep -oP '(?<=-p )\d+' || echo "22")
        SSH_KEY=$(echo "$SSH_CMD" | grep -oP '(?<=-i )\S+' || echo "")
    fi
fi

# Fallback: try getting IP from pod details
if [ -z "$SSH_HOST" ]; then
    echo "  Fetching pod details for SSH info..."
    POD_DETAIL=$(runpodctl pod get "$POD_ID" -o json 2>/dev/null || echo "{}")
    SSH_HOST=$(echo "$POD_DETAIL" | python3 -c "
import sys, json
d = json.load(sys.stdin)
if isinstance(d, list): d = d[0] if d else {}
# Try runtime fields
rt = d.get('runtime', {}) or {}
ports = rt.get('ports', []) or d.get('ports', []) or []
for p in (ports if isinstance(ports, list) else []):
    if isinstance(p, dict) and p.get('privatePort') == 22:
        print(p.get('ip', '')); break
else:
    print(d.get('publicIp', d.get('machine', {}).get('ip', '')))" 2>/dev/null || echo "")
    SSH_PORT=$(echo "$POD_DETAIL" | python3 -c "
import sys, json
d = json.load(sys.stdin)
if isinstance(d, list): d = d[0] if d else {}
rt = d.get('runtime', {}) or {}
ports = rt.get('ports', []) or d.get('ports', []) or []
for p in (ports if isinstance(ports, list) else []):
    if isinstance(p, dict) and p.get('privatePort') == 22:
        print(p.get('publicPort', '22')); break
else:
    print('22')" 2>/dev/null || echo "22")
fi

if [ -z "$SSH_HOST" ]; then
    echo ""
    echo "ERROR: Could not determine SSH connection details."
    echo "  Run manually: runpodctl ssh info $POD_ID"
    echo "  Then connect with: ssh root@<IP> -p <PORT>"
    echo ""
    echo "  Once connected, run these commands:"
    echo "    pip install torch transformers datasets wandb mamba-ssm causal-conv1d"
    echo "    pip install flash-attn --no-build-isolation"
    echo "    # Upload mohawk_train.py to /workspace/mohawk/"
    echo "    cd /workspace/mohawk && python mohawk_train.py --stage all --tier ${TIER} --output-dir /workspace/mohawk_${TIER}"
    exit 1
fi

# Build SSH key flag
SSH_KEY_FLAG=""
if [ -n "$SSH_KEY" ]; then
    SSH_KEY_FLAG="-i $SSH_KEY"
elif [ -f "$HOME/.runpod/ssh/RunPod-Key-Go" ]; then
    SSH_KEY_FLAG="-i $HOME/.runpod/ssh/RunPod-Key-Go"
elif [ -f "$HOME/.runpod/ssh/id_ed25519" ]; then
    SSH_KEY_FLAG="-i $HOME/.runpod/ssh/id_ed25519"
fi

# Redefine helpers with key
pod_ssh() {
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=30 \
        $SSH_KEY_FLAG -p "$SSH_PORT" "root@${SSH_HOST}" "$1"
}

echo "  SSH: root@${SSH_HOST}:${SSH_PORT}"
write_status "ssh_connected" "SSH verified, installing dependencies"

# Wait for SSH to actually accept connections
echo "  Testing SSH connection..."
for i in $(seq 1 12); do
    if pod_ssh "echo ok" >/dev/null 2>&1; then
        echo "  SSH connected!"
        break
    fi
    printf "  SSH not ready yet (%d/12)\r" "$i"
    sleep 10
done

# ── 4. Install deps ──
echo "[4/6] Installing dependencies on pod..."
pod_ssh "pip install -q torch transformers datasets wandb 2>&1 | tail -3" || true
pod_ssh "pip install -q mamba-ssm causal-conv1d 2>&1 | tail -3" || true
pod_ssh "pip install -q flash-attn --no-build-isolation 2>&1 | tail -3" || echo "  (flash-attn optional, continuing)"

if [ -n "${HF_TOKEN:-}" ]; then
    pod_ssh "huggingface-cli login --token $HF_TOKEN" || true
fi

write_status "deps_installed" "Dependencies installed, uploading training script"

# ── 5. Upload training script ──
echo "[5/6] Uploading training script..."
pod_ssh "mkdir -p /workspace/mohawk"
scp -o StrictHostKeyChecking=no $SSH_KEY_FLAG -P "$SSH_PORT" \
    "${SCRIPT_DIR}/mohawk_train.py" "root@${SSH_HOST}:/workspace/mohawk/mohawk_train.py"
echo "  Uploaded mohawk_train.py"

# Verify
pod_ssh "python3 -c \"import torch; print(f'CUDA: {torch.cuda.is_available()}, GPU: {torch.cuda.get_device_name(0)}')\""

# ── 6. Launch training in tmux ──
echo "[6/6] Launching training..."
pod_ssh "tmux new-session -d -s train 'cd /workspace/mohawk && python mohawk_train.py --stage all --tier ${TIER} --output-dir /workspace/mohawk_${TIER} --convert-mlx 2>&1 | tee /workspace/train.log'"

write_status "training_launched" "Training running in tmux session 'train' on pod ${POD_ID}"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Training running in tmux session 'train'"
echo "  Pod ID:  $POD_ID"
echo "  SSH:     ssh $SSH_KEY_FLAG -p $SSH_PORT root@${SSH_HOST}"
echo "  Status:  $STATUS_FILE"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "  Monitor:"
echo "    ssh $SSH_KEY_FLAG -p $SSH_PORT root@${SSH_HOST} 'tail -30 /workspace/train.log'"
echo ""
echo "  Sync local status (pulls remote progress):"
echo "    ${SCRIPT_DIR}/runpod_sync_status.sh"
echo ""
echo "  Attach to training:"
echo "    ssh $SSH_KEY_FLAG -p $SSH_PORT root@${SSH_HOST} -t 'tmux attach -t train'"
echo ""
echo "  When done, download the model:"
echo "    scp $SSH_KEY_FLAG -P $SSH_PORT -r root@${SSH_HOST}:/workspace/mohawk_${TIER}/mlx_model/ ./mohawk_${TIER}_mlx/"
echo ""
echo "  Stop pod when finished:"
echo "    runpodctl pod stop $POD_ID"
echo ""
