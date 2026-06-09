#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

cargo run --manifest-path agent_core/Cargo.toml --bin falsify_gemma_direct_harness_owner_approved_redacted_dry_run_receipt_gate
cargo run --manifest-path agent_core/Cargo.toml --bin falsifier_validator -- artifacts/falsifiers/gemma_direct_harness_owner_approved_redacted_dry_run_receipt_gate/result.json
