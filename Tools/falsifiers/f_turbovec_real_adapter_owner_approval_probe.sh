#!/usr/bin/env bash
set -euo pipefail

cargo run --manifest-path agent_core/Cargo.toml --bin falsify_turbovec_real_adapter_owner_approval_probe
cargo run --manifest-path agent_core/Cargo.toml --bin falsifier_validator -- artifacts/falsifiers/turbovec_real_adapter_owner_approval_probe/result.json
