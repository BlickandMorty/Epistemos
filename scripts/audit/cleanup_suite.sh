#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STAMP="${1:-$(date +%F)}"
REPORT_DIR="${ROOT_DIR}/docs/audits"

mkdir -p "${REPORT_DIR}"

dead_code_report="${REPORT_DIR}/dead-code-report-${STAMP}.md"
xcode_orphan_report="${REPORT_DIR}/xcode-orphan-report-${STAMP}.md"
ffi_surface_report="${REPORT_DIR}/ffi-surface-report-${STAMP}.md"
summary_report="${REPORT_DIR}/cleanup-suite-${STAMP}.md"

"${ROOT_DIR}/scripts/audit/dead_code_report.sh" "${dead_code_report}"
python3 "${ROOT_DIR}/scripts/audit/xcode_orphan_report.py" "${xcode_orphan_report}"
python3 "${ROOT_DIR}/scripts/audit/ffi_surface_report.py" "${ffi_surface_report}"

{
  echo "# Cleanup Suite Report"
  echo
  echo "- Generated: $(date)"
  echo "- Root: \`${ROOT_DIR}\`"
  echo
  echo "## Reports"
  echo "- [Dead Code Report](${dead_code_report})"
  echo "- [Xcode Orphan Report](${xcode_orphan_report})"
  echo "- [FFI Surface Report](${ffi_surface_report})"
  echo
  echo "## Quick Commands"
  echo '```bash'
  echo "./scripts/audit/cleanup_suite.sh"
  echo "./scripts/audit/dead_code_report.sh"
  echo "python3 ./scripts/audit/xcode_orphan_report.py"
  echo "python3 ./scripts/audit/ffi_surface_report.py"
  echo '```'
} > "${summary_report}"

printf 'Wrote %s\n' "${summary_report}"
