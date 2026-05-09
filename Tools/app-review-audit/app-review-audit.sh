#!/usr/bin/env bash
#
# HELIOS V5 W26 — App Review §2.5.2 compliance audit.
#
# HELIOS-W26 guard
#
# Per docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md §3 W26 +
# docs/fusion/helios v5 updated.md PART 7:
#
#   "tools/app-review-audit/ — per-release: enumerate every bundled
#    artifact; assert no runtime download path; assert all Tier-2
#    toggles default OFF."
#
# Apple App Review §2.5.2 verbatim (Q1-2026):
#
#   "Apps should be self-contained in their bundles, and may not
#    read or write data outside the designated container area, nor
#    may they download, install, or execute code which introduces
#    or changes features or functionality of the app, including
#    other apps."
#
# Audit checks:
#   1. Resources/ directory enumeration — every artifact named.
#   2. No runtime URLSession-download patterns into executable
#      code paths (model GGUFs / Metal kernels).
#   3. HELIOS V5 runtime toggles remain absent for the v1 freeze.
#   4. For App Store/MAS, no `Process()` / `Process.init()` / `Pipe()` /
#      `system()` calls in MAS-visible Swift source.
#
# Exit codes:
#   0 — audit clean
#   1 — at least one finding (CI fails)
#   2 — usage error
#
# Usage:
#   ./app-review-audit.sh            Run App Store checks
#   ./app-review-audit.sh appstore   Run App Store checks
#   ./app-review-audit.sh pro        Run Pro/direct checks with subprocess notices
#   ./app-review-audit.sh --list     Print bundled artifacts only

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RES_DIR="${REPO_ROOT}/Epistemos/Resources"
target="${1:-appstore}"

case "${target}" in
  --help|-h)
    cat <<USAGE
HELIOS V5 W26 — App Review §2.5.2 compliance audit.

Usage:
  app-review-audit.sh            App Store audit (default; 4 checks).
  app-review-audit.sh appstore   App Store audit (fails MAS-visible subprocess surfaces).
  app-review-audit.sh pro        Pro/direct audit (reports subprocess surfaces as notices).
  app-review-audit.sh --list     List bundled artifacts only.
USAGE
    exit 0
    ;;
  --list)
    if [ -d "${RES_DIR}" ]; then
      find "${RES_DIR}" -type f | sort
    fi
    exit 0
    ;;
  appstore|mas|pro|direct)
    ;;
  *)
    echo "::error::usage: app-review-audit.sh [appstore|mas|pro|direct|--list]" >&2
    exit 2
    ;;
esac

findings=0

mas_visible_swift_source() {
  local file
  find "${REPO_ROOT}/Epistemos" -type f -name '*.swift' -print0 |
    while IFS= read -r -d '' file; do
      awk -v file="${file}" '
        function trim_line(value) {
          sub(/^[ \t]+/, "", value)
          return value
        }
        function push(skip_current) {
          depth += 1
          parent_skip[depth] = current_skip
          skip[depth] = skip_current
          if (current_skip || skip_current) {
            current_skip = 1
          } else {
            current_skip = 0
          }
        }
        function pop() {
          if (depth <= 0) {
            current_skip = 0
            return
          }
          current_skip = parent_skip[depth]
          delete parent_skip[depth]
          delete skip[depth]
          depth -= 1
        }
        {
          line = $0
          trimmed = trim_line(line)
          if (trimmed ~ /^#if[ \t]+!EPISTEMOS_APP_STORE/ ||
              trimmed ~ /^#if[ \t]+!MAS_SANDBOX/ ||
              trimmed ~ /^#if[ \t]+!\(EPISTEMOS_APP_STORE[ \t]*\|\|[ \t]*MAS_SANDBOX\)/) {
            push(1)
            next
          }
          if (trimmed ~ /^#if[ \t]+/) {
            push(0)
            next
          }
          if (trimmed ~ /^#else/) {
            if (depth > 0 && parent_skip[depth] == 0 && skip[depth] == 1) {
              skip[depth] = 0
              current_skip = 0
            }
            next
          }
          if (trimmed ~ /^#endif/) {
            pop()
            next
          }
          if (!current_skip && trimmed !~ /^\/\//) {
            print file ":" FNR ":" line
          }
        }
      ' "${file}"
    done
}

