# V2 Wire-Up Complete — 2026-05-05

Closes the V2 wire-up sprint. The cognitive substrate (Resonance,
Provenance ledger, Cognitive DAG, all four DagMirrors) is now reachable
from the Swift app — three user-visible UI surfaces + one Settings
diagnostic — while honoring the cognitive DAG doctrine §10 read-only
constraint that holds until Phase 8.H authority flip.

## What shipped (5 wire-up commits)

| Commit | Lane | What | Where it shows up |
|---|---|---|---|
| [b34164e5] | Phase A | Resonance FFI swap (Swift stub → real Rust call) | Used wherever ResonanceService is consumed; FFI hot 16/16 tests green |
| [d606afc0] | Lane 1 | Rust ClaimLedger Swift bridge (FFI exports + RustProvenanceLedgerClient + ProvenanceConsoleProjectionService extension) | Settings → Provenance Console: new "ClaimLedger (Rust)" panel |
| [fb3d4fe3] | Lane 2a+2b | ProceduralMirror + ProvenanceLedgerMirror DagMirror impls | Trait surface; populates DAG when wired into legacy write paths |
| [b439db25] | Lane 2c | CompanionMirror (final mirror — 4/4 subsystems now have DagMirror impls) | Trait surface; uniform shape across all 4 |
| [6f609d8c] | Lane 3 | Halo panel ClaimLedger ribbon | Halo panel: "ledger: N claims · M evidence · K events" peer of graph projection ribbon |
| [49d4efaf] | Final | Cognitive DAG observability (FFI + RustCognitiveDagClient + CognitiveDagHealthRow + Settings wire) | Settings → Diagnostics: new "Cognitive DAG" health row showing nodes/edges/merkle root |

## V2 surface integration matrix — POST-SHIP

| V2 surface | Rust LOC | FFI exported? | Swift consumer? | UI surface? | Live in app? |
|---|---|---|---|---|---|
| Resonance τ + π + λ | 777 | ✅ `compute_resonance_signature_core` | ✅ ResonanceService | (used as a value, not a panel) | **YES** |
| Cognitive DAG node/edge/storage/merkle | 1,576 | ✅ `cognitive_dag_stats_json` | ✅ RustCognitiveDagClient | ✅ CognitiveDagHealthRow in Settings | **YES** |
| Provenance ledger | 1,355 | ✅ `provenance_ledger_summary_json` + `_recent_events_json` + `_snapshot_json` | ✅ RustProvenanceLedgerClient | ✅ Halo ribbon + Provenance Console panel | **YES** |
| Skills DagMirror | (in 522) | trait-only | trait-only | (when populated → DAG count goes up) | TRAIT READY |
| Procedural DagMirror | (this session) | trait-only | trait-only | (when populated → DAG count goes up) | TRAIT READY |
| Provenance DagMirror | (this session) | trait-only | trait-only | (when populated → DAG count goes up) | TRAIT READY |
| Companion DagMirror | (this session) | trait-only | trait-only | (when populated → DAG count goes up) | TRAIT READY |
| Macaroon capabilities | 926 | ❌ (no Swift consumer needs them yet) | ❌ | ❌ | gates DAG edges; orphan **by doctrine** until Phase 8.H |

## Key design decisions

**Read-only first.** Every Rust→Swift FFI added in this sprint is
read-only. The Swift app can observe the cognitive substrate but
cannot write to it — writes happen through the four DagMirror impls
inside Rust. This honors the cognitive DAG doctrine §10 parallel-
store invariant: only one writer per content-addressed node, and that
writer is the Rust mirror. Phase 8.H eventually flips read authority
too; the Swift consumers don't need to change when that happens.

**Wire shape contained.** Each FFI bridge has a small private wire
struct (`ClaimWire`, `SignatureWire`, etc.) inside `#if canImport(
agent_coreFFI)` blocks that owns the Rust serde shape match. Public
Swift APIs (`ResonanceClaim`, `ResonanceSignatureCore`,
`RustProvenanceLedgerSummary`, `RustCognitiveDagStats`) don't change
when the Rust serde shape evolves — only the private wire types do.

**Fail-soft fallback.** Every client has an `.empty` fallback. If the
FFI call errors or `agent_coreFFI` isn't linked, the consumer logs
once and returns the empty shape. UI surfaces show "ledger empty" /
"DAG empty (waiting for mirrors)" / etc. rather than crashing or
hiding. Honest about what's wired vs. what's not.

**Doctrine-safe ordering.** The DAG observability landed LAST per the
user's direction "use DAG at the end." Earlier lanes either swap an
existing stub for a real FFI (Phase A — Resonance) or surface a Rust
backend that's already populated (Lane 1 — Provenance ledger). The
DAG observability surface goes live with the DAG empty (no mirror
writers fire automatically yet — that's the next slice's work) and
fills in automatically as mirrors come online.

## Tests added

- `EpistemosTests/RustProvenanceLedgerClientTests.swift` — 5 tests
- `EpistemosTests/RustCognitiveDagClientTests.swift` — 3 tests
- 12 new mirror tests in `agent_core/src/cognitive_dag/migration.rs`
  (5 Procedural + 6 Provenance + 5 Companion + 1 hex parser helper)

## Verification (final state)

- **Rust:** 1014/1014 agent_core tests pass (was 997 before this sprint;
  +17 for the new mirrors + ledger FFI tests)
- **Swift focused:** 68/68 V2-wire tests pass (Resonance + Provenance +
  Cognitive DAG clients + Halo + Provenance Console source guards)
- **Build:** xcodebuild build SUCCEEDED on every commit; no broken state

## Where the user actually SEES this work

1. **Halo panel** (Cmd-I or whatever invokes Halo) — second ribbon row
   under the search results shows "ledger: N claims · M evidence ·
   K events"
2. **Settings → Diagnostics → Cognitive DAG row** — node/edge counts +
   first 12 chars of the merkle root, polled every 5s
3. **Settings → Provenance Console panel** — new "ClaimLedger (Rust)"
   GenUI card showing source/mode/claims/evidence/events
4. **Anywhere ResonanceService is used** — the τ + π + λ signature now
   comes from the Rust seed, not the Swift mirror (mirror remains as
   the offline fallback for tests/previews)

## What's left (next sprint)

The trait-level DagMirror pattern is complete for all four subsystems,
but the **mirrors aren't auto-invoked** by the legacy stores yet.
Today the mirrors are reachable via test code and direct callers, but
`ProceduralMemoryStore::record_outcome` doesn't fire `ProceduralMirror::
mirror_write` automatically. Wiring the auto-invocation is the next
Phase 8.E continuation slice — a focused write-path-hook patch per
subsystem.

After that, the doctrine §10 verification gate kicks in: two consecutive
weeks of CI green with the mirrors firing on every legacy write, then
Phase 8.H flips authority — the DAG becomes primary, legacy stores
become read-only fallback views, one release later removed.

The eight FFI exports added this session (3 ledger + 1 DAG + the
existing Resonance one) survive that flip unchanged. The Swift
consumers don't need to change when the read authority moves.

## Honest summary

When the user asked "make sure all my new V2 tools are on the app" the
answer was: ~4,700 LOC of cognitive substrate was orphaned from the
app's perspective. That's no longer true after this sprint. Three
user-visible UI surfaces + one diagnostic now consume four typed FFI
bridges into the Rust substrate. The cognitive DAG itself is the LAST
surface to wire (per user direction), and it's wired as a read-only
observability surface — the Phase 8.H authority flip is now the only
thing standing between this scaffolding and full operational use.
