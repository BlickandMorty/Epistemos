#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

cargo run --manifest-path agent_core/Cargo.toml --bin falsify_proof_search_signal_route_feedback
cargo run --manifest-path agent_core/Cargo.toml --bin falsifier_validator artifacts/falsifiers/proof_search_signal_route_feedback/result.json
