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
| **B5** | 0b30d060 + faee8b68 + Codex continuation | MAS/Pro source-guard sweep. 9 tools modules properly Pro-gated, `BashExecuteHandler` impl-level Pro-gated, and `tirith.rs` moved to a Pro-only top-level module so its subprocess scanner is not compiled into MAS. Codex removed 2 proven-dead orphan files (`code_execution.rs`, `graph_query.rs`) and promoted `note_tools.rs` into the compiled registry with R.5 gating for template writes. |

### Observability migration (Codex C-series)

| Item | Commit | What |
|---|---|---|
| **C1** | e523405e | `eprintln!` → `tracing::warn!` with structured fields in 4 dispatch sites (cognitive_dag mirror error paths). Doctrine §10 verification-window observability. |
| **C2** | 90bdddee | `provenance_ledger()` Mutex → RwLock. Codex continuation resolved the drift: no parallel writes to the legacy global; the visible Halo/Provenance Console Rust signal reads the DAG-authoritative `cognitive_dag_store` projection, while the old bridge stays as read-only scaffold. |

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
| **#1** (canon-merge — third wave: VERIFY-then-MERGE) | 3ed75568 + 54c807f9 + ddb8a8d1 + 309e837a | C7 (Resource Runtime + Phase R §9 anchors — verified that staged claim was stale; substrate already on main), C11 (pre-release evidence package as Annex C — verified PrivacyInfo.xcprivacy present, flagged WORKFLOW_MATRIX.md as missing deliverable), C15 (CRDT collaboration deferred §6), and C9 finalize (ALL_DOCS_INDEX §3.5). **All 15 of 15 C-blocks now MERGED.** Status checklist refreshed. Only B1-B3 bonus blocks (read-then-absorb passes against 44-67 KB QuickCapture addenda) remain as future-session work. |
| **#5 + #9** (XPC trust spine) | 5645e303 | `Epistemos/XPC/XPCTrust.swift` — canonical helper that emits `anchor apple generic and identifier "<svc>" and certificate leaf[subject.OU] = "AL562BVF23"` and applies it via `NSXPCConnection.setCodeSigningRequirement(_:)`. Wired into `AgentServiceClient` + `ProviderServiceClient`. 4 new XPCSmokeTests. **Verified at xcodebuild test-build level: TEST BUILD SUCCEEDED 2026-05-05 13:30 PDT.** |
| **A2** (macaroon-derived dispatch cap) | 661fd7d0 | `system_mirror_capability_hash()` was a 0xE5 sentinel; now derived from a real `Macaroon` issued at process start with a process-local random root key (~244 bits CSPRNG entropy from two uuid v4 draws). Hash is process-stable but per-process unique. Doctrine §1.2 contract upgrade. |
| **Canon hardening protocol** | 72b9fe0a | `CANON_HARDENING_PROTOCOL_2026_05_05.md` installs the WRV state machine (research → implemented → wired → reachable → visible → verified → released), the canon promotion protocol (research → candidate → canon → superseded → historical → rejected), and the no-date-gates rule (only six valid gate types: capability / verification / distribution / entitlement / licensing / doctrine). |
| **Canonical roadmap** | 9e33a61a | `CANONICAL_ROADMAP_2026_05_05.md` — 8-section synthesis tying Codex's 10-item canon-hardening list + the agent-driven 17-item audit + this session's commits into one ledger. |
| **V2 close-out + Codex verification handoff** | b238f085 | `V2_FINAL_CLOSEOUT_2026_05_05.md` + `CODEX_VERIFICATION_HANDOFF_2026_05_05.md` — explicit "treat all work as unverified until Codex re-verifies" framing. |

### Codex drift register (`CODEX_CANONICAL_DRIFT_AUDIT_2026_05_05.md`)

