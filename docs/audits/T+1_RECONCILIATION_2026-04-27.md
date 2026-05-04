# T+1 Reconciliation Report — Round 1

**Date**: 2026-04-27
**Phase**: T+1 (Reconcile new doctrine docs with code)
**Audit floor**: ac8c6d28 (canonical HEAD; zero post-cutoff commits on `feature/landing-liquid-wave`)
**Mode**: Read-only verification — no code edits in T+1
**Author**: Claude builder (Opus 4.7 1M)
**Auditor**: deferred (Codex unavailable per user instruction; user adjudicating)

---

## Working tree adjudication

Investigated and classified as **benign**: the dirty payload (336 modified docs + 4 untracked clusters + Cargo.lock) is the in-flight 2026-04-27 documentation consolidation pass referenced in `READ_FIRST.md §5` and the canonical state doc.

- 336 modified docs receive a uniform 5-line `Index status` banner injection (2308 insertions / 20 deletions across the tree).
- 113 untracked files in `docs/_archive/` distributed across 10 expected clusters (plans_old 32 / google_research_packs 17 / architecture_handoffs 16 / sessions_handoffs 13 / audits_old 8 / sprint_sessions_old 7 / theme_shipped 6 / omega_retired 5 / kimi_goose_research 5 / knowledge_fusion_old 4).
- `agent_core/Cargo.lock` adds `blake3 + arrayref` — necessary substrate for the BLAKE3 Merkle chain landed in `fe97e512`.
- No Swift/Rust source files modified.

**Decision**: proceed with T+1 verification treating dirty docs as out-of-scope context. No mutations to the dirty payload.

---

## Verification results

### Check 1 — BLAKE3 Merkle chain (`fe97e512`) ↔ MASTER_FUSION §3.5

**Verdict**: SIGNIFICANT DRIFT (deferred to T+4.8 per user decision)

**What `fe97e512` actually shipped**: `agent_core/Cargo.toml +5`, `agent_core/src/oplog.rs +329/-9`. Verified bullet-by-bullet:
- ✅ `prev_hash BLOB NOT NULL DEFAULT (zeroblob(32))` schema column on `epistemos_oplog` (`oplog.rs:276-285`); idempotent ALTER guard at lines 291-301.
- ✅ `compute_chain_link()` BLAKE3 function (`oplog.rs:316-334`): folds `prev_hash` first, then `seq` / `lamport` / `actor_id` / `ts_unix_ms` / serde_json-canonicalized payload.
- ✅ Append-only confirmed: zero UPDATE/DELETE statements against `epistemos_oplog`; only one INSERT at `oplog.rs:460-462`.
- ✅ Reopen-resume tested (5 new D1 tests; 713 total green).

**Where doctrine and code diverge** (§3.5 claims four-layer hierarchy "substrate-real"):
| §3.5 claim | Code reality |
|---|---|
| Layer 1 `RunEventLog` | **Type does not exist** — no `RunEvent` enum, no `RunEventLog` struct in `agent_core/`. |
| Layer 2 `MutationEnvelope` | **Struct does not exist** — commit message references `prev_hash: [u8; 32]` on it, but type absent from tree. |
| Layer 3 `AgentEvent` | Exists at `epistemos-core/src/agent_runtime.rs:22-28` with 4 fields (`sequence`, `phase`, `payload`, `timestamp`) — **no prev_hash, no integrity_hash, no link to MutationEnvelope**. |
| Layer 4 `GraphEvent` | Exists at `substrate-rt/src/graph_event.rs:20-33` as 64-byte fixed-size POD (CursorMove, EditDelta, LayoutUpdate, McpTokenChunk, AgentFrameTick) — **no link to AgentEvent or mutation chain**. |
| 10 durable-event fields | `Op` struct (`oplog.rs:80-96`) has 5 of 10. Missing: event_id, run_id, schema_version, sensitivity, integrity_hash (computed but not stored). |
| `RunEvent::MutationCommitted { envelope }` projection variant | **Does not exist** — no projection wiring between any of the 4 layers. |
| Hashing redacts secrets BEFORE hashing | `compute_chain_link` calls no redaction. Currently safe (OpPayload has only graph mutation fields), but **not future-safe**. |

**Diagnosis**: `fe97e512` shipped a real substrate primitive (OpLog with BLAKE3 chain) but §3.5's broader "four-layer hierarchy is substrate-real" overstates current code. Under the existing chronological queue, **T+4.8** is explicitly "MutationEnvelope pattern (typed; not broad NotificationCenter)". The aspirational types will be built there.

**Decision (per user, 2026-04-27)**: skip the doctrine refresh now; T+4.8 will build the missing layers; refresh §3.5 tense post-T+4.8. Tracked as `Drift Q1` in TaskList.