# Check 1: enumerate bundled artifacts under Resources/
echo "[1/4] Bundled-artifact enumeration"
if [ ! -d "${RES_DIR}" ]; then
  echo "  (no Resources/ directory yet)"
else
  count=$(find "${RES_DIR}" -type f | wc -l | tr -d ' ')
  echo "  ${count} bundled artifact(s) under Epistemos/Resources/"
fi

# Check 2: no runtime download patterns for executable code
echo ""
echo "[2/4] Runtime executable-code download paths"
download_patterns=(
  "URLSession.*download.*\.gguf"
  "URLSession.*download.*\.metallib"
  "URLSession.*download.*\.dylib"
  "URLSession.*download.*\.bundle"
)
for pat in "${download_patterns[@]}"; do
  hits=$(grep -rEn "${pat}" "${REPO_ROOT}/Epistemos" --include='*.swift' 2>/dev/null || true)
  if [ -n "${hits}" ]; then
    echo "::error::W26 §2.5.2 finding — runtime download of executable artifact:"
    echo "${hits}"
    findings=$((findings + 1))
  fi
done
if [ "${findings}" -eq 0 ]; then
  echo "  no runtime executable-code download patterns detected"
fi

# Check 3: HELIOS V5 runtime toggles remain absent for the v1 freeze
echo ""
echo "[3/4] HELIOS V5 v1 runtime toggle freeze"
helios_toggle_hits=$(grep -rEn '@AppStorage\("epistemos\.helios\.v5' "${REPO_ROOT}/Epistemos" --include='*.swift' 2>/dev/null || true)
if [ -n "${helios_toggle_hits}" ]; then
  echo "::error::W26 §2.5.2 finding — HELIOS v1 freeze forbids runtime AppStorage toggles:"
  echo "${helios_toggle_hits}"
  findings=$((findings + 1))
else
  echo "  no HELIOS V5 runtime AppStorage toggles detected"
fi

# Check 4: no Process()/Pipe()/system() calls outside Pro-build gate
echo ""
echo "[4/4] Subprocess / shell-execution surface (${target})"
forbidden_subprocess_patterns=(
  "(^|[^A-Za-z0-9_])Process\("
  "Process\.init\("
  "(^|[^A-Za-z0-9_])Pipe\("
  "(^|[^A-Za-z0-9_])system\(\""
  "(^|[^A-Za-z0-9_])popen\("
  "posix_spawn"
  "NSTask"
)
mas_subprocess_findings=0
for pat in "${forbidden_subprocess_patterns[@]}"; do
  if [[ "${target}" == "appstore" || "${target}" == "mas" ]]; then
    hits=$(mas_visible_swift_source | grep -E "${pat}" || true)
  else
    hits=$(grep -rEn "${pat}" "${REPO_ROOT}/Epistemos" --include='*.swift' 2>/dev/null || true)
  fi
  if [ -n "${hits}" ]; then
    if [[ "${target}" == "appstore" || "${target}" == "mas" ]]; then
      echo "::error::W26 §2.5.2 finding — MAS-reachable subprocess surface detected:"
      findings=$((findings + 1))
    else
      echo "::notice::W26 Pro/direct subprocess surface detected:"
    fi
    echo "${hits}" | head -5
    mas_subprocess_findings=$((mas_subprocess_findings + 1))
  fi
done
if [ "${mas_subprocess_findings}" -eq 0 ]; then
  echo "  no subprocess launch surface detected for target ${target}"
else
  echo "  ${mas_subprocess_findings} subprocess pattern(s) detected for target ${target}"
fi

echo ""
if [ "${findings}" -gt 0 ]; then
  echo "::error::W26 §2.5.2 audit FAILED with ${findings} finding(s)"
  exit 1
fi
echo "W26 §2.5.2 audit: PASS"
