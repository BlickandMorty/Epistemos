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
report="${run_dir}/scroll_audit.md"

cat > "${report}" <<'EOF'
# Scroll Audit
EOF

capture_rg "${report}" "Main, mini, and note scroll paths" \
  "ScrollViewReader|ScrollView\\(|NSScrollView|scrollTo\\(|scrollRangeToVisible|boundsDidChangeNotification|reflectScrolledClipView" \
  "${ROOT}/Epistemos/Views/Chat" \
  "${ROOT}/Epistemos/Views/MiniChat" \
  "${ROOT}/Epistemos/Views/Notes"

capture_rg "${report}" "Geometry and preference-key churn in scrollable UI" \
  "GeometryReader|PreferenceKey|onPreferenceChange|TimelineView|animation\\(|withAnimation" \
  "${ROOT}/Epistemos/Views/Chat" \
  "${ROOT}/Epistemos/Views/MiniChat" \
  "${ROOT}/Epistemos/Views/Notes"

capture_rg "${report}" "Scroll-anchor and auto-follow policy sites" \
  "scrollTo\\(|scrollRangeToVisible|selectedRange\\(|scrollY|contentView\\.scroll\\(|documentVisibleRect" \
  "${ROOT}/Epistemos/Views/Chat/ChatView.swift" \
  "${ROOT}/Epistemos/Views/MiniChat/MiniChatView.swift" \
  "${ROOT}/Epistemos/Views/Notes/NoteChatSidebar.swift" \
  "${ROOT}/Epistemos/Views/Notes/ProseEditorRepresentable.swift" \
  "${ROOT}/Epistemos/Views/Notes/ProseEditorRepresentable2.swift"

swift_test "${report}" "Scroll stability regression tests" "EpistemosTests/ScrollStabilityTests"

echo "${run_dir}"
