#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

cargo run --manifest-path agent_core/Cargo.toml --bin falsify_distribution_project_integrity_release_blocker_card
cargo run --manifest-path agent_core/Cargo.toml --bin falsifier_validator -- \
  artifacts/falsifiers/distribution_project_integrity_release_blocker_card/result.json
