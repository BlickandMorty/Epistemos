#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

cargo run --manifest-path agent_core/Cargo.toml --bin falsify_gguf_in_process_runtime_admission_packet
cargo run --manifest-path agent_core/Cargo.toml --bin falsifier_validator -- \
  artifacts/falsifiers/gguf_in_process_runtime_admission_packet/result.json
