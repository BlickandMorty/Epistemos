#!/bin/bash
# Goose Phase-0 live ACP surface probe — end-to-end wrapper (re-runnable evidence).
#
# Spawns the staged Goose `goose serve` on an ephemeral loopback port with an
# isolated HOME + a provider default (so session/new + prompt resolve), runs the
# Node ACP probe (scripts/goose-acp-live-probe.mjs) against it, then tears the
# server down. Proves the live ACP surface the env-blocked app-hosted suites cover,
# without the test host. No real provider key needed (prompt proves stream/end_turn
# plumbing; a dummy key yields used=0 tokens — real token content needs owner creds).
#
# Usage:  bash scripts/goose-acp-live-probe.sh
# Env:    GOOSE_BIN (path to goose binary; default = staged GooseRuntime/goose)
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GOOSE_BIN="${GOOSE_BIN:-$HOME/Library/Application Support/Epistemos/GooseRuntime/goose}"
if [[ ! -x "$GOOSE_BIN" ]]; then
  # fall back to the cargo release build used at staging time
  GOOSE_BIN="$ROOT_DIR/.research-clones/work/goose/target/aarch64-apple-darwin/release/goose"
fi
[[ -x "$GOOSE_BIN" ]] || { echo "goose binary not found (set GOOSE_BIN)"; exit 64; }

PORT="${PORT:-53300}"
SECRET="probe-$$"
GHOME="$(mktemp -d)"
LOG="$(mktemp)"
cleanup() {
  [[ -n "${GPID:-}" ]] && kill -9 "$GPID" 2>/dev/null || true
  for pid in $(lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | awk -v p=":$PORT" '/goose/ && $9 ~ p {print $2}' | sort -u); do kill -9 "$pid" 2>/dev/null || true; done
  rm -rf "$GHOME" "$LOG" 2>/dev/null || true
}
trap cleanup EXIT

HOME="$GHOME" GOOSE_PROVIDER="${GOOSE_PROVIDER:-openai}" GOOSE_MODEL="${GOOSE_MODEL:-gpt-4o-mini}" \
  OPENAI_API_KEY="${OPENAI_API_KEY:-sk-dummy-probe}" GOOSE_SERVER__SECRET_KEY="$SECRET" \
  "$GOOSE_BIN" serve --host 127.0.0.1 --port "$PORT" --with-builtin developer > "$LOG" 2>&1 &
GPID=$!

for i in $(seq 1 15); do
  sleep 1
  [[ "$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/health" 2>/dev/null)" == "200" ]] && break
  [[ $i -eq 15 ]] && { echo "goose serve never became healthy; log:"; tail -5 "$LOG"; exit 2; }
done
echo "goose serve healthy on 127.0.0.1:$PORT (binary: $GOOSE_BIN)"

node "$ROOT_DIR/scripts/goose-acp-live-probe.mjs" "ws://127.0.0.1:$PORT/acp?token=$SECRET"
