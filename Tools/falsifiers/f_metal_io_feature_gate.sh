#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
cargo run --manifest-path agent_core/Cargo.toml --bin falsify_metal_io_feature_gate
cargo run --manifest-path agent_core/Cargo.toml --bin falsifier_validator -- artifacts/falsifiers/metal_io_feature_gate/result.json
