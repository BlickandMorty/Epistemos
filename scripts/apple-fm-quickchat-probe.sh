#!/usr/bin/env bash
# Surface A Apple FM witness (Plan 1-MAS R5-P1). Re-runnable:
#   bash scripts/apple-fm-quickchat-probe.sh
# Asserts: FM available on this machine, a live streamed answer arrived via
# the cumulative-snapshot → delta pattern (the exact shape
# AppleFMQuickChatBackend ships), and reports the guardrail-trip outcome
# honestly (triggered OR topic-passed — both are valid data for the §2.1
# fallback design). Requires a user session with Apple Intelligence enabled
# (macOS 26+); exits 2 (SKIP) when FM is unavailable on this machine.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${ROOT}/scripts/apple-fm-quickchat-probe/main.swift"
STAGE="$(mktemp -d)"
trap 'rm -rf "${STAGE}"' EXIT
BIN="${STAGE}/fm-probe"

echo "[fm-probe] compiling…"
swiftc -O -framework FoundationModels "${SRC}" -o "${BIN}"

# FoundationModels needs a signed binary; ad-hoc is sufficient (no sandbox).
codesign --force --sign - "${BIN}" 2>/dev/null || true

echo "[fm-probe] running…"
set +e
OUTPUT="$("${BIN}" 2>&1)"
STATUS=$?
set -e
echo "${OUTPUT}" | sed 's/^/[fm-probe]   /'

if [[ ${STATUS} -eq 2 ]]; then
    echo "[fm-probe] RESULT: SKIP — Apple Intelligence not available on this machine (Surface A falls back to the GGUF lane)."
    exit 2
fi
if [[ ${STATUS} -ne 0 ]]; then
    echo "[fm-probe] RESULT: FAIL (exit ${STATUS})"
    exit 1
fi
if ! grep -q "FM-PROBE stream=ok deltas=" <<<"${OUTPUT}"; then
    echo "[fm-probe] RESULT: FAIL — no streamed deltas"
    exit 1
fi
echo "[fm-probe] RESULT: PASS — Apple FM answered live via cumulative-snapshot → delta; guardrail outcome reported above."
