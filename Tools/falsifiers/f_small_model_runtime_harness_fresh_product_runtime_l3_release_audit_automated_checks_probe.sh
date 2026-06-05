#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

ARTIFACT_DIR="artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe"
LOG_DIR="$ARTIFACT_DIR/logs"
LEDGER="$ARTIFACT_DIR/checks.tsv"
TMP_LEDGER="$LEDGER.tmp"

mkdir -p "$LOG_DIR"
rm -f "$LOG_DIR"/*.log

printf 'id\tstatus\texit_code\tduration_seconds\tlog_path\n' > "$TMP_LEDGER"

run_check() {
  local id="$1"
  shift
  local log_path="$LOG_DIR/$id.log"
  local start end duration code status

  start="$(date +%s)"
  set +e
  "$@" > "$log_path" 2>&1
  code=$?
  set -e
  end="$(date +%s)"
  duration=$((end - start))
  if [[ "$duration" -lt 1 ]]; then
    duration=1
  fi
  if [[ "$code" -eq 0 ]]; then
    status="pass"
  else
    status="fail"
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$status" "$code" "$duration" "$log_path" >> "$TMP_LEDGER"
}

run_check xcodebuild_build \
  xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build

run_check xcodebuild_test \
  xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test

run_check graph_engine_cargo_test \
  cargo test --manifest-path graph-engine/Cargo.toml

run_check omega_mcp_cargo_test \
  cargo test --manifest-path omega-mcp/Cargo.toml

run_check omega_ax_cargo_test \
  cargo test --manifest-path omega-ax/Cargo.toml

mv "$TMP_LEDGER" "$LEDGER"

set +e
cargo run --manifest-path agent_core/Cargo.toml --release \
  --bin falsify_small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe
falsifier_code=$?
set -e

cargo run --manifest-path agent_core/Cargo.toml --release --bin falsifier_validator -- \
  artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe/result.json

exit "$falsifier_code"
