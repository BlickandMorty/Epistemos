#!/usr/bin/env bash
set -euo pipefail

# Plan 3 browser-use Pro loopback smoke.
# Starts the staged Gradio Web UI on 127.0.0.1, probes the root document,
# records non-secret evidence, and always stops the child process.

usage() {
  cat <<'USAGE'
Usage: browser-use-pro-loopback-smoke.sh [--repo-root PATH] [--port PORT] [--timeout SECONDS] [--artifact-dir PATH]
                                      [--signed-bundle PATH | --payload-root PATH]

Verifies the staged or signed browser-use Pro payload can boot the vendored
web-ui.py on 127.0.0.1 and answer an HTTP loopback request. This is a server
smoke harness; it does not load the Epistemos WKWebView shell or submit an
agent task.
USAGE
}

repo_root=""
port=""
timeout_seconds=90
artifact_dir=""
payload_root=""
signed_bundle=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      repo_root="${2:?missing --repo-root value}"
      shift 2
      ;;
    --port)
      port="${2:?missing --port value}"
      shift 2
      ;;
    --timeout)
      timeout_seconds="${2:?missing --timeout value}"
      shift 2
      ;;
    --artifact-dir)
      artifact_dir="${2:?missing --artifact-dir value}"
      shift 2
      ;;
    --payload-root)
      payload_root="${2:?missing --payload-root value}"
      shift 2
      ;;
    --signed-bundle)
      signed_bundle="${2:?missing --signed-bundle value}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 64
      ;;
  esac
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "$repo_root" ]]; then
  repo_root="$(cd -- "$script_dir/.." && pwd)"
else
  repo_root="$(cd -- "$repo_root" && pwd)"
fi

if [[ -n "$signed_bundle" && -n "$payload_root" ]]; then
  echo "Use either --signed-bundle or --payload-root, not both" >&2
  exit 64
fi

if [[ -n "$signed_bundle" ]]; then
  signed_bundle="$(cd -- "$signed_bundle" && pwd)"
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$signed_bundle" >/dev/null
  payload_root="$signed_bundle/Contents/Resources/BrowserUsePro"
elif [[ -n "$payload_root" ]]; then
  payload_root="$(cd -- "$payload_root" && pwd)"
fi

if [[ -n "$payload_root" ]]; then
  vendor_root="$payload_root"
  python_bin="$payload_root/.venv/bin/python"
  webui_py="$payload_root/web-ui/webui.py"
  playwright_dir="$payload_root/playwright"
  wheelhouse_dir="$payload_root/wheels"
  build_manifest="$payload_root/BUILD_MANIFEST.json"
else
  vendor_root="$repo_root/agent_core/vendor/browser-use"
  python_bin="$repo_root/build/browser-use-pro/.venv/bin/python"
  webui_py="$vendor_root/web-ui/webui.py"
  playwright_dir="$vendor_root/playwright"
  wheelhouse_dir="$vendor_root/wheels"
  build_manifest="$vendor_root/BUILD_MANIFEST.json"
fi

[[ -x "$python_bin" ]] || { echo "Missing executable staged Python at $python_bin" >&2; exit 66; }
[[ -f "$webui_py" ]] || { echo "Missing browser-use web-ui entrypoint at $webui_py" >&2; exit 66; }
[[ -f "$build_manifest" ]] || { echo "Missing browser-use BUILD_MANIFEST.json at $build_manifest" >&2; exit 66; }
[[ -d "$wheelhouse_dir" ]] || { echo "Missing browser-use wheelhouse at $wheelhouse_dir" >&2; exit 66; }
[[ -d "$playwright_dir" ]] || { echo "Missing browser-use Playwright payload at $playwright_dir" >&2; exit 66; }
if [[ -n "$signed_bundle" ]]; then
  signature_manifest="$payload_root/SIGNATURE_MANIFEST.json"
  if [[ ! -f "$signature_manifest" || -L "$signature_manifest" ]]; then
    echo "Missing regular signed package evidence at $signature_manifest" >&2
    exit 66
  fi
