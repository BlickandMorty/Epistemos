#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

TOOLCHAIN="${RUSTUP_TOOLCHAIN:-stable-aarch64-apple-darwin}"

cargo +"$TOOLCHAIN" run --manifest-path agent_core/Cargo.toml --bin falsify_qwen3_8b_128k_gguf_route
status=$?

cargo +"$TOOLCHAIN" run --manifest-path agent_core/Cargo.toml --bin falsifier_validator -- \
  artifacts/falsifiers/qwen3_8b_128k_gguf_route/result.json
validator_status=$?

if [[ "$validator_status" -ne 0 ]]; then
  exit "$validator_status"
fi

exit "$status"
