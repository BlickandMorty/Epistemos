#!/usr/bin/env bash
# Fetch the pinned upstream llama.cpp XCFramework into
# LocalPackages/EpistemosLlama/Binary/ (Plan 1-MAS §2.1 / §11 R1).
#
# - Pinned release + sha256 (verify-then-install; delete on mismatch).
# - Idempotent: skips when the pinned tag is already installed.
# - Never committed: the artifact is per-checkout (see .gitignore).
# - Offline/CI: set EPISTEMOS_LLAMA_ZIP=/path/to/llama-<tag>-xcframework.zip
#   to install from a pre-downloaded archive instead of the network.
#
# Run once per checkout BEFORE building anything that depends on the
# EpistemosLlama package (a missing local binaryTarget breaks SwiftPM
# resolution for the whole workspace).
set -euo pipefail

TAG="b9870"
SHA256="792cb6560abc2e04262b105eb9ca3d5890814f358f998adea4e28497788e59f7"
MACOS_BINARY_SHA256="debe3c4a5d52cf41ecd2b50f18b2b186787cb1b01bbf50e40bf717393b35c261"
MACOS_MODULEMAP_SHA256="b5651903a342dc59fb4fe16ff9cc82ba4d08fdb142458aeacf516e7c31c15f15"
MACOS_INFO_SHA256="518c9cbaa95bfa21f2acad01fe1d29bd8a6bdfd797021a2b39de3c5145b48ac0"
URL="https://github.com/ggml-org/llama.cpp/releases/download/${TAG}/llama-${TAG}-xcframework.zip"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST_DIR="${ROOT}/LocalPackages/EpistemosLlama/Binary"
DEST="${DEST_DIR}/llama.xcframework"
MARKER="${DEST_DIR}/.llama-${TAG}.sha256-ok"

verify_installed_xcframework() {
    local framework_root="$1"
    local macos_root="${framework_root}/macos-arm64_x86_64/llama.framework/Versions/A"

    [[ -f "${macos_root}/llama" ]] || return 1
    [[ -f "${macos_root}/Modules/module.modulemap" ]] || return 1
    [[ -f "${macos_root}/Resources/Info.plist" ]] || return 1
    echo "${MACOS_BINARY_SHA256}  ${macos_root}/llama" | shasum -a 256 -c - >/dev/null
    echo "${MACOS_MODULEMAP_SHA256}  ${macos_root}/Modules/module.modulemap" | shasum -a 256 -c - >/dev/null
    echo "${MACOS_INFO_SHA256}  ${macos_root}/Resources/Info.plist" | shasum -a 256 -c - >/dev/null
}

if [[ -d "${DEST}" && -f "${MARKER}" ]]; then
    if [[ "$(cat "${MARKER}")" == "${SHA256}" ]] \
        && verify_installed_xcframework "${DEST}"; then
        echo "[fetch-llama] ${TAG} already installed and verified at ${DEST}"
        exit 0
    fi
    echo "[fetch-llama] existing ${TAG} artifact failed receipt verification; reinstalling"
fi

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
ZIP="${TMP}/llama-${TAG}-xcframework.zip"

if [[ -n "${EPISTEMOS_LLAMA_ZIP:-}" && -f "${EPISTEMOS_LLAMA_ZIP}" ]]; then
    echo "[fetch-llama] using pre-downloaded archive ${EPISTEMOS_LLAMA_ZIP}"
    cp "${EPISTEMOS_LLAMA_ZIP}" "${ZIP}"
else
    echo "[fetch-llama] downloading ${URL}"
    curl -fL --retry 3 --connect-timeout 30 -o "${ZIP}" "${URL}"
fi

echo "${SHA256}  ${ZIP}" | shasum -a 256 -c - >/dev/null
echo "[fetch-llama] sha256 verified (${SHA256})"

unzip -q "${ZIP}" -d "${TMP}"
SRC="${TMP}/build-apple/llama.xcframework"
if [[ ! -d "${SRC}" ]]; then
    SRC="$(find "${TMP}" -maxdepth 3 -type d -name llama.xcframework | head -1)"
fi
if [[ -z "${SRC}" || ! -d "${SRC}" ]]; then
    echo "[fetch-llama] ERROR: llama.xcframework not found inside the archive" >&2
    exit 1
fi
if [[ ! -d "${SRC}/macos-arm64_x86_64/llama.framework" ]]; then
    echo "[fetch-llama] ERROR: archive lacks the macOS slice" >&2
    exit 1
fi

rm -rf "${DEST}"
mkdir -p "${DEST_DIR}"
mv "${SRC}" "${DEST}"
if ! verify_installed_xcframework "${DEST}"; then
    rm -rf "${DEST}"
    echo "[fetch-llama] ERROR: extracted macOS framework failed pinned digest verification" >&2
    exit 1
fi
rm -f "${DEST_DIR}"/.llama-*.sha256-ok
printf '%s\n' "${SHA256}" > "${MARKER}"
echo "[fetch-llama] installed ${TAG} -> ${DEST}"
