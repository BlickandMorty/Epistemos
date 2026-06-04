#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

cargo run --manifest-path agent_core/Cargo.toml --bin falsify_sparse_wake_proposal_budget
cargo run --manifest-path agent_core/Cargo.toml --bin falsifier_validator -- artifacts/falsifiers/sparse_wake_proposal_budget/result.json
