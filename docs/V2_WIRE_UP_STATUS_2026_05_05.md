# V2 Wire-Up Status — 2026-05-05

Honest accounting of which V2 surfaces are wired into the live Swift
app, which are intentionally orphaned per doctrine sequencing, and
which are genuinely worth wiring next.

## TL;DR

- **Phase A (Resonance) — WIRED** today (commit `b34164e5`). The
  Swift `ResonanceService` now calls the real Rust
  `agent_core::resonance::compute_signature_core` FFI. 16/16 tests
  green.
- **Phase 8.A-8.E Cognitive DAG (~4,700 LOC) — INTENTIONALLY ORPHANED**
  per the cognitive DAG doctrine §10. The DAG is supposed to remain
  unconsumed by the app until Phase 8.E begins write-mirroring from
  the seven existing subsystems. **Wiring it now would violate the
  doctrine sequencing.**
- **Sim Mode S0-S11 (17 commits on `worktree-simulation`) — NOT LOST**;
  in queue for V2.5 per the post-recovery V2 plan. (Note: S9 references
  the now-deleted Hermes graph faculty; future merge needs conflict
  resolution.)
- **No genuinely "lost" work found.** lane-A, worktree-agent-a0550f9c,
  worktree-hermes-parity all have 0 commits not on the current branch
  (already merged).

## V2 surface integration matrix

| V2 surface | Rust LOC | FFI exported? | Swift consumer? | Live in app? |
|---|---|---|---|---|
| Resonance τ + π + λ | 777 | ✅ `compute_resonance_signature_core` | ✅ ResonanceService | **YES (today)** |
| Cognitive DAG node/edge/storage/merkle | 1,576 | ❌ | ❌ | NO — orphan **by doctrine** |
| Resonance propagation (TruthCache, propagate) | (777 above) | ❌ | ❌ | NO — orphan |
| Macaroon capabilities | 926 | ❌ | ❌ | NO — orphan |
| Companion registry + LoRA estimates | 637 | ❌ | ❌ (Swift uses local CompanionState) | NO — orphan |
| DagMirror skill migration | 522 | ❌ | ❌ | NO — by design (not Phase 8.E yet) |
| Provenance ledger + ReplayBundle | 1,355 | ❌ (CLI binary only) | ❌ (Swift Provenance Console reads local EventStore) | PARTIAL — CLI only |
| `epistemos-trace` CLI | 80 | n/a (standalone bin) | n/a | YES (CLI tool, not app) |

## Why Cognitive DAG (Phase 8.A-8.E) is intentionally orphaned

From `docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md` §10:

> "The seven existing subsystems remain authoritative throughout
> Phase 8.A-G; the DAG runs alongside, mirroring writes for one week
> before Phase 8.H flips authority."

The doctrine sequencing is:

1. **Now (kernel + Phase 8.A-8.E shipped):** scaffold + types + tests.
   No app integration yet.
2. **Phase 8.E continuation:** subsystems start mirror-writing to the
   DAG. Skills mirror landed (`69e4013d`); procedural memory + provenance
   ledger + companions mirrors still pending.
3. **Phase 8.F-G:** replay verification CLI + doctrine linter.
4. **Phase 8.H:** flip-the-switch — the DAG becomes authoritative,
   legacy subsystems become read-only fallback views.

Wiring DAG/Macaroon FFI exports to Swift consumers BEFORE Phase 8.E
mirroring is in place would create a parallel-store hazard: writes
would land in legacy stores OR the DAG (depending on call site) but
not both, breaking the "one week of mirroring" verification gate.

**This is the right kind of orphan.** It's substrate waiting for its
sequence in the doctrine. It is NOT lost work.

## What was actually wired today (Phase A)

Single file change (`Epistemos/Engine/ResonanceService.swift`,
+130 / -7):

