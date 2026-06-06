#!/usr/bin/env bash
set -euo pipefail

cargo run --manifest-path agent_core/Cargo.toml --bin falsify_turbovec_quarantine_adapter_microbench_probe
cargo run --manifest-path agent_core/Cargo.toml --bin falsifier_validator -- artifacts/falsifiers/turbovec_quarantine_adapter_microbench_probe/result.json
