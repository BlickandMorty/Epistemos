#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
MODEL_MANIFEST="${EPISTEMOS_MODEL_MANIFEST:-${REPO_ROOT}/config/model_manifest.json}"

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

require_file() {
  [[ -f "$1" ]] || die "Missing file: $1"
}

require_dir() {
  [[ -d "$1" ]] || die "Missing directory: $1"
}

expand_path() {
  python3 - "$1" <<'PY'
import os
import sys
print(os.path.abspath(os.path.expanduser(sys.argv[1])))
PY
}

manifest_get() {
  python3 - "$MODEL_MANIFEST" "$@" <<'PY'
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
  python3 - "$@" <<'PY'
import importlib
import sys

missing = [name for name in sys.argv[1:] if importlib.util.find_spec(name) is None]
if missing:
    raise SystemExit("Missing Python modules: " + ", ".join(missing))
PY
}

verify_adapter_base() {
  local adapter_dir="$1"
  local expected_base="$2"
  python3 - "$adapter_dir/adapter_config.json" "$expected_base" <<'PY'
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

download_base_snapshot_if_needed() {
  local model_id="$1"
  local destination="$2"
  if [[ -d "${destination}" && -n "$(find "${destination}" -mindepth 1 -maxdepth 1 2>/dev/null)" ]]; then
    log "base snapshot already present: ${destination}"
    return
  fi

  require_cmd huggingface-cli
  ensure_dir "${destination}"
  log "downloading base model ${model_id} -> ${destination}"
  huggingface-cli download "${model_id}" --local-dir "${destination}"
}

merge_peft_adapter_to_hf() {
  local base_dir="$1"
  local adapter_dir="$2"
  local output_dir="$3"
  local trust_remote_code="$4"

  ensure_dir "${output_dir}"
  verify_python_modules transformers peft torch

  python3 - "$base_dir" "$adapter_dir" "$output_dir" "$trust_remote_code" <<'PY'
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

convert_hf_to_mlx() {
  local merged_dir="$1"
  local mlx_dir="$2"
  local q_bits="$3"
  local q_group_size="$4"

  verify_python_modules mlx_lm
  ensure_dir "${mlx_dir}"
  log "converting merged artifact -> MLX ${mlx_dir}"
  python3 -m mlx_lm.convert \
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
  if ! find "${mlx_dir}" -maxdepth 1 -name '*.safetensors' | grep -q .; then
    die "No .safetensors files found in ${mlx_dir}"
  fi
}

prepare_peft_causal_lm_artifact() {
  local model_key="$1"

  local adapter_path expected_base base_model_id base_snapshot_path merge_output_path mlx_output_path trust_remote_code q_bits q_group_size

  adapter_path="$(expand_path "$(model_get "${model_key}" adapter_path)")"
  expected_base="$(model_get "${model_key}" expected_adapter_base_model_id)"
  base_model_id="$(model_get "${model_key}" base_model_id)"
  base_snapshot_path="$(expand_path "$(model_get "${model_key}" base_snapshot_path)")"
  merge_output_path="$(expand_path "$(model_get "${model_key}" merge_output_path)")"
  mlx_output_path="$(expand_path "$(model_get "${model_key}" mlx_output_path)")"
  trust_remote_code="$(model_get "${model_key}" trust_remote_code)"
  q_bits="$(model_get "${model_key}" quantization bits)"
  q_group_size="$(model_get "${model_key}" quantization group_size)"

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
  audit_tokenizer_payload "${merge_output_path}"

  rm -rf "${mlx_output_path}"
  convert_hf_to_mlx "${merge_output_path}" "${mlx_output_path}" "${q_bits}" "${q_group_size}"
  audit_mlx_artifact "${mlx_output_path}"

  log "prepared ${model_key}"
  log "  merged: ${merge_output_path}"
  log "  mlx:    ${mlx_output_path}"
}
