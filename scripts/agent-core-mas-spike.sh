#!/usr/bin/env bash
# Phase-0 spike B witness (Plan 1-MAS §7 / §11 R2 / R5): one real
# runAgentSession turn streaming AgentEventDelegate deltas through the SAME
# generated UniFFI bindings the app compiles, against libagent_core built
# with the MAS feature set (--no-default-features --features
# mas-build,lsp-runtime — mirroring build-agent-core.sh's Epistemos-AppStore
# branch).
#
# Re-runnable: bash scripts/agent-core-mas-spike.sh [provider_slug]
# (default provider: claude_sonnet; needs epistemos.anthropic.apiKey in the
#  Keychain — read at runtime by the harness, never printed).
#
# Asserts: on_text_delta events arrived, on_complete fired, zero on_error,
# every callback hopped to the main queue (main_hop=1).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROVIDER="${1:-claude_sonnet}"
STAGE="${ROOT}/.derived-data-agent-spike"
mkdir -p "${STAGE}"

if [ -f "${HOME}/.cargo/env" ]; then
    # shellcheck disable=SC1091
    source "${HOME}/.cargo/env"
fi

echo "[spike-b] building libagent_core with MAS features (release, arm64)…"
(cd "${ROOT}/agent_core" && cargo build --lib \
    --no-default-features --features "mas-build,lsp-runtime" \
    --release --target aarch64-apple-darwin) >/dev/null

LIB_SRC="${ROOT}/agent_core/target/aarch64-apple-darwin/release/libagent_core.dylib"
[[ -f "${LIB_SRC}" ]] || { echo "[spike-b] ERROR: dylib missing at ${LIB_SRC}" >&2; exit 1; }
cp -f "${LIB_SRC}" "${STAGE}/libagent_core.dylib"
install_name_tool -id "@rpath/libagent_core.dylib" "${STAGE}/libagent_core.dylib"
codesign --force --sign - "${STAGE}/libagent_core.dylib" 2>/dev/null || true

# Generate bindings FROM the MAS dylib into a scratch dir (feature sets gate
# FFI exports, so pro-build bindings don't link against a mas-build lib).
# Never touches the shared build-rust/swift-bindings the app builds own.
HOST_TRIPLE="$(rustc -vV | sed -n 's/^host: //p')"
UNIFFI_BINDGEN="${ROOT}/epistemos-core/target/${HOST_TRIPLE}/debug/uniffi_bindgen"
if [[ ! -x "${UNIFFI_BINDGEN}" ]]; then
    echo "[spike-b] building uniffi_bindgen…"
    (cd "${ROOT}" && cargo build --manifest-path epistemos-core/Cargo.toml \
        --target "${HOST_TRIPLE}" --bin uniffi_bindgen) >/dev/null
fi
codesign --force --sign - "${UNIFFI_BINDGEN}" 2>/dev/null || true

BINDINGS="${STAGE}/bindings"
mkdir -p "${BINDINGS}"
# cwd must be the crate dir — uniffi_bindgen shells out to `cargo metadata`.
(cd "${ROOT}/agent_core" && "${UNIFFI_BINDGEN}" generate \
    --library "${LIB_SRC}" \
    --crate agent_core \
    --language swift \
    --no-format \
    --out-dir "${BINDINGS}")
python3 "${ROOT}/patch-uniffi-bindings.py" "${BINDINGS}/agent_core.swift"

echo "[spike-b] compiling harness…"
swiftc -O \
    "${ROOT}/scripts/agent-core-mas-spike/main.swift" \
    "${BINDINGS}/agent_core.swift" \
    -I "${BINDINGS}" \
    -Xcc -fmodule-map-file="${BINDINGS}/agent_coreFFI.modulemap" \
    -L "${STAGE}" -lagent_core \
    -Xlinker -rpath -Xlinker "${STAGE}" \
    -o "${STAGE}/agent-core-mas-spike"

echo "[spike-b] running one ${PROVIDER} turn…"
set +e
OUTPUT="$(RUST_LOG="${RUST_LOG:-agent_core=info}" "${STAGE}/agent-core-mas-spike" "${PROVIDER}" 2>&1)"
STATUS=$?
set -e
echo "${OUTPUT}" | grep -E "SPIKE" | sed 's/^/[spike-b]   /'

FAIL=0
[[ ${STATUS} -eq 0 ]] || { echo "[spike-b] FAIL: harness exited ${STATUS}"; FAIL=1; }
grep -Eq "SPIKE-PROOF text_deltas=[1-9]" <<<"${OUTPUT}" || { echo "[spike-b] FAIL: no text deltas"; FAIL=1; }
grep -q "SPIKE-EVENT complete stop=" <<<"${OUTPUT}" || { echo "[spike-b] FAIL: no on_complete"; FAIL=1; }
grep -q "main_hop=1" <<<"${OUTPUT}" || { echo "[spike-b] FAIL: callbacks did not hop to main"; FAIL=1; }

if [[ ${FAIL} -ne 0 ]]; then
    echo "[spike-b] RESULT: FAIL"
    exit 1
fi
echo "[spike-b] RESULT: PASS — runAgentSession streamed deltas over UniFFI (MAS feature set) with main-queue hops."
