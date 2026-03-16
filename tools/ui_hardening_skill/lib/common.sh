#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
HARNESS_DIR="${ROOT}/tools/ui_hardening_skill"
REPORT_ROOT="${HARNESS_DIR}/reports"
PROFILE_ROOT="${HARNESS_DIR}/profiles"
DERIVED_DATA_PATH="${UI_HARDENING_DERIVED_DATA_PATH:-${REPORT_ROOT}/derived-data/$(date +"%Y%m%d-%H%M%S")-$$}"
mkdir -p "${DERIVED_DATA_PATH}"

timestamp() {
  date +"%Y%m%d-%H%M%S"
}

new_run_dir() {
  local slug="$1"
  local run_dir="${REPORT_ROOT}/$(timestamp)-${slug}"
  mkdir -p "${run_dir}"
  printf '%s\n' "${run_dir}"
}

section() {
  local file="$1"
  local title="$2"
  {
    printf '\n## %s\n\n' "${title}"
  } >> "${file}"
}

note() {
  local file="$1"
  shift
  printf '%s\n' "$*" >> "${file}"
}

capture_cmd() {
  local file="$1"
  local title="$2"
  shift 2
  section "${file}" "${title}"
  {
    printf '```bash\n'
    printf '%q ' "$@"
    printf '\n```\n\n'
    "$@" 2>&1 || true
  } >> "${file}"
}

capture_rg() {
  local file="$1"
  local title="$2"
  local pattern="$3"
  shift 3
  capture_cmd "${file}" "${title}" rg -n --hidden -S "${pattern}" "$@"
}

swift_test() {
  local file="$1"
  local title="$2"
  local only_testing="$3"
  if [[ "${UI_HARDENING_SKIP_TESTS:-0}" == "1" ]]; then
    section "${file}" "${title}"
    note "${file}" "Skipped because \`UI_HARDENING_SKIP_TESTS=1\`."
    return
  fi
  capture_cmd \
    "${file}" \
    "${title}" \
    xcodebuild \
    -project "${ROOT}/Epistemos.xcodeproj" \
    -scheme Epistemos \
    -destination "platform=macOS" \
    -derivedDataPath "${DERIVED_DATA_PATH}" \
    test \
    -only-testing:"${only_testing}"
}

swift_build() {
  local file="$1"
  local title="$2"
  if [[ "${UI_HARDENING_SKIP_BUILD:-0}" == "1" ]]; then
    section "${file}" "${title}"
    note "${file}" "Skipped because \`UI_HARDENING_SKIP_BUILD=1\`."
    return
  fi
  capture_cmd \
    "${file}" \
    "${title}" \
    xcodebuild \
    -project "${ROOT}/Epistemos.xcodeproj" \
    -scheme Epistemos \
    -destination "platform=macOS" \
    -derivedDataPath "${DERIVED_DATA_PATH}" \
    build
}
