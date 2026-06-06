#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

cargo run --manifest-path agent_core/Cargo.toml \
  --bin falsify_gemma_qat_local_runtime_candidate_card

cargo run --manifest-path agent_core/Cargo.toml \
  --bin falsifier_validator \
  artifacts/falsifiers/gemma_qat_local_runtime_candidate_card/result.json
