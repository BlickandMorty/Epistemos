#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

run_dir=""
if [[ "${1:-}" == "--run-dir" ]]; then
  run_dir="$2"
fi
run_dir="${run_dir:-$(new_run_dir "ui-hardening")}"
report="${run_dir}/layout_churn_audit.md"

cat > "${report}" <<'EOF'
# Layout Churn Audit
EOF

capture_rg "${report}" "Potential layout churn sources" \
  "GeometryReader|PreferenceKey|onPreferenceChange|frameDidChangeNotification|boundsDidChangeNotification|updateCenteringInsets|refresh\\(|TimelineView|Canvas" \
  "${ROOT}/Epistemos/Theme" \
  "${ROOT}/Epistemos/Views"

capture_rg "${report}" "Overlay refresh paths in notes" \
  "refresh\\(|refreshForScroll|refreshAfterTextChange|RenderedTableOverlayManager|TransclusionOverlayManager" \
  "${ROOT}/Epistemos/Views/Notes"

echo "${run_dir}"
