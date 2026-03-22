#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPORT_PATH="${1:-${ROOT_DIR}/docs/audits/native-cleanup-scan-$(date +%F).md}"
RULE_DIR="${ROOT_DIR}/scripts/audit/ast-grep"

mkdir -p "$(dirname "${REPORT_PATH}")"

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

has_cargo_subcommand() {
  cargo --list 2>/dev/null | rg -q "^ +$1$"
}

has_rustup_nightly() {
  rustup toolchain list 2>/dev/null | rg -q '^nightly'
}

run_or_note() {
  local title="$1"
  local command_string="$2"
  local output_path="$3"

  {
    echo "### ${title}"
    echo '```bash'
    echo "${command_string}"
    echo '```'
    if eval "${command_string}" >"${output_path}" 2>&1; then
      sed 's/^/    /' "${output_path}"
    else
      sed 's/^/    /' "${output_path}"
    fi
    echo
  } >> "${REPORT_PATH}"
}

{
  echo "# Native Cleanup Scan"
  echo
  echo "- Generated: $(date)"
  echo "- Root: \`${ROOT_DIR}\`"
  echo
  echo "## Tool Availability"
  echo "- ast-grep: $(has_cmd ast-grep && echo installed || echo missing)"
  echo "- periphery: $(has_cmd periphery && echo installed || echo missing)"
  echo "- cargo-machete: $(cargo --list 2>/dev/null | rg -q '^ +machete$' && echo installed || echo missing)"
  echo "- cargo-udeps: $(cargo --list 2>/dev/null | rg -q '^ +udeps$' && echo installed || echo missing)"
  echo
  echo "## Immediate Install Commands"
  echo '```bash'
  echo 'brew install ast-grep peripheryapp/periphery/periphery'
  echo 'cargo install cargo-machete'
  echo 'cargo install cargo-udeps'
  echo 'rustup toolchain install nightly'
  echo '```'
  echo
  echo "## Rule Files"
  echo "- \`${RULE_DIR}/legacy-runtime-ban-swift.yml\`"
  echo "- \`${RULE_DIR}/observable-object-ban-swift.yml\`"
  echo "- \`${RULE_DIR}/ffi-json-copy-ban-swift.yml\`"
  echo "- \`${RULE_DIR}/legacy-runtime-ban-rust.yml\`"
  echo
} > "${REPORT_PATH}"

if has_cmd ast-grep; then
  run_or_note \
    "ast-grep Swift Legacy Runtime Scan" \
    "ast-grep scan --rule '${RULE_DIR}/legacy-runtime-ban-swift.yml' '${ROOT_DIR}/Epistemos'" \
    "${tmpdir}/ast_grep_swift_legacy.txt"

  run_or_note \
    "ast-grep Swift ObservableObject Scan" \
    "ast-grep scan --rule '${RULE_DIR}/observable-object-ban-swift.yml' '${ROOT_DIR}/Epistemos'" \
    "${tmpdir}/ast_grep_swift_observable.txt"

  run_or_note \
    "ast-grep Swift FFI JSON Copy Scan" \
    "ast-grep scan --rule '${RULE_DIR}/ffi-json-copy-ban-swift.yml' '${ROOT_DIR}/Epistemos/Engine' '${ROOT_DIR}/Epistemos/Graph' '${ROOT_DIR}/Epistemos/Views/Graph'" \
    "${tmpdir}/ast_grep_swift_ffi_copy.txt"

  run_or_note \
    "ast-grep Rust Legacy Runtime Scan" \
    "ast-grep scan --rule '${RULE_DIR}/legacy-runtime-ban-rust.yml' '${ROOT_DIR}/graph-engine'" \
    "${tmpdir}/ast_grep_rust_legacy.txt"
else
  run_or_note \
    "Fallback Legacy Runtime Grep" \
    "rg -n 'LocalSidecar|DeepSeek|\\breasoner\\b|mlx-openai-server|127\\.0\\.0\\.1|\\bSSE\\b' '${ROOT_DIR}/Epistemos' '${ROOT_DIR}/graph-engine' '${ROOT_DIR}/graph-engine-bridge' --glob '!docs/**' --glob '!scripts/audit/**'" \
    "${tmpdir}/legacy_runtime_grep.txt"

  run_or_note \
    "Fallback SwiftUI Legacy State Grep" \
    "rg -n 'ObservableObject|@Published|objectWillChange' '${ROOT_DIR}/Epistemos'" \
    "${tmpdir}/observable_object_grep.txt"

  run_or_note \
    "Fallback FFI JSON Copy Grep" \
    "rg -n 'JSONEncoder\\(\\)\\.encode|JSONDecoder\\(\\)\\.decode|JSONSerialization' '${ROOT_DIR}/Epistemos/Graph' '${ROOT_DIR}/Epistemos/Engine' '${ROOT_DIR}/graph-engine'" \
    "${tmpdir}/ffi_copy_grep.txt"
fi

if has_cmd periphery; then
  run_or_note \
    "Periphery Swift Reachability Scan" \
    "cd '${ROOT_DIR}' && periphery scan --project Epistemos.xcodeproj --schemes Epistemos --targets Epistemos --format xcode --retain-codable-properties --retain-objc-accessible" \
    "${tmpdir}/periphery.txt"
else
  run_or_note \
    "Periphery Missing" \
    "printf 'periphery is not installed\\n'" \
    "${tmpdir}/periphery_missing.txt"
fi

if has_cargo_subcommand machete; then
  run_or_note \
    "cargo-machete Dependency Scan" \
    "cd '${ROOT_DIR}/graph-engine' && cargo machete" \
    "${tmpdir}/cargo_machete.txt"
else
  run_or_note \
    "cargo-machete Missing" \
    "printf 'cargo-machete is not installed\\n'" \
    "${tmpdir}/cargo_machete_missing.txt"
fi

if has_cargo_subcommand udeps && has_rustup_nightly; then
  run_or_note \
    "cargo-udeps Dependency Scan" \
    "cd '${ROOT_DIR}/graph-engine' && cargo +nightly udeps --all-targets" \
    "${tmpdir}/cargo_udeps.txt"
elif has_cargo_subcommand udeps; then
  run_or_note \
    "cargo-udeps Nightly Missing" \
    "printf 'cargo-udeps is installed but requires rustup nightly; run: rustup toolchain install nightly\\n'" \
    "${tmpdir}/cargo_udeps_missing_nightly.txt"
else
  run_or_note \
    "cargo-udeps Missing" \
    "printf 'cargo-udeps is not installed\\n'" \
    "${tmpdir}/cargo_udeps_missing.txt"
fi

printf 'Wrote %s\n' "${REPORT_PATH}"
