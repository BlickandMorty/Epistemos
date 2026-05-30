#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

uv run --with mlx-lm python Tools/falsifiers/run_kv_direct_mlx_live.py "$@"
