#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

cargo run --manifest-path agent_core/Cargo.toml --bin falsify_slab_arena_copy_count
cargo run --manifest-path agent_core/Cargo.toml --bin falsifier_validator \
  artifacts/falsifiers/slab_arena_copy_count/result.json
