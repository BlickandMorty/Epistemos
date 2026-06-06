#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

cargo run --manifest-path agent_core/Cargo.toml \
  --bin falsify_qat_model_route_card_memory_preflight

cargo run --manifest-path agent_core/Cargo.toml \
  --bin falsifier_validator \
  artifacts/falsifiers/qat_model_route_card_memory_preflight/result.json
