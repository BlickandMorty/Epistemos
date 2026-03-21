#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
MODEL_MANIFEST="${EPISTEMOS_MODEL_MANIFEST:-${REPO_ROOT}/config/model_manifest.json}"
PYTHON_BIN="${EPISTEMOS_MODEL_PYTHON:-python3}"

log() {
  printf '[models] %s\n' "$*"
}

die() {
  printf '[models] ERROR: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

require_python() {
  command -v "${PYTHON_BIN}" >/dev/null 2>&1 || die "Missing required Python interpreter: ${PYTHON_BIN}"
}

python_cmd() {
  require_python
  "${PYTHON_BIN}" "$@"
}

hf_cli_cmd() {
  if command -v huggingface-cli >/dev/null 2>&1; then
    printf 'huggingface-cli\n'
    return
  fi
  if command -v hf >/dev/null 2>&1; then
    printf 'hf\n'
    return
  fi
  die "Missing required command: huggingface-cli or hf"
}

require_file() {
  [[ -f "$1" ]] || die "Missing file: $1"
}

require_dir() {
  [[ -d "$1" ]] || die "Missing directory: $1"
}

expand_path() {
  python_cmd - "$1" <<'PY'
import os
import sys
print(os.path.abspath(os.path.expanduser(sys.argv[1])))
PY
}

manifest_get() {
  python_cmd - "$MODEL_MANIFEST" "$@" <<'PY'
import json
import sys

with open(sys.argv[1], 'r', encoding='utf-8') as fh:
    value = json.load(fh)

for key in sys.argv[2:]:
    value = value[key]

if isinstance(value, bool):
    print("true" if value else "false")
elif value is None:
    print("")
elif isinstance(value, (dict, list)):
    print(json.dumps(value))
else:
    print(value)
PY
}

model_get() {
  local model_key="$1"
  shift
  manifest_get models "$model_key" "$@"
}

ensure_dir() {
  mkdir -p "$1"
}

verify_python_modules() {
  python_cmd - "$@" <<'PY'
from importlib.util import find_spec
import sys

missing = [name for name in sys.argv[1:] if find_spec(name) is None]
if missing:
    raise SystemExit("Missing Python modules: " + ", ".join(missing))
PY
}

verify_adapter_base() {
  local adapter_dir="$1"
  local expected_base="$2"
  python_cmd - "$adapter_dir/adapter_config.json" "$expected_base" <<'PY'
import json
import sys

with open(sys.argv[1], 'r', encoding='utf-8') as fh:
    config = json.load(fh)

actual = config.get("base_model_name_or_path")
expected = sys.argv[2]
if actual != expected:
    raise SystemExit(f"Adapter base mismatch: expected {expected}, found {actual}")
PY
}

audit_tokenizer_payload() {
  local model_dir="$1"
  local required=(tokenizer.json tokenizer_config.json special_tokens_map.json)
  local file
  for file in "${required[@]}"; do
    require_file "${model_dir}/${file}"
  done
  if [[ -f "${model_dir}/chat_template.jinja" ]]; then
    log "chat template present: ${model_dir}/chat_template.jinja"
  else
    log "chat template not present in ${model_dir}; conversion will rely on tokenizer config"
  fi
}

normalize_tokenizer_chat_template() {
  local source_dir="$1"
  local target_dir="$2"

  python_cmd - "$source_dir" "$target_dir" <<'PY'
import json
import shutil
import sys
from pathlib import Path

source_dir = Path(sys.argv[1])
target_dir = Path(sys.argv[2])
source_config_path = source_dir / "tokenizer_config.json"
target_config_path = target_dir / "tokenizer_config.json"
source_tokenizer_path = source_dir / "tokenizer.json"
target_tokenizer_path = target_dir / "tokenizer.json"
source_special_tokens_path = source_dir / "special_tokens_map.json"
target_special_tokens_path = target_dir / "special_tokens_map.json"

if not source_config_path.exists() or not target_config_path.exists():
    raise SystemExit("tokenizer_config.json missing while normalizing chat template")

with source_config_path.open("r", encoding="utf-8") as fh:
    source_config = json.load(fh)
with target_config_path.open("r", encoding="utf-8") as fh:
    target_config = json.load(fh)

source_template = source_config.get("chat_template")
target_template = target_config.get("chat_template")
if source_template and not target_template:
    target_config["chat_template"] = source_template
    with target_config_path.open("w", encoding="utf-8") as fh:
        json.dump(target_config, fh, indent=2, sort_keys=True)
        fh.write("\n")

source_template_path = source_dir / "chat_template.jinja"
target_template_path = target_dir / "chat_template.jinja"
if source_template_path.exists() and not target_template_path.exists():
    shutil.copy2(source_template_path, target_template_path)

should_restore_tokenizer_payload = False
if source_tokenizer_path.exists() and target_tokenizer_path.exists():
    with source_tokenizer_path.open("r", encoding="utf-8") as fh:
        source_tokenizer = json.load(fh)
    with target_tokenizer_path.open("r", encoding="utf-8") as fh:
        target_tokenizer = json.load(fh)

    source_pre_type = (source_tokenizer.get("pre_tokenizer") or {}).get("type")
    target_pre_type = (target_tokenizer.get("pre_tokenizer") or {}).get("type")
    source_decoder_type = (source_tokenizer.get("decoder") or {}).get("type")
    target_decoder_type = (target_tokenizer.get("decoder") or {}).get("type")

    should_restore_tokenizer_payload = (
        source_pre_type == "Sequence"
        and source_decoder_type == "ByteLevel"
        and target_pre_type == "Metaspace"
        and target_decoder_type == "Sequence"
    )

if should_restore_tokenizer_payload:
    shutil.copy2(source_tokenizer_path, target_tokenizer_path)

if source_special_tokens_path.exists() and (should_restore_tokenizer_payload or not target_special_tokens_path.exists()):
    shutil.copy2(source_special_tokens_path, target_special_tokens_path)
PY
}

audit_chat_template_payload() {
  local model_dir="$1"

  python_cmd - "$model_dir" <<'PY'
import json
import sys
from pathlib import Path

model_dir = Path(sys.argv[1])
tokenizer_config_path = model_dir / "tokenizer_config.json"
chat_template_path = model_dir / "chat_template.jinja"

if chat_template_path.exists():
    raise SystemExit(0)

with tokenizer_config_path.open("r", encoding="utf-8") as fh:
    tokenizer_config = json.load(fh)

chat_template = tokenizer_config.get("chat_template")
if isinstance(chat_template, str) and chat_template.strip():
    raise SystemExit(0)

raise SystemExit("Missing chat template payload in " + str(model_dir))
PY
}

download_base_snapshot_if_needed() {
  local model_id="$1"
  local destination="$2"
  if [[ -d "${destination}" && -n "$(find "${destination}" -mindepth 1 -maxdepth 1 2>/dev/null)" ]]; then
    log "base snapshot already present: ${destination}"
    return
  fi

  local hf_cli
  hf_cli="$(hf_cli_cmd)"
  ensure_dir "${destination}"
  log "downloading base model ${model_id} -> ${destination}"
  if [[ "${hf_cli}" == "hf" ]]; then
    hf download "${model_id}" --local-dir "${destination}"
  else
    huggingface-cli download "${model_id}" --local-dir "${destination}"
  fi
}

merge_peft_adapter_to_hf() {
  local base_dir="$1"
  local adapter_dir="$2"
  local output_dir="$3"
  local trust_remote_code="$4"

  ensure_dir "${output_dir}"
  verify_python_modules transformers peft torch

  python_cmd - "$base_dir" "$adapter_dir" "$output_dir" "$trust_remote_code" <<'PY'
import os
import shutil
import sys
from pathlib import Path

from peft import PeftModel
from transformers import AutoModelForCausalLM, AutoTokenizer

base_dir = sys.argv[1]
adapter_dir = sys.argv[2]
output_dir = sys.argv[3]
trust_remote_code = sys.argv[4].lower() == "true"

tokenizer = AutoTokenizer.from_pretrained(
    adapter_dir if Path(adapter_dir, "tokenizer.json").exists() else base_dir,
    trust_remote_code=trust_remote_code,
)

model = AutoModelForCausalLM.from_pretrained(
    base_dir,
    trust_remote_code=trust_remote_code,
    torch_dtype="auto",
    low_cpu_mem_usage=True,
)
model = PeftModel.from_pretrained(model, adapter_dir)
merged = model.merge_and_unload()
merged.save_pretrained(output_dir, safe_serialization=True)
tokenizer.save_pretrained(output_dir)

for name in [
    "added_tokens.json",
    "chat_template.jinja",
    "merges.txt",
    "special_tokens_map.json",
    "tokenizer.json",
    "tokenizer_config.json",
    "vocab.json",
]:
    src = Path(adapter_dir, name)
    if src.exists():
        shutil.copy2(src, Path(output_dir, name))
PY
}

normalize_hf_config_for_mlx() {
  local base_dir="$1"
  local merged_dir="$2"

  python_cmd - "$base_dir" "$merged_dir" <<'PY'
import json
import sys
from pathlib import Path

base_dir = Path(sys.argv[1])
merged_dir = Path(sys.argv[2])
base_config_path = base_dir / "config.json"
merged_config_path = merged_dir / "config.json"

with base_config_path.open("r", encoding="utf-8") as fh:
    base_config = json.load(fh)
with merged_config_path.open("r", encoding="utf-8") as fh:
    merged_config = json.load(fh)

rope_theta = merged_config.get("rope_theta")
if rope_theta is None:
    rope_theta = merged_config.get("rope_parameters", {}).get("rope_theta")
if rope_theta is None:
    rope_theta = base_config.get("rope_theta")
if rope_theta is not None:
    merged_config["rope_theta"] = rope_theta

if "torch_dtype" not in merged_config and "torch_dtype" in base_config:
    merged_config["torch_dtype"] = base_config["torch_dtype"]

with merged_config_path.open("w", encoding="utf-8") as fh:
    json.dump(merged_config, fh, indent=2, sort_keys=True)
    fh.write("\n")
PY
}

convert_hf_to_mlx() {
  local merged_dir="$1"
  local mlx_dir="$2"
  local q_bits="$3"
  local q_group_size="$4"

  verify_python_modules mlx_lm
  log "converting merged artifact -> MLX ${mlx_dir}"
  python_cmd -m mlx_lm convert \
    --hf-path "${merged_dir}" \
    --mlx-path "${mlx_dir}" \
    -q \
    --q-bits "${q_bits}" \
    --q-group-size "${q_group_size}"
}

audit_mlx_artifact() {
  local mlx_dir="$1"
  require_dir "${mlx_dir}"
  require_file "${mlx_dir}/config.json"
  require_file "${mlx_dir}/tokenizer.json"
  require_file "${mlx_dir}/tokenizer_config.json"
  if ! find "${mlx_dir}" -maxdepth 1 -name '*.safetensors' | grep -q .; then
    die "No .safetensors files found in ${mlx_dir}"
  fi
  audit_chat_template_payload "${mlx_dir}"
}

prepare_peft_causal_lm_artifact() {
  local model_key="$1"

  local adapter_path expected_base base_model_id base_snapshot_path merge_output_path mlx_output_path trust_remote_code q_bits q_group_size role

  adapter_path="$(expand_path "$(model_get "${model_key}" adapter_path)")"
  expected_base="$(model_get "${model_key}" expected_adapter_base_model_id)"
  base_model_id="$(model_get "${model_key}" base_model_id)"
  base_snapshot_path="$(expand_path "$(model_get "${model_key}" base_snapshot_path)")"
  merge_output_path="$(expand_path "$(model_get "${model_key}" merge_output_path)")"
  mlx_output_path="$(expand_path "$(model_get "${model_key}" mlx_output_path)")"
  trust_remote_code="$(model_get "${model_key}" trust_remote_code)"
  q_bits="$(model_get "${model_key}" quantization bits)"
  q_group_size="$(model_get "${model_key}" quantization group_size)"
  role="$(model_get "${model_key}" role)"

  require_dir "$(dirname "${MODEL_MANIFEST}")"
  require_file "${MODEL_MANIFEST}"
  require_dir "${adapter_path}"
  require_file "${adapter_path}/adapter_config.json"

  verify_adapter_base "${adapter_path}" "${expected_base}"
  audit_tokenizer_payload "${adapter_path}"
  download_base_snapshot_if_needed "${base_model_id}" "${base_snapshot_path}"

  log "merging ${model_key} adapter into base snapshot"
  rm -rf "${merge_output_path}"
  merge_peft_adapter_to_hf "${base_snapshot_path}" "${adapter_path}" "${merge_output_path}" "${trust_remote_code}"
  normalize_hf_config_for_mlx "${base_snapshot_path}" "${merge_output_path}"
  normalize_tokenizer_chat_template "${base_snapshot_path}" "${merge_output_path}"
  audit_tokenizer_payload "${merge_output_path}"
  audit_chat_template_payload "${merge_output_path}"

  rm -rf "${mlx_output_path}"
  convert_hf_to_mlx "${merge_output_path}" "${mlx_output_path}" "${q_bits}" "${q_group_size}"
  normalize_tokenizer_chat_template "${merge_output_path}" "${mlx_output_path}"
  audit_mlx_artifact "${mlx_output_path}"

  log "prepared ${model_key}"
  log "  merged: ${merge_output_path}"
  log "  mlx:    ${mlx_output_path}"
}

write_retrieval_index_manifest() {
  local output_path="$1"
  local retriever_model_id="$2"
  local reranker_model_id="${3:-}"
  local embedding_format="$4"
  local embedding_dimension="$5"
  local document_count="$6"
  local embeddings_file="$7"
  local documents_file="$8"

  python_cmd - "$output_path" "$retriever_model_id" "$reranker_model_id" "$embedding_format" "$embedding_dimension" "$document_count" "$embeddings_file" "$documents_file" <<'PY'
import json
import os
import sys

(
    output_path,
    retriever_model_id,
    reranker_model_id,
    embedding_format,
    embedding_dimension,
    document_count,
    embeddings_file,
    documents_file,
) = sys.argv[1:]
payload = {
    "version": 1,
    "retrieverModelID": retriever_model_id,
    "rerankerModelID": reranker_model_id or None,
    "embeddingFormat": embedding_format,
    "embeddingDimension": int(embedding_dimension),
    "documentCount": int(document_count),
    "embeddingsFile": embeddings_file,
    "documentsFile": documents_file,
}
os.makedirs(os.path.dirname(output_path), exist_ok=True)
with open(output_path, "w", encoding="utf-8") as fh:
    json.dump(payload, fh, indent=2, sort_keys=True)
    fh.write("\n")
PY
}
