#!/usr/bin/env bash
# scripts/check-perf-budgets.sh
#
# Wave 2.5 of the Extended Program Plan
# (`docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md`,
#  cross-ref dpp §1.1 Task 0.5).
#
# Parses docs/perf-budgets.toml and asserts every measurable budget:
#
#   [binary]   — measures release Rust dylibs under each crate's
#                target/aarch64-apple-darwin/release/ and fails the
#                build if any dylib exceeds its ceiling.
#                substrate-rt is OPTIONAL — absent dylib is OK
#                (it ships in Wave 5).
#
#   [runtime]  — reads measurement JSON from [meta].runtime_results_path.
#                If absent, prints "no measurement yet" and DOES NOT
#                fail. Wave 2.6 (bench/morning-session.swift) wires
#                the producer; this script is the consumer.
#
#   [appstore] — informational only; the Patch 9 step in CI already
#                enforces it via env EPISTEMOS_APPSTORE_BUNDLE_SIZE_LIMIT_MB.
#                Logged here for one-document budget visibility.
#
#   [keelstone.*] — reads measurement JSON from [meta].keelstone_results_path.
#                If absent, prints "no measurement yet" and does not fail.
#                KEELSTONE_SEED_PERF_REGRESSION=1 writes an over-budget
#                measurement to prove the CI gate fails on regression.
#
# Designed to run from the repo root with no toml dependency. Uses
# awk for TOML parsing — keys live on individual `key = value` lines
# inside `[section]` headers, no nested tables, no inline comments
# stripped from value side (we tolerate trailing comments via awk).
#
# Exit codes:
#   0 — all enforceable budgets pass (runtime gracefully skipped if
#       measurement file is absent)
#   1 — at least one binary budget exceeded OR perf-budgets.toml is
#       malformed
#   2 — runtime measurement file present but malformed / missing keys

set -u
set -o pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUDGETS_TOML="${REPO_ROOT}/docs/perf-budgets.toml"

if [[ ! -f "${BUDGETS_TOML}" ]]; then
    echo "::error::perf-budgets.toml not found at ${BUDGETS_TOML}" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# TOML helpers — single-table, no nesting, no array values needed.
# ---------------------------------------------------------------------------

# Read `key` from `[section]`. Prints the value (sans surrounding quotes)
# or empty string if the key is absent.
toml_get() {
    local section="$1"
    local key="$2"
    awk -v sec="${section}" -v k="${key}" '
        BEGIN { in_section = 0 }
        /^\[/ {
            current = $0
            sub(/^\[/, "", current)
            sub(/\].*$/, "", current)
            in_section = (current == sec)
            next
        }
        in_section == 0 { next }
        /^[[:space:]]*#/ { next }
        /^[[:space:]]*$/ { next }
        {
            line = $0
            # Strip trailing comment (TOML allows # outside strings)
            comment_idx = index(line, "#")
            if (comment_idx > 0) {
                line = substr(line, 1, comment_idx - 1)
            }
            split(line, kv, "=")
            key_text = kv[1]
            val_text = kv[2]
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", key_text)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", val_text)
            if (key_text == k) {
                gsub(/^"|"$/, "", val_text)
                print val_text
                exit
            }
        }
    ' "${BUDGETS_TOML}"
}

