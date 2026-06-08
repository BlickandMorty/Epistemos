#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

cargo run --manifest-path agent_core/Cargo.toml \
  --bin falsify_gemma_qat_e2b_runtime_router_admission_packet_gate

cargo run --manifest-path agent_core/Cargo.toml \
  --bin falsifier_validator \
  artifacts/falsifiers/gemma_qat_e2b_runtime_router_admission_packet_gate/result.json
