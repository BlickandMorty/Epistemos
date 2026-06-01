#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

INTERVAL_SECONDS="${EPISTEMOS_ARCH_LOOP_INTERVAL_SECONDS:-120}"
STATE_DIR="${EPISTEMOS_ARCH_LOOP_STATE_DIR:-/tmp/epistemos_architecture_heartbeat_loop}"
PID_FILE="$STATE_DIR/loop.pid"
LOG_FILE="$STATE_DIR/loop.log"
LOCK_DIR="$STATE_DIR/tick.lock"
MODE_ENV_FILE="$STATE_DIR/mode.env"
LAST_TICK_FILE="$STATE_DIR/last_tick"
LAST_COMPLETED_RUN_FILE="$STATE_DIR/last_completed_run"
SCREEN_NAME="${EPISTEMOS_ARCH_LOOP_SCREEN_NAME:-epistemos_architecture_heartbeat_loop}"
WORKER_PID_FILE="$STATE_DIR/worker.pid"
WORKER_STARTED_AT_FILE="$STATE_DIR/worker.started_at"
WORKER_RUN_DIR_FILE="$STATE_DIR/worker.run_dir"
WORKER_EXIT_FILE="$STATE_DIR/worker.exit"
AUTOPILOT="${EPISTEMOS_ARCH_LOOP_AUTOPILOT:-0}"
AUTOPILOT_PROMPT="${EPISTEMOS_ARCH_LOOP_AUTOPILOT_PROMPT:-$ROOT/docs/audits/ARCHITECTURE_AUTOPILOT_PROMPT_2026_05_30.md}"
AUTOPILOT_LOG_DIR="$STATE_DIR/codex_runs"
REFRESH_FALSIFIERS="${EPISTEMOS_ARCH_LOOP_REFRESH_FALSIFIERS:-0}"
WORKER_STALE_SECONDS="${EPISTEMOS_ARCH_LOOP_STALE_WORKER_SECONDS:-1800}"

usage() {
  cat <<'USAGE'
Usage: Tools/audits/epistemos_architecture_heartbeat_loop.sh <command> [options]

Commands:
  start                    Start the detached scheduler.
  stop [--kill-worker]     Stop only the scheduler by default.
  status [--verbose]       Show persisted scheduler mode and worker state.
  tick [--dry-run]         Run one foreground supervisor tick.
  run                      Internal scheduler loop.
  stop-worker              Stop the active worker only.
  kill-worker [--force]    Stop the active worker only; --force sends KILL.

Environment used by start/tick when no persisted mode exists:
  EPISTEMOS_ARCH_LOOP_INTERVAL_SECONDS=120
  EPISTEMOS_ARCH_LOOP_STATE_DIR=/tmp/epistemos_architecture_heartbeat_loop
  EPISTEMOS_ARCH_LOOP_REFRESH_FALSIFIERS=0
  EPISTEMOS_ARCH_LOOP_AUTOPILOT=0
  EPISTEMOS_ARCH_LOOP_AUTOPILOT_PROMPT=docs/audits/ARCHITECTURE_AUTOPILOT_PROMPT_2026_05_30.md
  EPISTEMOS_ARCH_LOOP_STALE_WORKER_SECONDS=1800

The scheduler is a nonblocking supervisor. Each tick emits a heartbeat, reaps
completed workers, and launches at most one Codex worker when autopilot is on.
USAGE
}

utc_now() {
  date -u '+%Y-%m-%dT%H:%M:%SZ'
}

epoch_now() {
  date -u '+%s'
}

ensure_state_dir() {
  mkdir -p "$STATE_DIR" "$AUTOPILOT_LOG_DIR"
}

read_pid_from() {
  local path="$1"
  [[ -f "$path" ]] || return 1
  local pid
  pid="$(cat "$path" 2>/dev/null || true)"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  printf '%s\n' "$pid"
}

read_scheduler_pid() {
  read_pid_from "$PID_FILE"
}

read_worker_pid() {
  read_pid_from "$WORKER_PID_FILE"
}

pid_is_running() {
  local pid="$1"
  kill -0 "$pid" 2>/dev/null
}

