#!/usr/bin/env bash
#
# HELIOS V5 W24 — Lean sorry-budget tracker.
#
# HELIOS-W24 guard
#
# Per docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md §3 W24 +
# docs/fusion/helios v5 first.md PART 2 Q4:
#
#   "Sorry-budget locked at <= 7 for T1-T7 at canon-promotion. T8-T17
#    may carry larger sorry-budgets in Lane 3."
#
# Per v5.2 namespace hardening:
#   E1-E7 EV theorems: sorry budget <= 2 each (foundational)
#   H1-H10 architectural claims: sorry budget <= 4 each
#   H11-H17 cross-tradition: sorry budget <= 7 each
#   PCF-1..PCF-10 candidates: sorry budget <= 7 each
#   Primitive-IR schema modules: sorry budget = 0 each
#
# Portable: avoids bash 4+ `declare -A` (macOS ships bash 3.2).
#
# Exit codes:
#   0 — within budget OR no Lean repo yet (graceful skip)
#   1 — over budget (CI failure)
#   2 — usage error
#
# Usage:
#   ./sorry-budget.sh           Run check against ../../lean/Epistemos/
#   ./sorry-budget.sh --report  Print per-theorem counts even when within budget

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# Lake convention: lean/<package>/<package>/<module>.lean — the
# inner Epistemos/ directory holds per-theorem .lean files. Per
# `lean/Epistemos/README.md` Layout section.
LEAN_DIR="${REPO_ROOT}/lean/Epistemos/Epistemos"

if [ ! -d "${LEAN_DIR}" ]; then
  echo "W24 sorry-budget tracker: lean/Epistemos/ not present yet"
  echo "  (Lean repo creation deferred per v2 plan §6 candidate item)"
  echo "  graceful skip — exit 0"
  exit 0
fi

REPORT_MODE=0
if [ "${1:-}" = "--report" ]; then
  REPORT_MODE=1
fi

# Per-id budget table: id|budget
# Budgets per docs/HELIOS_V5_DOC_6_THEOREM_CANON.md §1.
BUDGETS=$(cat <<'BUDGET_BODY'
E1|2
E2|2
E3|1
E4|2
E5|2
E6|1
E7|2
H1|4
H2|4
H3|4
H4|4
H5|4
H6|4
H7|4
H8|4
H9|4
H10|4
H11|7
H12|7
H13|7
H14|7
H15|7
H16|7
H17|7
PCF-1|7
PCF-2|7
PCF-3|7
PCF-4|7
PCF-5|7
PCF-6|7
PCF-7|7
PCF-8|7
PCF-9|7
PCF-10|7
BUDGET_BODY
)

total_over_budget=0
total_sorries=0
while IFS='|' read -r id budget; do
  [ -z "${id}" ] && continue
  # Translate canonical id (e.g. PCF-1) to a Lean-compatible
  # filename (PCF_1.lean). Lean module names cannot contain hyphens
  # — Lake's auto-discovery would reject `PCF-1.lean` as an
  # invalid module identifier. The canonical id stays hyphenated
  # per DOC 6; only the file path uses underscores.
  fname=$(echo "${id}" | tr '-' '_')
  file="${LEAN_DIR}/${fname}.lean"
  if [ ! -f "${file}" ]; then
    if [ "${REPORT_MODE}" -eq 1 ]; then
      echo "  ${id}: file not present yet (budget ${budget})"
    fi
    continue
  fi
  # awk always exits 0 + emits exactly one integer; avoids the
  # grep-c-+-pipefail SIGPIPE trap that ate report rows for files
  # with zero sorries (E3).
  count=$(awk '/^[[:space:]]*sorry[[:space:]]*(--.*)?$/{n++} END{print n+0}' "${file}")
  count="${count:-0}"
  total_sorries=$((total_sorries + count))
  if [ "${count}" -gt "${budget}" ]; then
    echo "::error file=${file}::W24 sorry-budget OVER for ${id}: ${count} > ${budget}"
    total_over_budget=$((total_over_budget + 1))
  elif [ "${REPORT_MODE}" -eq 1 ]; then
    echo "  ${id}: ${count}/${budget} sorries"
  fi
done <<< "${BUDGETS}"

# Lean-first T5 Primitive IR schema modules. These files are schema
# authority surfaces, so newly introduced `sorry` placeholders must be
# explicit budget failures instead of silently sitting outside W24's
# original E/H/PCF theorem-id table.
SCHEMA_MODULES=$(cat <<'SCHEMA_BODY'
EML
Tropical
Scan
Operator
Info
Geometry
SCHEMA_BODY
)

while IFS= read -r module; do
  [ -z "${module}" ] && continue
  file="${LEAN_DIR}/${module}.lean"
  if [ ! -f "${file}" ]; then
    if [ "${REPORT_MODE}" -eq 1 ]; then
      echo "  Primitive-IR schema ${module}: file not present yet (budget 0)"
    fi
    continue
  fi
  count=$(awk '/^[[:space:]]*sorry[[:space:]]*(--.*)?$/{n++} END{print n+0}' "${file}")
  count="${count:-0}"
  total_sorries=$((total_sorries + count))
  if [ "${count}" -gt 0 ]; then
    echo "::error file=${file}::Primitive-IR schema sorry-budget OVER for ${module}: ${count} > 0"
    total_over_budget=$((total_over_budget + 1))
  elif [ "${REPORT_MODE}" -eq 1 ]; then
    echo "  Primitive-IR schema ${module}: ${count}/0 sorries"
  fi
done <<< "${SCHEMA_MODULES}"

# Lean theorem stubs are no longer allowed to discharge an obligation
# by targeting `True`; each theorem must expose at least a schema
# witness, constant, status flag, or hypothesis-carrying shape.
TRUE_PLACEHOLDER_REPORT=$(find "${LEAN_DIR}" -maxdepth 1 -name '*.lean' -type f -exec awk '
  /^[[:space:]]*theorem[[:space:]][^:]+:[[:space:]]*True[[:space:]]*:=/ {
    printf "%s:%d:%s\n", FILENAME, FNR, $0
  }
' {} +)

if [ -n "${TRUE_PLACEHOLDER_REPORT}" ]; then
  true_placeholder_count=$(printf "%s\n" "${TRUE_PLACEHOLDER_REPORT}" | awk 'NF{n++} END{print n+0}')
  printf "%s\n" "${TRUE_PLACEHOLDER_REPORT}" |
    while IFS= read -r line; do
      [ -z "${line}" ] && continue
      file=${line%%:*}
      rest=${line#*:}
      line_no=${rest%%:*}
      echo "::error file=${file},line=${line_no}::Lean theorem targets True; sharpen the obligation"
    done
  total_over_budget=$((total_over_budget + true_placeholder_count))
elif [ "${REPORT_MODE}" -eq 1 ]; then
  echo "  Lean theorem True placeholders: 0/0"
fi

if [ "${total_over_budget}" -gt 0 ]; then
  echo "::error::W24 sorry-budget OVER on ${total_over_budget} theorem(s); ${total_sorries} total sorries"
  exit 1
fi

echo "W24 sorry-budget: PASS (${total_sorries} total sorries across all ids)"
