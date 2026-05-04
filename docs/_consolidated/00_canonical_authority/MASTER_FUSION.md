# MASTER_FUSION.md — The Single Canonical Execution Plan

> **Authored**: 2026-04-27 by consolidation pass synthesizing 8 master-plan-class documents + 218 research files.
> **Role**: The "ONE checkable list" the user requested. Replaces the need to read 5+ overlapping master plans by collapsing them into a single layered document where each layer answers one question.
> **Originals**: untouched at `~/Downloads/` and `docs/_consolidated/50_research_corpus/master_plans/`.
> **Status of this fusion**: CANONICAL. Sits one tier *above* `MASTER_BUILD_PLAN.md` (operational queue) and one tier *below* `PLAN_V2.md` (architectural doctrine). Reading order: this → MASTER_BUILD_PLAN §0 loop.

---

## §0 — How to use this document

Every section answers one question. If you only have 10 minutes, read §1 + §3 + §6 + §7 (the executive view). If you have 1 hour, read everything. If you're a fresh agent: read §1 first, then jump to §6 (the checklist) and start ticking items.

**Status legend** (carried from `EPISTEMOS_MOAT_AND_OPTIMIZATION_MASTER.md`):

- ✅ **Shipped** + wired end-to-end + user-facing
- 🟡 **Partial** — code exists, integration pending
- 🟠 **Forward-compat scaffold** — deliberately gated on future SDK / Apple API
- 🔴 **Drift** — doc says one thing, code says another
- ❓ **Unverified** — flagged for grep/test before status changes
- ⚪ **Pending** — not started, queued for sprint
- 🆕 **New from research** — surfaced in this fusion, not yet in canonical doctrine

**Canonical authority hierarchy** (normative, not merely read order):

1. **`docs/architecture/PLAN_V2.md`** — architectural truth. System shape, layered model, doctrine, non-negotiables. Wins over everything below.
2. **`CLAUDE.md`** — repo-specific code standards, provider matrix, file map, hard DO NOT list.
3. **`docs/MASTER_BUILD_PLAN.md`** — operational execution loop, queue, verification gates, WRV contract.
4. **`docs/plan/00_AUTHORITY_AND_ANTI_DRIFT.md`** — execution contract, anti-drift rules, pre-flight reads, verification requirements.
5. **`docs/plan/01_DOCTRINE.md`** — doctrinal rulings, provenance model, four-layer event hierarchy (§3.5 below), Hermes positioning, Concept Door / Depth Kernel (§16 below).
6. **`docs/plan/02_BUILD_MATRIX.md`** — Pro/MAS feature gating.
7. **`docs/plan/03_EXECUTION_MAP.md`** — per-item implementation depth.
8. **`docs/plan/04_PHASES.md`** — phase sequencing.
9. **`docs/plan/05_RESEARCH_INDEX.md`** — research lookup index.
10. **`docs/MASTER_FUSION.md`** (this document) — synthesis / checklist layer. Canonical as context. **Not the operational queue** — that role belongs to MASTER_BUILD_PLAN.

**Code reality is verification evidence, not architectural authority.** If code contradicts `PLAN_V2.md`, `CLAUDE.md`, or the master plan stack, mark the mismatch as **DRIFT** and surface it. Do not silently declare that code wins. The correct action is to either fix the code or propose an explicit doctrine amendment for human approval.

### §0.0 — Canonical audit floor (2026-04-25 cutoff)

**`ac8c6d28` is the canonical verified HEAD.** See `CODEX_VERIFIED_STATE_2026_04_25.md` for the full list of ~36 verified commits across two audit chains (Codex release-audit + Claude full_session_orchestrator). **Any commit, doc edit, file change, stash pop, or branch operation that happened after `ac8c6d28` — regardless of who did it, when, or how green it looked at the time — must be called into question and re-audited before being treated as canonical.**

