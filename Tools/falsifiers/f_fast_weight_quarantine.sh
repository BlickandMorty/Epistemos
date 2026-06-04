#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

cargo run --manifest-path agent_core/Cargo.toml --bin falsify_fast_weight_quarantine
cargo run --manifest-path agent_core/Cargo.toml --bin falsifier_validator artifacts/falsifiers/fast_weight_quarantine/result.json
