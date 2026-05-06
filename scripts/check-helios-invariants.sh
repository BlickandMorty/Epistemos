#!/usr/bin/env bash
#
# B5 — HELIOS theorem-invariant smoke gate (skeleton)
#
# Per HELIOS V5 Canon Lock v2 + DOC 0 §0.7:
#   - T1-T17 / E1-E7 / H1-H17 EV theorems: 1/100 sample rate
#   - PCF-1..PCF-10 CANDIDATE theorems: 1/10 sample rate
#   - aggregate ≤ 5 ms cumulative per inference
#
# This skeleton verifies the *wiring* — not the per-invariant
# falsifier output yet. As W1-W26 land, this script grows teeth:
#
#   Stage 0  (this commit) — anchor-table parity + guard-test
#                            presence count; reports counts.
#   W1-W3    — AnswerPacket / ClaimKind / VRM label guards
#              must each appear in EpistemosTests.
#   W6/W7/W8 — Tier-1 ULP-equality smoke must run without
#              regression vs reference path.
#   W23      — forensic-cite tool must resolve every E/H/PCF id
#              to (arXiv, DOI, mathlib4) tuple.
#   W24      — sorry-budget tracker reports E1-E7 ≤ 7 sorry
#              total + per-PCF ≤ 7 sorry.
#   W25      — hardware falsifier rig nightly run posts to
#              ClaimLedger as TypedArtifact.
#
# Exit codes:
#   0  — all gates pass
#   1  — anchor table drift (a doc's hash diverged from DOC 0 §0.7)
#   2  — guard-test count below required threshold (per W-slice)
#   3  — usage error
#
# Run from repo root:
#   ./scripts/check-helios-invariants.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOC_0="${REPO_ROOT}/docs/HELIOS_V5_DOC_0_INDEX.md"

if [ ! -f "${DOC_0}" ]; then
  echo "::error::B5 gate could not locate DOC 0 INDEX at ${DOC_0}"
  exit 3
fi

echo "B5 — HELIOS theorem-invariant smoke (skeleton)"
echo "  repo:   ${REPO_ROOT}"
echo "  doc 0:  ${DOC_0}"

# -- Sub-gate 1: anchor-table parity ------------------------------------------
#
# Re-compute SHA-256 for every doc named in DOC 0 §0.7 and compare against the
# anchor written there. Drift fails the gate.
#
# Anchor table format (markdown row): | `<path>` | `<sha256>` |

echo ""
echo "[1/3] Anchor-table parity check (DOC 0 §0.7)"

