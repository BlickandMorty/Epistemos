#!/usr/bin/env bash

set -euo pipefail

APP_SUPPORT_DIR="${HOME}/Library/Application Support/Epistemos"
RUNTIME_DIR="${APP_SUPPORT_DIR}/runtime_diagnostics"
CRASH_DIR="${APP_SUPPORT_DIR}/crash_reports"
TODAY_FILE="${RUNTIME_DIR}/$(date +%F).ndjson"
SUMMARY_FILE="${RUNTIME_DIR}/$(date +%F)-summary.json"
SESSION_FILE="${RUNTIME_DIR}/current_session.json"
LOG_LEVEL="${LOG_LEVEL:-info}"
RUNTIME_TAIL_LINES="${RUNTIME_TAIL_LINES:-40}"

mkdir -p "${RUNTIME_DIR}" "${CRASH_DIR}"
touch "${TODAY_FILE}"

cat <<EOF
Watching Epistemos runtime signals
- Unified log predicate: process == "Epistemos" && subsystem == "com.epistemos"
- Unified log level: ${LOG_LEVEL}
- Runtime diagnostics: ${RUNTIME_DIR}
- Crash reports: ${CRASH_DIR}
- Daily diagnostics file: ${TODAY_FILE}
- Daily issue summary: ${SUMMARY_FILE}
- Current session snapshot: ${SESSION_FILE}
- Runtime tail lines: ${RUNTIME_TAIL_LINES}

Tip:
- Launch the app, then reproduce the issue.
- Runtime diagnostics are newline-delimited JSON you can grep or attach to bug reports.
- The session snapshot tracks lifecycle events, severity counts, and the latest durable issue.
EOF

cleanup() {
    trap - INT TERM EXIT
    kill 0
}

trap cleanup INT TERM EXIT

watch_json_snapshot() {
    local label="$1"
    local file_path="$2"
    local render_kind="$3"
    local previous_checksum=""

    while true; do
        if [[ -f "${file_path}" ]]; then
            local checksum
            checksum="$(/usr/bin/cksum < "${file_path}")"
            if [[ "${checksum}" != "${previous_checksum}" ]]; then
                previous_checksum="${checksum}"
                /usr/bin/python3 - "${label}" "${file_path}" "${render_kind}" <<'PY'
import json
import sys
from pathlib import Path

label = sys.argv[1]
file_path = Path(sys.argv[2])
render_kind = sys.argv[3]

try:
    payload = json.loads(file_path.read_text())
except Exception as exc:
    print(f"[{label}] failed to parse {file_path}: {exc}", flush=True)
    raise SystemExit(0)

if render_kind == "session":
    counts = payload.get("severityCounts", {})
    latest = payload.get("latestIssueMessage") or "none"
    lifecycle = payload.get("lifecycleEvents", [])
    latest_event = lifecycle[-1]["name"] if lifecycle else "none"
    print(
        f"[{label}] session={payload.get('sessionId')} latest_issue={latest} "
        f"counts={counts} latest_lifecycle={latest_event}",
        flush=True,
    )
elif render_kind == "summary":
    issues = payload.get("issues", [])
    if not issues:
        print(f"[{label}] no warning/error/fault issues captured yet", flush=True)
    else:
        top = issues[0]
        print(
            f"[{label}] top_issue={top.get('message')} severity={top.get('highestSeverity')} "
            f"count={top.get('count')} category={top.get('category')}",
            flush=True,
        )
PY
            fi
        fi
        sleep 2
    done
}

tail -n "${RUNTIME_TAIL_LINES}" -F "${TODAY_FILE}" | awk '{ print "[runtime] " $0; fflush(); }' &
watch_json_snapshot "session" "${SESSION_FILE}" "session" &
watch_json_snapshot "summary" "${SUMMARY_FILE}" "summary" &
/usr/bin/log stream \
    --style compact \
    --predicate 'process == "Epistemos" && subsystem == "com.epistemos"' \
    --level "${LOG_LEVEL}" | awk '{ print "[unified] " $0; fflush(); }' &

wait
