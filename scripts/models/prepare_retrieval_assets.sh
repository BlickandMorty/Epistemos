#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

verify_python_modules huggingface_hub

download_model_asset() {
  local model_key="$1"
  local model_id download_path hf_cli
  model_id="$(model_get "${model_key}" model_id)"
  download_path="$(expand_path "$(model_get "${model_key}" download_path)")"
  if [[ -d "${download_path}" && -n "$(find "${download_path}" -mindepth 1 -maxdepth 1 2>/dev/null)" ]]; then
    log "asset already present: ${download_path}"
    return
  fi
  hf_cli="$(hf_cli_cmd)"
  ensure_dir "${download_path}"
  log "downloading ${model_id} -> ${download_path}"
  if [[ "${hf_cli}" == "hf" ]]; then
    hf download "${model_id}" --local-dir "${download_path}"
  else
    huggingface-cli download "${model_id}" --local-dir "${download_path}"
  fi
}

download_model_asset "retriever_primary"
download_model_asset "reranker_primary"

retriever_model_id="$(model_get "retriever_primary" served_model_id)"
reranker_model_id="$(model_get "reranker_primary" served_model_id)"
retriever_source_root="$(expand_path "$(model_get "retriever_primary" download_path)")"
index_root="$(dirname "${retriever_source_root}")/index"
index_manifest_path="${index_root}/manifest.json"

ensure_dir "${index_root}"
if [[ "${EPISTEMOS_BUILD_RETRIEVAL_INDEX:-false}" == "true" ]]; then
  bash "${SCRIPT_DIR}/build_retrieval_index.sh"
elif [[ -f "${index_manifest_path}" ]]; then
  log "retrieval index manifest present: ${index_manifest_path}"
else
  log "retrieval index assets pending: run ${SCRIPT_DIR}/build_retrieval_index.sh after source download"
fi

log "retrieval assets prepared"
