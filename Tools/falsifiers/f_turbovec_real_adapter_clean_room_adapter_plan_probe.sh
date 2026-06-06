#!/usr/bin/env bash
set -euo pipefail

cargo run --manifest-path agent_core/Cargo.toml --bin falsify_turbovec_real_adapter_clean_room_adapter_plan_probe
cargo run --manifest-path agent_core/Cargo.toml --bin falsifier_validator -- artifacts/falsifiers/turbovec_real_adapter_clean_room_adapter_plan_probe/result.json
