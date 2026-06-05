#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

cargo run --manifest-path agent_core/Cargo.toml --bin falsify_small_model_runtime_harness_fresh_product_runtime_live_probe
cargo run --manifest-path agent_core/Cargo.toml --bin falsifier_validator artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_live_probe/result.json
