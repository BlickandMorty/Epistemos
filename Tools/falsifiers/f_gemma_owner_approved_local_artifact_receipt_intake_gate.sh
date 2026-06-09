#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

cargo run --manifest-path agent_core/Cargo.toml --bin falsify_gemma_owner_approved_local_artifact_receipt_intake_gate
cargo run --manifest-path agent_core/Cargo.toml --bin falsifier_validator -- artifacts/falsifiers/gemma_owner_approved_local_artifact_receipt_intake_gate/result.json
