#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

export LC_ALL=C
export TZ=UTC

if command -v cargo >/dev/null 2>&1; then
  CARGO=(cargo)
else
  CARGO=(/Users/jojo/.cargo/bin/cargo)
fi

"${CARGO[@]}" run --manifest-path agent_core/Cargo.toml --bin falsify_turbovec_recall_quality_exact_baseline
"${CARGO[@]}" run --manifest-path agent_core/Cargo.toml --bin falsifier_validator -- artifacts/falsifiers/turbovec_recall_quality_exact_baseline/result.json
