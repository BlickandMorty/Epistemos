#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

cargo run --manifest-path agent_core/Cargo.toml --bin falsify_small_model_runtime_harness_dry_run_witness
cargo run --manifest-path agent_core/Cargo.toml --bin falsifier_validator -- \
  artifacts/falsifiers/small_model_runtime_harness_dry_run_witness/result.json
