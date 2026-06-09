#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

cargo run --manifest-path agent_core/Cargo.toml --bin falsify_gemma_local_artifact_acquisition_receipt_gate
cargo run --manifest-path agent_core/Cargo.toml --bin falsifier_validator artifacts/falsifiers/gemma_local_artifact_acquisition_receipt_gate/result.json
