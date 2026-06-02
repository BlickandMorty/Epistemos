#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

python3 Tools/falsifiers/merge_kv_direct_mlx_shards.py "$@"
