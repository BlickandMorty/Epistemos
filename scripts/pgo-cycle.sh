#!/usr/bin/env bash
# scripts/pgo-cycle.sh
#
# Wave 6.1 of the Extended Program Plan
# (`docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md` Wave 6.1,
#  cross-ref dpp §6.1-6.2 Sprint 5).
#
# Drives one full cargo-pgo cycle for the largest Rust dylib (agent_core)
# per the canonical research finding:
#
#   1. cargo-pgo 0.2.x is the canonical 2026 PGO frontend.
#   2. The Rust dylib must be built INSTRUMENTED, then loaded by the
#      Swift host doing real work — `cargo bench` profiles record
#      synthetic paths, not what the user actually triggers.
#   3. CRITICAL Apple ld64 trap: do NOT combine cargo-pgo with
#      lto = "fat". The Apple ld64 LTO pass discards the
#      `__llvm_prf_*` sections silently. Use lto = "thin" for the
#      PGO profile only (the canonical release profile per Wave 2.4
#      stays lto = "fat" for non-PGO builds).
#      Reference: rust-lang/rust#119016.
#   4. Bench coverage minimum: 3 distinct workloads (idle scroll,
#      agent turn, graph layout) totalling 5+ minutes. Fewer over-fits
#      to the dominant path and regresses cold paths.
#
# Designed to be invoked manually during a PGO sweep, NOT in CI (the
# instrumentation cycle takes ~20 minutes wall-clock and produces
# multi-GB profile data).
#
# Usage:
#   ./scripts/pgo-cycle.sh                    # full instrument → run → optimize
#   ./scripts/pgo-cycle.sh instrument         # just the instrumented build
#   ./scripts/pgo-cycle.sh optimize           # just the optimized build (uses
#                                              # already-collected profiles)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CRATE="agent_core"
PROFILE="release-pgo"
TARGET="aarch64-apple-darwin"

step="${1:-all}"

ensure_cargo_pgo() {
    if ! command -v cargo-pgo >/dev/null 2>&1; then
        echo "==> installing cargo-pgo (one-time)"
        cargo install cargo-pgo
    fi
}

instrumented_build() {
    echo "==> building ${CRATE} INSTRUMENTED (release-pgo profile, lto=thin)"
    cd "${REPO_ROOT}/${CRATE}"
    # cargo-pgo expects a separate profile so its instrumented build
    # doesn't collide with the canonical release profile (which uses
    # lto = "fat" — incompatible with PGO per the Apple ld64 trap).
    cargo pgo instrument build --release --target "${TARGET}"
    echo "==> instrumented dylib at:"
    find "${REPO_ROOT}/${CRATE}/target/${TARGET}" -name "lib${CRATE}*.dylib" 2>/dev/null
}

run_workload() {
    echo "==> running morning-session bench against the instrumented dylib"
    echo "    (NOTE: full PGO needs you to ALSO drive the Swift host through"
    echo "     idle scroll, agent turn, and graph layout — the bench alone is"
    echo "     not enough coverage. See plan §Wave 6.1 minimum-bench-coverage.)"
    "${REPO_ROOT}/scripts/run-morning-session.sh"
}

optimized_build() {
    echo "==> building ${CRATE} PGO-OPTIMIZED"
    cd "${REPO_ROOT}/${CRATE}"
    cargo pgo optimize build --release --target "${TARGET}"
    echo ""
    echo "==> optimized dylib at:"
    find "${REPO_ROOT}/${CRATE}/target/${TARGET}" -name "lib${CRATE}*.dylib" 2>/dev/null
    echo ""
    echo "==> compare sizes against the canonical release profile:"
    "${REPO_ROOT}/scripts/check-perf-budgets.sh" || true
}

case "${step}" in
    instrument)
        ensure_cargo_pgo
        instrumented_build
        ;;
    optimize)
        ensure_cargo_pgo
        optimized_build
        ;;
    all|*)
        ensure_cargo_pgo
        instrumented_build
        run_workload
        echo ""
        echo "==> NEXT STEP: drive the Swift host through real workloads"
        echo "    (idle scroll, agent turn, graph layout) for 5+ minutes"
        echo "    THEN re-run: ./scripts/pgo-cycle.sh optimize"
        ;;
esac
