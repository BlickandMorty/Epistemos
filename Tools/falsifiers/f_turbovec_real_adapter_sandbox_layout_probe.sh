#!/usr/bin/env bash
set -euo pipefail

cargo run --manifest-path agent_core/Cargo.toml --bin falsify_turbovec_real_adapter_sandbox_layout_probe
cargo run --manifest-path agent_core/Cargo.toml --bin falsifier_validator -- artifacts/falsifiers/turbovec_real_adapter_sandbox_layout_probe/result.json
