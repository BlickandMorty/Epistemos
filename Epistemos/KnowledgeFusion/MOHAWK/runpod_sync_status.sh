#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# RunPod Status Sync — Pulls remote training state to local disk
# ═══════════════════════════════════════════════════════════════
# Run this anytime to get an auditable local snapshot of remote
# training progress. Reads connection info from .runpod_status.json.
#
# Usage: ./runpod_sync_status.sh
#
# Output: Updates .runpod_status.json with remote training state.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATUS_FILE="${SCRIPT_DIR}/.runpod_status.json"
POD_ID_FILE="${SCRIPT_DIR}/.last_pod_id"

write_status() {
    local phase="$1"
    local detail="$2"
    local remote_snapshot="${3:-}"
    local ssh_host_value="${4:-${SSH_HOST:-}}"
    local ssh_port_value="${5:-${SSH_PORT:-}}"

    STATUS_PATH="$STATUS_FILE" \
    POD_VALUE="${POD_ID}" \
    POD_NAME_VALUE="${POD_NAME:-?}" \
    TIER_VALUE="${TIER:-unknown}" \
    CLOUD_VALUE="${CLOUD:-?}" \
    PHASE_VALUE="${phase}" \
    DETAIL_VALUE="${detail}" \
    SSH_HOST_VALUE="${ssh_host_value}" \
    SSH_PORT_VALUE="${ssh_port_value}" \
    UPDATED_AT_VALUE="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    STARTED_AT_VALUE="${STARTED_AT:-}" \
    REMOTE_SNAPSHOT_VALUE="${remote_snapshot}" \
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

raw_snapshot = os.environ.get("REMOTE_SNAPSHOT_VALUE", "").strip()
if raw_snapshot:
    try:
        payload["remote_snapshot"] = json.loads(raw_snapshot)
    except json.JSONDecodeError:
        payload["remote_snapshot"] = {"raw": raw_snapshot}

with open(os.environ["STATUS_PATH"], "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2)
    handle.write("\n")
PY
}

if [ ! -f "$STATUS_FILE" ]; then
    if [ ! -f "$POD_ID_FILE" ]; then
        echo "ERROR: No status file found at $STATUS_FILE"
        echo "  Run runpod_train_full.sh first to launch training."
        exit 1
    fi
    POD_ID="$(cat "$POD_ID_FILE" 2>/dev/null || echo "")"
    if [ -z "$POD_ID" ]; then
        echo "ERROR: Could not read pod id from $POD_ID_FILE"
        exit 1
    fi
    SSH_HOST=""
    SSH_PORT="22"
    TIER="unknown"
    STARTED_AT=""
    CLOUD="?"
    POD_NAME="?"
else
    # Read connection info from status file
    POD_ID=$(python3 -c "import json; print(json.load(open('$STATUS_FILE'))['pod_id'])" 2>/dev/null || echo "")
    SSH_HOST=$(python3 -c "import json; print(json.load(open('$STATUS_FILE'))['ssh_host'])" 2>/dev/null || echo "")
    SSH_PORT=$(python3 -c "import json; print(json.load(open('$STATUS_FILE'))['ssh_port'])" 2>/dev/null || echo "22")
    TIER=$(python3 -c "import json; print(json.load(open('$STATUS_FILE'))['tier'])" 2>/dev/null || echo "nano")
    STARTED_AT=$(python3 -c "import json; print(json.load(open('$STATUS_FILE'))['started_at'])" 2>/dev/null || echo "")
    CLOUD=$(python3 -c "import json; print(json.load(open('$STATUS_FILE')).get('cloud','?'))" 2>/dev/null || echo "?")
    POD_NAME=$(python3 -c "import json; print(json.load(open('$STATUS_FILE')).get('pod_name','?'))" 2>/dev/null || echo "?")
fi

if [ -z "$POD_ID" ]; then
    echo "ERROR: Missing pod_id. Cannot sync RunPod state."
    exit 1
fi

# Detect SSH key
SSH_KEY_FLAG=""
if [ -f "$HOME/.runpod/ssh/RunPod-Key-Go" ]; then
    SSH_KEY_FLAG="-i $HOME/.runpod/ssh/RunPod-Key-Go"
elif [ -f "$HOME/.runpod/ssh/id_ed25519" ]; then
    SSH_KEY_FLAG="-i $HOME/.runpod/ssh/id_ed25519"
fi

pod_ssh() {
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
        $SSH_KEY_FLAG -p "$SSH_PORT" "root@${SSH_HOST}" "$1" 2>/dev/null
}

echo "Syncing status from pod $POD_ID (${SSH_HOST}:${SSH_PORT})..."

update_from_pod_state() {
    local pod_state
    pod_state=$(runpodctl pod get "$POD_ID" -o json 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
if isinstance(d, list): d = d[0] if d else {}
print(d.get('desiredStatus', d.get('status', 'UNKNOWN')))" 2>/dev/null || echo "UNKNOWN")
    write_status "pod_state_only" "Pod state: ${pod_state}. SSH details are not available yet or pod is unreachable."
    echo "  Pod state: $pod_state"
    echo "  Status written to $STATUS_FILE"
}

if [ -z "$SSH_HOST" ]; then
    update_from_pod_state
    exit 0
fi

# Check if pod is reachable
if ! pod_ssh "echo ok" >/dev/null 2>&1; then
    local_pod_state=$(runpodctl pod get "$POD_ID" -o json 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
if isinstance(d, list): d = d[0] if d else {}
print(d.get('desiredStatus', d.get('status', 'UNKNOWN')))" 2>/dev/null || echo "UNKNOWN")
    write_status "unreachable" "Pod state: ${local_pod_state}. SSH failed — pod may be stopped or terminated."
    echo "  Pod unreachable (state: $local_pod_state). Status updated."
    exit 0
fi

# Pull remote training state
REMOTE_STATUS=$(pod_ssh "
# Check if training process is running
TMUX_ALIVE=\$(tmux has-session -t train 2>/dev/null && echo 'yes' || echo 'no')
TRAIN_LOG='/workspace/train.log'
OUTPUT_DIR='/workspace/mohawk_${TIER}'

# Parse progress from train.log
LAST_STAGE=''
LAST_LINE=''
TOTAL_LINES=0
if [ -f \"\$TRAIN_LOG\" ]; then
    TOTAL_LINES=\$(wc -l < \"\$TRAIN_LOG\")
    LAST_STAGE=\$(grep -oE 'Stage [0-9]+/[0-9]+|stage [0-9]+' \"\$TRAIN_LOG\" | tail -1 || echo '')
    LAST_LINE=\$(tail -1 \"\$TRAIN_LOG\" | head -c 200 || echo '')
fi

# Check for output artifacts
HAS_MLX='false'
HAS_CKPT='false'
CKPT_COUNT=0
[ -d \"\$OUTPUT_DIR/mlx_model\" ] && HAS_MLX='true'
if [ -d \"\$OUTPUT_DIR\" ]; then
    CKPT_COUNT=\$(find \"\$OUTPUT_DIR\" -name 'checkpoint-*' -maxdepth 1 -type d 2>/dev/null | wc -l)
    [ \"\$CKPT_COUNT\" -gt 0 ] && HAS_CKPT='true'
fi

# GPU utilization
GPU_UTIL=\$(nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 || echo '')

TMUX_ALIVE_VALUE=\"\$TMUX_ALIVE\" \
TOTAL_LINES_VALUE=\"\$TOTAL_LINES\" \
LAST_STAGE_VALUE=\"\$LAST_STAGE\" \
LAST_LINE_VALUE=\"\$LAST_LINE\" \
HAS_MLX_VALUE=\"\$HAS_MLX\" \
HAS_CKPT_VALUE=\"\$HAS_CKPT\" \
CKPT_COUNT_VALUE=\"\$CKPT_COUNT\" \
GPU_UTIL_VALUE=\"\$GPU_UTIL\" \
python3 - <<'PY'
import json
import os

def as_bool(value: str) -> bool:
    return str(value).strip().lower() == 'true'

payload = {
    "tmux_alive": os.environ.get("TMUX_ALIVE_VALUE", ""),
    "log_lines": int(os.environ.get("TOTAL_LINES_VALUE", "0") or "0"),
    "last_stage": os.environ.get("LAST_STAGE_VALUE", ""),
    "last_log_line": os.environ.get("LAST_LINE_VALUE", ""),
    "has_mlx": as_bool(os.environ.get("HAS_MLX_VALUE", "false")),
    "has_checkpoint": as_bool(os.environ.get("HAS_CKPT_VALUE", "false")),
    "checkpoint_count": int(os.environ.get("CKPT_COUNT_VALUE", "0") or "0"),
    "gpu_util": os.environ.get("GPU_UTIL_VALUE", ""),
}
print(json.dumps(payload))
PY
" || echo '{}')

# Determine phase from remote state
PHASE=$(echo "$REMOTE_STATUS" | python3 -c "
import sys, json
try:
    d = json.loads(sys.stdin.read())
    if d.get('has_mlx', False):
        print('training_complete_mlx_ready')
    elif d.get('tmux_alive') == 'no' and d.get('log_lines', 0) > 0:
        print('training_finished_or_crashed')
    elif d.get('tmux_alive') == 'yes':
        print('training_in_progress')
    else:
        print('unknown')
except:
    print('sync_parse_error')
" 2>/dev/null || echo "sync_parse_error")

DETAIL=$(echo "$REMOTE_STATUS" | python3 -c "
import sys, json
try:
    d = json.loads(sys.stdin.read())
    parts = []
    if d.get('last_stage'): parts.append(f\"Stage: {d['last_stage']}\")
    parts.append(f\"Log lines: {d.get('log_lines', '?')}\")
    if d.get('checkpoint_count', 0) > 0: parts.append(f\"Checkpoints: {d['checkpoint_count']}\")
    if d.get('has_mlx'): parts.append('MLX model ready')
    if d.get('gpu_util'): parts.append(f\"GPU: {d['gpu_util']}\")
    if d.get('tmux_alive') == 'no': parts.append('tmux session ended')
    print('; '.join(parts))
except:
    print('Could not parse remote status')
" 2>/dev/null || echo "Could not parse remote status")

write_status "$PHASE" "$DETAIL" "$REMOTE_STATUS" "$SSH_HOST" "$SSH_PORT"

echo "  Phase: $PHASE"
echo "  Detail: $DETAIL"
echo "  Status written to $STATUS_FILE"
