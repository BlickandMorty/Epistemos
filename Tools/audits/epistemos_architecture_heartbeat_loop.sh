#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

INTERVAL_SECONDS="${EPISTEMOS_ARCH_LOOP_INTERVAL_SECONDS:-120}"
STATE_DIR="${EPISTEMOS_ARCH_LOOP_STATE_DIR:-/tmp/epistemos_architecture_heartbeat_loop}"
PID_FILE="$STATE_DIR/loop.pid"
LOG_FILE="$STATE_DIR/loop.log"
LOCK_DIR="$STATE_DIR/tick.lock"
SCREEN_NAME="${EPISTEMOS_ARCH_LOOP_SCREEN_NAME:-epistemos_architecture_heartbeat_loop}"
AUTOPILOT="${EPISTEMOS_ARCH_LOOP_AUTOPILOT:-0}"
AUTOPILOT_PROMPT="${EPISTEMOS_ARCH_LOOP_AUTOPILOT_PROMPT:-$ROOT/docs/audits/ARCHITECTURE_AUTOPILOT_PROMPT_2026_05_30.md}"
AUTOPILOT_LOG_DIR="$STATE_DIR/codex_runs"

usage() {
  cat <<'USAGE'
Usage: Tools/audits/epistemos_architecture_heartbeat_loop.sh <start|stop|status|tick|run>

Environment:
  EPISTEMOS_ARCH_LOOP_INTERVAL_SECONDS=120
  EPISTEMOS_ARCH_LOOP_STATE_DIR=/tmp/epistemos_architecture_heartbeat_loop
  EPISTEMOS_ARCH_LOOP_REFRESH_FALSIFIERS=0
  EPISTEMOS_ARCH_LOOP_AUTOPILOT=0
  EPISTEMOS_ARCH_LOOP_AUTOPILOT_PROMPT=docs/audits/ARCHITECTURE_AUTOPILOT_PROMPT_2026_05_30.md

This is a conservative unattended architecture loop. It logs the current
architecture cursor, runs read-only/local-safe audits, and refuses heavy model,
Metal, mmap, SSD, Xcode, and live inference probes by default.

Set EPISTEMOS_ARCH_LOOP_AUTOPILOT=1 to run one non-interactive Codex work
session per cycle using the autopilot prompt.
USAGE
}

ensure_state_dir() {
  mkdir -p "$STATE_DIR"
}

read_pid() {
  [[ -f "$PID_FILE" ]] || return 1
  local pid
  pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  printf '%s\n' "$pid"
}

is_running() {
  local pid
  pid="$(read_pid)" || return 1
  kill -0 "$pid" 2>/dev/null
}

start_loop() {
  ensure_state_dir
  if is_running; then
    echo "architecture heartbeat loop already running pid=$(read_pid)"
    echo "log: $LOG_FILE"
    return 0
  fi

  rm -f "$PID_FILE"
  rm -rf "$LOCK_DIR"
  local script="$ROOT/Tools/audits/epistemos_architecture_heartbeat_loop.sh"
  local pid
  if command -v screen >/dev/null 2>&1; then
    screen -dmS "$SCREEN_NAME" bash -lc \
      'cd "$1" && echo $$ > "$2" && exec "$3" run >> "$4" 2>&1' \
      _ "$ROOT" "$PID_FILE" "$script" "$LOG_FILE"
    for _ in 1 2 3 4 5; do
      [[ -f "$PID_FILE" ]] && break
      sleep 0.1
    done
    pid="$(read_pid || true)"
  else
    nohup "$script" run >> "$LOG_FILE" 2>&1 &
    pid=$!
    echo "$pid" > "$PID_FILE"
  fi
  if [[ -z "${pid:-}" ]]; then
    echo "failed to start architecture heartbeat loop"
    return 1
  fi
  echo "started architecture heartbeat loop pid=$pid interval=${INTERVAL_SECONDS}s"
  echo "autopilot: $AUTOPILOT"
  echo "log: $LOG_FILE"
}

stop_loop() {
  ensure_state_dir
  if ! is_running; then
    echo "architecture heartbeat loop is not running"
    rm -f "$PID_FILE"
    return 0
  fi

  local pid
  pid="$(read_pid)"
  kill "$pid"
  rm -f "$PID_FILE"
  echo "stopped architecture heartbeat loop pid=$pid"
}

status_loop() {
  ensure_state_dir
  if is_running; then
    echo "architecture heartbeat loop running pid=$(read_pid)"
    if command -v screen >/dev/null 2>&1; then
      screen -list | grep -F "$SCREEN_NAME" || true
    fi
  else
    echo "architecture heartbeat loop stopped"
  fi
  echo "interval: ${INTERVAL_SECONDS}s"
  echo "autopilot: $AUTOPILOT"
  echo "state: $STATE_DIR"
  echo "log: $LOG_FILE"
  if [[ -f "$LOG_FILE" ]]; then
    echo "--- last 40 log lines ---"
    tail -40 "$LOG_FILE"
  fi
}

run_loop() {
  ensure_state_dir
  echo "architecture heartbeat loop booted at $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo "root: $ROOT"
  echo "interval: ${INTERVAL_SECONDS}s"
  echo "autopilot: $AUTOPILOT"
  while true; do
    "$0" tick || true
    sleep "$INTERVAL_SECONDS"
  done
}

