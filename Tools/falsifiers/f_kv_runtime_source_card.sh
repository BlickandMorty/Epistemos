#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

if rustup toolchain list 2>/dev/null | grep -q '^stable-aarch64-apple-darwin'; then
  CARGO=(cargo +stable-aarch64-apple-darwin)
else
  CARGO=(cargo)
fi

"${CARGO[@]}" run --manifest-path agent_core/Cargo.toml \
  --bin falsify_kv_runtime_source_card

"${CARGO[@]}" run --manifest-path agent_core/Cargo.toml \
  --bin falsifier_validator \
  artifacts/falsifiers/kv_runtime_source_card/result.json
