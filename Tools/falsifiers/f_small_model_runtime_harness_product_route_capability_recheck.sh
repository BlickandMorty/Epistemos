#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

cargo run --manifest-path agent_core/Cargo.toml --bin falsify_small_model_runtime_harness_product_route_capability_recheck
cargo run --manifest-path agent_core/Cargo.toml --bin falsifier_validator artifacts/falsifiers/small_model_runtime_harness_product_route_capability_recheck/result.json
