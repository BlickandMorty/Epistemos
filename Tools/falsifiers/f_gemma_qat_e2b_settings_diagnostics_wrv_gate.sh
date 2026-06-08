#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

cargo run --manifest-path agent_core/Cargo.toml --bin falsify_gemma_qat_e2b_settings_diagnostics_wrv_gate
cargo run --manifest-path agent_core/Cargo.toml --bin falsifier_validator -- \
  artifacts/falsifiers/gemma_qat_e2b_settings_diagnostics_wrv_gate/result.json
