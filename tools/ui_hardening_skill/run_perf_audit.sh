#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

run_dir=""
if [[ "${1:-}" == "--run-dir" ]]; then
  run_dir="$2"
fi
run_dir="${run_dir:-$(new_run_dir "ui-hardening")}"
report="${run_dir}/perf_audit.md"

cat > "${report}" <<'EOF'
# Performance Audit
EOF

capture_rg "${report}" "Built-in perf instrumentation" \
  "Log\\.appPerf|Log\\.notesPerf|beginInterval|endInterval|TimelineView|Canvas|rendersAsynchronously" \
  "${ROOT}/Epistemos"

swift_build "${report}" "Build for profiler and perf smoke"

if [[ "${UI_HARDENING_SKIP_PROFILE:-0}" == "1" ]]; then
  section "${report}" "xctrace profile"
  note "${report}" "Skipped because \`UI_HARDENING_SKIP_PROFILE=1\`."
else
  app_path="${DERIVED_DATA_PATH}/Build/Products/Debug/Epistemos.app"
  if [[ -x "${app_path}/Contents/MacOS/Epistemos" ]]; then
    capture_cmd \
      "${report}" \
      "Time Profiler / Leaks capture" \
      "${ROOT}/scripts/profile_app_with_xctrace.sh" \
      "${app_path}" \
      10 \
      "${PROFILE_ROOT}/$(timestamp)-ui-hardening"
  else
    section "${report}" "xctrace profile"
    note "${report}" "Skipped because the built app was not found at \`${app_path}\`."
  fi
fi

echo "${run_dir}"
