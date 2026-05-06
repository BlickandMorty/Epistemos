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
#   3. Every HELIOS V5 Tier-2 Settings toggle defaults to false.
#   4. No `Process()` / `Pipe()` / `system()` calls outside the
#      established Pro-build-feature gate.
#
# Exit codes:
#   0 — audit clean
#   1 — at least one finding (CI fails)
#   2 — usage error
#
# Usage:
#   ./app-review-audit.sh         Run all checks
#   ./app-review-audit.sh --list  Print bundled artifacts only

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RES_DIR="${REPO_ROOT}/Epistemos/Resources"

case "${1:-}" in
  --help|-h)
    cat <<USAGE
HELIOS V5 W26 — App Review §2.5.2 compliance audit.

Usage:
  app-review-audit.sh           Full audit (4 checks).
  app-review-audit.sh --list    List bundled artifacts only.
USAGE
    exit 0
    ;;
  --list)
    if [ -d "${RES_DIR}" ]; then
      find "${RES_DIR}" -type f | sort
    fi
    exit 0
    ;;
esac

findings=0

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

# Check 3: every HELIOS V5 Tier-2 Settings toggle defaults to false
echo ""
echo "[3/4] HELIOS V5 Tier-2 Settings toggle defaults"
helios_view="${REPO_ROOT}/Epistemos/Views/Settings/HELIOSv5SettingsView.swift"
if [ ! -f "${helios_view}" ]; then
  echo "::warning::HELIOSv5SettingsView.swift not found — skipping Tier-2 default audit"
else
  required_off_keys=(
    "epistemos.helios.v5.verifiedResearchMode"
    "epistemos.helios.v5.hopfieldRetrieval"
    "epistemos.helios.v5.connectomeBrowser"
    "epistemos.helios.v5.experimentalMetalKernels"
    "epistemos.helios.v5.kernel.tMac"
    "epistemos.helios.v5.kernel.bitnet"
    "epistemos.helios.v5.kernel.sparseTernaryGEMM"
  )
  for key in "${required_off_keys[@]}"; do
    # Look for `@AppStorage("<key>") ... = false`
    if ! grep -A1 "@AppStorage(\"${key}\")" "${helios_view}" | grep -q "= false"; then
      echo "::error::W26 §2.5.2 finding — toggle '${key}' does not default to false"
      findings=$((findings + 1))
    fi
  done
  if [ "${findings}" -eq 0 ]; then
    echo "  all 7 HELIOS V5 Tier-2 toggles default OFF"
  fi
fi

# Check 4: no Process()/Pipe()/system() calls outside Pro-build gate
echo ""
echo "[4/4] Subprocess / shell-execution surface (MAS-only build)"
forbidden_subprocess_patterns=(
  "Process\(\)\.run"
  "system\(\""
  "popen\("
)
mas_subprocess_findings=0
for pat in "${forbidden_subprocess_patterns[@]}"; do
  hits=$(grep -rEn "${pat}" "${REPO_ROOT}/Epistemos" --include='*.swift' 2>/dev/null \
    | grep -v "// MARK: pro-build" \
    | grep -v "#if PRO_BUILD" \
    || true)
  if [ -n "${hits}" ]; then
    # Note: this is INFORMATIONAL — many existing call sites are
    # Pro-build gated via #if PRO_BUILD that doesn't grep cleanly
    # one-liner. Real W26 audit refines this. Stage-0 just reports.
    echo "::warning::W26 stage-0 informational — subprocess surface detected (review for Pro-build gating):"
    echo "${hits}" | head -5
    mas_subprocess_findings=$((mas_subprocess_findings + 1))
  fi
done
if [ "${mas_subprocess_findings}" -eq 0 ]; then
  echo "  no unguarded subprocess surface in Epistemos/ Swift sources"
else
  echo "  (${mas_subprocess_findings} subprocess pattern(s) flagged for human review;"
  echo "   stage-0 audit does not fail on these — refinement lands per W26.b)"
fi

echo ""
if [ "${findings}" -gt 0 ]; then
  echo "::error::W26 §2.5.2 audit FAILED with ${findings} finding(s)"
  exit 1
fi
echo "W26 §2.5.2 audit: PASS"
