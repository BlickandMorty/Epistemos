#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

temp_dir="$(mktemp -d)"
trap 'rm -rf "${temp_dir}"' EXIT

base_dir="${temp_dir}/base"
merged_dir="${temp_dir}/merged"
mlx_dir="${temp_dir}/mlx"
mkdir -p "${base_dir}" "${merged_dir}" "${mlx_dir}"

cat > "${base_dir}/tokenizer_config.json" <<'JSON'
{
  "tokenizer_class": "LlamaTokenizerFast",
  "chat_template": "base-template"
}
JSON

cat > "${merged_dir}/tokenizer_config.json" <<'JSON'
{
  "tokenizer_class": "LlamaTokenizerFast"
}
JSON

cat > "${mlx_dir}/tokenizer_config.json" <<'JSON'
{
  "tokenizer_class": "LlamaTokenizer"
}
JSON

cat > "${base_dir}/tokenizer.json" <<'JSON'
{
  "model": { "type": "BPE" },
  "pre_tokenizer": {
    "type": "Sequence",
    "pretokenizers": [
      { "type": "Split", "pattern": { "Regex": "x" }, "behavior": "Isolated", "invert": false },
      { "type": "ByteLevel", "add_prefix_space": false, "trim_offsets": true, "use_regex": false }
    ]
  },
  "decoder": { "type": "ByteLevel", "add_prefix_space": true, "trim_offsets": true, "use_regex": true }
}
JSON

cat > "${merged_dir}/tokenizer.json" <<'JSON'
{
  "model": { "type": "BPE" },
  "pre_tokenizer": {
    "type": "Sequence",
    "pretokenizers": [
      { "type": "Split", "pattern": { "Regex": "x" }, "behavior": "Isolated", "invert": false },
      { "type": "ByteLevel", "add_prefix_space": false, "trim_offsets": true, "use_regex": false }
    ]
  },
  "decoder": { "type": "ByteLevel", "add_prefix_space": true, "trim_offsets": true, "use_regex": true }
}
JSON

cat > "${mlx_dir}/tokenizer.json" <<'JSON'
{
  "model": { "type": "BPE" },
  "pre_tokenizer": {
    "type": "Metaspace",
    "replacement": "▁",
    "prepend_scheme": "always",
    "split": false
  },
  "decoder": {
    "type": "Sequence",
    "decoders": [
      { "type": "Replace", "pattern": { "String": "▁" }, "content": " " },
      { "type": "ByteFallback" }
    ]
  }
}
JSON

cat > "${merged_dir}/special_tokens_map.json" <<'JSON'
{
  "bos_token": {
    "content": "<bos>",
    "single_word": false,
    "lstrip": false,
    "rstrip": false,
    "normalized": false
  }
}
JSON

normalize_tokenizer_chat_template "${base_dir}" "${merged_dir}"
normalize_tokenizer_chat_template "${merged_dir}" "${mlx_dir}"

python_cmd - "${merged_dir}/tokenizer_config.json" "${mlx_dir}/tokenizer_config.json" "${mlx_dir}/tokenizer.json" "${mlx_dir}/special_tokens_map.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    merged = json.load(fh)
with open(sys.argv[2], "r", encoding="utf-8") as fh:
    mlx = json.load(fh)
with open(sys.argv[3], "r", encoding="utf-8") as fh:
    mlx_tokenizer = json.load(fh)
with open(sys.argv[4], "r", encoding="utf-8") as fh:
    mlx_special_tokens = json.load(fh)

if merged.get("chat_template") != "base-template":
    raise SystemExit("merged tokenizer config did not inherit chat_template")
if mlx.get("chat_template") != "base-template":
    raise SystemExit("mlx tokenizer config did not inherit chat_template")
if mlx_tokenizer.get("pre_tokenizer", {}).get("type") != "Sequence":
    raise SystemExit("mlx tokenizer.json did not restore the byte-level tokenizer payload")
if mlx_special_tokens.get("bos_token", {}).get("content") != "<bos>":
    raise SystemExit("mlx special tokens map was not copied from the merged tokenizer payload")
PY

printf 'common_test.sh passed\n'