fi

if [[ -z "$port" ]]; then
  port="$(PYTHONDONTWRITEBYTECODE=1 "$python_bin" - <<'PY'
import socket
with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
    sock.bind(("127.0.0.1", 0))
    print(sock.getsockname()[1])
PY
)"
fi

if ! [[ "$port" =~ ^[0-9]+$ ]] || (( port < 1024 || port > 65535 )); then
  echo "Port must be an integer from 1024 through 65535; got $port" >&2
  exit 64
fi
if ! [[ "$timeout_seconds" =~ ^[0-9]+$ ]] || (( timeout_seconds < 5 || timeout_seconds > 600 )); then
  echo "Timeout must be an integer from 5 through 600 seconds; got $timeout_seconds" >&2
  exit 64
fi

if [[ -z "$artifact_dir" ]]; then
  artifact_dir="$(mktemp -d "${TMPDIR:-/tmp}/epistemos-browser-use-pro-smoke.XXXXXX")"
else
  if [[ -L "$artifact_dir" ]]; then
    echo "Artifact directory must not be a symlink: $artifact_dir" >&2
    exit 66
  fi
  mkdir -p "$artifact_dir"
  if [[ -L "$artifact_dir" ]]; then
    echo "Artifact directory must not be a symlink: $artifact_dir" >&2
    exit 66
  fi
  artifact_dir="$(cd -P -- "$artifact_dir" && pwd)"
fi

state_root="$(mktemp -d "${TMPDIR:-/tmp}/epistemos-browser-use-pro-state.XXXXXX")"
log_file="$artifact_dir/webui.log"
body_file="$artifact_dir/root.html"
result_file="$artifact_dir/result.json"
state_log_file="$state_root/webui.log"
probe_body_file="$state_root/root.html"
max_log_evidence_bytes=$((1024 * 1024))
max_body_evidence_bytes=$((1024 * 1024))
loopback_url="http://127.0.0.1:$port/"
webui_pid=""
chmod 700 "$state_root"

copy_evidence_no_follow() {
  local source_path="$1"
  local destination_path="$2"
  local label="$3"
  local max_bytes="$4"
  SOURCE_PATH="$source_path" \
  DESTINATION_PATH="$destination_path" \
  EVIDENCE_LABEL="$label" \
  MAX_EVIDENCE_BYTES="$max_bytes" \
  PYTHONDONTWRITEBYTECODE=1 \
  "$python_bin" - <<'PY'
import os
import stat
from pathlib import Path

source = Path(os.environ["SOURCE_PATH"])
destination = Path(os.environ["DESTINATION_PATH"])
label = os.environ["EVIDENCE_LABEL"]
max_bytes = int(os.environ["MAX_EVIDENCE_BYTES"])
if max_bytes <= 0:
    raise SystemExit(f"{label} byte cap is invalid")

read_flags = os.O_RDONLY | getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0)
read_fd = os.open(source, read_flags)
try:
    metadata = os.fstat(read_fd)
    if not stat.S_ISREG(metadata.st_mode):
        raise SystemExit(f"{label} source is not a regular file")
    with os.fdopen(read_fd, "rb") as handle:
        read_fd = -1
        data = handle.read(max_bytes + 1)
finally:
    if read_fd >= 0:
        os.close(read_fd)

if len(data) > max_bytes:
    data = data[:max_bytes] + b"\n[epistemos-smoke: evidence truncated]\n"

write_flags = (
    os.O_WRONLY
    | os.O_CREAT
    | os.O_TRUNC
    | getattr(os, "O_CLOEXEC", 0)
    | getattr(os, "O_NOFOLLOW", 0)
)
write_fd = os.open(destination, write_flags, 0o600)
try:
    metadata = os.fstat(write_fd)
    if not stat.S_ISREG(metadata.st_mode):
        raise SystemExit(f"{label} destination is not a regular file")
    with os.fdopen(write_fd, "wb") as handle:
        write_fd = -1
        handle.write(data)
