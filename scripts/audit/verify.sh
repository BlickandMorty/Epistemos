#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STAMP="$(date +%F-%H%M%S)"
REPORT_PATH="${ROOT_DIR}/docs/audits/verify-${STAMP}.md"
DERIVED_DATA_PATH="${ROOT_DIR}/build/verify-derived-data"
APP_BINARY="${DERIVED_DATA_PATH}/Build/Products/Release/Epistemos.app/Contents/MacOS/Epistemos"
FIX_FORMAT=0

usage() {
  cat <<'EOF'
Usage: ./scripts/audit/verify.sh [--fix-format] [--report PATH]

Strict post-purge verification for the live in-process architecture.
- Fails on banned legacy runtime strings in live code.
- Runs native cleanup scan.
- Runs strict Rust linting and tests.
- Runs Release Swift strict-concurrency verification.
- Runs targeted runtime validation tests.
- Prints manual-only powermetrics and leaks commands.
EOF
}

while (($#)); do
  case "$1" in
    --fix-format)
      FIX_FORMAT=1
      shift
      ;;
    --report)
      REPORT_PATH="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

mkdir -p "$(dirname "${REPORT_PATH}")" "${DERIVED_DATA_PATH}"
: > "${REPORT_PATH}"

section() {
  local title="$1"
  printf '\n## %s\n\n' "${title}" | tee -a "${REPORT_PATH}"
}

run_cmd() {
  local label="$1"
  shift
  section "${label}"
  printf '```bash\n%s\n```\n\n' "$*" | tee -a "${REPORT_PATH}"
  "$@" 2>&1 | tee -a "${REPORT_PATH}"
}

run_shell() {
  local label="$1"
  local command_string="$2"
  section "${label}"
  printf '```bash\n%s\n```\n\n' "${command_string}" | tee -a "${REPORT_PATH}"
  /bin/zsh -lc "${command_string}" 2>&1 | tee -a "${REPORT_PATH}"
}

fail_if_matches() {
  local label="$1"
  local pattern="$2"
  local output_file
  output_file="$(mktemp)"

  if rg -n "${pattern}" \
    "${ROOT_DIR}/Epistemos" \
    "${ROOT_DIR}/graph-engine" \
    "${ROOT_DIR}/graph-engine-bridge" \
    --glob '!docs/**' \
    --glob '!scripts/audit/**' \
    >"${output_file}"; then
    section "${label}"
    printf 'Legacy residue detected:\n\n' | tee -a "${REPORT_PATH}"
    printf '```text\n' | tee -a "${REPORT_PATH}"
    cat "${output_file}" | tee -a "${REPORT_PATH}"
    printf '```\n' | tee -a "${REPORT_PATH}"
    rm -f "${output_file}"
    exit 1
  fi

  rm -f "${output_file}"
}

fail_if_warnings() {
  local label="$1"
  local log_file="$2"

  if rg -n "warning:" "${log_file}" >/dev/null; then
    section "${label}"
    printf 'Swift strict-concurrency build emitted warnings and therefore failed verification.\n\n' | tee -a "${REPORT_PATH}"
    printf '```text\n' | tee -a "${REPORT_PATH}"
    rg -n "warning:" "${log_file}" | tee -a "${REPORT_PATH}"
    printf '```\n' | tee -a "${REPORT_PATH}"
    exit 1
  fi
}

report_project_warnings() {
  local label="$1"
  local log_file="$2"
  local output_file
  output_file="$(mktemp)"

  if rg -n "${ROOT_DIR}/Epistemos/.*warning:|${ROOT_DIR}/graph-engine/.*warning:" "${log_file}" >"${output_file}"; then
    section "${label}"
    printf '```text\n' | tee -a "${REPORT_PATH}"
    cat "${output_file}" | tee -a "${REPORT_PATH}"
    printf '```\n' | tee -a "${REPORT_PATH}"
  fi

  rm -f "${output_file}"
}