json_get_flat() {
    local file="$1"
    local key="$2"
    awk -v k="${key}" '
        {
            gsub(/[{}",]/, " ")
            for (i = 1; i <= NF; i++) {
                if ($i == k ":" || $i == k) {
                    for (j = i + 1; j <= NF; j++) {
                        if ($j != ":" && $j != "") {
                            print $j
                            exit
                        }
                    }
                }
            }
        }
    ' "${file}"
}

# ---------------------------------------------------------------------------
# Binary budgets
# ---------------------------------------------------------------------------

# Map TOML key → (crate-dir, dylib-filename, optional?)
# Optional means absent dylib is OK (substrate-rt ships in Wave 5).
declare -a BINARY_TARGETS=(
    "libagent_core_mb_max     | agent_core      | libagent_core.dylib      | required"
    "libepistemos_core_mb_max | epistemos-core  | libepistemos_core.dylib  | required"
    "libomega_mcp_mb_max      | omega-mcp       | libomega_mcp.dylib       | required"
    "libomega_ax_mb_max       | omega-ax        | libomega_ax.dylib        | required"
    "libsubstrate_rt_mb_max   | substrate-rt    | libsubstrate_rt.dylib    | optional"
)

binary_failures=0
binary_checked=0
binary_skipped=0

echo ""
echo "==> [binary] budgets"
for entry in "${BINARY_TARGETS[@]}"; do
    IFS='|' read -r raw_key raw_crate raw_name raw_required <<< "${entry}"
    key="$(echo "${raw_key}" | xargs)"
    crate="$(echo "${raw_crate}" | xargs)"
    name="$(echo "${raw_name}" | xargs)"
    required="$(echo "${raw_required}" | xargs)"

    budget_mb="$(toml_get binary "${key}")"
    if [[ -z "${budget_mb}" ]]; then
        echo "::error::perf-budgets.toml is missing [binary].${key}" >&2
        binary_failures=$((binary_failures + 1))
        continue
    fi

    dylib="${REPO_ROOT}/${crate}/target/aarch64-apple-darwin/release/${name}"
    if [[ ! -f "${dylib}" ]]; then
        if [[ "${required}" == "optional" ]]; then
            printf "  %-26s  budget %4s MB  — SKIP (optional, %s/release not built)\n" \
                "${name}" "${budget_mb}" "${crate}"
            binary_skipped=$((binary_skipped + 1))
            continue
        fi
        echo "::warning::${dylib} not found — run 'cargo build --release --target aarch64-apple-darwin' in ${crate}" >&2
        binary_skipped=$((binary_skipped + 1))
        continue
    fi

    # Use `du -m` (rounded MiB) to match the Patch 9 bundle-size step semantics.
    actual_mb=$(du -m "${dylib}" | awk '{print $1}')
    binary_checked=$((binary_checked + 1))

    if (( actual_mb > budget_mb )); then
        echo "::error title=Binary budget exceeded::${name}: ${actual_mb} MB > ${budget_mb} MB ([binary].${key} in docs/perf-budgets.toml)"
        binary_failures=$((binary_failures + 1))
    else
        printf "  %-26s  %4d MB ≤ %4s MB  OK\n" "${name}" "${actual_mb}" "${budget_mb}"
    fi
done

# ---------------------------------------------------------------------------
# Runtime budgets (informational unless results file exists)
# ---------------------------------------------------------------------------

runtime_results_path="$(toml_get meta runtime_results_path)"
runtime_results_path="${runtime_results_path:-build/perf-budgets-runtime.json}"
runtime_results_full="${REPO_ROOT}/${runtime_results_path}"

declare -a RUNTIME_KEYS=(
    "cold_start_ms_p99"
    "frame_ms_p99"
    "mcp_invoke_ms_p99"
    "ffi_hot_path_us_p99"
)

echo ""
echo "==> [runtime] budgets"
runtime_failures=0
if [[ ! -f "${runtime_results_full}" ]]; then
    for key in "${RUNTIME_KEYS[@]}"; do
        budget="$(toml_get runtime "${key}")"
        printf "  %-22s  budget %s  — no measurement yet (Wave 2.6 will write %s)\n" \
            "${key}" "${budget}" "${runtime_results_path}"
    done
else
    for key in "${RUNTIME_KEYS[@]}"; do
        budget="$(toml_get runtime "${key}")"
        if [[ -z "${budget}" ]]; then
            echo "::error::perf-budgets.toml is missing [runtime].${key}" >&2
            runtime_failures=$((runtime_failures + 1))
            continue
        fi
        # Naive JSON read: expects flat object {"cold_start_ms_p99": 765.0, ...}
        actual="$(json_get_flat "${runtime_results_full}" "${key}")"

        if [[ -z "${actual}" ]]; then
            echo "::warning::Runtime measurement for ${key} not found in ${runtime_results_path}" >&2
            continue
        fi

        # Use awk for float comparison (bash arithmetic is integer-only).
        cmp=$(awk -v a="${actual}" -v b="${budget}" 'BEGIN { print (a + 0 > b + 0) ? "1" : "0" }')
        if [[ "${cmp}" == "1" ]]; then
            echo "::error title=Runtime budget exceeded::${key}: ${actual} > ${budget} ([runtime].${key} in docs/perf-budgets.toml)"
            runtime_failures=$((runtime_failures + 1))
        else
            printf "  %-22s  %8s ≤ %s  OK\n" "${key}" "${actual}" "${budget}"
        fi
    done
fi

# ---------------------------------------------------------------------------
# KEELSTONE budgets (release-blocking when measurements exist).
# ---------------------------------------------------------------------------

keelstone_results_path="$(toml_get meta keelstone_results_path)"
keelstone_results_path="${keelstone_results_path:-build/perf-budgets-keelstone.json}"
keelstone_results_full="${REPO_ROOT}/${keelstone_results_path}"
keelstone_seeded_path=""

declare -a KEELSTONE_KEYS=(
    "keelstone.launch             | cold_to_interactive_p50_ms       | keelstone_launch_cold_to_interactive_p50_ms       | max"
    "keelstone.launch             | cold_to_interactive_p95_ms       | keelstone_launch_cold_to_interactive_p95_ms       | max"
    "keelstone.launch             | warm_to_interactive_p50_ms       | keelstone_launch_warm_to_interactive_p50_ms       | max"
    "keelstone.editor             | first_open_p50_ms                | keelstone_editor_first_open_p50_ms                | max"
    "keelstone.editor             | first_open_p95_ms                | keelstone_editor_first_open_p95_ms                | max"
    "keelstone.search             | first_search_ready_p50_ms        | keelstone_search_first_search_ready_p50_ms        | max"
    "keelstone.search             | first_search_ready_p95_ms        | keelstone_search_first_search_ready_p95_ms        | max"
    "keelstone.reconcile          | after_1000_changes_max_ms        | keelstone_reconcile_after_1000_changes_max_ms     | max"
    "keelstone.reconcile          | main_thread_fs_ops               | keelstone_reconcile_main_thread_fs_ops            | max"
    "keelstone.memory             | idle_resident_mb_max             | keelstone_memory_idle_resident_mb                 | max"
    "keelstone.thermal            | no_escalation_under_soak_minutes | keelstone_thermal_no_escalation_under_soak_minutes | min"
    "keelstone.enterprise.budgets | cold_to_interactive_p95_ms       | keelstone_enterprise_cold_to_interactive_p95_ms   | max"
    "keelstone.enterprise.budgets | first_search_ready_p95_ms        | keelstone_enterprise_first_search_ready_p95_ms    | max"
    "keelstone.enterprise.budgets | reconcile_20k_change_burst_max_ms | keelstone_enterprise_reconcile_20k_change_burst_ms | max"
    "keelstone.enterprise.budgets | idle_resident_mb_max             | keelstone_enterprise_idle_resident_mb             | max"
    "keelstone.enterprise.budgets | wal_file_mb_max                  | keelstone_enterprise_wal_file_mb                  | max"
)

echo ""
echo "==> [keelstone.*] budgets"
keelstone_failures=0
keelstone_missing=0
keelstone_checked=0

if [[ "${KEELSTONE_SEED_PERF_REGRESSION:-0}" == "1" ]]; then
    keelstone_seeded_path="$(mktemp "${TMPDIR:-/tmp}/keelstone-perf-regression.XXXXXX.json")"
    cat >"${keelstone_seeded_path}" <<'JSON'
{
  "keelstone_launch_cold_to_interactive_p50_ms": 999999,
  "keelstone_launch_cold_to_interactive_p95_ms": 999999,
  "keelstone_launch_warm_to_interactive_p50_ms": 999999,
  "keelstone_editor_first_open_p50_ms": 999999,
  "keelstone_editor_first_open_p95_ms": 999999,
  "keelstone_search_first_search_ready_p50_ms": 999999,
  "keelstone_search_first_search_ready_p95_ms": 999999,
  "keelstone_reconcile_after_1000_changes_max_ms": 999999,
  "keelstone_reconcile_main_thread_fs_ops": 1,
  "keelstone_memory_idle_resident_mb": 999999,
  "keelstone_thermal_no_escalation_under_soak_minutes": 0,
  "keelstone_enterprise_cold_to_interactive_p95_ms": 999999,
  "keelstone_enterprise_first_search_ready_p95_ms": 999999,
  "keelstone_enterprise_reconcile_20k_change_burst_ms": 999999,
  "keelstone_enterprise_idle_resident_mb": 999999,
  "keelstone_enterprise_wal_file_mb": 999999
}
JSON
    keelstone_results_full="${keelstone_seeded_path}"
fi

if [[ ! -f "${keelstone_results_full}" ]]; then
    for entry in "${KEELSTONE_KEYS[@]}"; do
        IFS='|' read -r raw_section raw_key _raw_metric _raw_direction <<< "${entry}"
        section="$(echo "${raw_section}" | xargs)"
        key="$(echo "${raw_key}" | xargs)"
        budget="$(toml_get "${section}" "${key}")"
        printf "  %-48s  budget %s  — no measurement yet (%s)\n" \
            "${section}.${key}" "${budget}" "${keelstone_results_path}"
    done
else
    for entry in "${KEELSTONE_KEYS[@]}"; do
        IFS='|' read -r raw_section raw_key raw_metric raw_direction <<< "${entry}"
        section="$(echo "${raw_section}" | xargs)"
        key="$(echo "${raw_key}" | xargs)"
        metric="$(echo "${raw_metric}" | xargs)"
        direction="$(echo "${raw_direction}" | xargs)"

        budget="$(toml_get "${section}" "${key}")"
        if [[ -z "${budget}" ]]; then
            echo "::error::perf-budgets.toml is missing [${section}].${key}" >&2
            keelstone_failures=$((keelstone_failures + 1))
            continue
        fi

        actual="$(json_get_flat "${keelstone_results_full}" "${metric}")"
        if [[ -z "${actual}" ]]; then
            echo "::error::KEELSTONE measurement ${metric} not found in ${keelstone_results_path}" >&2
            keelstone_missing=$((keelstone_missing + 1))
            continue
        fi

        keelstone_checked=$((keelstone_checked + 1))
        if [[ "${direction}" == "min" ]]; then
            cmp="$(awk -v a="${actual}" -v b="${budget}" 'BEGIN { print (a + 0 < b + 0) ? "1" : "0" }')"
            symbol="≥"
        else
            cmp="$(awk -v a="${actual}" -v b="${budget}" 'BEGIN { print (a + 0 > b + 0) ? "1" : "0" }')"
            symbol="≤"
        fi

        if [[ "${cmp}" == "1" ]]; then
            echo "::error title=KEELSTONE perf budget exceeded::${metric}: ${actual} violates ${symbol} ${budget} ([${section}].${key} in docs/perf-budgets.toml)"
            keelstone_failures=$((keelstone_failures + 1))
        else
            printf "  %-48s  %8s %s %s  OK\n" "${metric}" "${actual}" "${symbol}" "${budget}"
        fi
    done
fi

if [[ -n "${keelstone_seeded_path}" ]]; then
    rm -f "${keelstone_seeded_path}"
fi

# ---------------------------------------------------------------------------
# App Store bundle (informational; Patch 9 already enforces in CI).
# ---------------------------------------------------------------------------

appstore_budget="$(toml_get appstore appstore_bundle_mb_max)"
echo ""
echo "==> [appstore] budgets"
printf "  %-26s  budget %s MB  — enforced separately by the Patch 9 step\n" \
    "appstore_bundle_mb_max" "${appstore_budget}"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo ""
echo "==> summary"
echo "  binary:  ${binary_checked} checked, ${binary_skipped} skipped, ${binary_failures} failed"
echo "  runtime: $([ -f "${runtime_results_full}" ] && echo "measured" || echo "no measurement file")"
echo "  keelstone: ${keelstone_checked} checked, ${keelstone_missing} missing, ${keelstone_failures} failed"

if (( binary_failures > 0 )); then
    exit 1
fi
if (( runtime_failures > 0 )); then
    exit 2
fi
if (( keelstone_missing > 0 )); then
    exit 2
fi
if (( keelstone_failures > 0 )); then
    exit 1
fi
exit 0