scheduler_is_running() {
  local pid
  pid="$(read_scheduler_pid)" || return 1
  pid_is_running "$pid"
}

worker_is_running() {
  [[ ! -f "$WORKER_EXIT_FILE" ]] || return 1
  local pid
  pid="$(read_worker_pid)" || return 1
  pid_is_running "$pid"
}

file_size() {
  local path="$1"
  if [[ -f "$path" ]]; then
    wc -c < "$path" | tr -d '[:space:]'
  else
    printf '0'
  fi
}

load_mode_env() {
  [[ -f "$MODE_ENV_FILE" ]] || return 0
  local key value
  while IFS='=' read -r key value; do
    case "$key" in
      interval_seconds) INTERVAL_SECONDS="$value" ;;
      autopilot) AUTOPILOT="$value" ;;
      autopilot_prompt) AUTOPILOT_PROMPT="$value" ;;
      refresh_falsifiers) REFRESH_FALSIFIERS="$value" ;;
      worker_stale_seconds) WORKER_STALE_SECONDS="$value" ;;
    esac
  done < "$MODE_ENV_FILE"
}

write_mode_env() {
  local scheduler_pid="${1:-}"
  ensure_state_dir
  {
    printf 'root=%s\n' "$ROOT"
    printf 'state_dir=%s\n' "$STATE_DIR"
    printf 'interval_seconds=%s\n' "$INTERVAL_SECONDS"
    printf 'autopilot=%s\n' "$AUTOPILOT"
    printf 'autopilot_prompt=%s\n' "$AUTOPILOT_PROMPT"
    printf 'refresh_falsifiers=%s\n' "$REFRESH_FALSIFIERS"
    printf 'worker_stale_seconds=%s\n' "$WORKER_STALE_SECONDS"
    printf 'scheduler_pid=%s\n' "$scheduler_pid"
    printf 'mode_written_at=%s\n' "$(utc_now)"
  } > "$MODE_ENV_FILE"
}

log_mode() {
  if [[ -f "$MODE_ENV_FILE" ]]; then
    echo "mode_source=$MODE_ENV_FILE"
  else
    echo "mode_source=current_environment"
  fi
  echo "interval=${INTERVAL_SECONDS}s"
  echo "autopilot=$AUTOPILOT"
  echo "autopilot_prompt=$AUTOPILOT_PROMPT"
  echo "refresh_falsifiers=$REFRESH_FALSIFIERS"
  echo "worker_stale_seconds=$WORKER_STALE_SECONDS"
}

worker_elapsed_seconds() {
  [[ -f "$WORKER_STARTED_AT_FILE" ]] || {
    printf 'unknown'
    return 0
  }
  local started now
  started="$(cat "$WORKER_STARTED_AT_FILE" 2>/dev/null || true)"
  [[ "$started" =~ ^[0-9]+$ ]] || {
    printf 'unknown'
    return 0
  }
  now="$(epoch_now)"
  printf '%s' "$((now - started))"
}

worker_run_dir() {
  [[ -f "$WORKER_RUN_DIR_FILE" ]] || return 1
  cat "$WORKER_RUN_DIR_FILE"
}

log_worker_sizes() {
  local run_dir="$1"
  echo "worker_stdout_bytes=$(file_size "$run_dir/stdout.log")"
  echo "worker_stderr_bytes=$(file_size "$run_dir/stderr.log")"
  echo "worker_final_bytes=$(file_size "$run_dir/final.md")"
}

file_mtime_epoch() {
  local path="$1"
  [[ -f "$path" ]] || return 1
  stat -f '%m' "$path" 2>/dev/null || stat -c '%Y' "$path" 2>/dev/null
}

iso_from_epoch() {
  local epoch="$1"
  date -u -r "$epoch" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null \
    || date -u -d "@$epoch" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null \
    || printf 'unknown'
}

worker_last_output_epoch() {
  local run_dir="$1"
  local file mtime latest=""
  for file in "$run_dir/stdout.log" "$run_dir/stderr.log" "$run_dir/final.md"; do
    [[ -s "$file" ]] || continue
    mtime="$(file_mtime_epoch "$file" || true)"
    [[ "$mtime" =~ ^[0-9]+$ ]] || continue
    if [[ -z "$latest" || "$mtime" -gt "$latest" ]]; then
      latest="$mtime"
    fi
  done
  [[ -n "$latest" ]] || return 1
  printf '%s\n' "$latest"
}

