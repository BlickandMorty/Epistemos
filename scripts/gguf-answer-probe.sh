#!/usr/bin/env bash
# Surface A GGUF live-answer witness (Plan 1-MAS §2.1/§2.2 / R5-P1).
# Complements the SANDBOX witness (scripts/llama-mas-sandbox-spike.sh, which
# proves token-gen inside the App Sandbox with no JIT). This one proves the
# APP'S DEFAULT catalog model (Qwen3-4B) + the app's ChatML template produce a
# coherent answer through LlamaLocalChatEngine — the same engine
# LocalGGUFQuickChatBackend wraps — and that the download URL + the download
# manager's HF-oid checksum source are correct.
#
#   bash scripts/gguf-answer-probe.sh [/path/to/Qwen3-4B-Q4_K_M.gguf]
#
# With no arg it fetches the app's default (Qwen/Qwen3-4B-GGUF /
# Qwen3-4B-Q4_K_M.gguf), verifying the published sha256 (HF tree oid) exactly
# as QuickChatModelDownloadManager does.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="Qwen/Qwen3-4B-GGUF"          # matches GGUFModelCatalog default entry
FILE="Qwen3-4B-Q4_K_M.gguf"
MODEL="${1:-}"

if [[ -z "${MODEL}" ]]; then
    CACHE="${ROOT}/.gguf-probe-cache"
    mkdir -p "${CACHE}"
    MODEL="${CACHE}/${FILE}"
    if [[ ! -f "${MODEL}" ]]; then
        echo "[gguf-probe] fetching published sha256 (HF tree oid)…"
        OID="$(curl -s --max-time 30 "https://huggingface.co/api/models/${REPO}/tree/main?recursive=false" \
            | python3 -c "import sys,json; print(next(e['lfs']['oid'] for e in json.load(sys.stdin) if e['path']=='${FILE}'))")"
        echo "[gguf-probe] downloading ${REPO}/${FILE} (~2.5 GB)…"
        curl -fL --retry 3 -o "${MODEL}" \
            "https://huggingface.co/${REPO}/resolve/main/${FILE}"
        ACTUAL="$(shasum -a 256 "${MODEL}" | cut -d' ' -f1)"
        if [[ "${ACTUAL}" != "${OID}" ]]; then
            echo "[gguf-probe] FAIL: sha256 ${ACTUAL} != published oid ${OID}"
            rm -f "${MODEL}"; exit 1
        fi
        echo "[gguf-probe] checksum verified (oid == file sha256) ✓"
    fi
fi

bash "${ROOT}/scripts/fetch-llama-xcframework.sh" >/dev/null

echo "[gguf-probe] generating an answer via LlamaLocalChatEngine (ChatML)…"
OUT="$(swift run -c release --package-path "${ROOT}/LocalPackages/EpistemosLlama" \
    llama-spike "${MODEL}" "In one sentence, what is a knowledge graph?" 80 2>/dev/null)"
echo "${OUT}" | sed 's/^/[gguf-probe]   /'

TOKENS="$(grep -oE "SPIKE-PROOF tokens=[0-9]+" <<<"${OUT}" | grep -oE "[0-9]+" || echo 0)"
if [[ "${TOKENS}" -ge 20 ]]; then
    echo "[gguf-probe] RESULT: PASS — Qwen3-4B default model answered (${TOKENS} tokens) via the embedded engine + app ChatML template."
else
    echo "[gguf-probe] RESULT: FAIL — too few tokens (${TOKENS})"
    exit 1
fi
