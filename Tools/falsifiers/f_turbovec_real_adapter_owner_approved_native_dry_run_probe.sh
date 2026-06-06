#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

cargo run --manifest-path agent_core/Cargo.toml \
  --bin falsify_turbovec_real_adapter_owner_approved_native_dry_run_probe
cargo run --manifest-path agent_core/Cargo.toml \
  --bin falsifier_validator \
  artifacts/falsifiers/turbovec_real_adapter_owner_approved_native_dry_run_probe/result.json
