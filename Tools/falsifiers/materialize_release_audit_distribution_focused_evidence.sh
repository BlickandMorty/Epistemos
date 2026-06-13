#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

cargo run --manifest-path agent_core/Cargo.toml --release \
  --bin materialize_release_audit_distribution_focused_evidence

cargo run --manifest-path agent_core/Cargo.toml --release --bin falsifier_validator -- \
  artifacts/falsifiers/release_audit_distribution_focused_evidence/result.json