log_worker_progress() {
  local run_dir="$1"
  local last_output now idle elapsed
  now="$(epoch_now)"
  elapsed="$(worker_elapsed_seconds)"
  echo "worker_stale_threshold_seconds=$WORKER_STALE_SECONDS"
  last_output="$(worker_last_output_epoch "$run_dir" || true)"
  if [[ -z "${last_output:-}" ]]; then
    echo "worker_last_output_at=none"
    echo "worker_output_idle_seconds=unknown"
    echo "worker_progress_state=no_output_yet"
    return 0
  fi

  idle="$((now - last_output))"
  echo "worker_last_output_at=$(iso_from_epoch "$last_output")"
  echo "worker_output_idle_seconds=$idle"
  if [[ "$elapsed" =~ ^[0-9]+$ && "$idle" -ge "$WORKER_STALE_SECONDS" && "$elapsed" -ge "$WORKER_STALE_SECONDS" ]]; then
    echo "worker_progress_state=stale_silent"
    echo "worker_stale_hint=worker_not_killed_automatically_use_stop-worker_or_kill-worker_explicitly_if_restart_is_desired"
  else
    echo "worker_progress_state=recent_or_within_stale_window"
  fi
}

log_git_dirty_summary() {
  local status dirty_count
  status="$(git status --short --untracked-files=all 2>/dev/null || true)"
  if [[ -z "$status" ]]; then
    echo "git_dirty_count=0"
    echo "git_dirty_summary=clean"
    return 0
  fi

  dirty_count="$(printf '%s\n' "$status" | wc -l | tr -d '[:space:]')"
  echo "git_dirty_count=$dirty_count"
  echo "git_dirty_summary:"
  printf '%s\n' "$status" | sed -n '1,80p'
}

log_architecture_cursor() {
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
}

log_optional_falsifiers() {
  if [[ "$REFRESH_FALSIFIERS" == "1" ]]; then
    echo
    echo "[optional falsifier refresh: enabled]"
    Tools/falsifiers/f_capability_ceiling_evaluation_kernel.sh || true
    Tools/falsifiers/f_architecture_pending_work_guard.sh || true
  else
    echo
    echo "[optional falsifier refresh: skipped]"
    echo "Set EPISTEMOS_ARCH_LOOP_REFRESH_FALSIFIERS=1 to refresh schema artifacts."
  fi
}

unique_run_dir() {
  local tick_id="$1"
  local safe_tick_id="${tick_id//:/}"
  safe_tick_id="${safe_tick_id//-/}"
  local run_dir="$AUTOPILOT_LOG_DIR/$safe_tick_id"
  if [[ ! -e "$run_dir" ]]; then
    printf '%s\n' "$run_dir"
    return 0
  fi

  local suffix=1
  while [[ -e "${run_dir}_$suffix" ]]; do
    suffix="$((suffix + 1))"
  done
  printf '%s\n' "${run_dir}_$suffix"
}

write_worker_runner() {
  local runner="$1"
  cat > "$runner" <<'WORKER'
#!/usr/bin/env bash
set +e
trap '' HUP

root="$1"
prompt="$2"
stdout="$3"
stderr="$4"
final="$5"
run_dir="$6"
worker_exit_file="$7"
worker_pid_file="$8"

printf '%s\n' "$$" > "$worker_pid_file"
codex \
  -C "$root" \
  --add-dir "$root/.." \
  --sandbox danger-full-access \
  --ask-for-approval never \
  exec \
  --output-last-message "$final" \
  - < "$prompt" > "$stdout" 2> "$stderr"
status=$?
printf '%s\n' "$status" > "$run_dir/exit_code"
printf '%s\n' "$status" > "$worker_exit_file"
date -u '+%Y-%m-%dT%H:%M:%SZ' > "$run_dir/completed_at"
exit "$status"
WORKER
  chmod +x "$runner"
}

