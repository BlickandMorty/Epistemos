#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

if command -v rustup >/dev/null 2>&1 && rustup toolchain list | grep -q '^stable-aarch64-apple-darwin'; then
  CARGO=(cargo +stable-aarch64-apple-darwin)
else
  CARGO=(cargo)
fi

"${CARGO[@]}" run --manifest-path agent_core/Cargo.toml --bin falsify_source_to_residency_no_poison

"${CARGO[@]}" run --manifest-path agent_core/Cargo.toml --bin falsifier_validator -- \
  artifacts/falsifiers/source_to_residency_no_poison/result.json
