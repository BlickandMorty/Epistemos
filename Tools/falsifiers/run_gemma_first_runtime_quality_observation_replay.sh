#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
source Tools/falsifiers/gemma_first_runtime_paths.sh
gemma_configure_first_runtime_paths

python3 Tools/falsifiers/run_gemma_first_runtime_quality_observation_replay.py "$@"