launch_worker() {
  local tick_id="$1"

  if worker_is_running; then
    echo "[worker: launch skipped]"
    echo "reason=worker_already_active"
    log_active_worker
    return 0
  fi

  echo
  echo "[worker: launch requested]"
  if ! command -v codex >/dev/null 2>&1; then
    echo "worker_launch_skipped=codex_cli_not_found"
    return 0
  fi
  if [[ ! -f "$AUTOPILOT_PROMPT" ]]; then
    echo "worker_launch_skipped=prompt_not_found"
    echo "autopilot_prompt=$AUTOPILOT_PROMPT"
    return 0
  fi

  local run_dir stdout stderr final runner started_at head_start pid worker_screen
  run_dir="$(unique_run_dir "$tick_id")"
  stdout="$run_dir/stdout.log"
  stderr="$run_dir/stderr.log"
  final="$run_dir/final.md"
  runner="$run_dir/worker.sh"
  started_at="$(epoch_now)"
  head_start="$(git rev-parse HEAD 2>/dev/null || echo unknown)"

  mkdir -p "$run_dir"
  printf '%s\n' "$head_start" > "$run_dir/head.start"
  printf '%s\n' "$AUTOPILOT_PROMPT" > "$run_dir/prompt.path"
  printf '%s\n' "$(utc_now)" > "$run_dir/started_at"
  : > "$stdout"
  : > "$stderr"
  rm -f "$final" "$WORKER_EXIT_FILE" "$run_dir/exit_code" "$run_dir/completed_at"

  printf '%s\n' "$started_at" > "$WORKER_STARTED_AT_FILE"
  printf '%s\n' "$run_dir" > "$WORKER_RUN_DIR_FILE"

  write_worker_runner "$runner"
  worker_screen="${SCREEN_NAME}_worker_$(basename "$run_dir")"
  if command -v screen >/dev/null 2>&1; then
    screen -dmS "$worker_screen" bash "$runner" \
      "$ROOT" "$AUTOPILOT_PROMPT" "$stdout" "$stderr" "$final" \
      "$run_dir" "$WORKER_EXIT_FILE" "$WORKER_PID_FILE"
    local _wait
    for _wait in 1 2 3 4 5 6 7 8 9 10; do
      pid="$(read_worker_pid || true)"
      [[ -n "${pid:-}" ]] && break
      sleep 0.1
    done
  else
    nohup bash "$runner" \
      "$ROOT" "$AUTOPILOT_PROMPT" "$stdout" "$stderr" "$final" \
      "$run_dir" "$WORKER_EXIT_FILE" "$WORKER_PID_FILE" >/dev/null 2>&1 &
    pid="$!"
    printf '%s\n' "$pid" > "$WORKER_PID_FILE"
  fi

  if [[ -z "${pid:-}" ]]; then
    echo "worker_launch_failed=pid_not_recorded"
    rm -f "$WORKER_PID_FILE" "$WORKER_STARTED_AT_FILE" "$WORKER_RUN_DIR_FILE"
    return 1
  fi

  echo "worker_pid=$pid"
  echo "worker_screen=$worker_screen"
  echo "worker_started_at_epoch=$started_at"
  echo "worker_run_dir=$run_dir"
  echo "worker_prompt=$AUTOPILOT_PROMPT"
  echo "worker_head_start=$head_start"
}

log_active_worker() {
  local pid run_dir
  pid="$(read_worker_pid || true)"
  run_dir="$(worker_run_dir || true)"
  echo "[worker: active]"
  echo "worker_pid=${pid:-unknown}"
  echo "worker_elapsed_seconds=$(worker_elapsed_seconds)"
  echo "worker_run_dir=${run_dir:-unknown}"
  if [[ -n "${run_dir:-}" ]]; then
    log_worker_sizes "$run_dir"
    log_worker_progress "$run_dir"
  fi
  log_git_dirty_summary
}