- New `computeViaFFI(claim:)` private static path
- New private `ClaimWire` / `SignatureWire` / `TruthWire` /
  `ClassWire` / `ResidencyWire` types that match the Rust serde shape
  exactly (PascalCase enums, snake_case `evidence_count`, `class` not
  `class_`, etc.)
- New `rustName` mapping on `ResonanceClaimType` to bridge the
  camelCase ↔ PascalCase variant naming gap
- New `ffiCallCount` + `stubFallbackCount` diagnostic counters
- Public Swift API unchanged — Rust serde shape drift is contained
  in private wire structs inside `#if canImport(agent_coreFFI)`
- On FFI failure: logs and falls back to the existing Swift stub
  (UI never breaks)

Verification:
- xcodebuild build: SUCCEEDED
- 16/16 ResonanceServiceTests pass
- 78/78 V2 + cloud surface tests pass (Resonance + HermesGatewayPolicy
  + HermesGatewayEvidenceContract + CapabilityBridge +
  CloudProviderAuthService + ConfidenceRouter)

## What I'd do next (user picks)

Three lanes, ranked by user-visible impact + doctrine-safe:

**Lane 1 — Provenance ledger bridge (medium effort, high audit value)**
- Add FFI exports for `ClaimLedger::summary_json()` + recent retraction
  reports
- Add a Swift `RustProvenanceLedgerClient`
- Extend `ProvenanceConsoleProjectionService` to surface Rust ledger
  state alongside the existing local EventStore reads
- Result: Provenance Console becomes the single dashboard for both
  the Swift event log AND the Rust claim ledger
- **Doctrine-safe** — this is a read-only bridge; no parallel-write hazard

**Lane 2 — Continue V2.1 Phase 8.E migrations (high effort, sets up 8.H)**
- Wire procedural memory through `DagMirror` (similar pattern to the
  Skills mirror that landed in `69e4013d`)
- Wire provenance ledger through `DagMirror`
- Wire companions through `DagMirror`
- Result: the DAG starts populating from real subsystem traffic;
  Phase 8.F replay verification becomes executable
- **Doctrine-aligned** — this IS Phase 8.E continuation

**Lane 3 — Move to V2.2 Halo V1 (variable effort)**
- Per `project_post_recovery_v2_plan` memory, V2.2 is next after V2.1
- The Halo Search service + ShadowVaultBootstrapper already exist
  (`Epistemos/Engine/HaloController.swift`, `ShadowSearchService.swift`)
- V2.2 work would extend or polish that surface

**Lane 4 — Wait for Sim Mode V2.5 (no work needed now)**
- worktree-simulation has S0-S11 ready
- S9 conflict (Hermes graph faculty) needs resolution at merge time

## What was NOT wired today and why

- **Cognitive DAG (Node/Edge/Storage)** — doctrine says don't wire
  until 8.E mirroring is in place. Adding FFI exports now would
  invite ad-hoc Swift consumers that break the parallel-store
  invariant.
- **Macaroon capabilities** — same reason. Macaroons are meant to
  gate edges in the DAG. Without DAG consumers, exposing macaroon
  FFI gives Swift a capability system with nothing to gate.
- **DagMirror skill migration** — the Rust pattern landed
  (`69e4013d`) but the migration itself (rewiring writes) is multi-day
  work per subsystem and is the actual Phase 8.E body. Worth doing
  but as a focused multi-commit slice.

## Honest summary

The user's worry — "make sure all my new V2 tools are on the app and
all the other things that were lost" — resolves to:

1. ✅ One V2 tool (Resonance) is now wired and verifiable
2. ✅ Nothing is lost — every branch I checked is either merged or
   in queue
3. ⚠️ The big chunk of V2.1 (Cognitive DAG) is orphaned **by design**
   — wiring it before its time would actively damage the doctrine

If the user wants more user-visible V2 wired NOW, **Lane 1 (Provenance
bridge)** is the cleanest doctrine-safe next step. **Lane 2 (Phase 8.E
migrations)** is the right architectural next step but is multi-day.

This document deliberately stops here so the user can pick.
