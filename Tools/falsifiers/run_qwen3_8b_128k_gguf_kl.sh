#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

python3 Tools/falsifiers/run_qwen3_8b_128k_gguf_kl.py "$@"
