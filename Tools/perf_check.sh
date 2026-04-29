#!/usr/bin/env bash
# Tools/perf_check.sh — Simulation Mode perf-gate harness (S0)
#
# Reports go/no-go against DOCTRINE.md §12 performance budgets. At S0
# only the framework wiring is verified — most budgets graduate from
# FRAMEWORK ONLY to ENFORCED at later slices (S4 = Metal renderer,
# S7 = graph theater hysteresis, S10 = atlas budget, S14 = final audit).
#
# Exit codes:
#   0 — go (framework wired; no measured-now budget violated)
#   1 — no-go (a measured-now budget violated)
#   2 — environment failure (cargo missing, bench harness broken)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

if [[ -t 1 ]]; then
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    RED='\033[0;31m'
    NC='\033[0m'
else
    GREEN=''; YELLOW=''; RED=''; NC=''
fi

ok()    { printf "${GREEN}✓${NC} %s\n" "$1"; }
warn()  { printf "${YELLOW}⚠${NC} %s\n" "$1"; }
fail() { printf "${RED}✗${NC} %s\n" "$1"; }

command -v cargo >/dev/null 2>&1 || { fail "cargo not found; cannot measure Rust budgets"; exit 2; }

echo "════════════════════════════════════════════════════════════════════"
echo " Epistemos Simulation Mode — Perf Gate (DOCTRINE §12)"
echo " Slice substrate: S0 (perf framework wiring only)"
echo "════════════════════════════════════════════════════════════════════"
echo

# ─────────────────────────────────────────────────────────────────────
# [1/4] Framework wiring — criterion bench harness builds + runs.
# ─────────────────────────────────────────────────────────────────────
echo "[1/4] Framework wiring (S0 acceptance)"
BENCH_LOG="$(mktemp -t epistemos-perf-bench.XXXXXX)"
trap 'rm -f "$BENCH_LOG"' EXIT
if cargo bench --manifest-path agent_core/Cargo.toml --bench reducer_bench --quiet -- --quick >"$BENCH_LOG" 2>&1; then
    ok "criterion bench harness builds + runs (perf framework wired)"
    if grep -qE 'perf::signpost_(interval|event)_baseline' "$BENCH_LOG"; then
        ok "baseline signposts emitted by bench (Instruments-visible)"
    else
        warn "bench ran but baseline signpost names not detected in output"
    fi
else
    fail "criterion bench failed to build/run"
    echo "── bench log ────────────────────────────────────────────────────"
    cat "$BENCH_LOG"
    echo "─────────────────────────────────────────────────────────────────"
    exit 1
fi
echo

# ─────────────────────────────────────────────────────────────────────
# [2/4] Subsystem alignment — Rust + Swift agree on the subsystem name.
# ─────────────────────────────────────────────────────────────────────
echo "[2/4] Signpost subsystem alignment"
RUST_OK=0
SWIFT_OK=0
grep -q 'com.epistemos.simulation' agent_core/src/perf.rs && RUST_OK=1
grep -q 'com.epistemos.simulation' Epistemos/Simulation/Perf.swift && SWIFT_OK=1
if [[ $RUST_OK -eq 1 && $SWIFT_OK -eq 1 ]]; then
    ok "subsystem 'com.epistemos.simulation' present on both Rust + Swift sides"
else
    fail "subsystem mismatch — Rust=${RUST_OK} Swift=${SWIFT_OK}"
    exit 1
fi
echo

# ─────────────────────────────────────────────────────────────────────
# [3/4] Per-slice category coverage (IMPLEMENTATION.md §5).
# ─────────────────────────────────────────────────────────────────────
echo "[3/4] Per-slice category coverage (IMPLEMENTATION.md §5)"
# Each slice declares categories it will emit. For S0 we ship the full
# canonical set so subsequent slices can wire signposts without
# circling back to perf.rs / Perf.swift.
required_categories=(theater companions events audit ffi hermes landing)
all_present=true
for cat in "${required_categories[@]}"; do
    in_rust=0; in_swift=0
    grep -q "c\"${cat}\"" agent_core/src/perf.rs && in_rust=1
    grep -q "category: \"${cat}\"" Epistemos/Simulation/Perf.swift && in_swift=1
    if [[ $in_rust -eq 1 && $in_swift -eq 1 ]]; then
        ok "category '${cat}'  rust=✓ swift=✓"
    else
        fail "category '${cat}'  rust=$([[ $in_rust -eq 1 ]] && echo ✓ || echo ✗) swift=$([[ $in_swift -eq 1 ]] && echo ✓ || echo ✗)"
        all_present=false
    fi
done
if [[ $all_present == false ]]; then
    fail "category coverage incomplete"
    exit 1
fi
echo

# ─────────────────────────────────────────────────────────────────────
# [4/4] DOCTRINE §12 budget table — gate status by slice.
# ─────────────────────────────────────────────────────────────────────
echo "[4/4] DOCTRINE §12 budgets — gate status by slice"
cat <<'TABLE'
  Subsystem                                                  Budget       Gate (S0)
  ─────────────────────────────────────────────────────────  ───────────  ──────────
  Metal rendering (theater frame, ≤12 active companions)     ≤ 5 ms p99   FRAMEWORK ONLY → S4
  Rust reducer (per event)                                   ≤ 1 ms       FRAMEWORK ONLY → S2/S4
  FFI control call (UniFFI)                                  ≤ 50 µs      FRAMEWORK ONLY → S5
  FFI hot delta (ringbuffer)                                 ≤ 5 µs p95   FRAMEWORK ONLY → S4
  Graph FTS5 query (semantic search)                         ≤ 10 ms p95  FRAMEWORK ONLY → S9
  Idle CPU (no active sessions)                              ≤ 1 %        FRAMEWORK ONLY → S14
  Idle memory resident                                       ≤ 300 MB     FRAMEWORK ONLY → S14
  Active session memory (1 cloud + 1 local model)            ≤ 6 GB       FRAMEWORK ONLY → S14
  Companion atlas total                                      ≤ 3 MB disk  FRAMEWORK ONLY → S10
  Composed texture memory (VRAM)                             ≤ 50 MB      FRAMEWORK ONLY → S10
  Local model inference (Fast-tier role) p95                 ≤ 500 ms     EXISTING (MLXInferenceService)
  Companion creation transaction (§6.3)                      ≤ 300 ms p95 FRAMEWORK ONLY → S1
  Adapter unwrap (system_prompt_preset)                      ≤ 50 ms      FRAMEWORK ONLY → S11
TABLE
echo

echo "════════════════════════════════════════════════════════════════════"
ok "S0 perf-gate framework: GO"
echo "  Substantive budget enforcement begins at S4 (Metal renderer) and"
echo "  S14 (final audit). Re-run this script after each slice to track"
echo "  which budgets graduate from FRAMEWORK ONLY to ENFORCED."
echo "════════════════════════════════════════════════════════════════════"
exit 0
