#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

cargo run --manifest-path agent_core/Cargo.toml \
  --bin falsify_small_model_runtime_harness_fresh_product_runtime_l3_log_correlation_probe

cargo run --manifest-path agent_core/Cargo.toml \
  --bin falsifier_validator \
  artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_l3_log_correlation_probe/result.json
