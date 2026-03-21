#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

verify_python_modules sqlite3

database_path="${EPISTEMOS_SEARCH_DB_PATH:-$HOME/Library/Application Support/Epistemos/search.sqlite}"
database_path="$(expand_path "${database_path}")"
require_file "${database_path}"

retriever_model_id="$(model_get "retriever_primary" served_model_id)"
reranker_model_id="$(model_get "reranker_primary" served_model_id)"
retriever_source_root="$(expand_path "$(model_get "retriever_primary" download_path)")"
index_root="$(dirname "${retriever_source_root}")/index"
batch_size="${EPISTEMOS_RETRIEVAL_BATCH_SIZE:-16}"
max_length="${EPISTEMOS_RETRIEVAL_MAX_LENGTH:-1024}"
max_docs="${EPISTEMOS_RETRIEVAL_MAX_DOCS:-0}"

require_dir "${retriever_source_root}"
log "building retrieval index from ${database_path}"
python_cmd "${SCRIPT_DIR}/build_retrieval_index.py" \
  --database "${database_path}" \
  --retriever "${retriever_source_root}" \
  --output-dir "${index_root}" \
  --retriever-model-id "${retriever_model_id}" \
  --reranker-model-id "${reranker_model_id}" \
  --batch-size "${batch_size}" \
  --max-length "${max_length}" \
  --max-docs "${max_docs}"

log "retrieval index built: ${index_root}"
