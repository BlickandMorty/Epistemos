#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

run_dir=""
if [[ "${1:-}" == "--run-dir" ]]; then
  run_dir="$2"
fi
run_dir="${run_dir:-$(new_run_dir "ui-hardening")}"
report="${run_dir}/dead_code_audit.md"

cat > "${report}" <<'EOF'
# Dead Code Audit
EOF

capture_rg "${report}" "Candidate dead UI paths" \
  "NativeToolbarToggle|themedGlassToolbar|applyThemedGlassToolbar|WindowAccessor|showChatSidebar.toggle\\(|Long-Form Editor \\(Beta\\)" \
  "${ROOT}/Epistemos/Theme" \
  "${ROOT}/Epistemos/Views" \
  "${ROOT}/Epistemos/App"

capture_rg "${report}" "Legacy editor split and transitional adapters" \
  "useTK2Editor|ProseEditorRepresentable2|PageStoragePool|TransclusionOverlayManager2|RenderedTableOverlayManager2" \
  "${ROOT}/Epistemos/Views/Notes" \
  "${ROOT}/Epistemos/State" \
  "${ROOT}/EpistemosTests"

echo "${run_dir}"
