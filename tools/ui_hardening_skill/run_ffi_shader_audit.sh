#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

run_dir=""
if [[ "${1:-}" == "--run-dir" ]]; then
  run_dir="$2"
fi
run_dir="${run_dir:-$(new_run_dir "ui-hardening")}"
report="${run_dir}/ffi_shader_audit.md"

cat > "${report}" <<'EOF'
# FFI / Shader Audit
EOF

capture_rg "${report}" "FFI bridge and shader surfaces" \
  "graph_engine|FFI|ffi|shader|uniform|Metal|Toolbar|overlay" \
  "${ROOT}/graph-engine/src" \
  "${ROOT}/graph-engine-bridge" \
  "${ROOT}/Epistemos/Graph" \
  "${ROOT}/Epistemos/Theme"

capture_cmd "${report}" "Rust renderer tests" cargo test --manifest-path "${ROOT}/graph-engine/Cargo.toml" renderer

echo "${run_dir}"
