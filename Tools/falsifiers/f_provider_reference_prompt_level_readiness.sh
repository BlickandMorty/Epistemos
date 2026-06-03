#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

TOOLCHAIN="${RUSTUP_TOOLCHAIN:-stable-aarch64-apple-darwin}"

cargo +"$TOOLCHAIN" run --manifest-path agent_core/Cargo.toml --bin falsify_provider_reference_prompt_level_readiness
status=$?

cargo +"$TOOLCHAIN" run --manifest-path agent_core/Cargo.toml --bin falsifier_validator -- \
  artifacts/falsifiers/provider_reference_prompt_level_readiness/result.json
validator_status=$?

if [[ "$validator_status" -ne 0 ]]; then
  exit "$validator_status"
fi

exit "$status"
