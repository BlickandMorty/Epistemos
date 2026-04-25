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
# spawned from a location outside macOS TCC protected folders. The test-runner
# launch handshake hangs when the host bundle lives under ~/Downloads / ~/Desktop
# / ~/Documents because tccd surfaces a SystemPolicyDownloadsFolder /
# SystemPolicyAllFiles consent prompt against the freshly-spawned PID and there
# is no foreground app to host the prompt; see docs/PHASE_S_AUDIT.md §8.9 / §8.10.
home_real="$(cd "${HOME}" && pwd)"
root_real="$(cd "${ROOT_DIR}" && pwd)"
case "${root_real}" in
  "${home_real}/Downloads"/*|"${home_real}/Desktop"/*|"${home_real}/Documents"/*)
    protected_root_default="${TMPDIR:-/tmp}/epistemos-reliability-derived-data"
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
  run_gate tsan -enableThreadSanitizer YES
fi

if gate_enabled ubsan; then
  run_gate ubsan -enableUndefinedBehaviorSanitizer YES
fi

if gate_enabled soak_repeat; then
  run_gate soak_repeat \
    -test-iterations 8 \
    -run-tests-until-failure \
    -test-repetition-relaunch-enabled YES \
    -test-timeouts-enabled YES \
    -maximum-test-execution-time-allowance 180
fi

echo
echo "Quality gates complete."
echo "Executed gates: ${GATES}"
echo "Artifacts: ${out_dir}"
echo "DerivedData: ${DERIVED_DATA_ROOT}"
