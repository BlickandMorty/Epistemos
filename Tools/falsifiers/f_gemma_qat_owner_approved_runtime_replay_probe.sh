#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

cargo run --manifest-path agent_core/Cargo.toml --bin falsify_gemma_qat_owner_approved_runtime_replay_probe
cargo run --manifest-path agent_core/Cargo.toml --bin falsifier_validator -- artifacts/falsifiers/gemma_qat_owner_approved_runtime_replay_probe/result.json
