#!/usr/bin/env bash
set -euo pipefail

cargo run --manifest-path agent_core/Cargo.toml --bin falsify_turbovec_real_adapter_exact_baseline_shadow_replay_probe
cargo run --manifest-path agent_core/Cargo.toml --bin falsifier_validator -- artifacts/falsifiers/turbovec_real_adapter_exact_baseline_shadow_replay_probe/result.json