reap_finished_worker() {
  [[ -f "$WORKER_PID_FILE" || -f "$WORKER_EXIT_FILE" ]] || return 1

  if worker_is_running; then
    return 1
  fi

  local pid run_dir exit_code head_start head_now completed_at
  pid="$(read_worker_pid || true)"
  run_dir="$(worker_run_dir || true)"
  exit_code="unknown"
  if [[ -f "$WORKER_EXIT_FILE" ]]; then
    exit_code="$(cat "$WORKER_EXIT_FILE" 2>/dev/null || echo unknown)"
  elif [[ -n "${run_dir:-}" && -f "$run_dir/exit_code" ]]; then
    exit_code="$(cat "$run_dir/exit_code" 2>/dev/null || echo unknown)"
  fi

  echo
  echo "[worker: completed]"
  echo "worker_pid=${pid:-unknown}"
  echo "worker_exit=$exit_code"
  echo "worker_run_dir=${run_dir:-unknown}"
  if [[ -n "${run_dir:-}" ]]; then
    log_worker_sizes "$run_dir"
    if [[ -s "$run_dir/final.md" ]]; then
      echo "--- worker final tail ---"
      tail -80 "$run_dir/final.md"
    else
      echo "worker_final_tail=empty_or_missing"
    fi

    head_start="$(cat "$run_dir/head.start" 2>/dev/null || echo unknown)"
    completed_at="$(cat "$run_dir/completed_at" 2>/dev/null || utc_now)"
  else
    head_start="unknown"
    completed_at="$(utc_now)"
  fi
  head_now="$(git rev-parse HEAD 2>/dev/null || echo unknown)"

  echo "worker_head_start=$head_start"
  echo "worker_head_now=$head_now"
  if [[ "$head_start" != "$head_now" ]]; then
    echo "worker_commit_changed=true"
    echo "worker_commit_hash=$head_now"
  else
    echo "worker_commit_changed=false"
  fi

  {
    printf 'run_dir=%s\n' "${run_dir:-unknown}"
    printf 'pid=%s\n' "${pid:-unknown}"
    printf 'exit_code=%s\n' "$exit_code"
    printf 'completed_at=%s\n' "$completed_at"
    printf 'head_start=%s\n' "$head_start"
    printf 'head_end=%s\n' "$head_now"
  } > "$LAST_COMPLETED_RUN_FILE"

  rm -f "$WORKER_PID_FILE" "$WORKER_STARTED_AT_FILE" "$WORKER_RUN_DIR_FILE" "$WORKER_EXIT_FILE"
  return 0
}

start_loop() {
  ensure_state_dir
  load_mode_env
  INTERVAL_SECONDS="${EPISTEMOS_ARCH_LOOP_INTERVAL_SECONDS:-$INTERVAL_SECONDS}"
  AUTOPILOT="${EPISTEMOS_ARCH_LOOP_AUTOPILOT:-$AUTOPILOT}"
  AUTOPILOT_PROMPT="${EPISTEMOS_ARCH_LOOP_AUTOPILOT_PROMPT:-$AUTOPILOT_PROMPT}"
  REFRESH_FALSIFIERS="${EPISTEMOS_ARCH_LOOP_REFRESH_FALSIFIERS:-$REFRESH_FALSIFIERS}"
  WORKER_STALE_SECONDS="${EPISTEMOS_ARCH_LOOP_STALE_WORKER_SECONDS:-$WORKER_STALE_SECONDS}"

  if scheduler_is_running; then
    echo "architecture heartbeat loop already running pid=$(read_scheduler_pid)"
    log_mode
    echo "log: $LOG_FILE"
    return 0
  fi

  rm -f "$PID_FILE"
  rm -rf "$LOCK_DIR"
  : >> "$LOG_FILE"

  local script pid
  script="$ROOT/Tools/audits/epistemos_architecture_heartbeat_loop.sh"
  write_mode_env ""
  if command -v screen >/dev/null 2>&1; then
    screen -dmS "$SCREEN_NAME" bash -lc \
      'cd "$1" && exec "$2" run >> "$3" 2>&1' \
      _ "$ROOT" "$script" "$LOG_FILE"
    local _wait
    for _wait in 1 2 3 4 5 6 7 8 9 10; do
      pid="$(read_scheduler_pid || true)"
      [[ -n "${pid:-}" ]] && break
      sleep 0.1
    done
  else
    nohup "$script" run >> "$LOG_FILE" 2>&1 < /dev/null &
    pid="$!"
    printf '%s\n' "$pid" > "$PID_FILE"
  fi
  write_mode_env "$pid"

  sleep 0.2
  if [[ -z "${pid:-}" ]] || ! pid_is_running "$pid"; then
    echo "failed to start architecture heartbeat loop"
    tail -40 "$LOG_FILE" || true
    return 1
  fi

  echo "started architecture heartbeat loop pid=$pid interval=${INTERVAL_SECONDS}s"
  echo "autopilot: $AUTOPILOT"
  echo "mode: $MODE_ENV_FILE"
  echo "log: $LOG_FILE"
}

