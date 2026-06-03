#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

if rustup toolchain list 2>/dev/null | grep -q '^stable-aarch64-apple-darwin'; then
  CARGO=(cargo +stable-aarch64-apple-darwin)
else
  CARGO=(cargo)
fi

"${CARGO[@]}" run --manifest-path agent_core/Cargo.toml --bin falsify_proof_carrying_residency_lease
status=$?

"${CARGO[@]}" run --manifest-path agent_core/Cargo.toml --bin falsifier_validator -- \
  artifacts/falsifiers/proof_carrying_residency_lease/result.json
validator_status=$?

if [[ "$validator_status" -ne 0 ]]; then
  exit "$validator_status"
fi

exit "$status"
