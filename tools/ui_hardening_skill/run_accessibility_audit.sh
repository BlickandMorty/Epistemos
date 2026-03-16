#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

run_dir=""
if [[ "${1:-}" == "--run-dir" ]]; then
  run_dir="$2"
fi
run_dir="${run_dir:-$(new_run_dir "ui-hardening")}"
report="${run_dir}/accessibility_audit.md"

cat > "${report}" <<'EOF'
# Accessibility Audit
EOF

capture_rg "${report}" "Accessibility hooks" \
  "accessibility|reduceMotion|Reduce Motion|Reduce Transparency|colorSchemeContrast|accessibilityLabel|accessibilityHint" \
  "${ROOT}/Epistemos/App" \
  "${ROOT}/Epistemos/Theme" \
  "${ROOT}/Epistemos/Views"

echo "${run_dir}"
