#!/usr/bin/env zsh
set -euo pipefail

cd "$(dirname "$0")/../.."

cargo run --manifest-path agent_core/Cargo.toml --bin falsify_small_model_runtime_harness_product_wrv_probe
cargo run --manifest-path agent_core/Cargo.toml --bin falsifier_validator -- artifacts/falsifiers/small_model_runtime_harness_product_wrv_probe/result.json
