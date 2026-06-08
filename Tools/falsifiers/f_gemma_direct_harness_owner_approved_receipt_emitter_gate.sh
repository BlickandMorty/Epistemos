#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

cargo run --manifest-path agent_core/Cargo.toml \
  --bin falsify_gemma_direct_harness_owner_approved_receipt_emitter_gate

cargo run --manifest-path agent_core/Cargo.toml \
  --bin falsifier_validator \
  artifacts/falsifiers/gemma_direct_harness_owner_approved_receipt_emitter_gate/result.json
