#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

ARTIFACT_DIR="artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe"
LOG_DIR="$ARTIFACT_DIR/logs"
XCODE_RESULT_BUNDLE_DIR="$ARTIFACT_DIR/xcresults"
LEDGER="$ARTIFACT_DIR/checks.tsv"
TMP_LEDGER="$LEDGER.tmp"
XCODEBUILD_WRAPPER="$ROOT/scripts/xcodebuild_epistemos.sh"
RUN_ID="$(date +%Y%m%d-%H%M%S)-$$"
XCODE_DERIVED_DATA_ROOT="${EPI_RELEASE_AUDIT_DERIVED_DATA_ROOT:-${TMPDIR:-/tmp}/epistemos-release-audit-derived-data/${RUN_ID}}"
RELEASE_AUDIT_DEFAULT_TIMEOUT_SECONDS="${EPI_RELEASE_AUDIT_DEFAULT_TIMEOUT_SECONDS:-0}"
RELEASE_AUDIT_XCODEBUILD_BUILD_TIMEOUT_SECONDS="${EPI_RELEASE_AUDIT_XCODEBUILD_BUILD_TIMEOUT_SECONDS:-1800}"
RELEASE_AUDIT_XCODEBUILD_TEST_TIMEOUT_SECONDS="${EPI_RELEASE_AUDIT_XCODEBUILD_TEST_TIMEOUT_SECONDS:-3600}"

mkdir -p "$LOG_DIR"
mkdir -p "$XCODE_RESULT_BUNDLE_DIR"
mkdir -p "$XCODE_DERIVED_DATA_ROOT"
rm -f "$LOG_DIR"/*.log
rm -rf "$XCODE_RESULT_BUNDLE_DIR"/*.xcresult

printf 'id\tstatus\texit_code\tduration_seconds\tlog_path\n' > "$TMP_LEDGER"
cp "$TMP_LEDGER" "$LEDGER"

timeout_for_check() {
  case "$1" in
    xcodebuild_build)
      printf '%s\n' "$RELEASE_AUDIT_XCODEBUILD_BUILD_TIMEOUT_SECONDS"
      ;;
    xcodebuild_test)
      printf '%s\n' "$RELEASE_AUDIT_XCODEBUILD_TEST_TIMEOUT_SECONDS"
      ;;
    *)
      printf '%s\n' "$RELEASE_AUDIT_DEFAULT_TIMEOUT_SECONDS"
      ;;
  esac
}

terminate_process_tree() {
  local root_pid="$1"
  local child_pid

  while read -r child_pid; do
    [[ -z "$child_pid" ]] && continue
    terminate_process_tree "$child_pid"
  done < <(pgrep -P "$root_pid" 2>/dev/null || true)

  kill "$root_pid" 2>/dev/null || true
}

append_hang_diagnostics() {
  local id="$1"
  local timeout_seconds="$2"
  local log_path="$3"

  {
    printf '\n[release-audit] %s timed out after %s seconds\n' "$id" "$timeout_seconds"
    printf '[release-audit] active xcode/test processes at timeout:\n'
    ps -axo pid,ppid,stat,etime,%cpu,%mem,command \
      | grep -E 'xcodebuild|xctest|EpistemosTests|Epistemos\[|swift-frontend|SWBBuildService' \
      | grep -v grep \
      || true
  } >> "$log_path" 2>&1
}

run_check() {
  local id="$1"
  shift
  local log_path="$LOG_DIR/$id.log"
  local start end duration code status timeout_seconds command_pid timed_out

  start="$(date +%s)"
  timeout_seconds="$(timeout_for_check "$id")"
  timed_out=0
  set +e
  if [[ "$timeout_seconds" =~ ^[0-9]+$ ]] && [[ "$timeout_seconds" -gt 0 ]]; then
    "$@" > "$log_path" 2>&1 &
    command_pid=$!

    while kill -0 "$command_pid" 2>/dev/null; do
      if [[ $(( $(date +%s) - start )) -ge "$timeout_seconds" ]]; then
        timed_out=1
        append_hang_diagnostics "$id" "$timeout_seconds" "$log_path"
        terminate_process_tree "$command_pid"
        sleep 5
        kill -9 "$command_pid" 2>/dev/null || true
        break
      fi
      sleep 5
    done

    wait "$command_pid"
    code=$?
    if [[ "$timed_out" -eq 1 ]]; then
      code=124
    fi
  else
    "$@" > "$log_path" 2>&1
    code=$?
  fi
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
  cp "$TMP_LEDGER" "$LEDGER"
}

run_check xcodebuild_build \
  "$XCODEBUILD_WRAPPER" build \
    -project Epistemos.xcodeproj \
    -scheme Epistemos \
    -destination 'platform=macOS' \
    -derivedDataPath "$XCODE_DERIVED_DATA_ROOT/build" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""

run_check xcodebuild_test \
  "$XCODEBUILD_WRAPPER" test \
    -project Epistemos.xcodeproj \
    -scheme Epistemos \
    -destination 'platform=macOS' \
    -derivedDataPath "$XCODE_DERIVED_DATA_ROOT/test" \
    -resultBundlePath "$XCODE_RESULT_BUNDLE_DIR/xcodebuild_test.xcresult" \
    -collect-test-diagnostics on-failure \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""

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