finally:
    if write_fd >= 0:
        os.close(write_fd)
PY
}

body_has_marker_no_follow() {
  local source_path="$1"
  SOURCE_PATH="$source_path" \
  PYTHONDONTWRITEBYTECODE=1 \
  "$python_bin" - <<'PY'
import os
import stat
import sys
from pathlib import Path

max_sample_bytes = 256 * 1024
path = Path(os.environ["SOURCE_PATH"])
flags = os.O_RDONLY | getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0)
fd = os.open(path, flags)
try:
    metadata = os.fstat(fd)
    if not stat.S_ISREG(metadata.st_mode):
        raise SystemExit(1)
    with os.fdopen(fd, "rb") as handle:
        fd = -1
        body = handle.read(max_sample_bytes)
finally:
    if fd >= 0:
        os.close(fd)

lower_body = body.decode("utf-8", errors="replace").lower()
if any(marker in lower_body for marker in ("gradio", "browser use webui", "<html")):
    sys.exit(0)
sys.exit(1)
PY
}

sync_log_evidence() {
  copy_evidence_no_follow "$state_log_file" "$log_file" "web-ui log evidence" "$max_log_evidence_bytes"
}

sync_body_evidence() {
  if [[ -f "$probe_body_file" ]]; then
    copy_evidence_no_follow "$probe_body_file" "$body_file" "root body evidence" "$max_body_evidence_bytes"
  fi
}

write_result() {
  local passed="$1"
  local reason="$2"
  local http_status="${3:-}"
  RESULT_FILE="$result_file" \
  PASSED="$passed" \
  REASON="$reason" \
  HTTP_STATUS="$http_status" \
  LOOPBACK_URL="$loopback_url" \
  ARTIFACT_DIR="$artifact_dir" \
  LOG_FILE="$log_file" \
  BODY_FILE="$body_file" \
  PYTHON_BIN="$python_bin" \
  WEBUI_PY="$webui_py" \
  PLAYWRIGHT_DIR="$playwright_dir" \
  PAYLOAD_ROOT="$vendor_root" \
  SIGNED_BUNDLE="$signed_bundle" \
  TIMEOUT_SECONDS="$timeout_seconds" \
  PYTHONDONTWRITEBYTECODE=1 \
  "$python_bin" - <<'PY'
import json
import os
import stat
from pathlib import Path

MAX_BODY_SAMPLE_BYTES = 256 * 1024


def read_body_sample_no_follow(path):
    if not path.exists():
        return b"", False
    flags = os.O_RDONLY | getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0)
    fd = os.open(path, flags)
    try:
        metadata = os.fstat(fd)
        if not stat.S_ISREG(metadata.st_mode):
            return b"", False
        with os.fdopen(fd, "rb") as handle:
            fd = -1
            data = handle.read(MAX_BODY_SAMPLE_BYTES + 1)
    finally:
        if fd >= 0:
            os.close(fd)
    return data[:MAX_BODY_SAMPLE_BYTES], len(data) > MAX_BODY_SAMPLE_BYTES


def write_text_no_follow(path, text):
    flags = (
        os.O_WRONLY
        | os.O_CREAT
        | os.O_TRUNC
        | getattr(os, "O_CLOEXEC", 0)
        | getattr(os, "O_NOFOLLOW", 0)
    )
    fd = os.open(path, flags, 0o600)
    try:
        metadata = os.fstat(fd)
        if not stat.S_ISREG(metadata.st_mode):
            raise SystemExit("result evidence path is not a regular file")
        with os.fdopen(fd, "wb") as handle:
            fd = -1
            handle.write(text.encode("utf-8"))
    finally:
        if fd >= 0:
            os.close(fd)


