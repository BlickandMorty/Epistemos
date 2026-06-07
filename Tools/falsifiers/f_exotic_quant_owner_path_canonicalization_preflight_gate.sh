#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

cargo run --manifest-path agent_core/Cargo.toml --bin falsify_exotic_quant_owner_path_canonicalization_preflight_gate
cargo run --manifest-path agent_core/Cargo.toml --bin falsifier_validator -- \
  artifacts/falsifiers/exotic_quant_owner_path_canonicalization_preflight_gate/result.json