fail_if_concurrency_warnings() {
  local label="$1"
  local log_file="$2"
  local output_file
  output_file="$(mktemp)"

  if rg -n "warning: .*main actor-isolated|warning: .*actor-isolated|warning: .*Sendable closure|warning: .*non-sendable|warning: .*sending .* risks|warning: .*data race" "${log_file}" >"${output_file}"; then
    section "${label}"
    printf 'Strict-concurrency verification failed on project concurrency warnings.\n\n' | tee -a "${REPORT_PATH}"
    printf '```text\n' | tee -a "${REPORT_PATH}"
    cat "${output_file}" | tee -a "${REPORT_PATH}"
    printf '```\n' | tee -a "${REPORT_PATH}"
    rm -f "${output_file}"
    exit 1
  fi

  rm -f "${output_file}"
}

{
  echo "# Verification Report"
  echo
  echo "- Generated: $(date)"
  echo "- Root: \`${ROOT_DIR}\`"
  echo "- DerivedData: \`${DERIVED_DATA_PATH}\`"
  echo "- App Binary: \`${APP_BINARY}\`"
  echo
} >> "${REPORT_PATH}"

section "Legacy Ban Gate"
printf '%s\n' \
  '- Failing on sidecar / DeepSeek / localhost transport residue in live code.' \
  '- Excludes docs and audit scripts to keep the gate focused on executable paths.' \
  | tee -a "${REPORT_PATH}"

fail_if_matches \
  "Legacy Runtime Residue Failure" \
  'LocalSidecarClient|LocalSidecarController|LocalSidecarSSEStreamDecoder|mlx-openai-server|http://127\.0\.0\.1(?::[0-9]+)?/v1/|Server-Sent Events'

run_shell \
  "Native Cleanup Scan" \
  "cd '${ROOT_DIR}' && ./scripts/audit/native_cleanup_scan.sh"

if (( FIX_FORMAT )); then
  run_shell \
    "Rust Format Fix" \
    "cd '${ROOT_DIR}' && cargo fmt --all --manifest-path graph-engine/Cargo.toml"
else
  run_shell \
    "Rust Format Check" \
    "cd '${ROOT_DIR}' && cargo fmt --all --manifest-path graph-engine/Cargo.toml --check"
fi

run_shell \
  "Rust Strict Clippy" \
  "cd '${ROOT_DIR}' && cargo clippy --manifest-path graph-engine/Cargo.toml --all-targets --all-features -- -D warnings -D dead_code"

run_shell \
  "Rust Test Suite" \
  "cd '${ROOT_DIR}' && cargo test --manifest-path graph-engine/Cargo.toml"

strict_build_log="$(mktemp)"
section "Swift 6 Strict Concurrency Release Build"
printf '```bash\n%s\n```\n\n' \
  "cd '${ROOT_DIR}' && ./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -configuration Release -derivedDataPath '${DERIVED_DATA_PATH}' -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO OTHER_SWIFT_FLAGS='\$(inherited) -Xfrontend -strict-concurrency=complete' build" \
  | tee -a "${REPORT_PATH}"
/bin/zsh -lc "cd '${ROOT_DIR}' && ./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -configuration Release -derivedDataPath '${DERIVED_DATA_PATH}' -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO OTHER_SWIFT_FLAGS='\$(inherited) -Xfrontend -strict-concurrency=complete' build" \
  2>&1 | tee "${strict_build_log}" | tee -a "${REPORT_PATH}"
report_project_warnings "Swift Project Warnings" "${strict_build_log}"
fail_if_concurrency_warnings "Swift Strict Concurrency Warnings" "${strict_build_log}"
rm -f "${strict_build_log}"

run_shell \
  "Targeted Runtime Validation" \
  "cd '${ROOT_DIR}' && ./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test -only-testing:EpistemosTests/RuntimeValidationTests -only-testing:EpistemosTests/PipelineServiceTests"

section "Manual Telemetry Commands"
cat <<EOF | tee -a "${REPORT_PATH}"
Run these manually after launching the Release build and exercising a real retrieval + generation path:

\`\`\`bash
sudo powermetrics --samplers gpu_power --show-process-energy -i 1000
MallocStackLogging=1 '${APP_BINARY}'
leaks Epistemos
\`\`\`

If you want to target a specific running PID instead of the process name:

\`\`\`bash
leaks "\$(pgrep -x Epistemos | tail -n 1)"
\`\`\`
EOF

section "Verification Result"
printf 'Verification succeeded with compiler, lint, and targeted test gates.\n' | tee -a "${REPORT_PATH}"
printf '\nWrote %s\n' "${REPORT_PATH}"
