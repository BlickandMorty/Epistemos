#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

cargo run --manifest-path agent_core/Cargo.toml --bin falsify_depth_lease_checkpoint
cargo run --manifest-path agent_core/Cargo.toml --bin falsifier_validator artifacts/falsifiers/depth_lease_checkpoint/result.json
