---
state: canon
canon_promoted_on: 2026-05-05
covers: 2026-05-05 canon-hardening session (post Codex verification round)
---

# Canonical Sweep — Close-out (2026-05-05)

> **Scope.** This doc closes the 2026-05-05 canon-hardening session
> that ran after Codex's V2 + V2.3 + canon-hardening advice rounds.
> It is the deliberate "stop here, write the handoff" pause after
> ~50 commits across kernel, doctrine, CI, and trust-spine work.
>
> **Read alongside:**
> - `docs/CANON_HARDENING_PROTOCOL_2026_05_05.md` — WRV / canon
>   promotion protocol / no-date-gates rule (the *prospective*
>   discipline this session installed)
> - `docs/CANONICAL_UPGRADE_AUDIT_2026_05_05.md` — the 17-item audit
>   that drove the work
> - `docs/CANONICAL_ROADMAP_2026_05_05.md` — synthesis ledger
> - `docs/CODEX_VERIFICATION_HANDOFF_2026_05_05.md` — the handoff
>   that asks Codex to act as if nothing has been verified yet
> - `docs/MAS_PRO_SOURCE_GUARD_2026_05_05.md` — B5 sweep findings

---

## What landed (this session)

Grouped by Codex audit-item ID. Every item below is **WRV-state =
verified-by-Claude / unverified-by-Codex** until Codex's next pass
signs them off.

### Authority blockers (V2.1 Phase 8.H prerequisites)

| Item | Commit | What |
|---|---|---|
| **CD-005** | 9835b439 | Capability-bound `put_edge` — `InMemoryDagStore` now carries a `BTreeSet<Hash>` capability registry, dispatch registers `system_mirror_capability_hash` on init, `put_edge` rejects edges that don't verify against any registered capability. 7 new tests. Closes the §1.2 + §4.1 + §5.2 doctrine miss Codex flagged. |

### CI / verification gates (Codex audit B-series)

| Item | Commit | What |
|---|---|---|
| **B1** | e523405e | Doctrine linter (`epistemos_doctrine_lint`) runs on every push/PR. |
| **B2** | 412f9e77 | Sample `.epbundle` generator (`generate_sample_epbundle.rs` example) + `epistemos_trace verify-replay` against it. Catches drift in wire format / BLAKE3 chain / DAG merkle root / storage / signature / capability paths. |
| **B3** | e523405e | Pro-build feature surface (`pro-build,lsp-runtime`) is built + tested in CI in addition to default features. Doctrine §3.1 satisfied. |
| **B4** | e523405e | `lsp-runtime` feature also tested in CI under default features (Xcode build path enables it; cargo CI was missing it). |
| **B5** | 0b30d060 + faee8b68 | MAS/Pro source-guard sweep. 9 modules properly Pro-gated, `BashExecuteHandler` impl-level Pro-gated, `tirith.rs:268` resolved-with-recommendation (runtime-gated under MAS sandbox; recommend Pro-gating to clean App Review surface). 3 orphan files flagged for sign-off (904 LOC). |

### Observability migration (Codex C-series)

| Item | Commit | What |
|---|---|---|
| **C1** | e523405e | `eprintln!` → `tracing::warn!` with structured fields in 4 dispatch sites (cognitive_dag mirror error paths). Doctrine §10 verification-window observability. |
| **C2** | 90bdddee | `provenance_ledger()` Mutex → RwLock. All 3 callers use `.read()`. Documented architectural drift: `provenance_ledger` is never written to under current dispatch (writes go to `cognitive_dag_store`). Flagged for Codex review. |

### Doctrine surface

| Item | Commit | What |
|---|---|---|
| **A6** | dcffdfc9 | Cognitive Kernel Doctrine module-name reconciliation note. The doctrine referenced `agent_core::hermes/`; current code has `agent_core::agent_runtime/` after the 2026-05-05 Hermes subprocess removal. 12-line note added to A6 of `COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md`. |
| **G1+G2** | 473e7e92 | `AGENT_PROGRESS.md` 2026-05-05 entry + `CLAUDE.md` FILE MAP additions for `cognitive_dag/`, `provenance/`, `lsp_runtime/`, `agent_runtime/`, two CLI binaries, examples. |

