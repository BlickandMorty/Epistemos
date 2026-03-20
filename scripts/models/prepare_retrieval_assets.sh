#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

require_cmd huggingface-cli
verify_python_modules huggingface_hub

download_model_asset() {
  local model_key="$1"
  local model_id download_path
  model_id="$(model_get "${model_key}" model_id)"
  download_path="$(expand_path "$(model_get "${model_key}" download_path)")"
  if [[ -d "${download_path}" && -n "$(find "${download_path}" -mindepth 1 -maxdepth 1 2>/dev/null)" ]]; then
    log "asset already present: ${download_path}"
    return
  fi
  ensure_dir "${download_path}"
  log "downloading ${model_id} -> ${download_path}"
  huggingface-cli download "${model_id}" --local-dir "${download_path}"
}

download_model_asset "retriever_primary"
download_model_asset "reranker_primary"

log "retrieval assets prepared"
