#!/usr/bin/env bash
# Phase-0 spike A witness (Plan 1-MAS §7 / §11 R1 / R5): prove the embedded
# llama.cpp lane generates tokens via Metal INSIDE the App Sandbox with zero
# forbidden entitlements (no JIT / no exec-memory / no library-validation
# bypass / no network / no user-file access).
#
# Re-runnable: bash scripts/llama-mas-sandbox-spike.sh [/path/to/model.gguf]
#
# Shape: the harness is staged as a minimal .app BUNDLE (macOS 26 secinit
# refuses to build a sandbox container for a bare CLI binary — it dies in
# _libsecinit_appsandbox with "Failed to create a code identity", OSStatus
# 100001). Bundling also mirrors the real ship shape: llama.framework inside
# Contents/Frameworks of a sandboxed app.
#
#   1. Ensures the pinned llama.cpp XCFramework is installed (fetch script).
#   2. swift-builds the llama-spike harness (release).
#   3. Stages LlamaSpike.app (Info.plist + Frameworks/llama.framework).
#   4. Signs inside-out — Apple Development identity when available
#      (hardened runtime + library validation exercised), ad-hoc fallback —
#      with ONLY com.apple.security.app-sandbox on the app.
#   5. Stages the model inside the harness's sandbox container (hardlink).
#   6. Runs it and asserts:
#        - the process is actually sandboxed (APP_SANDBOX_CONTAINER_ID)
#        - Metal used the EMBEDDED metallib (no filesystem metallib lookup)
#        - >= 8 real tokens were generated
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKG="${ROOT}/LocalPackages/EpistemosLlama"
MODEL="${1:-${HOME}/Downloads/gemma-4-E2B_q4_0-it.gguf}"
PROMPT="${2:-Count from one to ten as English words, comma separated.}"
MAX_NEW="${3:-32}"
BUNDLE_ID="app.epistemos.llama-spike"

if [[ ! -f "${MODEL}" ]]; then
    echo "[spike] ERROR: model not found: ${MODEL}" >&2
    exit 1
fi

bash "${ROOT}/scripts/fetch-llama-xcframework.sh"

echo "[spike] building llama-spike (release)"
swift build -c release --package-path "${PKG}" --product llama-spike >/dev/null

BIN_DIR="$(swift build -c release --package-path "${PKG}" --show-bin-path)"
BIN="${BIN_DIR}/llama-spike"
[[ -x "${BIN}" ]] || { echo "[spike] ERROR: harness missing at ${BIN}" >&2; exit 1; }

FRAMEWORK_SRC="${BIN_DIR}/llama.framework"
if [[ ! -d "${FRAMEWORK_SRC}" ]]; then
    FRAMEWORK_SRC="${PKG}/Binary/llama.xcframework/macos-arm64_x86_64/llama.framework"
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "${STAGE}"' EXIT
APP="${STAGE}/LlamaSpike.app"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Frameworks"
cp "${BIN}" "${APP}/Contents/MacOS/llama-spike"
cp -R "${FRAMEWORK_SRC}" "${APP}/Contents/Frameworks/llama.framework"

cat > "${APP}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
	<key>CFBundleName</key><string>LlamaSpike</string>
	<key>CFBundleExecutable</key><string>llama-spike</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>0.1</string>
	<key>CFBundleVersion</key><string>1</string>
	<key>LSMinimumSystemVersion</key><string>14.0</string>
	<key>LSBackgroundOnly</key><true/>
</dict>
</plist>
PLIST

# The SPM-built binary rpaths @loader_path; the bundle keeps the framework in
# Contents/Frameworks, so add the standard app rpath too.
install_name_tool -add_rpath "@executable_path/../Frameworks" \
    "${APP}/Contents/MacOS/llama-spike" 2>/dev/null || true

# Select by SHA-1 hash, not name — duplicate cert names are ambiguous to codesign.
IDENTITY="${EPISTEMOS_SPIKE_IDENTITY:-}"
if [[ -z "${IDENTITY}" ]]; then
    IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
        | awk '/Apple Development/ {print $2; exit}')"
fi

ENTITLEMENTS="${PKG}/Spike/llama-spike-sandbox.entitlements"
if [[ -n "${IDENTITY}" ]]; then
    echo "[spike] signing with identity ${IDENTITY} (hardened runtime + library validation)"
    codesign --force --sign "${IDENTITY}" --options runtime \
        "${APP}/Contents/Frameworks/llama.framework"
    codesign --force --sign "${IDENTITY}" --options runtime \
        --entitlements "${ENTITLEMENTS}" --identifier "${BUNDLE_ID}" "${APP}"
else
    echo "[spike] no Apple Development identity; ad-hoc signing (no hardened runtime)"
    codesign --force --sign - "${APP}/Contents/Frameworks/llama.framework"
    codesign --force --sign - --entitlements "${ENTITLEMENTS}" \
        --identifier "${BUNDLE_ID}" "${APP}"
fi

echo "[spike] effective entitlements:"
codesign -d --entitlements - "${APP}" 2>/dev/null | sed 's/^/[spike]   /' || true

HARNESS="${APP}/Contents/MacOS/llama-spike"

# First launch creates the sandbox container; usage exit (2) is expected.
set +e
"${HARNESS}" >/dev/null 2>&1
set -e

CONTAINER="${HOME}/Library/Containers/${BUNDLE_ID}/Data"
if [[ ! -d "${CONTAINER}" ]]; then
    echo "[spike] ERROR: sandbox container was not created — is the app actually sandboxed?" >&2
    exit 1
fi
mkdir -p "${CONTAINER}/tmp"
STAGED_MODEL="${CONTAINER}/tmp/$(basename "${MODEL}")"
ln -f "${MODEL}" "${STAGED_MODEL}" 2>/dev/null || cp "${MODEL}" "${STAGED_MODEL}"

echo "[spike] running sandboxed generation…"
set +e
OUTPUT="$("${HARNESS}" "${STAGED_MODEL}" "${PROMPT}" "${MAX_NEW}" 2>&1)"
STATUS=$?
set -e
echo "${OUTPUT}" | tail -30 | sed 's/^/[spike]   /'

FAIL=0
if [[ ${STATUS} -ne 0 ]]; then
    echo "[spike] FAIL: harness exited ${STATUS}"; FAIL=1
fi
if ! grep -q "SPIKE sandboxed=1" <<<"${OUTPUT}"; then
    echo "[spike] FAIL: process was not sandboxed"; FAIL=1
fi
if ! grep -q "using embedded metal library" <<<"${OUTPUT}"; then
    echo "[spike] FAIL: embedded metallib was not used"; FAIL=1
fi
if ! grep -Eq "SPIKE-PROOF tokens=([8-9]|[1-9][0-9]+)" <<<"${OUTPUT}"; then
    echo "[spike] FAIL: fewer than 8 tokens generated"; FAIL=1
fi

if [[ ${FAIL} -ne 0 ]]; then
    echo "[spike] RESULT: FAIL"
    exit 1
fi
echo "[spike] RESULT: PASS — llama.cpp b9870 generated tokens under App Sandbox with app-sandbox as the ONLY entitlement (no JIT)."
