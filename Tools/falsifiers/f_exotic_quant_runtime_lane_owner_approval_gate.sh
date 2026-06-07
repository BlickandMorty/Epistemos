#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

cargo run --manifest-path agent_core/Cargo.toml \
  --bin falsify_exotic_quant_runtime_lane_owner_approval_gate

cargo run --manifest-path agent_core/Cargo.toml \
  --bin falsifier_validator \
  artifacts/falsifiers/exotic_quant_runtime_lane_owner_approval_gate/result.json
