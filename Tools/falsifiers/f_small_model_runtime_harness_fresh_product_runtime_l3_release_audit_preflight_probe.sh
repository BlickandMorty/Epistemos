#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

cargo run --manifest-path agent_core/Cargo.toml --release \
  --bin falsify_small_model_runtime_harness_fresh_product_runtime_l3_release_audit_preflight_probe

cargo run --manifest-path agent_core/Cargo.toml --release --bin falsifier_validator -- \
  artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_l3_release_audit_preflight_probe/result.json