stop_loop() {
  ensure_state_dir
  load_mode_env
  local kill_worker_arg="${1:-0}"
  local pid

  if scheduler_is_running; then
    pid="$(read_scheduler_pid)"
    kill "$pid" 2>/dev/null || true
    local _wait
    for _wait in 1 2 3 4 5 6 7 8 9 10; do
      pid_is_running "$pid" || break
      sleep 0.1
    done
    if pid_is_running "$pid"; then
      echo "architecture heartbeat loop stop requested pid=$pid still_running=true"
    else
      echo "stopped architecture heartbeat loop pid=$pid"
      rm -f "$PID_FILE"
    fi
  else
    echo "architecture heartbeat loop is not running"
    rm -f "$PID_FILE"
  fi

  if worker_is_running; then
    echo "active worker left running:"
    log_active_worker
  elif [[ -f "$WORKER_EXIT_FILE" ]]; then
    echo "worker completed and will be reaped by the next tick"
  else
    echo "active worker: none"
  fi

  if [[ "$kill_worker_arg" == "1" ]]; then
    kill_worker "0"
  fi
}

status_loop() {
  ensure_state_dir
  load_mode_env
  local verbose="${1:-0}"

  if scheduler_is_running; then
    echo "architecture heartbeat loop running pid=$(read_scheduler_pid)"
  else
    echo "architecture heartbeat loop stopped"
  fi
  log_mode
  echo "state: $STATE_DIR"
  echo "log: $LOG_FILE"

  if [[ -f "$LAST_TICK_FILE" ]]; then
    echo "last_tick=$(cat "$LAST_TICK_FILE")"
  else
    echo "last_tick=never"
  fi

  if worker_is_running; then
    log_active_worker
  elif [[ -f "$WORKER_EXIT_FILE" ]]; then
    echo "[worker: completed_pending_reap]"
    echo "worker_exit=$(cat "$WORKER_EXIT_FILE" 2>/dev/null || echo unknown)"
    echo "worker_run_dir=$(worker_run_dir || echo unknown)"
  else
    echo "[worker: inactive]"
  fi

  if [[ -f "$LAST_COMPLETED_RUN_FILE" ]]; then
    echo "last_completed_run=$LAST_COMPLETED_RUN_FILE"
    if [[ "$verbose" == "1" ]]; then
      cat "$LAST_COMPLETED_RUN_FILE"
    fi
  else
    echo "last_completed_run=none"
  fi

  if [[ "$verbose" == "1" && -f "$LOG_FILE" ]]; then
    echo "--- last 80 log lines ---"
    tail -80 "$LOG_FILE"
  fi
}

run_loop() {
  ensure_state_dir
  load_mode_env
  printf '%s\n' "$$" > "$PID_FILE"
  write_mode_env "$$"
  echo "architecture heartbeat loop booted at $(utc_now)"
  echo "root: $ROOT"
  log_mode

  while true; do
    load_mode_env
    local tick_started_at now sleep_for
    tick_started_at="$(epoch_now)"
    "$0" tick || true
    load_mode_env
    now="$(epoch_now)"
    sleep_for="$((tick_started_at + INTERVAL_SECONDS - now))"
    if [[ "$sleep_for" -lt 1 ]]; then
      sleep_for=1
    fi
    sleep "$sleep_for" || true
  done
}

with_tick_lock() {
  ensure_state_dir
  load_mode_env
  local dry_run="${1:-0}"
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "tick skipped: previous tick still running"
    if [[ -f "$LOCK_DIR/pid" ]]; then
      echo "lock_pid=$(cat "$LOCK_DIR/pid" 2>/dev/null || true)"
    fi
    return 0
  fi
  printf '%s\n' "$$" > "$LOCK_DIR/pid"
  printf '%s\n' "$(utc_now)" > "$LOCK_DIR/started_at"

  local status
  set +e
  run_tick_body "$dry_run"
  status="$?"
  set -e
  rm -rf "$LOCK_DIR"
  return "$status"
}

