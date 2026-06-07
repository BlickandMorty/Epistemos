#!/usr/bin/env bash
set -euo pipefail

cargo run --manifest-path agent_core/Cargo.toml --bin falsify_exotic_quant_crash_safe_command_envelope_preflight_gate
cargo run --manifest-path agent_core/Cargo.toml --bin falsifier_validator -- \
  artifacts/falsifiers/exotic_quant_crash_safe_command_envelope_preflight_gate/result.json
