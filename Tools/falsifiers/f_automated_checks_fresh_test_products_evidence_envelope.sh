#!/usr/bin/env zsh
set -euo pipefail
cd "$(dirname "$0")/../.."
cargo run --manifest-path agent_core/Cargo.toml --bin falsify_automated_checks_fresh_test_products_evidence_envelope
cargo run --manifest-path agent_core/Cargo.toml --bin falsifier_validator -- artifacts/falsifiers/automated_checks_fresh_test_products_evidence_envelope/result.json