body_path = Path(os.environ["BODY_FILE"])
body_bytes, body_truncated = read_body_sample_no_follow(body_path)
body = body_bytes.decode("utf-8", errors="replace")
lower_body = body.lower()
markers = {
    "html": "<html" in lower_body,
    "gradio": "gradio" in lower_body,
    "browser_use_webui": "browser use webui" in lower_body,
}
status = os.environ["HTTP_STATUS"]
payload = {
    "passed": os.environ["PASSED"] == "true",
    "reason": os.environ["REASON"],
    "url": os.environ["LOOPBACK_URL"],
    "bind_host": "127.0.0.1",
    "http_status": int(status) if status.isdigit() else None,
    "timeout_seconds": int(os.environ["TIMEOUT_SECONDS"]),
    "body_markers": markers,
    "body_bytes_sampled": len(body.encode("utf-8")),
    "artifact_dir": os.environ["ARTIFACT_DIR"],
    "log_file": os.environ["LOG_FILE"],
    "body_file": os.environ["BODY_FILE"],
    "body_truncated": body_truncated,
    "python": os.environ["PYTHON_BIN"],
    "webui": os.environ["WEBUI_PY"],
    "playwright_browsers_path": os.environ["PLAYWRIGHT_DIR"],
    "payload_root": os.environ["PAYLOAD_ROOT"],
    "signed_bundle": os.environ["SIGNED_BUNDLE"] or None,
    "secrets": "not recorded",
}
write_text_no_follow(Path(os.environ["RESULT_FILE"]), json.dumps(payload, indent=2, sort_keys=True) + "\n")
PY
}

cleanup() {
  if [[ -n "$webui_pid" ]] && kill -0 "$webui_pid" 2>/dev/null; then
    kill "$webui_pid" 2>/dev/null || true
    for _ in $(seq 1 20); do
      kill -0 "$webui_pid" 2>/dev/null || break
      sleep 0.1
    done
    kill -9 "$webui_pid" 2>/dev/null || true
    wait "$webui_pid" 2>/dev/null || true
  fi
  rm -rf "$state_root" 2>/dev/null || true
}
trap cleanup EXIT

mkdir -p "$state_root/home" "$state_root/browser-use-home"
: >"$state_log_file"
: >"$probe_body_file"

(
  cd "$state_root"
  HOME="$state_root/home" \
  BROWSER_USE_HOME="$state_root/browser-use-home" \
  PLAYWRIGHT_BROWSERS_PATH="$playwright_dir" \
  PYTHON_DOTENV_DISABLED=true \
  PYTHONDONTWRITEBYTECODE=1 \
  ANONYMIZED_TELEMETRY=false \
  BROWSER_USE_CLOUD_SYNC=false \
  BROWSER_USE_VERSION_CHECK=false \
  GRADIO_ANALYTICS_ENABLED=False \
  "$python_bin" "$webui_py" --ip 127.0.0.1 --port "$port" --theme Ocean
) >"$state_log_file" 2>&1 &
webui_pid=$!

deadline=$((SECONDS + timeout_seconds))
http_status=""
while (( SECONDS < deadline )); do
  if ! kill -0 "$webui_pid" 2>/dev/null; then
    sync_log_evidence
    sync_body_evidence
    write_result false "web-ui process exited before becoming healthy" "$http_status"
    echo "browser-use Pro Web UI exited before readiness; evidence: $result_file" >&2
    tail -n 40 "$state_log_file" >&2 || true
    exit 2
  fi

  : >"$probe_body_file"
  http_status="$(curl -fsS --max-time 2 -o "$probe_body_file" -w '%{http_code}' "$loopback_url" 2>/dev/null || true)"
  sync_body_evidence
  if [[ "$http_status" == "200" ]] && body_has_marker_no_follow "$probe_body_file"; then
    sync_log_evidence
    write_result true "loopback Gradio root answered" "$http_status"
    echo "browser-use Pro loopback smoke passed: $loopback_url"
    echo "evidence: $result_file"
    exit 0
  fi

  sleep 1
done

sync_log_evidence
sync_body_evidence
write_result false "timed out waiting for loopback Gradio root" "$http_status"
echo "browser-use Pro loopback smoke timed out; evidence: $result_file" >&2
tail -n 40 "$state_log_file" >&2 || true
exit 2
