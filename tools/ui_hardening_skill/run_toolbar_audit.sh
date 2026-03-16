#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

run_dir=""
if [[ "${1:-}" == "--print-run-dir" ]]; then
  new_run_dir "ui-hardening"
  exit 0
fi
if [[ "${1:-}" == "--run-dir" ]]; then
  run_dir="$2"
fi
run_dir="${run_dir:-$(new_run_dir "ui-hardening")}"
report="${run_dir}/toolbar_audit.md"

cat > "${report}" <<'EOF'
# Toolbar Audit
EOF

capture_rg "${report}" "Toolbar dynamics map" \
  "ToolbarMorphHost|ToolbarMorphSurface|ExpandingModeButton|AnchoredPopoverButton|toolbarMorphItem|toolbarMorphInteractionSync|TimelineView|Canvas|GeometryReader|PreferenceKey" \
  "${ROOT}/Epistemos/App" \
  "${ROOT}/Epistemos/Theme" \
  "${ROOT}/Epistemos/Views"

capture_rg "${report}" "Legacy toolbar and glass paths" \
  "ToolbarGlass|themedGlassToolbar|applyThemedGlassToolbar|updateGlassToolbarTheme|NativeToolbarToggle" \
  "${ROOT}/Epistemos/Theme" \
  "${ROOT}/Epistemos/Views" \
  "${ROOT}/EpistemosTests"

capture_rg "${report}" "Window chrome and titlebar hooks" \
  "NSToolbar|toolbarStyle|titlebarAppearsTransparent|titleVisibility|titlebarAccessoryViewControllers" \
  "${ROOT}/Epistemos/App" \
  "${ROOT}/Epistemos/Views"

echo "${run_dir}"