| ID | Status | Closing artifact |
|---|---|---|
| **CD-001** V2.3 LSP runtime | ✓ resolved by Codex (SUPERSEDED/ALIGNED); committed 2026-05-05 7fb91735 | Codex's pass + late-session commit |
| **CD-002** V2 closeout V2.3 row | ✓ resolved by Codex (DRIFT FIXED); committed 2026-05-05 4ddf3cef | Codex's pass + late-session commit |
| **CD-003** Codex verification handoff counts | ✓ resolved by Codex (DRIFT FIXED); committed 2026-05-05 4ddf3cef | Codex's pass + late-session commit |
| **CD-004** V2.1 Phase 8 authority | **BLOCKED** — needs Codex verification of "prerequisites, mirror coverage, replay parity, authority flip criteria" | external Codex pass required |
| **CD-005** DAG edge signatures | ✓ closed (commit 9835b439 + A2 promotion 661fd7d0) | this session |
| **CD-006** Mirror auto-invoke coverage | ✓ closed | `docs/MIRROR_DISPATCH_COVERAGE_2026_05_05.md` (commit 747c4cd8) |
| **CD-007** MAS-first subprocess discipline | ✓ closed | `docs/MAS_PRO_SOURCE_GUARD_2026_05_05.md` (B5 commits 0b30d060 + faee8b68) |
| **CD-008** Full-app verification | **AUTOMATED GATES CODEX-VERIFIED; LIVE UI/BIOMETRIC MANUAL SMOKE PENDING** — all primary Rust crates green at `--all-targets`; `agent_core` Pro+lsp all-targets green; doctrine lint + replay verification green; `.epdoc` creation path, Settings Diagnostics, and Authority approval preview runtime-smoked with Computer Use; full `xcodebuild test` passed with 5,739 total tests, 0 failed, 49 skipped; semantic LSP focused tests passed in Rust and Swift, including tree-sitter hover/definition through `RustLSPTransport`. Live LSP editor UI affordance and real biometric approval remain manual. | `docs/CD_008_PARTIAL_CLOSURE_2026_05_05.md` + Codex continuation |
| **CD-009** Benchmark JSON dirtiness | ✓ procedural (don't commit dirty JSONs; satisfied by NOT adding the 7 dirty files in `git status` to any commit this session) | n/a |

### Late-session hygiene discovery (2026-05-05 13:0X tick)

A working-tree audit late in the session discovered that **Codex's
V2.3 semantic LSP work (the deliverable behind CD-001/CD-002/CD-003)
had been sitting uncommitted in the working tree the entire session**.
Codex did the work + verified it in a prior session; the artifacts
(LSP code, doc patches, the canonical drift audit doc itself) had
never been `git add`ed. The drift register table above marked them
"resolved by Codex" but the substrate was untracked.

This session's late commits land Codex's output into the branch:
  - 8fdeb017 — `docs/CODEX_CANONICAL_DRIFT_AUDIT_2026_05_05.md`
    (the audit doc this entire session has been working against)
  - 4ddf3cef — three doc patches (CODEX_VERIFICATION_HANDOFF,
    SUBSTRATE_V2_FINAL_CLOSEOUT, V2_3_LSP_MIGRATION_PLAN) closing
    CD-002 + CD-003
  - 7fb91735 — `agent_core/Cargo.toml` + `Cargo.lock` +
    `agent_core/src/lsp_runtime/mod.rs` (+613 lines) +
    `Epistemos/Engine/RustLSPTransport.swift` + 2 test files —
    the actual semantic LSP via tower-lsp 0.20 + tree-sitter 0.25 +
    tree-sitter-rust + tree-sitter-swift, closes CD-001

Verified locally at commit time: `cargo test --lib --features
lsp-runtime lsp_runtime` → 17 / 17 pass (matches Codex's own
verification table in the audit doc).

Lesson for future sessions: run `git status` at session START, not
just at session end — silently dirty work-in-progress from prior
sessions can ride along through 70+ commits without noticing.

### Long-tail (still pending — flagged for next session / Codex)

| Item | Status | Note |
|---|---|---|
| **A1** | **partial implementation landed by Codex continuation** | `RedbDagStore` now exists behind `cognitive-dag-redb` using current `redb` 4.1.0, five tables, JSON value bytes, durable reopen tests, CD-005 capability checks, directional indices, Merkle root parity, and snapshot parity. Verified: redb focused 8/8, feature-enabled cognitive DAG 144/144, default cognitive DAG 136/136, default clippy, and redb-feature clippy. Slice 5 remains pending: dispatch must not open the redb backend by default until Phase 8.H authority verification. |
| **A2** | **closed 2026-05-05** | Promoted dispatch hash from sentinel to real macaroon (commit 661fd7d0). |
| **A2-followup** | **closed 2026-05-05** | Per-mirror caveat-narrowed capabilities (commit 5f38f3c8). 5 derived caps via `Caveat::ScopePrefix` ("skills", "procedural", "provenance/evidence", "provenance/claim", "companions"); each dispatch site signs under its own narrowed authority; pre-positioned for the future "DAG enforces caveats at insert" verification slice. 4 new tests pin distinctness + registration + canonical derivation. |
| **A3** | mostly closed | Auto-invoke dispatch coverage: 4 of 5 dispatch helpers wired (Skills via `skill_router.rs:59`, Procedural via `agent_runtime/procedural_memory.rs:93`, Evidence via `provenance/ledger.rs:358`, Claim via `provenance/ledger.rs:423`). The 5th — `on_companion_registered` — has no live caller because `CompanionRegistry` is only used by tests today; will wire when companion lifecycle goes live. |
| **A4** | pending | WASM exec sandbox-within-sandbox. Doctrine §X.4. |
| **A5** | pending | In-process MCP. Currently MCP runs via stdio subprocess (Pro tier). |
| **A7** | pending | 5-XPC decomposition (Main + VaultXPC + AgentXPC + ProviderXPC + WASMExecXPC). Today's XPC trust spine (#5/#9) is the prerequisite — without peer attestation, decomposition is unsafe. |
| **C6, C8, C9, C10, C12, C14** | **MERGED 2026-05-05** | Second-wave merges. |
| **C7, C11, C15** | **MERGED 2026-05-05** | Third-wave verify-then-merge: C7 (verified that staged claim was stale — Phase R substrate already on main), C11 (verified-state Annex C with PrivacyInfo.xcprivacy ✓ + WORKFLOW_MATRIX.md missing-flag), C15 (§6 forbidden line). |
| **B1, B2, B3** | **Tier-1 doctrine landed; implementation queued** | All three QuickCapture addenda absorbed as lift-targets briefs (state: candidate for implementation). B1 = `docs/B1_BIOMETRIC_TAMAGOTCHI_BRAINEXPORT_LIFT_TARGETS_2026_05_05.md` (commit b1f75c1f), B2 = `docs/B2_LIVE_FILES_AND_SUBSTRATE_LIFT_TARGETS_2026_05_05.md` (commit e2d83e97), B3 = `docs/B3_OBSCURA_BROWSER_LIFT_TARGETS_2026_05_05.md` (commit 30b2f088). 689 + 1014 + 1190 = 2893 source-doc lines mapped to canon. Codex continuation landed the 15 Tier-1 doctrine lifts in `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md`; B1/B2/B3 runtime implementation remains queued behind deliberation briefs and verification. |
| **B1-B3 bonuses** | staged | Three bonus addenda from `CANON_GAPS_AND_ADDENDA` discovered during path verification. Not load-bearing. |
| **Orphan source files** | resolved | Codex continuation removed `code_execution.rs` (105 LOC) and `graph_query.rs` (276 LOC) after confirming they were respectively a dead local subprocess runner and superseded by wired `tools/graph.rs`. `note_tools.rs` (523 LOC) was preserved as intended scaffold and promoted to compiled, registered code with `note_template.output_path` mapped to the R.5 vault-note write gate. |
| **`tirith` Pro-gating** | resolved | Codex continuation Pro-gated the top-level `tirith` module and the `approval.rs` caller. MAS keeps pattern-based approval but no longer compiles the dormant Tirith subprocess scanner surface. |

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

**Action landed 2026-05-05:** `docs/MMAP_UTILIZATION_AUDIT_2026_05_05.md` (commit d00f7f15) — full audit + three mmap surfaces + three drift hazards + cross-refs. Companion to doctrine §2.2 invariant #1.

### Q2: "Artifact primitive that distinguishes Static Note from Dynamic AI Weight"

**Status:** doctrine-relevant, canonized by Codex continuation.

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

**Action landed 2026-05-05:** `docs/STATIC_NOTE_VS_DYNAMIC_WEIGHT_DELIBERATION_2026_05_05.md` was promoted to `state: canon` by Codex continuation. Survey shows the static/dynamic distinction is already encoded (8 of 10 NodeKind variants are static, 2 are dynamic-rooted). Implementation added `NodeKind::is_dynamic_rooted()` + an exhaustive test + doctrine §2.2 invariant. The wrapper-type option was deliberately skipped because it adds drift surface without behavioral change.

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
  sign-off**: provenance ledger drift,
  and the `provenance_ledger` architectural-drift finding.
- Long-tail items A1–A7 + B1/B2/B3 runtime implementation phases are
  candidates for the next sustained session. The C-blocks and the
  B1/B2/B3 Tier-1 doctrine lifts are no longer pending.

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