### Check 2 — AnyView count = 0 in production paths (`ac8c6d28`)

**Verdict**: CLEAN ✅

11 grep hits total, all in `Epistemos/Views/Graph/HologramOverlay.swift` lines 100, 121, 122, 124, 198, 212, 282, 655, 656, 658, 922 — every hit comment-only documenting doctrine §6 #6. `grep 'AnyView('` → 0 constructor calls. Variant searches (`(any View)`, `erasedToAny`, `eraseToAnyView`, `.any()` extension) → 0 hits.

`ac8c6d28`'s claim "16 violations resolved" verified.

### Check 3 — §6 status table spot-check

**Verdict**: 40% drift on 5-sample (3 MATCH, 2 OVERSTATED, 1 UNDERSTATED) ⚠️

| Item | §6 says | Code says | Verdict |
|---|---|---|---|
| V1.8 Halo recall chip | ✅ | Full FSM + button + controller shipped | MATCH |
| WS2.1 EpistemosOperatingMode | ✅ "5 modes (fast, thinking, research, agent, liveAgent)" | Enum has **4 cases**: fast/thinking/pro/agent — research/liveAgent absent | OVERSTATED |
| V1.10 6-state Halo FSM | 🟡 | 6 states + 1 error fully wired (`HaloState.swift:60` + `HaloController.swift:205-209`) — shipped | UNDERSTATED |
| WS3.1 AnthropicProvider | 🟡 | Rust complete (claude.rs/bridge.rs/agent_loop.rs); Swift UI for computer_use/MCP toggles not wired | MATCH |
| WS1.1 LocalTextModelID | ⚪ "17 models (6 MLX + 11 GGUF)" | Enum has ~42 cases (40 MLX + 2 GGUF) | OVERSTATED |

**Decision (per user, 2026-04-27)**: defer §6 patches until T+13 master hardening audit, which explicitly produces `USER_WIRING_CAPABILITY_MAP.md` and `MASTER_HARDENING_WIRING_AUDIT.md` and will rebuild the status picture comprehensively. The single trivial promotion (V1.10 → ✅) is queued as `Drift Q2` to land when the consolidation pass commits (MASTER_FUSION.md is currently untracked). The harder reconciliations (WS2.1 mode count, WS1.1 model count) tracked as `Drift Q3` and `Drift Q4` for T+13 / T+15.8 respectively.

### Check 4 — Archive faithfulness (`docs/_archive/`)

**Verdict**: FAITHFUL ✅

113 archive files distributed correctly across all 10 expected clusters. 5 sampled files (one per cluster, varied) bit-identical to HEAD originals **except** for the expected 5–6-line `SUPERSEDED-HISTORICAL` / `TRANSIENT-CANDIDATE` banner injection. Reference-fallback algorithm (MASTER_FUSION §0.1) returns unique basename matches.

---

## Drift queue (do not lose)

| ID | Drift | Phase to resolve | Rationale |
|---|---|---|---|
| Q1 | §3.5 four-layer hierarchy not implemented | post-T+4.8 | T+4.8 builds MutationEnvelope; refresh §3.5 tense after |
| Q2 | §6 V1.10 status 🟡 should be ✅ | post-consolidation | MASTER_FUSION.md is untracked; wait for consolidation commit |
| Q3 | WS2.1 enum: spec says 5, code has 4 (research/liveAgent missing) | T+13 | Master hardening audit produces USER_WIRING_CAPABILITY_MAP |
| Q4 | WS1.1 model count: spec says 17 (6+11), code has ~42 (40+2) | T+13 / T+15.8 | T+15.8 explicitly handles model expansion |

All four queued in TaskList with `kind: drift-queue` metadata.

---

## T+2 stash@{0} adjudication

**Decision**: defer (do not pop, do not discard).

Stash@{0} content (`session-stash-2026-04-27: W9.21 PR4 (X salvaged) + W9.8 wire-up partial; restart-fresh per user`) matches the canonical state doc's exact reference. W9.21 is Honest FFI (multi-PR Bucket C), W9.8 is approval modal wire-up — both surfaces re-touched during T+13 (Hardening + Wiring audit) and T+14 (Deterministic Knowledge Runtime). Re-implement clean during those phases per the prompt's default.

Stashes @{1}/@{2}/@{3} are older parallel sessions — out of scope; defer entirely.

---

## Phase status after T+1

| Phase | Status |
|---|---|
| T+0 Self-audit retrace | ✅ done |
| T+1 Doctrine ↔ code reconciliation | ✅ done (this doc) |
| T+2 Stash adjudication | ✅ deferred (decision recorded) |
| T+3 Phase S blockers | 🟡 entering — deliberation brief next |
| T+4 → T+15 | ⚪ queued |

Proceeding to T+3 deliberation brief.
