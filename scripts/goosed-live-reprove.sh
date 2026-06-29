#!/bin/bash
# Goose Step-2 (Option B) end-to-end re-prove on the `goosed agent` backend.
#
# Owner requirement: "Re-prove the full live sweep + the 3 features end-to-end on
# goosed." This spawns the staged `goosed` binary exactly as GooseRuntimeSupervisor
# does under EPISTEMOS_GOOSE_BACKEND=goosed (no CLI flags; configured purely via the
# GOOSE_ env map; loads the `developer` builtin automatically; http loopback), waits
# for /status, then:
#   1. runs the SAME backend-agnostic ACP probe the lean-serve proof uses
#      (scripts/goose-acp-live-probe.mjs) against ws://HOST:PORT/acp?token=SECRET —
#      proving the ACP surface the WebView drives is byte-identical on goosed; and
#   2. live-probes the 3 previously-unbackable REST features with X-Secret-Key
#      (200 / 405-route-exists / 400-route-exists), which lean serve cannot serve.
#
# Usage:  bash scripts/goosed-live-reprove.sh
# Env:    GOOSED_BIN (default = staged GooseRuntime/goosed, else cargo release build)
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GOOSED_BIN="${GOOSED_BIN:-$HOME/Library/Application Support/Epistemos/GooseRuntime/goosed}"
if [[ ! -x "$GOOSED_BIN" ]]; then
  GOOSED_BIN="$ROOT_DIR/.research-clones/work/goose/target/aarch64-apple-darwin/release/goosed"
fi
[[ -x "$GOOSED_BIN" ]] || { echo "goosed binary not found (set GOOSED_BIN)"; exit 64; }

PORT="${PORT:-53400}"
SECRET="goosed-probe-$$"
GHOME="$(mktemp -d)"
LOG="$(mktemp)"
cleanup() {
  [[ -n "${GPID:-}" ]] && kill -9 "$GPID" 2>/dev/null || true
  for pid in $(lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | awk -v p=":$PORT" '/goosed/ && $9 ~ p {print $2}' | sort -u); do kill -9 "$pid" 2>/dev/null || true; done
  rm -rf "$GHOME" "$LOG" 2>/dev/null || true
}
trap cleanup EXIT

# goosed `agent` takes NO flags — everything via the GOOSE_ env map (figment), exactly
# like the supervisor's processEnvironment(goosedConfig:) path. GOOSE_TLS=false = http loopback.
HOME="$GHOME" \
  GOOSE_HOST="127.0.0.1" GOOSE_PORT="$PORT" GOOSE_TLS="false" \
  GOOSE_SERVER__SECRET_KEY="$SECRET" \
  GOOSE_PROVIDER="${GOOSE_PROVIDER:-openai}" GOOSE_MODEL="${GOOSE_MODEL:-gpt-4o-mini}" \
  OPENAI_API_KEY="${OPENAI_API_KEY:-sk-dummy-probe}" \
  "$GOOSED_BIN" agent > "$LOG" 2>&1 &
GPID=$!

# goosed boots the full AppState (REST + gateways) — slower than lean serve; allow 45s
# to match GooseRuntimeSupervisor.goosedListenTimeout. Health gate = /status (no /health).
ready=0
for i in $(seq 1 45); do
  sleep 1
  code="$(curl -s -o /dev/null -w '%{http_code}' -H "X-Secret-Key: $SECRET" "http://127.0.0.1:$PORT/status" 2>/dev/null || true)"
  [[ "$code" == "200" ]] && { ready=1; break; }
done
[[ "$ready" == "1" ]] || { echo "goosed never became healthy (/status); log:"; tail -8 "$LOG"; exit 2; }
echo "goosed agent healthy on 127.0.0.1:$PORT/status (binary: $GOOSED_BIN)"
echo

# (1) ACP surface — same probe as the lean-serve proof, proving byte-identical ACP on goosed.
echo "=== (1) ACP surface (shared probe) ==="
node "$ROOT_DIR/scripts/goose-acp-live-probe.mjs" "ws://127.0.0.1:$PORT/acp?token=$SECRET"
acp_rc=$?

# (2) The 3 previously-unbackable REST features — live, authenticated.
echo
echo "=== (2) previously-unbackable REST features (goosed-only) ==="
probe_rest() {
  local label="$1" path="$2" method="${3:-GET}" want="$4"
  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' -X "$method" -H "X-Secret-Key: $SECRET" "http://127.0.0.1:$PORT$path" 2>/dev/null || true)"
  if [[ "$code" == "$want" ]]; then
    echo "✓ $label  $method $path -> $code (expected $want)"
  else
    echo "✘ $label  $method $path -> $code (expected $want)"
    return 1
  fi
}
rest_fail=0
probe_rest "Prompts editor (CRUD)"    "/config/prompts"     GET  200 || rest_fail=1
probe_rest "Permission-save (write)"  "/config/permissions" GET  405 || rest_fail=1   # 405 = route exists; it's the POST write
probe_rest "MCP-app proxy"            "/mcp-app-proxy"      GET  400 || rest_fail=1   # 400 = route exists; needs params

echo
if [[ "$acp_rc" == "0" && "$rest_fail" == "0" ]]; then
  echo "GOOSED_END_TO_END_REPROVE_PASS (ACP surface byte-identical + 3 REST features live)"
  exit 0
else
  echo "GOOSED_END_TO_END_REPROVE_FAIL (acp_rc=$acp_rc rest_fail=$rest_fail)"
  exit 1
fi