### Canon advice from Codex (post-V2 audit)

| Item | Commit | What |
|---|---|---|
| **#1** (canon-merge — first wave) | 77463e3a | Merge `CANON_GAPS_AND_ADDENDA` C1 (WRV), C2 (no silent fallback), C3 (BYOK off by default), C4 (UX posture §4.0), C5 (canonical state is the only source of truth — §2.2 invariant #5 + §6 forbidden), C13 (telemetry policy line). |
| **#1** (canon-merge — second wave) | 2b39cb3b + 2f008a2b + b0ed623a + 561e8a8d + b17355ce | C6 (Halo V1 stack reference §4.3), C8 (App Store closeout authority §1), C9 (Quick Capture standalone canon §1 #5.5), C10 (Flight Recorder §7 + Annex A.15), C12 (local-stream truncation watch in WORKTREE_INSIGHT_SALVAGE §8.5), C14 (ambient_V1_DECISION explicit naming), C13 Annex A.16 full policy table. Each merged block carries inline `(C#, merged 2026-05-05.)` provenance tag in the doctrine. |
| **#5 + #9** (XPC trust spine) | 5645e303 | `Epistemos/XPC/XPCTrust.swift` — canonical helper that emits `anchor apple generic and identifier "<svc>" and certificate leaf[subject.OU] = "AL562BVF23"` and applies it via `NSXPCConnection.setCodeSigningRequirement(_:)`. Wired into `AgentServiceClient` + `ProviderServiceClient`. 4 new XPCSmokeTests. **Verified at xcodebuild test-build level: TEST BUILD SUCCEEDED 2026-05-05 13:30 PDT.** |
| **A2** (macaroon-derived dispatch cap) | 661fd7d0 | `system_mirror_capability_hash()` was a 0xE5 sentinel; now derived from a real `Macaroon` issued at process start with a process-local random root key (~244 bits CSPRNG entropy from two uuid v4 draws). Hash is process-stable but per-process unique. Doctrine §1.2 contract upgrade. |
| **Canon hardening protocol** | 72b9fe0a | `CANON_HARDENING_PROTOCOL_2026_05_05.md` installs the WRV state machine (research → implemented → wired → reachable → visible → verified → released), the canon promotion protocol (research → candidate → canon → superseded → historical → rejected), and the no-date-gates rule (only six valid gate types: capability / verification / distribution / entitlement / licensing / doctrine). |
| **Canonical roadmap** | 9e33a61a | `CANONICAL_ROADMAP_2026_05_05.md` — 8-section synthesis tying Codex's 10-item canon-hardening list + the agent-driven 17-item audit + this session's commits into one ledger. |
| **V2 close-out + Codex verification handoff** | b238f085 | `V2_FINAL_CLOSEOUT_2026_05_05.md` + `CODEX_VERIFICATION_HANDOFF_2026_05_05.md` — explicit "treat all work as unverified until Codex re-verifies" framing. |

### Long-tail (still pending — flagged for next session / Codex)

