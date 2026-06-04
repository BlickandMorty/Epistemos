#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

cargo run --manifest-path agent_core/Cargo.toml --bin falsify_verifier_regret_fast_weights
cargo run --manifest-path agent_core/Cargo.toml --bin falsifier_validator artifacts/falsifiers/verifier_regret_fast_weights/result.json