run_tick_body() {
  local dry_run="$1"
  local now now_epoch completed_this_tick
  now="$(utc_now)"
  now_epoch="$(epoch_now)"
  completed_this_tick=0
  printf '%s\n' "$now" > "$LAST_TICK_FILE"

  echo
  echo "heartbeat timestamp=$now scheduler_pid=$$ autopilot=$AUTOPILOT"
  echo "=== architecture heartbeat tick $now ==="
  echo "root: $ROOT"
  echo "head: $(git rev-parse --short=12 HEAD 2>/dev/null || echo unknown)"
  echo "branch: $(git branch --show-current 2>/dev/null || echo detached)"
  echo "safe_mode: heavy_model=off metal=off mmap_stress=off xcode=off live_inference=off"
  log_mode

  echo
  echo "[git dirty summary]"
  log_git_dirty_summary

  echo
  echo "[git diff --check]"
  if git diff --check; then
    echo "diff_check=pass"
  else
    echo "diff_check=fail"
  fi

  log_architecture_cursor
  log_optional_falsifiers

  if reap_finished_worker; then
    completed_this_tick=1
  fi

  if [[ "$completed_this_tick" == "1" ]]; then
    echo
    echo "[worker: next_launch_waits_for_next_tick]"
  elif worker_is_running; then
    echo
    log_active_worker
  elif [[ "$dry_run" == "1" ]]; then
    echo
    echo "[worker: dry-run]"
    echo "worker_launch=skipped"
  elif [[ "$AUTOPILOT" == "1" ]]; then
    launch_worker "$now"
  else
    echo
    echo "[worker: autopilot disabled]"
    echo "Set EPISTEMOS_ARCH_LOOP_AUTOPILOT=1 before start to run one Codex worker per cycle."
  fi

  echo "tick_epoch=$now_epoch"
  echo "=== tick complete $now ==="
}

kill_descendants() {
  local parent="$1"
  local signal="$2"
  local child
  for child in $(pgrep -P "$parent" 2>/dev/null || true); do
    kill_descendants "$child" "$signal"
    kill "-$signal" "$child" 2>/dev/null || true
  done
}

kill_worker() {
  ensure_state_dir
  load_mode_env
  local force="${1:-0}"
  local pid signal
  pid="$(read_worker_pid || true)"
  if [[ -z "${pid:-}" ]] || ! pid_is_running "$pid"; then
    echo "active worker: none"
    rm -f "$WORKER_PID_FILE" "$WORKER_STARTED_AT_FILE" "$WORKER_RUN_DIR_FILE" "$WORKER_EXIT_FILE"
    return 0
  fi

  signal="TERM"
  if [[ "$force" == "1" ]]; then
    signal="KILL"
  fi
  kill_descendants "$pid" "$signal"
  kill "-$signal" "$pid" 2>/dev/null || true
  echo "worker_stop_signal=$signal"
  echo "worker_pid=$pid"
  echo "worker_run_dir=$(worker_run_dir || echo unknown)"
}

command="${1:-}"
shift || true

case "$command" in
  start)
    start_loop
    ;;
  stop)
    kill_active_worker=0
    if [[ "${1:-}" == "--kill-worker" ]]; then
      kill_active_worker=1
    fi
    stop_loop "$kill_active_worker"
    ;;
  status)
    verbose=0
    if [[ "${1:-}" == "--verbose" || "${1:-}" == "-v" ]]; then
      verbose=1
    fi
    status_loop "$verbose"
    ;;
  tick)
    dry_run=0
    if [[ "${1:-}" == "--dry-run" ]]; then
      dry_run=1
    fi
    with_tick_lock "$dry_run"
    ;;
  run)
    run_loop
    ;;
  stop-worker)
    kill_worker "0"
    ;;
  kill-worker)
    force=0
    if [[ "${1:-}" == "--force" ]]; then
      force=1
    fi
    kill_worker "$force"
    ;;
  *)
    usage
    exit 2
    ;;
esac
