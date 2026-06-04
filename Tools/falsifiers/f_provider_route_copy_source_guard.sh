#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
cargo run --manifest-path agent_core/Cargo.toml --bin falsify_provider_route_copy_source_guard
cargo run --manifest-path agent_core/Cargo.toml --bin falsifier_validator -- \
  artifacts/falsifiers/provider_route_copy_source_guard/result.json
