#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HARNESS_DIR="${ROOT}/tools/ui_hardening_skill"
RUN_DIR="$("${HARNESS_DIR}/run_scroll_audit.sh" --print-run-dir)"

echo "Run directory: ${RUN_DIR}"
"${HARNESS_DIR}/run_toolbar_audit.sh" --run-dir "${RUN_DIR}"
"${HARNESS_DIR}/run_scroll_audit.sh" --run-dir "${RUN_DIR}"
"${HARNESS_DIR}/run_layout_churn_audit.sh" --run-dir "${RUN_DIR}"
"${HARNESS_DIR}/run_dead_code_audit.sh" --run-dir "${RUN_DIR}"
"${HARNESS_DIR}/run_accessibility_audit.sh" --run-dir "${RUN_DIR}"
"${HARNESS_DIR}/run_perf_audit.sh" --run-dir "${RUN_DIR}"
"${HARNESS_DIR}/run_ffi_shader_audit.sh" --run-dir "${RUN_DIR}"

cat > "${RUN_DIR}/SUMMARY.md" <<EOF
# UI Hardening Audit Bundle

- Toolbar report: [toolbar_audit.md](toolbar_audit.md)
- Scroll report: [scroll_audit.md](scroll_audit.md)
- Layout churn report: [layout_churn_audit.md](layout_churn_audit.md)
- Dead code report: [dead_code_audit.md](dead_code_audit.md)
- Accessibility report: [accessibility_audit.md](accessibility_audit.md)
- Performance report: [perf_audit.md](perf_audit.md)
- FFI / shader report: [ffi_shader_audit.md](ffi_shader_audit.md)
EOF

echo "${RUN_DIR}"
