#!/usr/bin/env bash
set -euo pipefail

PROJECT="${PROJECT:-Epistemos.xcodeproj}"
SCHEME="${SCHEME:-Epistemos}"
DESTINATION="${DESTINATION:-platform=macOS}"
RESULT_ROOT="${RESULT_ROOT:-artifacts/reliability}"
SUITE_ID="${SUITE_ID:-EpistemosTests/GeneratedReliabilityMatrixTests}"
GATES="${GATES:-baseline,perf_diagnostics,asan,tsan,ubsan,soak_repeat}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XCODEBUILD_WRAPPER="${ROOT_DIR}/scripts/xcodebuild_epistemos.sh"

timestamp="$(date +%Y%m%d-%H%M%S)"
out_dir="${RESULT_ROOT}/${timestamp}"
mkdir -p "${out_dir}"

# DerivedData root is decoupled from RESULT_ROOT so logs/xcresult artifacts can
# remain under a project- or repo-relative path while the test host bundle is
# spawned from a location outside macOS TCC protected folders. The §8.9 hang
# evidence isolated a single proximate cause: the unhosted protected-folder
# (SystemPolicyDownloadsFolder / Desktop / Documents) consent-prompt path that
# tccd raises against the freshly-spawned test-host PID when the bundle lives
# under ~/Downloads / ~/Desktop / ~/Documents and `xcodebuild test` runs without
# a foreground app to host the prompt. The SystemPolicyAllFiles code-requirement
# mismatch line can still appear in the green /tmp run (see §8.10) and was
# non-fatal there; it is the unhosted protected-folder prompt fork specifically
# that produced the unbounded test-runner-launch handshake wait. The protected
# default below also includes the run timestamp so two back-to-back invocations
# never reuse the same DerivedData tree, which would risk cross-run cdhash /
# cache collisions while diagnosing TCC behavior. See docs/PHASE_S_AUDIT.md §8.9
# / §8.10.
home_real="$(cd "${HOME}" && pwd)"
root_real="$(cd "${ROOT_DIR}" && pwd)"
case "${root_real}" in
  "${home_real}/Downloads"|"${home_real}/Downloads"/*|"${home_real}/Desktop"|"${home_real}/Desktop"/*|"${home_real}/Documents"|"${home_real}/Documents"/*)
    protected_root_default="${TMPDIR:-/tmp}/epistemos-reliability-derived-data/${timestamp}"
    ;;
  *)
    protected_root_default="${out_dir}"
    ;;
esac

DERIVED_DATA_ROOT="${DERIVED_DATA_ROOT:-${protected_root_default}}"
mkdir -p "${DERIVED_DATA_ROOT}"

run_gate() {
  local name="$1"
  shift
  local log_file="${out_dir}/${name}.log"
  local result_bundle="${out_dir}/${name}.xcresult"
  local derived_data="${DERIVED_DATA_ROOT}/derived-data-${name}"

  echo "=== ${name} ==="
  echo "log: ${log_file}"
  echo "xcresult: ${result_bundle}"
  echo "derivedData: ${derived_data}"

  "${XCODEBUILD_WRAPPER}" test \
    -project "${PROJECT}" \
    -scheme "${SCHEME}" \
    -destination "${DESTINATION}" \
    -derivedDataPath "${derived_data}" \
    CODE_SIGNING_ALLOWED=NO \
    -resultBundlePath "${result_bundle}" \
    -collect-test-diagnostics on-failure \
    -only-testing:"${SUITE_ID}" \
    "$@" \
    > "${log_file}" 2>&1
}

run_soak_repeat_gate() {
  local name="soak_repeat"
  local log_file="${out_dir}/${name}.log"
  local result_dir="${out_dir}/${name}.xcresults"
  local derived_data="${DERIVED_DATA_ROOT}/derived-data-${name}"

  echo "=== ${name} ==="
  echo "log: ${log_file}"
  echo "xcresults: ${result_dir}"
  echo "derivedData: ${derived_data}"

  mkdir -p "${result_dir}"
  : > "${log_file}"

  # Keep the soak bounded in shell instead of relying on xcodebuild's repetition
  # mode, which can start a second batch after reporting an 8-iteration pass.
  for iteration in 1 2 3 4 5 6 7 8; do
    local iteration_id
    iteration_id="$(printf '%02d' "${iteration}")"
    local result_bundle="${result_dir}/iteration-${iteration_id}.xcresult"

    {
      echo "=== soak_repeat iteration ${iteration}/8 ==="
      echo "xcresult: ${result_bundle}"
      "${XCODEBUILD_WRAPPER}" test \
        -project "${PROJECT}" \
        -scheme "${SCHEME}" \
        -destination "${DESTINATION}" \
        -derivedDataPath "${derived_data}" \
        CODE_SIGNING_ALLOWED=NO \
        -resultBundlePath "${result_bundle}" \
        -collect-test-diagnostics on-failure \
        -only-testing:"${SUITE_ID}" \
        -test-timeouts-enabled YES \
        -maximum-test-execution-time-allowance 180
    } >> "${log_file}" 2>&1
  done
}

gate_enabled() {
  local name="$1"
  [[ ",${GATES}," == *",${name},"* ]]
}

if gate_enabled baseline; then
  run_gate baseline
fi

if gate_enabled perf_diagnostics; then
  run_gate perf_diagnostics -enablePerformanceTestsDiagnostics YES
fi

if gate_enabled asan; then
  run_gate asan -enableAddressSanitizer YES
fi

if gate_enabled tsan; then
  # TSAN links the full app with Swift, ObjC/C++, and Rust exception personalities.
  # Disabling compact-unwind generation avoids ld's personality-routine cap while
  # preserving ThreadSanitizer instrumentation.
  run_gate tsan \
    'OTHER_LDFLAGS=$(inherited) -Wl,-no_compact_unwind' \
    -enableThreadSanitizer YES
fi

if gate_enabled ubsan; then
  run_gate ubsan -enableUndefinedBehaviorSanitizer YES
fi

if gate_enabled soak_repeat; then
  run_soak_repeat_gate
fi

echo
echo "Quality gates complete."
echo "Executed gates: ${GATES}"
echo "Artifacts: ${out_dir}"
echo "DerivedData: ${DERIVED_DATA_ROOT}"
