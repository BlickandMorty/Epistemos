#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

cargo run --manifest-path agent_core/Cargo.toml --bin falsify_proof_pressure_signal
cargo run --manifest-path agent_core/Cargo.toml --bin falsifier_validator artifacts/falsifiers/proof_pressure_signal/result.json
