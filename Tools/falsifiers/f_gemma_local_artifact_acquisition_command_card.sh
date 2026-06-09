#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

cargo run --manifest-path agent_core/Cargo.toml --bin falsify_gemma_local_artifact_acquisition_command_card
cargo run --manifest-path agent_core/Cargo.toml --bin falsifier_validator artifacts/falsifiers/gemma_local_artifact_acquisition_command_card/result.json