with_tick_lock() {
  ensure_state_dir
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "tick skipped: previous tick still running"
    return 0
  fi
  trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' RETURN
  run_tick_body
}

run_tick_body() {
  local now
  now="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo
  echo "=== architecture heartbeat tick $now ==="
  echo "root: $ROOT"
  echo "head: $(git rev-parse --short=12 HEAD 2>/dev/null || echo unknown)"
  echo "branch: $(git branch --show-current 2>/dev/null || echo detached)"
  echo "safe_mode: heavy_model=off metal=off mmap_stress=off xcode=off live_inference=off"

  echo
  echo "[git status --short]"
  git status --short --untracked-files=all || true

  echo
  echo "[git diff --check]"
  if git diff --check; then
    echo "diff_check=pass"
  else
    echo "diff_check=fail"
  fi

  echo
  echo "[worktree inventory dry-run]"
  Tools/audits/epistemos_worktree_inventory.sh --dry-run || true

  echo
  echo "[kv-direct model context inventory temp output]"
  Tools/audits/kv_direct_model_context_inventory.sh \
    --output "$STATE_DIR/kv_direct_model_context_inventory.latest.json" || true

  echo
  echo "[architecture cursor]"
  python3 - <<'PY'
import json
from pathlib import Path

def load(path: str) -> dict:
    p = Path(path)
    if not p.exists():
        return {}
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception as exc:
        print(f"{path}: unreadable: {exc}")
        return {}

def measurement(data: dict, key: str, default="unknown"):
    value = data.get("measurements", {}).get(key, {})
    if isinstance(value, dict):
        return value.get("value", default)
    return default

capability = load("artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json")
guard = load("artifacts/falsifiers/architecture_pending_work_guard/result.json")
manifest = Path("docs/audits/UNFINISHED_ARCHITECTURE_AND_BEST_COMBO_MANIFEST_2026_05_30.md")

print(f"capability_next_bottleneck={measurement(capability, 'next_bottleneck')}")
print(f"pending_next_existing_work={measurement(guard, 'next_existing_work')}")
print(f"pending_cursor_available={measurement(guard, 'pending_work_cursor_available')}")

queue = measurement(capability, "ordered_build_queue", [])
if isinstance(queue, list):
    open_rows = [
        row for row in queue
        if str(row.get("status", "")).lower() not in {"completed", "green", "done"}
    ]
    if open_rows:
        row = open_rows[0]
        print(
            "first_open_queue_row="
            f"{row.get('order')}:{row.get('gap_id')} status={row.get('status')}"
        )

if manifest.exists():
    print(f"best_combo_manifest={manifest}")
else:
    print("best_combo_manifest=missing")
PY

  if [[ "${EPISTEMOS_ARCH_LOOP_REFRESH_FALSIFIERS:-0}" == "1" ]]; then
    echo
    echo "[optional falsifier refresh: enabled]"
    Tools/falsifiers/f_capability_ceiling_evaluation_kernel.sh || true
    Tools/falsifiers/f_architecture_pending_work_guard.sh || true
  else
    echo
    echo "[optional falsifier refresh: skipped]"
    echo "Set EPISTEMOS_ARCH_LOOP_REFRESH_FALSIFIERS=1 to refresh schema artifacts."
  fi

  if [[ "$AUTOPILOT" == "1" ]]; then
    run_autopilot "$now"
  else
    echo
    echo "[autopilot: skipped]"
    echo "Set EPISTEMOS_ARCH_LOOP_AUTOPILOT=1 to run one Codex work session per cycle."
  fi

  echo "=== tick complete $now ==="
}

run_autopilot() {
  local tick_id="$1"
  local safe_tick_id="${tick_id//:/}"
  safe_tick_id="${safe_tick_id//-/}"
  mkdir -p "$AUTOPILOT_LOG_DIR"

  echo
  echo "[autopilot: enabled]"
  if ! command -v codex >/dev/null 2>&1; then
    echo "autopilot skipped: codex CLI not found"
    return 0
  fi
  if [[ ! -f "$AUTOPILOT_PROMPT" ]]; then
    echo "autopilot skipped: prompt not found at $AUTOPILOT_PROMPT"
    return 0
  fi

  local run_dir="$AUTOPILOT_LOG_DIR/$safe_tick_id"
  mkdir -p "$run_dir"
  echo "autopilot_run_dir=$run_dir"
  echo "autopilot_prompt=$AUTOPILOT_PROMPT"

  set +e
  codex \
    -C "$ROOT" \
    --add-dir "$ROOT/.." \
    --sandbox danger-full-access \
    --ask-for-approval never \
    exec \
    --output-last-message "$run_dir/final.md" \
    - < "$AUTOPILOT_PROMPT" > "$run_dir/stdout.log" 2> "$run_dir/stderr.log"
  local status=$?
  set -e

  echo "autopilot_exit=$status"
  echo "autopilot_stdout=$run_dir/stdout.log"
  echo "autopilot_stderr=$run_dir/stderr.log"
  echo "autopilot_final=$run_dir/final.md"
  if [[ -s "$run_dir/final.md" ]]; then
    echo "--- autopilot final ---"
    tail -80 "$run_dir/final.md"
  fi
}

case "${1:-}" in
  start)
    start_loop
    ;;
  stop)
    stop_loop
    ;;
  status)
    status_loop
    ;;
  tick)
    with_tick_lock
    ;;
  run)
    run_loop
    ;;
  *)
    usage
    exit 2
    ;;
esac