| Item | Status | Note |
|---|---|---|
| **A1** | pending | redb-backed `DagStore` implementation. Current `InMemoryDagStore` is the only impl; reboot loses the DAG. Substantial multi-hour effort — separate slice. |
| **A2** | **closed 2026-05-05** | Promoted dispatch hash from sentinel to real macaroon (commit 661fd7d0). A2-followup (per-mirror caveats narrowing the authority surface) remains queued. |
| **A3** | mostly closed | Auto-invoke dispatch coverage: 4 of 5 dispatch helpers wired (Skills via `skill_router.rs:59`, Procedural via `agent_runtime/procedural_memory.rs:93`, Evidence via `provenance/ledger.rs:358`, Claim via `provenance/ledger.rs:423`). The 5th — `on_companion_registered` — has no live caller because `CompanionRegistry` is only used by tests today; will wire when companion lifecycle goes live. |
| **A4** | pending | WASM exec sandbox-within-sandbox. Doctrine §X.4. |
| **A5** | pending | In-process MCP. Currently MCP runs via stdio subprocess (Pro tier). |
| **A7** | pending | 5-XPC decomposition (Main + VaultXPC + AgentXPC + ProviderXPC + WASMExecXPC). Today's XPC trust spine (#5/#9) is the prerequisite — without peer attestation, decomposition is unsafe. |
| **C6, C8, C9, C10, C12, C14** | **MERGED 2026-05-05** | Second-wave merges: Halo V1 stack reference §4.3, App Store closeout authority §1, Quick Capture standalone canon §1 #5.5, Flight Recorder §7 + Annex A.15, local-stream truncation watch in WORKTREE_INSIGHT_SALVAGE §8.5, ambient_V1_DECISION explicit naming. |
| **C7, C11, C15** + **B1, B2, B3** | partially staged | C7 (Phase R / PromptTree anchors) + C11 (pre-release evidence package) need separate verification passes against current code state before merging — they reference work that may have moved. C15 + B-series are housekeeping/bonuses. |
| **B1-B3 bonuses** | staged | Three bonus addenda from `CANON_GAPS_AND_ADDENDA` discovered during path verification. Not load-bearing. |
| **3 orphan source files** | held for sign-off | `code_execution.rs` (105 LOC), `graph_query.rs` (276 LOC), `note_tools.rs` (523 LOC) in `agent_core/src/tools/` exist as files but are NOT declared as `pub mod` in `lib.rs`. They neither compile nor ship. Recommendation: delete (matches user's 2026-05-05 "if i dont need something get rid of it" directive on `LSPServerProcess`). Held — separate sign-off slice. |
| **`tirith` Pro-gating** | recommended for sign-off | Per B5 follow-up: `tirith.rs:268` spawn is runtime-gated under MAS sandbox but compile-reachable. Recommendation: Pro-gate the module + caller for App Review cleanliness. Loses zero MAS capability (Tirith is already a no-op under MAS). |

---

## What is **canon-state** vs **verified-state**

This session was an explicit `state: canon` push across many files.
Per the canon promotion protocol installed today, **`canon` is not
the same as `verified`**. The promotion sequence is:

```
research → candidate → canon → (superseded | historical | rejected)
```

Verification (the WRV pipeline) runs orthogonally:

```
research → implemented → wired → reachable → visible → verified → released
```

This session's deliverables are:
- All `state: canon` (doctrine merges, audit reports, sweep doc).
- WRV-state `implemented` (code lands and compiles in the target tier)
  for: CD-005 capability binding, all CI gates, XPC trust spine,
  `eprintln!`→tracing migration, `Mutex`→`RwLock` migration.
- WRV-state `verified` for items with green CI runs.
- WRV-state `released` for nothing in this session — release is the
  next session's gate, not this session's.

The `CODEX_VERIFICATION_HANDOFF_2026_05_05.md` asks Codex to run the
verification pass — until that returns, Claude's claims here are
self-attested only.

---

## Two architectural questions raised by the user (2026-05-05)

The user asked two questions during this session that deserve their
own deliberation slots:

### Q1: "is mmap utilized through my app as well?"

**Status:** partial / canonical opportunity.

The codebase uses `mmap` indirectly via:
- `tantivy` (lexical index) — uses memory-mapped files for posting
  lists and term dictionaries.
- `usearch` (HNSW vector index) — supports `mmap` mode for the
  vector segment.
- SQLite `PRAGMA mmap_size = 256 MiB` — `Epistemos/Sync/SearchIndexService.swift:204-228`
  (per the 2026-04-29 perf wave; trimmed from 1 GiB).
- GRDB (vault, audit, agent_events DBs) — inherits SQLite's mmap.

The canonical opportunity: `MTLBuffer` with `storageModeShared` already
gives zero-copy CPU↔GPU on Apple Silicon UMA (doctrine §2.2 invariant
#1). Direct mmap of model weight files into `MTLBuffer.contents()`
is a Research-tier path (Annex A.10 KV implantation + raw memory
inspection). Outside Research, MLX-Swift handles weight loading via
its own zero-copy path.

**Action queued:** doctrine annex on "where mmap lives in Epistemos"
to avoid future drift on this question. Not in this session.

### Q2: "Artifact primitive that distinguishes Static Note from Dynamic AI Weight"

**Status:** doctrine-relevant, requires deliberation brief.

The doctrine's substrate spine is:
```
TypedArtifact → MutationEnvelope → RunEventLog / AgentEvent / GraphEvent → projections
```

A canonical extension that distinguishes by mutability is reasonable:
- **StaticNote** — content-addressed, immutable after capture, Halo /
  Graph project from it.
- **DynamicAIWeight** — model weights, KV cache state, LoRA-light
  Companion deltas (Annex A.5 honest stance, A.9 KV substrate). These
  *do* mutate over time (continual learning, KV reuse) but their
  mutation surface is governed by Companion lineage and residency
  governor, not by the same `MutationEnvelope` shape that wraps user
  text edits.

The Cognitive DAG's `WeightRoot` node + `ModelLineage` already model
the dynamic side. The static side is `Note` + `Capture` nodes.
**The distinction is real and already partially encoded** — but it
is not surfaced as a top-level "Artifact" enum the way the user's
question implies.

**Action queued:** deliberation brief that either (a) introduces a
top-level `Artifact { Static(NoteId) | Dynamic(WeightRootId) | …}`
discriminator, or (b) documents why the existing `NodeKind` enum
already captures this distinction without a new type. Either resolution
is canon-worthy. Not in this session.

---

## Verification posture

This is the canonical statement Codex's next pass works against:

- ~50 commits land on `feature/landing-liquid-wave` since Codex's
  V2.3 + V2 verification rounds.
- Every commit is **self-attested by Claude only**.
- The verification handoff (`CODEX_VERIFICATION_HANDOFF_2026_05_05.md`)
  asks Codex to verify as if work has not been done, and to call out
  anything that's "still blocked, being honest, so the user makes
  sure it's still canon and not losing nuance from the plan."
- Three deliverables in this session are explicitly **held for
  sign-off**: orphan-file deletion, `tirith` Pro-gating recommendation,
  and the `provenance_ledger` architectural-drift finding.
- Long-tail items A1–A7 + the remaining `CANON_GAPS_AND_ADDENDA`
  blocks (C6, C7, C8, C9, C10, C11, C12, C14, C15 + B1, B2, B3) are
  candidates for the next sustained session.

---

## Cross-refs

- `docs/CANON_HARDENING_PROTOCOL_2026_05_05.md` — prospective discipline
- `docs/CANONICAL_UPGRADE_AUDIT_2026_05_05.md` — 17-item audit
- `docs/CANONICAL_ROADMAP_2026_05_05.md` — synthesis ledger
- `docs/CODEX_CANONICAL_DRIFT_AUDIT_2026_05_05.md` — Codex's matching observations
- `docs/MAS_PRO_SOURCE_GUARD_2026_05_05.md` — B5 sweep findings
- `docs/CODEX_VERIFICATION_HANDOFF_2026_05_05.md` — verification ask
- `docs/V2_FINAL_CLOSEOUT_2026_05_05.md` — V2 close
- `docs/SUBSTRATE_V2_FINAL_CLOSEOUT_2026_05_05.md` — Substrate V2 close
- `docs/V2_3_LSP_MIGRATION_PLAN_2026_05_05.md` — V2.3 LSP migration
- `docs/fusion/CANON_GAPS_AND_ADDENDA_2026_05_02.md` — staged addenda (C1-C5+C13 marked merged)
- `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` — destination of merges
- `docs/fusion/COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md` — A6 reconciliation note added

---

## Closing line

This session converted Codex's "the gap is enforcement, not
implementation" finding into **enforced gates** (CI), **codified
doctrine** (WRV, canon promotion, no-date-gates), and **trust spine
material** (XPC peer attestation). The next session continues the
A1–A7 long-tail or, more likely, runs whatever Codex's verification
pass surfaces.

Codex sign-off pending.