**Quick audit-boundary facts**:
- D4 ✅ Hermes 36B → Qwen 3 8B fallback (16 GB Mac OOM Blocker resolved)
- W9.27 PR3 + D1 ✅ BLAKE3 Merkle chain on RunEventLog (the §3.5 four-layer event hierarchy's integrity layer is now substrate-real)
- Pass #3 ✅ docs/architecture/ fusion (Drift A + Drift B resolved per CANONICAL_AUDIT_LOG)
- AnyView 16-violation cleanup ✅ (top-of-queue Blocker from §6.10 closed)
- S.5 reliability ✅ all 5 gates green (baseline + ASAN + UBSAN + TSAN + soak_repeat)
- S.6 privacy ✅ verified (Privacy pane + manifest tests + 13-section sidebar)
- S.2 entitlements ✅ verified independently via `codesign -d`

**Stashed (not verified)**: `stash@{0}` preserves W9.21 PR4 + W9.8 partial wire — recoverable but not yet WRV-proven.

**Still open** at audit floor (per `CODEX_VERIFIED_STATE §4.3`): S.1 launched-app dogfood, S.7-9 App Store Connect / TestFlight / submission, ProseEditor performance instrumentation, Instruments p99 signpost proof for non-reliability paths, distribution-signed archive, plus the Master Hardening + Wiring + Product Expression Audit (Phase 1 discovery just started in fresh Claude session at cutoff).

### §0.1 — Reference-fallback resolution (READ THIS — binding for any agent doing path-based reads)

When you read this fusion (or any canonical doc) and follow a reference path, **the path may be null, missing, or moved**. The repo went through cleanup passes 2026-04-27 that organized SUPERSEDED-HISTORICAL and TRANSIENT-CANDIDATE files into `docs/_archive/<cluster>/`. Most files exist in **both** their original location AND in `_archive/<cluster>/` (so legacy references still resolve), but some may have been moved to archive only.

**Resolution algorithm** when a referenced file is not found at its stated path:

```
1. Read the path as written. If it exists, use it. Done.

2. If NOT found at the stated path:
   a. Extract the basename (e.g., `OMEGA_ARCHITECTURE.md`).
   b. Search `docs/_archive/` recursively:
      find docs/_archive -name "<basename>" -type f
   c. If exactly one match: use it. Note in your audit that path was archive-resolved.
   d. If multiple matches (rare; happens when name collisions across clusters were
      disambiguated with src-dir prefix): prefer the one whose cluster matches the
      original path's parent dir (e.g., docs/plans/X.md → _archive/plans_old/X.md).
   e. If no match in archive: search `docs/_consolidated/50_research_corpus/`
      recursively (the docs may have been folded into a research cluster).
   f. If still no match: report the path as `[BROKEN-REFERENCE: <original-path>]`
      in your output. Do not guess. Do not silently substitute.

3. If the file IS found via fallback, read its banner (first 10 lines):
   - If banner says SUPERSEDED-HISTORICAL: this file is no longer canonical. Read
     the "Superseded by:" pointer instead. The original is preserved for state
     recovery only.
   - If banner says TRANSIENT-CANDIDATE: this file was a one-off prompt or session
     artifact. Read for context only.
   - If banner says CANONICAL-* or DEFERRED-RESEARCH: still active; treat as
     normally referenced.
```

**Cluster naming conventions in `docs/_archive/`** (so you can guess the right cluster fast):

| Cluster | What's in it |
|---|---|
| `_archive/plans_old/` | Older plan tree predecessor (`docs/plans/*` from 2026-03-03 through 2026-03-28) |
| `_archive/architecture_handoffs/` | Phase handoffs from `docs/architecture/` (CHAT_TRANSPARENCY, PHASE_*_HANDOFF, CANONICALIZATION, etc.) |
| `_archive/sprint_sessions_old/` | Older sprint plans (sprint-agent-* + sprint-omega-2/5/6); kept `sprint-omega-1-foundation` in place because it's CANONICAL-OPERATIONAL |
| `_archive/google_research_packs/` | Both `google-agent-research-pack-2026-03-18/` and `google-research-pack-2026-03-18/` |
| `_archive/knowledge_fusion_old/` | KF system retired (PHASE0-* + architecture.md + README.md from `knowledge-fusion/`) |
| `_archive/omega_retired/` | Omega system retired (OMEGA_*, CLAUDE_OMEGA, MASTER_SESSION_PROMPT) |
| `_archive/theme_shipped/` | Theme refactor shipped (THEME_*, CHANGELOG_THEME_REFACTOR) |
| `_archive/kimi_goose_research/` | Kimi/Goose comparative research (framework selection complete) |
| `_archive/sessions_handoffs/` | One-off session reports + dated handoffs (SESSION_*, *_HANDOFF_*, handoff-prompt) |
| `_archive/audits_old/` | Older one-off audits (AUDIT_REPORT, V1_SCOPE_BOUNDARY, EPISTEMOS_FUSED_v3, IMPLEMENTATION_BLUEPRINT, FINAL_VERIFICATION_CHECKLIST, PHASE_CHECKLIST, POST_V1_OPPORTUNITY_MAP, ROADMAP_NEXT_3) |

**Canonical files NEVER appear in `_archive/`** — if you find a canonical-class file there, treat it as drift and surface it. Canonical files always stay in their authority-chain location.

**Most reference paths still work** — the cleanup pass copied (not moved) files for the SUPERSEDED group, so old references resolve at their original paths. The archive is for *concept-organized navigation*, not for *replacing* the original tree. But if a path is broken, the algorithm above will find it.

**See `docs/_archive/MANIFEST.md`** for the exhaustive per-cluster file list.

**Status legend reminder for this hierarchy**: `EPISTEMOS_MOAT_AND_OPTIMIZATION_MASTER.md`, `EPISTEMOS_MEGAPROMPT.md`, `master_plan_doc.md`, `EPISTEMOS_MASTER_THESIS.md`, and `harness-engineering-thesis.md` are research-grade master plans that fed into this fusion. They are CANONICAL-RESEARCH (load-when-touched), NOT in the authority chain above.

---

## §1 — What Epistemos is (the one-paragraph thesis, distilled from 5 docs)

Epistemos is a **macOS-native cognitive operating system** for personal knowledge — a hardware-symbiotic Neural OS that treats the MacBook as a physical extension of the neural network rather than a dumb terminal for cloud APIs. The architecture is Swift 6.2 strict-concurrency UI + Rust (UniFFI) sovereign control plane + Metal rendering + GRDB persistence + MLX inference + Apple Foundation Models on macOS 26. The single-sentence claim: **sub-5ms meta-memory retrieval on a 16 GB M-series Mac via the Stateful Rotor + ButterflyQuant + zero-copy IPC + multi-objective KV quantization + asynchronous epoch reclamation, distilled overnight by the NightBrain consolidator.** The market thesis (`EPISTEMOS_MASTER_THESIS.md`): the path to useful, personal, trainable AGI runs through the local computer, not the cloud. The product thesis (`master_plan_doc.md`): turn fragmented personal knowledge into a usable, inspectable reasoning environment instead of leaving it scattered across notes, code, files, and chats. The distribution thesis (`ambient_V1_DECISION.md`): V1 ships sandboxed via Mac App Store with **Halo + Contextual Shadows** as the only differentiator; Pro / direct distribution ships later.

---

## §2 — The 5 master plans, what each contributes, and how they layer

The user said: *"5 super large dense master plans that were supposed to fuse to one that I just check off the list over time."* Here are the 8 master-plan-class documents identified, ordered by abstraction layer (most concrete at top):

| # | Doc | Date | KB | Layer | What it contributes |
|---|---|---|---|---|---|
| 1 | `EPISTEMOS_MOAT_AND_OPTIMIZATION_MASTER.md` | 2026-04-27 | 52 | **Audit** — verifies | Post-implementation file:line audit of 20 shipped moats + 13-item drift inventory + verification queue |
| 2 | `2026-03-27-master-gap-closure-plan.md` | 2026-03-27 | 124 | **Gap closure** — 30-file Opus 4.6 audit | Explicit blockers (training data unwired, deploy gate auto-passes, AX capture wrong app, no training run completed, 93% Epistemos-symbol-QA data mix) |
| 3 | `EPISTEMOS_MEGAPROMPT.md` | 2026-03-28 | 40 | **Sprint** — operationalizes | 7 workstreams × 17 days × file-level code guidance; pre-flight greps; acceptance criteria |
| 4 | `EPISTEMOS_PHASE_I_IMPLEMENTATION_GUIDE.md` | undated | 86 | **Phase I detail** | Pure-Rust Agent Runtime — UniFFI streaming bridge first, Provider trait extraction, Anthropic + OpenAI providers; 8–12 MB binary, <10ms cold start |
| 5 | `PLAN_V2_UPDATED.md` | undated | 60 | **Doctrine** — what to build | 27 sections: 3-runtime split (GGUF/MLX/Remote), 6 capability specs, Phases 1–6.5, BoltFFI audit, editor truth, anti-pattern register |
| 6 | `master_plan_doc.md` | undated | 26 | **Cognitive blueprint** — why | 16 phases of cognitive capability (ontology → decay → CLI → harness → hybrid brain → JIT context → Hermes → depth markers → distillation → NightBrain → brain dumps → cognitive data structures → ETL → intake valve → raw thoughts → conversation state) |
| 7 | `EPISTEMOS_MASTER_THESIS.md` | 2026-03 | 38 | **Positioning** — market thesis | "Harness Engineering and the Death of the Cloud" + Stateful Rotor + 5 hardware-symbiotic engines |
| 8 | `harness-engineering-thesis.md` | 2026-03 | 48 | **Positioning variant** — engineering thesis | Concurrency lattice, hidden depth, convergence thesis (3 forces: MLX-ready + PKM paradigm shift + macOS moat) |

**Relationship model:**
```
THESIS + HARNESS (why)         ──┐
   ↓                              ├── Justify
master_plan_doc.md (cognitive)  ──┘
   ↓
PLAN_V2_UPDATED.md (architecture/doctrine)
   ↓
EPISTEMOS_MEGAPROMPT.md (sprint ops, 7 workstreams × 17 days)
   ↓
EPISTEMOS_PHASE_I_GUIDE.md (Phase I deep dive)
   ↓
2026-03-27-master-gap-closure-plan.md (Opus 4.6 audit, 30 files)
   ↓
EPISTEMOS_MOAT_AND_OPTIMIZATION_MASTER.md (post-impl audit, 2026-04-27)
   ↓
[THIS DOCUMENT]: collapse all 8 into one checkable list
   ↓
docs/V1_5_IMPLEMENTATION_TRACKER.md (live status board)
```

---

## §3 — Convergent claims (where 3+ docs agree — these are bedrock)

These are the architectural positions held by multiple master plans. Treat them as **non-negotiable**:

1. **Memory retrieval, not compute, is the bottleneck.** Sub-5ms via Stateful Rotor is the architectural core. *(THESIS §I, HARNESS §I, PLAN_V2 §8)*
2. **Local models cannot reliably call tools autonomously.** 4B–27B hallucinate schemas; only cloud models get full agent capability. **Honest capability gating is the discipline.** *(MEGAPROMPT §2.0, MOAT §2.18, master_plan §Phase 5/7)*
3. **Rust is sole control-plane authority.** Swift UI cannot route models or policies — all decisions in Rust FFI. *(PLAN_V2 §3.1, MEGAPROMPT, PLAN_V1)*
4. **Apple Silicon unified memory = zero-copy advantage.** 200 GB/s shared bandwidth, `MTLBuffer.storageModeShared` eliminates DMA. *(THESIS §VII, HARNESS §VIII, PLAN_V2 §23.5)*
5. **NightBrain 3 AM consolidation gated on battery + thermal.** FSRS decay + memory distillation during sleep. *(MOAT §2.10 ✅, master_plan §Phase 10, THESIS §IV Engine 4)*
6. **Hermes orchestration via MCP + CLI bridge — sidecar, NOT inference.** Python subprocess for cloud APIs / skills / memory / multi-step planning. *(MEGAPROMPT §3.5/§7, master_plan §Phase 3/7, MOAT §2.19)*
7. **Structured conversation state (JSON state machine), not linear transcripts.** *(master_plan §Phase 16 ✅, MOAT §2.8, PLAN_V2 §16)*
8. **Screen capture → OCR → retrieval signal.** "What you were looking at when you had that insight." *(THESIS §V, HARNESS §VI, PLAN_V2 §code-editor benchmarks)*
9. **Entity extraction + nested ontology, NOT flat tags.** L1/L2/L3 depth markers, meta-analysis edges. *(master_plan §Phase 1/8, MEGAPROMPT §4.2, MOAT semantic gravity)*
10. **Raw thoughts = quarantined-but-retrievable.** Deterministic core stays structured; raw archive unlocks for ambient retrieval. *(master_plan §Phase 15, MOAT Halo, MEGAPROMPT §4.2)*
11. **Multi-objective KV cache precision allocation.** KVTuner + PM-KVQ + ThinKV — layer-wise MOO, progressive right-shift decay, thought-adaptive sparsity. *(THESIS §II Pillar Two, HARNESS §III, PLAN_V2 §BoltFFI audit)*
12. **Asynchronous Rust concurrency: epoch-based, MVCC, yield-aware.** Lock-free reads, atomic rotation swaps, `crossbeam-epoch` for old-version reclamation. *(THESIS §II Pillar Three, HARNESS §V, PLAN_V2 §BoltFFI)*
13. **Code editor: keep native macOS editing in Swift/TextKit 2; move parsing/tokens/diagnostics to Rust only when benchmarks justify.** *(PLAN_V2 §22.4 + §23, "1. Where Models Agree.md" — 3-model consensus, `workspace_epistemos_code_verdict.md`)*
14. **First BoltFFI migration candidate is graph data-plane (data loading + queries + search) behind a compatibility flag. Do NOT do mass migration.** Keep UniFFI for cold control-plane + permission/approval flows. *(3-model consensus per "1. Where Models Agree.md" §1, PLAN_V2 §22.2/§22.6)*
15. **Prefer typed buffers / stable ABI structs / numeric IDs + shared-memory for huge payloads. Avoid JSON strings on hot paths.** *(3-model consensus, PLAN_V2 §22.2)*

---

## §3.5 — Four-layer event hierarchy (binding doctrine, audit-resolved 2026-04-27)

The event system has **four distinct layers**. They were previously framed as a hot/cold split; that framing was incomplete. The corrected canonical model:

```text
RunEventLog       = durable record of observable runtime activity
MutationEnvelope  = durable record of graph/state mutation
AgentEvent        = hot UI projection
GraphEvent        = Metal/render projection
```

### Layer 1 — `RunEventLog` (durable runtime history)

Records: provider lifecycle, run status transitions, tool call start/finish, permission requests, errors, checkpoints, redaction reports, **committed graph mutations** (as `RunEvent::MutationCommitted { envelope }`).

High-volume token deltas, thinking deltas, bash output, and tool-call chunks **must not bloat** the durable event log unboundedly. They roll into a compressed transcript path such as `transcript.jsonl.zst` or an equivalent chunked transcript store.

### Layer 2 — `MutationEnvelope` (durable graph/state mutations)

A `MutationEnvelope` appears inside the run log as `RunEvent::MutationCommitted`. It is **NOT** the universal source of truth for token deltas, bash output, provider heartbeat events, or pure read-only progress events.

Required fields (canonical):
```rust
pub struct MutationEnvelope {
    pub id: String,
    pub run_id: String,
    pub sequence: u64,
    pub caused_by_event_id: Option<String>,
    pub actor: ActorRef,
    pub approval_id: Option<String>,
    pub status: MutationStatus,        // pending | committed | failed | reverted
    pub created_at_ms: i64,
    pub committed_at_ms: Option<i64>,
    pub op: GraphMutation,
    pub sensitivity: Sensitivity,
    pub reversibility: Reversibility,
    pub integrity_hash: String,
    pub schema_version: u32,
}
```

### Layer 3 — `AgentEvent` (hot UI projection)

Drives chat cards, thinking traces, tool cards, approval cards, artifact-ready events, status badges, visible execution state.

- `AgentEvent` may exist **without** a `MutationEnvelope` when the event is read-only or ephemeral (token streaming, thinking delta).
- A committed `MutationEnvelope` **must** produce the relevant `AgentEvent` projection unless explicitly marked `projection-suppressed` with justification.

### Layer 4 — `GraphEvent` (Metal/render projection)

Drives node pulses, edge flashes, phase-in animations, session focus, retraction visuals. Derived only from graph-relevant mutations or graph-relevant read events. Never lies about what cognition touched.

### Canonical rule

```
RunEventLog      records what happened.
MutationEnvelope records what changed.
AgentEvent       renders what the user should see.
GraphEvent       animates what cognition touched.
```

### Commit ordering (the outbox discipline)

```
1. receive/create RunEvent
2. if event proposes graph/state change, validate into MutationEnvelope
3. classify sensitivity + apply redaction
4. commit RunEvent + MutationEnvelope inside the persistence boundary
5. enqueue projection work into projection_outbox
6. commit
7. only after commit, derive and publish AgentEvent + GraphEvent
```

**Do not emit UI success before durable state succeeds.** If commit fails: emit failure event, mark mutation `failed`, do NOT emit `ArtifactReady`, do NOT animate graph success.

### Integrity (BLAKE3 / Merkle chain — D1 in 03_EXECUTION_MAP)

`RunEventLog` is **append-only**, ordered by `(run_id, sequence)`, and integrity-linked. Each durable event includes `event_id`, `run_id`, `sequence`, `schema_version`, `created_at`, `actor`, `sensitivity`, `kind`, `prev_hash`, `integrity_hash`. Hashing rule: canonicalize payload, include `prev_hash`, BLAKE3 (or repo-approved hash), redact secrets BEFORE hashing.

---

## §4 — Divergent claims (where docs disagree — pick a winner here)

These are real architectural choices the master plans don't agree on. We adjudicate:

| Topic | Doc A position | Doc B position | **Verdict** |
|---|---|---|---|
| **Agent on local models** | MEGAPROMPT §2.2: DAG executor + grammar-constrained local tool calls | MOAT §2.18: agent modes DISABLED for local; only cloud gets agent badge | **MOAT wins. Honest capability gating is sacred.** Local models can use grammar-constrained tool calls under supervised structures (research mode SOAR) but never carry the "agent" capability label. The first time we fake it, the moat cracks. |
| **TurboQuant scope** | Old-research brief: "PolarQuant + QJL, 3-bit signatures, apply to note index" | `Epistemos Instant Recall` doc: PolarQuant uses recursive multi-level (≥3 bits to angles); QJL is 1-bit inner-product; both are model-level KV optimizations | **Instant Recall wins.** Note index uses **binary quantization (1-bit, 32× memory reduction)** via `usearch` HNSW. PolarQuant/QJL are deferred to Phase 4 (Mamba internal state). |
| **Workspace ontology placement** | PLAN_V2 §19: Phase 5 product feature (isolated workspaces, separate ontologies, action permissions) | master_plan: focuses on note-level depth markers, no explicit phase | **Both correct, orthogonal.** master_plan = cognitive capability phases. PLAN_V2 = product features. Workspace = §5 feature. |
| **Overseer = SSM?** | PLAN_V2 §10.3: SSM is memory sidecar, NOT default planner | THESIS §IV: memory distillation (SSM-adjacent) is core consolidation engine | **Both agree, different framing.** SSM lives in the *memory* lane, not the *reasoning* lane. Don't make it the planner. |
| **CodeEditSourceEditor vs custom TextKit 2** | "1. Where Models Agree.md": 3-model split — GPT keep, Claude drop-if-blocking, Gemini either | `workspace_epistemos_code_verdict.md`: lock to TextKit 2 + SwiftTreeSitter + Rust background brain | **TextKit 2 surface wins.** CodeEditSourceEditor is "not ready for production" per its own README. Use Apple's native TextKit 2 for IME/undo/accessibility/scrolling; tree-sitter parsing in a Rust background actor; Metal viz only for minimap/heatmaps. |
| **Tiptap-in-WKWebView vs port AppFlowy vs native Swift Document editor** | User intuition: WKWebView feels heavy; AppFlowy is in Rust + Dart, maybe a moat? | `EDITOR_VERDICT_TIPTAP_VS_APPFLOWY.md` (2026-04-27): WKWebView overhead is real but bounded; AppFlowy is Flutter (Dart), porting it = catastrophic ROI; Tiptap is the gold standard for block WYSIWYG; the editor is NOT the moat | **Leave Tiptap alone wins.** Per `workspace_gpt_workspace_synthesis.md` Document = Tiptap-in-WKWebView with pre-warmed shared `WKProcessPool` + transaction-summary bridge + local bundle. Take inspiration from AppFlowy's data model patterns (block ID, slash commands, embed dispatch) — NOT their UI. **Benchmark before optimizing**: any editor change must be preceded by `EDITOR_BENCHMARK_BASELINES.csv` showing real regression. |
| **Rope choice if Rust owns canonical text** | GPT: Ropey safe default | Claude: prefer delaying canonical-buffer move | **Delay first.** Canonical text stays in Swift `NSTextStorage` until benchmarks prove the bottleneck. If/when needed, Ropey with snapshot semantics. |
| **Distribution scope V1** | PLAN_V2: macOS-only v1, double-helper SMAppService for App Store | MOAT: implies later Pro vs Standard tier (multi-profile workspace) | **`ambient_V1_DECISION.md` decides.** V1 = sandboxed App Store with Halo + Contextual Shadows as the *only* differentiator. Pro / direct ships later. 6-week roadmap. |
| **17-model lineup vs 6-model** | MEGAPROMPT §1.1: full 17-model `LocalTextModelID` (6 MLX + 11 GGUF) with RAM tiers | MOAT (April audit): doesn't detail the 17-model expansion | **MEGAPROMPT is the roadmap; MOAT audits current state.** Both correct at different times. The 17-model expansion is a Phase 2/3 deliverable. |

---

## §5 — Cognitive blueprint: the 16 phases (from `master_plan_doc.md`)

These are the **why** — what cognitive capability each phase unlocks. They don't map 1:1 to product phases, but they're the philosophical scaffolding the architecture serves. Status comes from the MOAT audit + V1.5 tracker:

| Phase | Capability | Status |
|---|---|---|
| 1 | Intelligent Semantic Ontology (nested knowledge tree) | 🟡 Ontology Classifier scaffolded; AFM caller ❓ |
| 2 | Organic Decay Engine (Ebbinghaus / FSRS-6) | ✅ FSRSDecayStore + Review Sidebar shipped |
| 3 | Omni-CLI Native Bridge (invisible PTY daemon, SwiftUI translation) | 🟡 Hermes sidecar shipped; full CLI tunnel design at `capability-tunnels.md` |
| 4 | Full Harness Wiring (BootstrapPacketBuilder integration) | 🟡 Harness stubs unit-tested; live UI wiring pending |
| 5 | Hybrid-Brain Architecture (local AFM 3B + cloud Hermes) | ✅ Capability handshake + honest gating shipped |
| 6 | Just-In-Time Context Injection (dynamic prompt hot-swapping) | ✅ PromptTree (JSPF + PTF + Relocation Trick) |
| 7 | Hermes as Chief of Staff (multi-agent orchestration via MCP) | ✅ Hermes orchestration sidecar; MCP partial |
| 8 | Cognitive Depth Markers (L1/L2/L3 + meta-analysis edges) | 🟡 Depth color tint shipped; altitude/radius cached but unused |
| 9 | High-Performance Session Distillation | ✅ ConversationStateClassifier (50-turn → 600-1200 tokens, 95% compression) |
| 10 | Model Metabolism / Overnight Consolidation | ✅ NightBrainScheduler + PowerGate; PowerGate call site ❓ |
| 11 | Omni-Contextual Brain Dumps (voice anchor everywhere) | ✅ ReadAloudButton + VoiceInputButton |
| 12 | Cognitive Data Structures (JSON interpretation directives) | 🟡 IntakeValve schemas shipped; structured-vs-prose policy partial |
| 13 | Unstructured Data Audit / ETL | ⚪ Pending (vault-wide auditing, legacy cleanup) |
| 14 | Intake Valve (synchronous structural routing) | ✅ IntakeValve + QuarantineArchive shipped |
| 15 | Deterministic Core vs Ambient Retrieval | ✅ Halo recall chip + raw-thoughts archive shipped |
| 16 | Structured Conversation State | ✅ ConversationStateClassifier; ChatCoordinator wiring ❓ |

---

## §6 — THE ONE CHECKABLE EXECUTION LIST (the user's actual ask)

This is the union of all master-plan checklists, deduped, statused, sequenced. Sourced from `EPISTEMOS_MEGAPROMPT.md` (workstreams), `EPISTEMOS_MOAT_AND_OPTIMIZATION_MASTER.md` (drift inventory), `2026-03-27-master-gap-closure-plan.md` (gap closure), `ambient_V1_DECISION.md` (V1 scope), `MASTER_BUILD_PLAN.md` (operational queue).

### §6.1 — V1 SHIP-CRITICAL (sandboxed Mac App Store; 6-week roadmap per `ambient_V1_DECISION.md`)

| # | Item | Status | Effort | Source |
|---|---|---|---|---|
| V1.1 | App Store entitlements populated (not `<dict/>`) | ✅ | — | MEGAPROMPT §6 → MOAT (no flag) |
| V1.2 | `PrivacyInfo.xcprivacy` exists | ❓ | XS | MEGAPROMPT §6 |
| V1.3 | Deployment target = 15.0 (not 26.0 conflict) | ❓ | XS | MEGAPROMPT §6 |
| V1.4 | Top 10 `try?` → `do/catch` | ❓ | S | MEGAPROMPT §6 |
| V1.5 | Top 50 `unsafe` blocks annotated with `// SAFETY:` | ❓ | M | MEGAPROMPT §6 |
| V1.6 | All 2,679 tests pass; zero regressions | ❓ | — | MEGAPROMPT §6 |
| V1.7 | ASAN/TSAN/UBSAN clean | ❓ | — | MEGAPROMPT §6 |
| V1.8 | **Halo recall chip** ✅ shipped + ambient retrieval | ✅ | — | MOAT §2.17 |
| V1.9 | **Contextual Shadows** popover (NSTextView caret tracking + nested editor + speculative completions) | 🟡 | M | `ambient_contextual_shadows_blueprint.txt` |
| V1.10 | 6-state Halo FSM | 🟡 | S | `ambient_V1_DECISION.md` |
| V1.11 | Stack lock: Model2Vec + usearch + tantivy + RRF | 🟡 | S | `ambient_V1_DECISION.md` |
| V1.12 | App Store review notes prepared (`docs/release/`) | ✅ | — | docs/release/ |

### §6.1.1 — V1 ship-critical hardening (5 canonical findings from `RELEASE_HARDENING_CANONICAL_PLAN_2026-04-20.md`)

When closing V1 release blockers, the **5 canonical findings** to address (file:line evidence in source doc):

| # | Finding | Hot-spot | Fix shape |
|---|---|---|---|
| RH.1 | **Silent-answer = post-processing bug** (NOT think-tag parser) | `Engine/Extensions.swift` | `UserFacingModelOutput` must **fail-open** when it can't confidently split reasoning from answer text. Heuristic stripping = narrow fallback only. ThinkTagStreamRouter is correct primitive; keep. |
| RH.2 | **Local freezing = actor/lifecycle problem** | `KnowledgeFusion/MLXInferenceBridge.swift` + `LocalAgent/LocalAgentLoop.swift` | UI state stays on `@MainActor`. Model load/generate/unload **must not**. Token gen + matmul **never** hops through `MainActor.run` in hot loop. Long-term: dedicated inference actor + stricter model supervisor. |
| RH.3 | **Local model safety = runtime-policy gap** (not just picker) | `Engine/MLXInferenceService.swift` + `State/InferenceState.swift` + `App/EpistemosApp.swift` | Unified runtime policy: admission control before load, one-active-model discipline, eviction on pressure, **explicit refusal** instead of swap death. Honest "this model can't load safely on this machine right now" error. |
| RH.4 | **FFI multi-turn continuity** (biggest engine-level win still missing) | `agent_core/src/bridge.rs` + `agent_core/src/agent_loop.rs` + `agent_core/src/context_loader.rs` | Swift holds the conversation; Rust still starts fresh each session call. Native prior-message support remains **P1 architectural task**. Tool-call continuity + prompt caching + thinking-signature preservation all improve once FFI becomes natively conversational. |
| RH.5 | **Thinking UI is serviceable but not end-state** | `Views/Chat/ThinkingPopoverView.swift` + `Views/Chat/MessageBubble.swift` | Tracked separately; lower priority than RH.1-4. |

**Plus immediate concrete bugs from `PERF_REPAIR_REPORT_2026_04_21.md`** (file:line citations in source):
- Semantic note lookups not propagated into planner context (`ChatCoordinator.swift`)
- Fenced ` ```tool_call ` blocks not parsed (`Omega/Inference/ToolCallParser.swift:344`)
- MLX Metal working set never released on unload (`Engine/MLXInferenceService.swift`)
- Direct-stream cloud path advertises app tools it can't execute (`Engine/PipelineService.swift`)
- Mini Chat shows `Thinking` while runtime in `Tools` mode (UI lying about execution path)

**Chat transparency status from `CHAT_TRANSPARENCY_PLAN_2026-04-19.md`** (already shipped — do NOT redo):
- ✅ EffectiveModelBadge under every assistant reply (Batch I `5ddd6db9` + Batch J `cfad9a99`)
- ✅ Routing rationale popover on model badge (Batch X `7235802f`)
- ✅ Pre-submit preview in context side panel (Batch Y `7ea2edfe`)
- ✅ Brain → Context side panel rename (Batch S `8d98661c`)
- ✅ Claude Code-style collapsible sections on Context panel (Batch BB `3187f820`)
- ✅ Error bubble recovery buttons authFailure / modelNotReady (Batch W `da1d13d4`)

### §6.2 — POST-V1 PRO MODE (direct distribution; tier "full" entitlements)

| # | Item | Status | Effort | Source |
|---|---|---|---|---|
| Pro.1 | Double-helper SMAppService split (sandboxed UI + non-sandboxed Gateway) | 🟡 | L | `Epistemos Omega — Dual-Brain Hardware-Action Protocol.md` §"APP STORE DISTRIBUTION" |
| Pro.2 | TCC entitlements: Accessibility, Screen Recording, Microphone | ❓ | M | PLAN_V2 §6 |
| Pro.3 | Hardened Runtime + Notarization | ⚪ | S | PLAN_V2 §15 |
| Pro.4 | OpenClaw integration (Pro-only Phase K) | 🟠 | XL | `OPENCLAW_FEATURE_SPEC.md` (DEFERRED) |

### §6.3 — DUAL-BACKEND INFERENCE (MEGAPROMPT WS1; Sprints 1–2, Days 1–4)

| # | Item | Status | Effort | Source |
|---|---|---|---|---|
| WS1.1 | `LocalTextModelID` has all 17 models (6 MLX + 11 new GGUF) | ⚪ | M | MEGAPROMPT §1.1 |
| WS1.2 | Every model: `ramRequirementQ4GB` + `ramRequirementQ8GB?` | ⚪ | S | MEGAPROMPT §1.1 |
| WS1.3 | `ModelBackend.swift` exists (.mlx, .gguf, .cloud) | ⚪ | S | MEGAPROMPT §1.1 |
| WS1.4 | `GGUFInferenceService` exists + compiles | ⚪ | M | MEGAPROMPT §1.2 |
| WS1.5 | Model picker: 5-tier sections + RAM labels | ⚪ | S | MEGAPROMPT §1.3 |
| WS1.6 | Q4/Q8 buttons per GGUF row | ⚪ | XS | MEGAPROMPT §1.3 |
| WS1.7 | TurboQuant toggle wired to MLX `--kv-bits` | ⚪ | S | MEGAPROMPT §1.4 |
| WS1.8 | oMLX SSD bridge for oversized models | ⚪ | M | MEGAPROMPT §5 |

### §6.4 — AGENT SYSTEM (MEGAPROMPT WS2; Sprint 4, Days 8–10)

| # | Item | Status | Effort | Source |
|---|---|---|---|---|
| WS2.1 | `EpistemosOperatingMode`: 5 modes (fast, thinking, research, agent, liveAgent) | ✅ | — | MOAT §2.18 |
| WS2.2 | `agent` + `liveAgent` DISABLED for local models | ✅ | — | MOAT §2.18 |
| WS2.3 | Thinking mode: `supportsDualThinkMode` AND ≥4B for local | ⚪ | S | MEGAPROMPT §4.1 |
| WS2.4 | Safari agent DAG-based + wait-for-load | ⚪ | M | MEGAPROMPT §2.2 |
| WS2.5 | Grammar-constrained JSON tool calls (EBNF masking) | ⚪ | M | MEGAPROMPT §2.2 |
| WS2.6 | `DAGExecutor` replaces linear ReAct | ⚪ | L | MEGAPROMPT §2.2 |
| WS2.7 | `Screen2AXService` visual fallback for sparse AX trees | ⚪ | L | MEGAPROMPT §2.3 |

### §6.5 — CLOUD INTEGRATION (MEGAPROMPT WS3; Sprints 3+5, Days 5–7 + 11–13)

| # | Item | Status | Effort | Source |
|---|---|---|---|---|
| WS3.1 | `AnthropicProvider` (tool calling, computer use, thinking, MCP) | 🟡 | M | MEGAPROMPT §3.1 |
| WS3.2 | Opus dispatch / Sonnet no / Haiku basic | 🟡 | S | MEGAPROMPT §3.2 |
| WS3.3 | `SubscriptionProxy` for Claude Max sessions | ⚪ | L | MEGAPROMPT §3.3 |
| WS3.4 | `ComputerUseService` continuous observation | ⚪ | L | MEGAPROMPT §3.4 |
| WS3.5 | MCP: local stdio + cloud HTTP | 🟡 | M | MEGAPROMPT §3.5 |
| WS3.6 | `mcp-url-servers.md` Tunnel B.1 deep-dive | 🟠 | M | docs/mcp-url-servers.md |

### §6.6 — RESEARCH MODE (MEGAPROMPT WS4; Sprint 6, Days 14–15)

| # | Item | Status | Effort | Source |
|---|---|---|---|---|
| WS4.1 | `TMSService` (SOAR scoring, NLI evaluation) | ⚪ | L | MEGAPROMPT §4.2 |
| WS4.2 | 4 SOAR tool schemas in `OmegaToolRegistry` (deepsearchweb, captureandgradesource, checkcontradiction, synthesizeresearchnode) | ⚪ | M | MEGAPROMPT §4.2 |
| WS4.3 | `MCPBridge` migration (soarScore, contradictionFlag, etc.) | ⚪ | M | MEGAPROMPT §4.2 |
| WS4.4 | Prompt Repetition for non-thinking models | ⚪ | S | MEGAPROMPT §4.1 |

### §6.7 — HERMES PARITY (`EPISTEMOS-HERMES-PARITY-PLAN.md`)

| # | Item | Status | Effort | Source |
|---|---|---|---|---|
| H.1 | Register 5 orphaned tools (delegate_task, file_ops, memory, skills, web_fetch) in `agent_core/src/tools/registry.rs` | ❓ | 30 min | HERMES_PARITY Phase 1 |
| H.2 | Build 7 new tools (rate-limit tracker, code exec sandbox, todo mgmt, clarify tool, title generator, process registry, structured compaction templates) | ⚪ | 2-3 days | HERMES_PARITY Phase 2 |
| H.3 | 15 pre-built skills at `[vault]/skills/` | ⚪ | 1-2 days | HERMES_PARITY Phase 3 |
| H.4 | Wire orphaned Swift (CredentialPool, HookRegistry, KnowledgeIndexBuilder, LiveNoteScheduler, DataviewService, EpistemicStatus) | ⚪ | 1 day | HERMES_PARITY Phase 4 |
| H.5 | Connect dead-code: `should_pierce_blanket()` + `compute_trajectory_metrics()` | ❓ | 30 min | HERMES_PARITY Phase 5 |

### §6.8 — DRIFT/GAP INVENTORY (MOAT §3, file:line cited)

| # | Item | Status | Effort | Action |
|---|---|---|---|---|
| D.1 | R3 `VoicePreferencesSection` integration | ❓ | XS | `grep -rn "VoicePreferencesSection(" Epistemos/Views/Settings/` |
| D.2 | R4 `OpenNoteIntent` + `note://` URL scheme | 🔴 | S | **ACTUAL FEATURE GAP** — design + ship |
| D.3 | R6 `VisualIntelligenceIntents.swift` exists? | 🔴 | XS | `ls Epistemos/Intents/Schemas/VisualIntelligenceIntents.swift` |
| D.4 | AR6 MetalGraphView altitude/radius push to Metal | 🟡 | M | FFI surface change needed |
| D.5 | ConversationState swap into ChatCoordinator | ❓ | XS | `grep -n "ConversationState" Epistemos/Engine/ChatCoordinator.swift` |
| D.6 | Multi-turn PTF replay (currently first-turn-only) | ❓ | S | Read `ChatCoordinator.swift:2213-2249`; extend |
| D.7 | OntologyClassifier AFM caller entry point | ❓ | XS | `grep -n "AFMSessionPool" Epistemos/Graph/OntologyClassifier.swift` |
| D.8 | PowerGate call site from NightBrain | ❓ | XS | `grep -rn "PowerGate.shouldDefer\|PowerGate.canRunNow" Epistemos/` |
| D.9 | `lowDistraction` Focus key — kill or wire to Landing | 🔴 | S | No read site exists per Lane A |
| D.10 | AP9 PasteClassifier regex — lift to static | ❓ | XS | `grep -n "Regex\|NSRegularExpression" Epistemos/Engine/IntakeValve.swift` |
| D.11 | FSRSReviewSidebar Binding error | ❓ | — | `xcodegen generate; xcodebuild -scheme Epistemos` |
| D.12 | EpdocEditorChromeView "Cannot find" diagnostics | ❓ | — | Reload Xcode after `xcodegen generate` |
| D.13 | MetalGraphView "Cannot find" diagnostics | ❓ | — | Reload Xcode after `xcodegen generate` |

### §6.9 — GAP-CLOSURE BLOCKERS (`2026-03-27-master-gap-closure-plan.md` Opus 4.6 audit)

| # | Item | Status | Severity |
|---|---|---|---|
| G.1 | `train_final.jsonl` not read by any training path; compose → IFD filter → CAMPUS pipeline produces output nothing consumes | 🔴 | **HARD BLOCKER** |
| G.2 | Deploy gate auto-passes every adapter; never loads model, never runs inference, never compares to baseline | 🔴 | **HARD BLOCKER** |
| G.3 | Cross-app AX capture records Epistemos's own AX tree instead of target app | 🔴 | **HARD BLOCKER** — produces actively harmful training signal |
| G.4 | No training run has ever completed; 6 adapter dirs are config-only | 🔴 | **HARD BLOCKER** |
| G.5 | Data mix is ~93% Epistemos symbol QA; should be 40% tool-calling / 20% general / 20% app-specific / 10% negative / 10% error recovery | 🔴 | **HARD BLOCKER** |

### §6.10 — V1.5 OPERATIONAL QUEUE (from `FUSED_AUDIT_VIEW.md §2`)

Top-of-queue still-open Blockers (priority order):

1. **W9.21 PR4** — Swift consumer cutover for honest-FFI handles (~1.5 hr Lane C) ⚪
2. **W9.8** — NSAlert → ApprovalModalView production wire (~2 hr Lane C) ⚪
3. **AnyView 16-violation cleanup** — Doctrine §6 #6 enforcement ✅ closed `ac8c6d28` 2026-04-27

These touch disjoint files; safe for parallel `isolation: "worktree"` agents.

### §6.11 — DEFERRED (research-ready, gated on phase X)

| # | Item | Phase Gate | Source |
|---|---|---|---|
| Z.1 | Phase H Halo / Ambient Recall master plan | gated on Phase R closure | `AMBIENT_RECALL_HALO_MASTER_PLAN.md` |
| Z.2 | Phase R Instant Recall architecture (Mamba-3 + binary HNSW + state injection) | post-V1.5 | `INSTANT_RECALL_ARCHITECTURE.md` + Instant Recall research |
| Z.3 | Phase K OpenClaw (Pro-only) | Pro-tier only | `OPENCLAW_FEATURE_SPEC.md` |
| Z.4 | Phase D Hermes integration (full agent provider) | Phase D | `HERMES_INTEGRATION_RESEARCH.md` |
| Z.5 | Phase D Control Plane research | Phase D research | `CONTROL_PLANE_RESEARCH.md` |
| Z.6 | Phase H Contextual Shadows (Mirror Speculative Decoding NPU+GPU) | post-V1 | `ambient_contextual_shadows_blueprint.txt` |
| Z.7 | Phase R Stateful Rotor + ButterflyQuant + zero-copy IPC | post-V1.5 | THESIS Pillars 1-3 |
| Z.8 | ODIA nightly LoRA flywheel | post-Phase 4 | Omega protocol |

---

## §7 — Verification queue (run these greps before declaring done)

```bash
# D.1 — VoicePreferencesSection wiring
grep -rn "VoicePreferencesSection(" Epistemos/Views/Settings/

# D.2 — OpenNoteIntent + note:// scheme
grep -rn "OpenNoteIntent\|note://" Epistemos/

# D.3 — VisualIntelligenceIntents existence
ls -la Epistemos/Intents/Schemas/VisualIntelligenceIntents.swift

# D.5 — ConversationState swap
grep -n "ConversationState" Epistemos/Engine/ChatCoordinator.swift

# D.6 — Multi-turn PTF replay
sed -n '2213,2249p' Epistemos/Engine/ChatCoordinator.swift

# D.7 — OntologyClassifier AFM caller
grep -n "AFMSessionPool" Epistemos/Graph/OntologyClassifier.swift

# D.8 — PowerGate call site
grep -rn "PowerGate.shouldDefer\|PowerGate.canRunNow" Epistemos/

# D.10 — PasteClassifier regex location
grep -n "Regex\|NSRegularExpression" Epistemos/Engine/IntakeValve.swift

# H.1 — Hermes 5 orphaned tools registration
grep -rn "delegate_task\|file_ops\|memory.rs\|skills.rs\|web_fetch" agent_core/src/tools/registry.rs

# H.5 — Dead-code call sites
grep -rn "should_pierce_blanket\|compute_trajectory_metrics" agent_core/src/

# Hermes Python entry point
find /Users/jojo/Downloads/Epistemos -name "hermes*" -type f

# Build verification
xcodegen generate; xcodebuild -scheme Epistemos
```

---

## §8 — `[UNVERIFIED]` markers preserved (claims sourced from research; not empirically proven in our codebase)

1. **BoltFFI 1000× speedup** — cited in `final v2/App Moats` and `opt/claude opt 2.md`; reaffirmed `[UNVERIFIED]` by `perf_invalidation_strategy.md` which argues "invalidation > transport" delivers most of the realistic gain.
2. **TurboQuant 6× memory + 8× attention** — H100 paper claim; Epistemos M-series benchmark not yet run.
3. **Mamba-3 beats Transformer at 220K context** — paper claim; Epistemos benchmark pending.
4. **78×–167× incremental outline-refresh gain** — `opt/claude opt 2.md` claim; pending production validation.
5. **VLM2VLA 85%+ base VQA retention via natural-language actions** — UI-TARS paper claim; Epistemos training pipeline not yet run end-to-end (G.4 blocker).
6. **ANE 0 mW idle power gating** — Apple datasheet claim; not measured on shipped Epistemos NightBrain helper.
7. **Mirror Speculative Decoding 2.8×–5.8× wall-time** — Apple ML Research paper (arXiv 2510.13161); Epistemos draft+target architecture not implemented.
8. **Sub-5ms meta-memory retrieval** — THESIS architectural claim; benchmark on real corpus pending.
9. **Hermes OAuth 2.1 + sampling parity** — claimed in HERMES_PARITY plan; depth not verified.
10. **5 major tools "already implemented but unregistered"** — Codex plan asserts; not independently verified (see H.1 grep).

---

## §9 — Reading order for new agents (collapsed from §5 of `COWORK_MASTER_PROMPT.md`)

If a fresh agent picks up this work, read in this order:

```
1. docs/_consolidated/00_canonical_authority/MASTER_FUSION.md  ← THIS FILE (start here)
2. docs/_consolidated/00_canonical_authority/CLAUDE.md          ← code standards
3. docs/_consolidated/00_canonical_authority/PLAN_V2.md         ← architectural authority (1631 lines)
4. docs/_consolidated/00_canonical_authority/MASTER_BUILD_PLAN.md ← operational queue
5. docs/_consolidated/00_canonical_authority/ambient_V1_DECISION.md ← V1 verdict
6. docs/_consolidated/00_canonical_authority/03_EXECUTION_MAP.md  ← per-item depth
7. docs/_consolidated/10_living_audits/FUSED_AUDIT_VIEW.md       ← single-pane Blocker view
8. docs/_consolidated/50_research_corpus/00_FUSED_RESEARCH_DIGEST.md ← cross-corpus synthesis
9. docs/_consolidated/COWORK_MASTER_PROMPT.md                    ← how to continue
```

For domain context, read in §5 listed canonical docs above, then jump to **§6 of THIS document** and start ticking items.

---

## §10 — Sprint plan (operationalized from MEGAPROMPT 17-day breakdown)

| Sprint | Days | Workstreams | Items |
|---|---|---|---|
| 1 | 1–2 | WS1 Foundation | WS1.1, WS1.2, WS1.3 (LocalTextModelID, RAM tiers, ModelBackend) |
| 2 | 3–4 | WS1 continued | WS1.4, WS1.7, WS1.8 (GGUFInferenceService, TurboQuant toggle, oMLX bridge) |
| 3 | 5–7 | WS3 Cloud APIs | WS3.1, WS3.2, WS3.3 (AnthropicProvider, capability gating, SubscriptionProxy) |
| 4 | 8–10 | WS2 Agent Overhaul | WS2.4, WS2.5, WS2.6, WS2.7 (DAGExecutor, grammar constraints, Screen2AX) |
| 5 | 11–13 | WS3 continued | WS3.4, WS3.5 (ComputerUseService, MCP local+cloud) |
| 6 | 14–15 | WS4 Research Mode | WS4.1, WS4.2, WS4.3, WS4.4 (TMSService, SOAR tools, MCPBridge, Prompt Repetition) |
| 7 | 16–17 | WS6 Release Blockers + V1 ship | V1.2–V1.7 (PrivacyInfo, deployment target, try?, unsafe annotations, tests, sanitizers) |

Each sprint completes when:
- Task list ✅ all items shipped or explicitly ❓-flagged
- Verification greps return expected results
- Acceptance criteria from MEGAPROMPT met
- WRV gate (`00_AUTHORITY_AND_ANTI_DRIFT.md §4.7`) — Wired + Reachable + Visible

---

## §11 — Anti-pattern register (from PLAN_V2 §27, distilled)

15 prohibitions. Treat as binding:

1. No silent backend rerouting (always log routing decisions)
2. No dropped errors during agent streaming
3. No exposing unsupported capabilities as supported
4. No `try!` in production paths
5. No force-unwraps (`!`) on optionals
6. No `print()` in production paths (use OSLog with categories)
7. No `AnyView` (Doctrine §6 #6) — use `@ViewBuilder` and concrete types
8. No `unsafe` blocks without `// SAFETY:` comment
9. No mutating state from observed Combine/AsyncSequence in `body`
10. No I/O overlap in serial-streamed paths (serial invariant)
11. No fake success on capability denial
12. No direct chat-to-weight path (poisoned adaptation defense)
13. No unstructured masks (mask must compile or block; never default-allow)
14. No allocation in hot paths (use arenas, mmap, preallocated buffers)
15. No JSON strings on hot FFI paths (use stable ABI structs, numeric IDs, shared memory)

### §11.1 — Production fallback inspector rule (audit-resolved 2026-04-27)

**Production rule:**
- No user-facing fallback inspector.
- Unknown A2UI schemas produce `VALIDATION_FAILED`.
- The model must retry against the closed A2UI catalog.
- Normal users never see generic JSON blobs as the product UI.

**DEBUG-only exception:**
- DEBUG builds may route unknown schemas into a quarantine renderer for schema-capture telemetry.
- Quarantine views must never compile into ReleasePro or ReleaseMAS.
- CI must include a check proving quarantine code is excluded from production targets.

**Reason:** The product must never degrade into generic JSON blobs, but development needs a controlled way to measure schema coverage against real provider/Hermes outputs. **This preserves closed-catalog discipline without blinding builders.**

### §11.2 — Hermes terminology bridge (audit-resolved 2026-04-27)

In product/UX language, **"Hermes faculty"** and **"Hermes mode"** are allowed as user-facing metaphors. In architecture, Hermes is an **integration-privileged provider** behind the same provider/graph/MCP contracts as every other engine.

Canonical phrase: **Hermes is UX-privileged and integration-privileged, but not substrate-sovereign.**

Hermes **may**:
- Receive dedicated UX affordances + branded landing mode
- Be the default foreman for Hermes-specific Co-op / hackathon demos
- Use `epistemos-hermes-mcp` seam
- Project skills into / out of graph-backed skill nodes

Hermes **may not**:
- Receive private graph access
- Bypass provider routing, approval policy, WRV, provenance, or A2UI validation

**Removing Hermes must not break the core Epistemos loop.**

### §11.3 — Subprocess inference clarification (audit-resolved 2026-04-27)

**No local model inference sidecar.** All local inference Epistemos owns runs in-process through MLX-Swift, Rust FFI, Apple Foundation Models, or the repo-approved in-process path. The app does not bundle a separate local inference daemon as the normal runtime.

**Pro-only exception** (NOT MAS): Installed cloud/coding CLIs (Claude Code, Codex, Gemini, Kimi, Hermes) may be used as **explicit provider adapters** in Epistemos Pro when:
- User intentionally enables the provider
- Route is visible in UI
- Provider is gated by policy + approval
- Environment is scrubbed
- Process is cancellable / kill-on-drop
- Outputs normalized into `RunEventLog` / `AgentEvent`
- No OAuth tokens proxied through Epistemos backend
- Path excluded from MAS builds

**MAS rule:** MAS target must not spawn arbitrary user-installed coding CLIs. CLI subprocess capability belongs in Pro or external helper path.

---

## §16 — Concept Door / Depth Kernel (N2 — the missing depth primitive)

**The user's framing**: "every concept is a world where you press it and that world has infinite insights about the sub-subjects of that concept. Each door is limitless; you can go as deep as you'd like to uncover infinite knowledge."

This is the **deliberate-depth counterpart to Halo's ambient recall**. Halo answers *"what nearby memory matters right now?"* — Concept Door answers *"what is the world inside this concept?"*

### §16.1 — Definition

A **Concept Door** is an interaction primitive. Any meaningful concept can be opened into a structured world of depth — minimal on the surface, infinite below.

A concept may originate from: selected text, note title, paragraph, claim, evidence item, graph node, search result, code symbol, run event, model output, skill, document block, tag, entity, source citation.

Opening the door produces a **Concept World** — a typed artifact (NOT a generated markdown blob) containing: definitions, subclaims, evidence, contradictions, examples, related notes, adjacent theories, implementation paths, code links, model debates, uncertainty, retraction status, "what changed since I last believed this," "what can I do with this concept."

### §16.2 — Canonical schema

```rust
pub struct ConceptWorld {
    pub id: String,
    pub root_ref: ConceptRef,
    pub title: String,
    pub summary: String,
    pub depth_budget: DepthBudget,
    pub facets: Vec<ConceptFacet>,
    pub claims: Vec<ClaimRef>,
    pub evidence: Vec<EvidenceRef>,
    pub contradictions: Vec<ContradictionRef>,
    pub related_artifacts: Vec<ArtifactRef>,
    pub implementation_paths: Vec<ImplementationPath>,
    pub open_questions: Vec<OpenQuestion>,
    pub next_doors: Vec<ConceptDoor>,
    pub provenance: ProvenanceRef,
    pub retraction_status: RetractionStatus,
    pub created_at_ms: i64,
    pub schema_version: u32,
}

pub enum DoorKind {
    Definition, Evidence, Counterargument, Implementation, History,
    CodePath, RelatedMemory, MathematicalForm, FailureMode,
    ResearchTrail, PersonalRelevance, NextAction,
}

pub enum ConceptDoorMode {
    Peek,        // local summary, no mutation
    Open,        // temporary ConceptWorld view, no durable mutation
    Pin,         // save as artifact, write MutationEnvelope
    Deepen,      // run retrieval+synthesis under budget
    Challenge,   // search contradictions, invalid evidence
    Implement,   // convert into ImplementationPlan
    Research,    // Pro-only or explicit cloud/web opt-in
}
```

### §16.3 — Infinite depth, bounded execution

The philosophical model is infinite. The implementation must be bounded. **Never implement unbounded recursion.**

```text
Depth 0: local summary / exact source context
Depth 1: nearest notes, claims, evidence, related code symbols
Depth 2: synthesis, contradictions, missing evidence
Depth 3: external research / model council / implementation plans
Depth 4+: requires explicit user approval or scheduled deep research
```

Each door expansion declares: cost, latency, source scope, provider, risk, reversibility, provenance. **No silent deepening. No silent web. No silent cloud. No silent mutation.**

### §16.4 — Mechanism (composes existing systems — does NOT create a parallel one)

```
PromptTree (N1)
  + StructureRegistry
  + AgentEvent
  + MutationEnvelope
  + ClaimLedger
  + A2UI closed catalog
  + Graph search
  + Contextual Shadows
  + Artifact router
= Concept Door
```

Concept Door is **not a new app mode**. It is a depth action available across existing surfaces (editor selection, graph node click, search result, artifact inspector, command palette, slash command).

### §16.5 — A2UI catalog additions (closed catalog discipline preserved)

```
ConceptWorldCard
FacetList
EvidenceStack
ContradictionBanner
NextDoorChips
DepthBudgetPill
ProvenanceTrailButton
RetractionStatusBadge
ImplementationPathCard
OpenQuestionList
```

Production: unknown schema → `VALIDATION_FAILED`. DEBUG: quarantine renderer (per §11.1).

### §16.6 — MAS / Pro gating

**MAS allowed**: local index, local graph, local embeddings, local AFM/MLX in-process, cloud APIs only with explicit user opt-in, no shell, no Docker, no external CLI subprocess.

**Pro deepening paths**: Hermes, CLI providers, shell, Docker, browser, computer use, external MCP, long-running research. Still subject to: visible provider route, approval policy, provenance, retraction, no silent fallback.

**One concept primitive. Two policy profiles.**

### §16.7 — Why this is the keystone

```
Halo gives ambient recall.
Concept Door gives deliberate depth.
ClaimLedger gives trust.
Retraction propagation gives correction.
Provenance gives the audit trail.
```

Together: the cognitive exoskeleton.

### §16.8 — Sequencing

Concept Door is **N2** in the plan tree. Sequencing:

- **V1**: Halo / Contextual Shadows (the magical first impression)
- **V1.5**: Concept Door / Depth Kernel + Raw Thoughts / Run provenance + typed artifact spine
- **Pro**: Hermes Expert Mode + CLI providers + Docker + computer use + NightBrain + Co-op Mode

Concept Door **does not block V1 ship**. It is added to `03_EXECUTION_MAP.md` as **N2** with WRV-gated definition of done. Standalone doctrine extension at `docs/_consolidated/00_canonical_authority/CONCEPT_DOOR_N2.md`.

### §16.9 — Implementation companion (architecture-spec cross-ref)

The **canonical implementation plan** for the typed-artifact spine that N2 sits on top of lives at:

```
docs/architecture/COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md
```

(also at `docs/_consolidated/20_canonical_research/architecture_specs/COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md` — both paths resolve)

It provides:
- **`ArtifactKind` enum** (7 kinds: ProseNote=1, Document=2, RawThought=3, Source=4, Code=5, Run=6, Output=7) — Rust + Swift mirrored across FFI
- **`ArtifactHeader`** (ULID + kind + schema_version + created_at + updated_at + title + vault_path + content_hash + provenance)
- **`ProvenanceBlock`** (producer + derived_from + generated_by_run + tool_id + source_artifacts)
- **Single-line invariant**: *"Filesystem is durable. Graph is rebuildable. Artifact identity is stable."*
- **Repo inventory (2026-04-25)**: Raw Thoughts substrate 80% done (Patches 4+5), typed graph types 30% done (Patch 5 added 4 node types + 4 edge types). NOT YET BUILT: ArtifactKind taxonomy as first-class typed identity, ArtifactHeader+ProvenanceBlock unified, .epdoc package format, Document editor host (Tiptap+WKWebView), block-level search projections (`readable_blocks` + `readable_blocks_fts`), Epistemos Code surface, agent patch/provenance workflow, MutationEnvelope pattern (current is broad NotificationCenter), compile-time `ArtifactRoute` enum.

When implementing N2 Concept Door, the agent **MUST read `COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md`** and pick up from the current state (don't re-design what's shipped; extend what's there).

---

## §17 — Minimal Surface, Infinite Depth (the design contract)

This is the binding design philosophy. It governs every UI decision, every depth interaction, every provenance surface.

### §17.1 — The contract

```
Nothing is always expanded.
Everything important is expandable.
Every expansion has provenance.
Every claim can be challenged.
Every dependency can be traced.
Every invalidated belief propagates.
```

### §17.2 — The three layers

```
Surface layer (minimal, always-visible):
  editor, Halo, graph, chat, command center, artifact viewer

Depth layer (summoned, never crowding):
  concept worlds, prompt trees, claim/evidence graphs,
  run provenance, related memory, implementation paths

Integrity layer (non-negotiable, invisible until challenged):
  MutationEnvelope, ClaimLedger, retraction propagation,
  ReplayBundle, WRV gates, four-layer event hierarchy
```

### §17.3 — The alien-smooth contract (engineering-binding, not aesthetic)

Performance is a **product feature**, not an optimization pass. Target the tail, not the average:

| Budget | Target | Hard ceiling |
|---|---|---|
| MainActor work per recall update | < 1 ms | 2 ms p99 |
| Debounce window | 200 ms | 250 ms |
| Query extraction | < 0.5 ms | 1 ms |
| FFI hop | < 0.5 ms | 1 ms |
| Model2Vec encode | < 2 ms | 4 ms |
| usearch HNSW top-k | < 5 ms | 10 ms |
| Tantivy BM25 | < 8 ms | 12 ms |
| RRF fusion + metadata fetch | < 3 ms | 5 ms |
| End-to-end recall pass after debounce | < 25 ms | 40 ms |
| Perceived recall after debounce | < 100 ms | — |
| Graph frame budget | never exceed display target | — |

Every hot path needs `os_signpost`. **If a feature cannot be measured, it cannot be claimed.**

### §17.4 — The 15 binding interaction rules

1. Typing never blocks.
2. No synchronous UI wait on Rust.
3. No synchronous UI wait on GPU.
4. No synchronous UI wait on model inference.
5. No modal where a panel works.
6. No spinner where progressive state works.
7. No generic AI blob where a precise artifact card works.
8. No animation that lies about real state.
9. No graph visual that pretends cognition happened if no data changed.
10. No fake success.
11. No silent fallback.
12. No silent cloud escalation.
13. No silent mutation.
14. No hidden token scraping.
15. No unsupported visible mode.

### §17.5 — The novelty stack (what makes Epistemos alien)

```
Ambient memory:    Contextual Shadows (Halo) — recall before search
Deliberate depth:  Concept Door — every concept opens a world
Provenance plane:  RunEventLog + MutationEnvelope + AgentEvent + GraphEvent
Typed artifacts:   ProseNote, Document, RawThought, Run, Source, Code, Output, Claim, Evidence, Skill, Session
Native moat:       NSPanel non-activating + TextKit + Metal + MLX + AFM in-process
Visible cognition: graph events reflect truth, never theater
Policy profiles:   one runtime, MAS + Pro
Self-improving:    harnesses + meta-harnesses (Pro/lab moat, not V1)
```

A normal app waits for commands. Epistemos senses the shape of thought.
A normal AI app gives answers. Epistemos preserves provenance.
A normal notes app stores files. Epistemos maintains living cognitive artifacts.
A normal graph is decorative. Epistemos's graph shows cognition touching memory.
A normal agent says it did something. Epistemos proves it.

---

## §18 — Exploration Spectrum Meter / Concept Diffusion Mode (N3)

**The user's framing**: *"I want there to be a meter in my app in the chats or sessions that adds another style — a spectrum that increases or decreases exploration into concepts. Simulate a world where a world is the semantic universe of infinitely nested concepts in an infinite concept map that exponentially multiplies per level. The model should completely get rid of its understanding of how words work in its assumed understanding — a scientist in a world of words / infinite doors. The model should adopt a new refined way of deliberating by simulating diffusion / real-time distillation by exploring infinitely conceptual multi-level concepts and sub-concepts marked by complexity score."*

This is **N3** in the plan tree. Sister to N2. Where N2 opens a single concept into a world, **N3 reshapes how the model thinks about every query** along an exploration spectrum.

### §18.1 — The meter

A single horizontal slider in the chat input bar (and session settings). 0.0 → 1.0. Five modes:

| Mode | Range | Depth | Branching | Drops priors? | Cost |
|---|---|---|---|---|---|
| Grounded | 0.0–0.2 | 1 | 2 | no | 1× |
| Curious | 0.2–0.4 | 2 | 3 | no | 2× |
| Exploratory | 0.4–0.6 | 3 | 4 | no | 4× |
| **Scientist** | 0.6–0.8 | 5 | 5 | **yes** | 8× |
| **InfiniteDoors** | 0.8–1.0 | 7 | 7 | **yes** | 16× |

At ≥ 0.6, the model is reframed as a "scientist exploring the semantic universe of words" with an explicit prompt-injected persona that **suspends assumed semantic priors** and re-derives understanding via diffusion-distillation across the concept tree.

### §18.2 — The pipeline (composes with N1 + N2 — no parallel architecture)

```
1. Seed     — query becomes root ConceptNode
2. Branch   — emit ${branching_factor} child concepts per node along distinct axes
3. Score    — assign complexity_score + novelty_score to each
4. Prune    — drop children where complexity_score < threshold
5. Recurse  — repeat steps 2–4 until depth >= max_concept_depth
6. Distill  — ${diffusion_steps} iterations of synthesis per surviving node
7. Answer   — coherent synthesis grounded in distilled tree, with tree as provenance
```

The "exponential multiplication per level" is `branching_factor^depth` — at InfiniteDoors mode, up to ~823,000 conceptual paths, but **only the top-N by complexity score survive at each level**. Bounded simulation of infinite exploration.

### §18.3 — Composition (clean, not parallel)

```
N1 PromptTree    — the prompt is data; ExplorationSpectrum compiles into one
N2 ConceptDoor   — each ConceptNode in the diffusion tree IS a Concept Door target
N3 Spectrum      — the meter reshapes deliberation per query; concept tree is audit trail
```

Each `ConceptNode` in the diffusion tree is automatically clickable as a Concept Door (per N2). The user can descend any node into a full ConceptWorld.

### §18.4 — The hybrid JSON + prompt-folder approach (N1-grounded)

The user said: *"frame it as a mix of JSON and prompt folder."* This is exactly what N1 (Prompt Tree / JSPF + PTF format) provides. N3 is a **PromptTree generator** that produces N1-format prompt trees parameterized by spectrum config. **No new prompt format. No string concatenation.**

### §18.5 — Output schema (closed A2UI catalog discipline preserved)

`epistemos.diffusion_answer.v1` — `DiffusionAnswerCard` with summary + concept_tree + meter_value + survived/pruned counts + provenance trail. Production: unknown schema → `VALIDATION_FAILED`. DEBUG: quarantine (per §11.1). Default UI shows summary + small chip; tree expands progressively on demand.

### §18.6 — MAS / Pro gating

- **MAS**: 0.0–0.6 unrestricted. 0.6–0.8 (Scientist) approval-gated per session. 0.8–1.0 (InfiniteDoors) approval + token cost confirmation. No external CLI / shell / Docker / browser at any meter value. Cloud requires explicit per-provider key + per-session opt-in.
- **Pro**: all modes default-enabled. High-meter mode can call external research if `allow_web` policy allows. NightBrain can run high-meter modes on user-approved topics in background.

### §18.7 — Why this is the third pillar

```
Halo:           ambient recall — "what nearby memory matters right now?"
Concept Door:   deliberate depth on a single concept — "what is the world inside this concept?"
Exploration Spectrum: shape of deliberation per query — "how exploratory should the model be RIGHT NOW?"
```

A normal AI app gives one style of answer. **Epistemos gives the user a meter that reshapes the model's mind for each query — and shows the concept tree as evidence of how it thought.**

### §18.8 — Definition of done

18 acceptance criteria locked in `CONCEPT_DOOR_N2.md`'s sister doc **`EXPLORATION_SPECTRUM_N3.md`** (in `00_canonical_authority/`). Covers: 5 UI surface items, 3 schemas, 5 pipeline items, 3 policy items, 2 provenance + verification items. WRV-gated. **Authored to be VERY EXPLICIT so it actually ships.**

### §18.9 — Sequencing

**N3 does NOT block V1 ship.** Lands in V1.5 alongside N2. The infrastructure (PromptTree from N1) already exists. V1 = Halo. V1.5 = N2 + N3. Pro = full InfiniteDoors mode + agent autonomy.

**See standalone canonical doc**: `_consolidated/00_canonical_authority/EXPLORATION_SPECTRUM_N3.md` for full schemas, pipeline definitions, prompt persona text, MAS/Pro policy table, 18-item acceptance criteria, and anti-overbuild stops.

---

## §19 — Local Analysis Mode / Deterministic Math+ML Verification (N4)

**The user's framing**: *"I want my app to do math that precises up the code output the model makes... a final toggle that turns on local analysis mode. Local deep deliberation guided by deterministic process in ML and math. That's important — it must be deterministic enough."*

This is **N4** in the plan tree. The rigor pillar. Where N3 reshapes deliberation, N4 verifies the output. Plausibility → proof.

### §19.1 — The toggle + 4-pillar exoskeleton

A single icon-toggle (`λ`) next to the N3 spectrum meter in chat input bar. ⌘⇧L. Per-message verification chip (✓/amber/?/red).

```
N1 Prompt Tree           — prompt is data
N2 Concept Door          — every concept opens a world (vertical depth)
N3 Exploration Spectrum  — meter reshapes deliberation (lateral exploration)
N4 Local Analysis Mode   — deterministic verification of output (rigor)
```

### §19.2 — The 6-stage deterministic pipeline

```
1. Claim extraction       — pure deterministic AST parse (NO LLM)
2. Code verification      — tree-sitter + type-check + lint + AntipatternRegister
3. Math verification      — symbolic + numeric + interval + dimensional, triangulated ≥ 2 methods
4. Citation verification  — vault FTS5 + ClaimLedger
5. Factual cross-check    — vault-only by default; Pro web is opt-in
6. Synthesis              — produces LocalAnalysisReport with reproducibility_hash
```

### §19.3 — The determinism contract (the whole point)

**Same input → same output. Always.** Eight rules:
1. Fixed seeds (default `seed = 0`, recorded in report)
2. Pinned library versions (`Cargo.lock` / `Package.resolved`, recorded in report)
3. Pinned compiler/parser versions
4. Fixed math kernels (IEEE 754 + controlled rounding, `inari` for intervals)
5. **No LLM calls in verification path** (LLM is the thing being verified, never the verifier)
6. No clock dependence (except `elapsed_ms` for telemetry)
7. No network calls (cloud only via explicit Pro opt-in + RunEventLog record)
8. Reproducibility token in report; same input + same library versions → byte-identical report

**Anti-violations**: LLM "double-checker" (banned), system clock as verification input (banned), unrecorded `/dev/urandom` (banned), silent network (banned), unpinned library (banned).

### §19.4 — Composition with N3

| N3 Mode | LAM stages run | Triangulation |
|---|---|---|
| Grounded + LAM | Stages 1-2 | none |
| Curious + LAM | Stages 1-3 | 2 methods |
| Exploratory + LAM | All 6 stages | 2 methods |
| Scientist + LAM | All 6 + triangulation = 3 (require 2-of-3 agree) | 3 methods |
| InfiniteDoors + LAM | All 6 + triangulation = 4 + dimensional + interval | 4 methods |

### §19.5 — Code precision-up math (specific operations)

For numerical/algebraic code:
- Type-check formula matches known algorithm
- Loop bound analysis (symbolic execution, depth ≤ 8)
- Big-O verification (claimed complexity vs static analysis)
- Edge cases enumerated (`0`, `±∞`, `NaN`, empty input)
- Precision contract verified by interval arithmetic
- Linear algebra: dimensional consistency + conservation laws + symmetry properties
- Reference implementation diff (when available)
- ML/RNG: seed verification + numerical stability checks

### §19.6 — MAS / Pro gating

- **MAS**: all 6 stages run with strictly local libraries; subprocess shell-out forbidden if MAS sandbox blocks; `[MAS-UNVERIFIED]` flag if a stage needs unavailable tool
- **Pro**: external `cargo check` / `swiftc` allowed, web factual verification with opt-in, heavier symbolic computation via vetted subprocess

### §19.7 — Definition of done

20 acceptance criteria locked in **`LOCAL_ANALYSIS_MODE_N4.md`** (UI surface 4 + Schemas 3 + Pipeline 6 + Determinism 3 + Composition 2 + Provenance/Verification 2). WRV-gated. **Authored to be VERY EXPLICIT so it actually ships.**

### §19.8 — Why this is the rigor pillar

A normal AI app gives a plausible answer. **Epistemos gives an answer with code/math claims verified by a deterministic pipeline whose output is byte-reproducible.** Plausibility is not enough. Proof, where proof is possible. Honest `[UNVERIFIED]` where proof is not.

**See standalone canonical doc**: `_consolidated/00_canonical_authority/LOCAL_ANALYSIS_MODE_N4.md` for full schemas, 6-stage pipeline definitions, library version pinning details, MAS/Pro policy table, 20-item acceptance criteria, and anti-overbuild stops.

---

## §12 — Provenance log

| Date | Author | Action |
|---|---|---|
| 2026-04-27 (initial) | consolidation pass (Cowork) | Initial fusion authoring. Synthesized 8 master-plan-class docs + 218 research files via 2 parallel Explore agents. Status table reflects MOAT audit (2026-04-27). |
| 2026-04-27 (audit pass) | consolidation pass (Cowork) | Applied 4 audit fixes (authority hierarchy unification §0, four-layer event hierarchy §3.5, DEBUG quarantine exception §11.1, Hermes terminology bridge §11.2 + subprocess clarification §11.3). Added Concept Door / Depth Kernel as §16 (the missing depth primitive). Added Minimal Surface / Infinite Depth design contract as §17. Authored standalone `CONCEPT_DOOR_N2.md` doctrine extension. |
| 2026-04-27 (N3 pass) | consolidation pass (Cowork) | Added §18 — Exploration Spectrum Meter / Concept Diffusion Mode. Authored standalone `EXPLORATION_SPECTRUM_N3.md` with 18 acceptance criteria, 5-mode spectrum, ConceptNode schema, diffusion-distillation pipeline, scientist-of-words persona injection, MAS/Pro gating, anti-overbuild stops. **Authored to be VERY EXPLICIT so it actually ships.** Final state: V1 = Halo magic; V1.5 = N2 Concept Door + N3 Exploration Spectrum + provenance spine; Pro = full InfiniteDoors + agent autonomy. The three pillars: Halo (ambient recall) + Concept Door (deliberate depth) + Exploration Spectrum (deliberation shape). |

---

## §13 — Maintenance protocol

This document drifts unless maintained. Every time you ship a §6 item:

1. Update status (⚪ → 🟡 or ✅).
2. Add commit SHA to source row.
3. Cross-link to V1.5 tracker entry.
4. If item revealed new sub-items, add them.
5. If item revealed contradictions with this doc, document in §4 and adjudicate.
6. Re-copy this file to `_consolidated/00_canonical_authority/` (no-op since it lives there).

Run quarterly: cross-check this doc against `PLAN_V2.md`, `MASTER_BUILD_PLAN.md`, and `EPISTEMOS_MOAT_AND_OPTIMIZATION_MASTER.md` (re-run audit). Reconcile divergences in §4.

---

**END OF MASTER_FUSION.md**

> *"Perfection is achieved not when there is nothing more to add, but when there is nothing left to take away." — Saint-Exupéry*
>
> This fusion replaces 5+ overlapping master plans with one layered checklist. Originals at `_consolidated/50_research_corpus/master_plans/` and `~/Downloads/`. Untouched.
