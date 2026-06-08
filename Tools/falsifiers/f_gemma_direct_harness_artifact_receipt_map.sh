#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

cargo run --manifest-path agent_core/Cargo.toml \
  --bin falsify_gemma_direct_harness_artifact_receipt_map

cargo run --manifest-path agent_core/Cargo.toml \
  --bin falsifier_validator \
  artifacts/falsifiers/gemma_direct_harness_artifact_receipt_map/result.json