drifted=0
checked=0
while IFS= read -r line; do
  # Anchor-table row format (markdown table):
  #   | `<path>` | `<sha256>` |
  # We accept ONLY rows that begin with '|' AND whose second backtick column
  # is exactly 64 lowercase hex chars. That filter excludes the §0.5 reading-
  # list rows (which use **`path`** prose) and the verification command block.
  case "${line}" in
    "|"*) ;;
    *) continue ;;
  esac
  path=$(echo "${line}" | awk -F'`' 'NF>=4 {print $2}')
  expected_sha=$(echo "${line}" | awk -F'`' 'NF>=4 {print $4}')
  if [ -z "${path}" ] || [ -z "${expected_sha}" ]; then
    continue
  fi
  # SHA-256 hex is 64 lowercase chars.
  if ! echo "${expected_sha}" | grep -Eq '^[0-9a-f]{64}$'; then
    continue
  fi
  # Only act on rows that look like "docs/..." paths.
  case "${path}" in
    docs/*) ;;
    *) continue ;;
  esac
  full="${REPO_ROOT}/${path}"
  if [ ! -f "${full}" ]; then
    echo "::warning::anchor-table row references missing file: ${path}"
    drifted=$((drifted + 1))
    continue
  fi
  actual_sha=$(shasum -a 256 "${full}" | awk '{print $1}')
  checked=$((checked + 1))
  if [ "${actual_sha}" != "${expected_sha}" ]; then
    echo "::error::anchor-table drift on ${path}"
    echo "  expected: ${expected_sha}"
    echo "  actual:   ${actual_sha}"
    drifted=$((drifted + 1))
  fi
done < "${DOC_0}"

echo "  checked ${checked} anchor rows; ${drifted} drift(s) detected"
if [ "${drifted}" -gt 0 ]; then
  echo "::error::B5 sub-gate 1 (anchor-table parity) FAILED"
  exit 1
fi

# -- Sub-gate 2: guard-test presence count ------------------------------------
#
# Count source-text guard tests for E/H/PCF invariants. Each invariant gets a
# guard once its W-slice lands. This sub-gate reports the count and warns when
# coverage is below the required threshold per stage.
#
# Required thresholds:
#   Stage 0  — count ≥ 0  (skeleton; no enforcement)
#   Stage 1  — count ≥ 3  (W1 + W2 + W3 minimum)
#   Stage 2  — count ≥ 8  (Tier-1 kernel slices added)
#   etc.

echo ""
echo "[2/3] E/H/PCF source-text guard count"

guard_dir="${REPO_ROOT}/EpistemosTests"
# Suppress set -e for grep-with-no-matches case (exit 1 = "no match", not error).
e_count=0
h_count=0
pcf_count=0
if [ -d "${guard_dir}" ]; then
  e_count=$(grep -rl "// E[1-7] guard\|// HELIOS-E[1-7]" "${guard_dir}" 2>/dev/null | wc -l | tr -d ' ' || true)
  h_count=$(grep -rl "// H[0-9]\+ guard\|// HELIOS-H[0-9]\+" "${guard_dir}" 2>/dev/null | wc -l | tr -d ' ' || true)
  pcf_count=$(grep -rl "// PCF-[0-9]\+ guard\|// HELIOS-PCF-[0-9]\+" "${guard_dir}" 2>/dev/null | wc -l | tr -d ' ' || true)
fi
# Defaults if grep printed nothing.
e_count="${e_count:-0}"
h_count="${h_count:-0}"
pcf_count="${pcf_count:-0}"

echo "  E1-E7  guards: ${e_count}"
echo "  H1-H17 guards: ${h_count}"
echo "  PCF guards:    ${pcf_count}"
echo "  (skeleton phase: no minimum threshold enforced; W1-W26 grow these)"

# -- Sub-gate 3: theorem id surface ------------------------------------------
#
# Confirm DOC 0 + DOC FINALIZE list every E/H/PCF id that's expected at lock.
# Exact set per DOC 0 §0.2: E1-E7, H1-H17, PCF-1..PCF-10.

echo ""
echo "[3/3] Theorem id surface check (DOC 0 §0.2)"

missing=0
for id in E1 E2 E3 E4 E5 E6 E7 \
          H1 H2 H3 H4 H5 H6 H7 H8 H9 H10 H11 H12 H13 H14 H15 H16 H17 \
          PCF-1 PCF-2 PCF-3 PCF-4 PCF-5 PCF-6 PCF-7 PCF-8 PCF-9 PCF-10; do
  if ! grep -q "\*\*${id}\*\*" "${DOC_0}"; then
    echo "::warning::DOC 0 missing canonical id surface for ${id}"
    missing=$((missing + 1))
  fi
done

if [ "${missing}" -gt 0 ]; then
  echo "  ${missing} theorem id(s) not surfaced in DOC 0"
  echo "::warning::B5 sub-gate 3 (theorem id surface) reports gaps"
else
  echo "  all 34 ids surfaced (E1-E7, H1-H17, PCF-1..PCF-10)"
fi

echo ""
echo "B5 (skeleton): PASS"
echo ""
echo "Note: this gate grows teeth as W1-W26 land. Per W-slice, the slice's"
echo "      WRV proof MUST add a source-text guard test referencing the"
echo "      relevant E/H/PCF id with the canonical \`// HELIOS-<id> guard\`"
echo "      comment. CI will then count and enforce per-stage thresholds."
