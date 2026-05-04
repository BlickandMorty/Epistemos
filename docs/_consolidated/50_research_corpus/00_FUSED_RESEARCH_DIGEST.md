# Fused Research Digest — `/Advice` + `/final` + `/final v2` + `/final v3`

> **Status**: DERIVED VIEW (synthesized from 4 Explore-agent passes 2026-04-27 across the four corpus folders + manual full-read of `EPISTEMOS_HERMES_MANIFESTO.md`).
> **Authoritative sources**: each corpus folder in this same `50_research_corpus/` tree. This is a navigation/synthesis layer, not source of truth.
> **Purpose**: tell a fresh agent (a) what each corpus uniquely contributes, (b) where they converge, (c) where they diverge (and which view the doctrine adopted), (d) what's NOT yet in canonical doctrine that's load-bearing.

---

## §1 — Origin chronology (read in this order if doing research archeology)

| Corpus | Era | Volume | Role |
|---|---|---|---|
| `advice/` | **Earliest** — 4-model architectural advice (Claude, Gemini, GPT, Perplexity) | 8 files (5 .md + 2 PDF + 1 misc) | Foundational architecture brainstorming. Framework choices (Swift 6 + Rust + UniFFI + MLX-Swift), runtime-path ranking, CLI integration constraints, licensing/notarization realities. |
| `final/` | **Post-research convergence** — hackathon-ready material | 16 files (incl. `last round of thinking/` and `executive sumaries/` subdirs) | Hermes manifesto (vision + executable research brief + 9-day vector). Master architecture brief. Council-style debate documents (consensus + disruption). Executive summaries fusing the 4-architect tracks. |
| `final_v2/` | **Most recent runtime/inference research** | 6 files | The corpus where current doctrine crystallized. Master Doctrine & Implementation Cookbook. KIVI vs TurboQuant. UniFFI 0.28 → 0.29.5 specifics. Faculty roster locked at 16 GB. BLAKE3 Merkle chain. FSRS-6. Hierarchical concept extraction. SSM/Mamba placement. **BoltFFI claims (marked `[UNVERIFIED]`).** |
| `final_v3/` | **Latest drop — orthogonal scope** | 1 file (`deep-research-report (4).md`) | LLM prompt engineering for production robustness — JSON-schema prompting ("Ambiguity Tax"), prompt industrialization, modular prompt trees, Anthropic prompt caching mechanics (85–92 % token savings via `cache_control`), Tool Search (~85 % token deferral), validation pipelines. **Does NOT supersede v2 — different domain.** |

**Conflict resolution rule**: prefer C-corpus (`final_v2`) over B-corpus (`final`) over A-corpus (`advice`) when they conflict. `final_v3` is orthogonal — cumulative not superseding. PLAN_V2 wins regardless of corpus.

---

## §2 — What each corpus uniquely contributes (still load-bearing)

### `advice/` — load-bearing residuals

1. **Runtime-path ranking + licensing constraints (`Claude paper.pdf`)**: subprocess CLI as Power Mode default (not just one option) requires Developer ID non-sandbox ship + explicit "we launch your Claude Code" framing. Rules out certain SDK-Path-B business models. **Already in DOCTRINE §1.4 + BUILD_MATRIX §4–5.**
2. **CLI discovery implementation (`claudy research.md`)**: concrete probe order (NSWorkspace → known paths → version pinning → GRDB 24h TTL). Fills gap between PLAN_V2's abstract "Rust owns runtime resolution" and executable code. **Cited from `IMPLEMENTATION_PLAN_FROM_ADVICE.md` §Phase R.**
3. **Dynamic few-shot prompting for Qwen3-4B (`Claude paper.pdf`)**: injection of 2–3 successful prior examples from GRDB into system prompt recovers ~40 % of small-model failures. **NOT yet in canonical doctrine.** Should be added when local-model tool-call accuracy is the active bottleneck (post-W9.25 grammar masking).

### `final/` — load-bearing residuals

1. **Hermes manifesto (`EPISTEMOS_HERMES_MANIFESTO.md`)**: aesthetic discipline (pixel fonts, ASCII wave intro, glare shaders, restraint-as-warmth). Substrate-as-runtime framing ("the graph IS the agent runtime"). Six-verb MCP boundary precursor (later expanded to seven in `final_v2`). **Strategic vision; aspirations beyond V1.5 stay aspirational.**
2. **Master Architecture Brief**: provider matrix detail, EpisWidgetSpec schema (closed catalog precursor), three-tier Qwen agentic (local ReAct → cloud escalation), Hermes-as-MCP-server pattern. **Largely absorbed into PLAN_V2 + DOCTRINE.**
3. **Hackathon Plan + 9-day vector**: realistic delivery cadence proven possible. Not directly canonical but informs realistic phase sizing.
4. **`epistemos-rival-doctrine.md` (defeated opinion)**: pre-consensus position arguing Hermes-as-faculty (privileged). DOCTRINE §2.2 explicitly rejects this in favor of provider-equality. **Kept as historical record of debate; not active.**
5. **`AI App Architecture Consensus Building.txt`**: pre-doctrine synthesis — exposes the reasoning that led to the fifth-position rulings on the 5 A/B/C/D tensions. **Useful for understanding doctrine-not-just-following-it.**
6. **`Epistemos App_ Privacy, Speed, SDK Integration.txt`**: Pro vs MAS sandbox tradeoffs — fully absorbed into BUILD_MATRIX entirely. Doctrine §6 #9 ("no MAS sandbox compromises in Pro paths") is the rule.

### `final_v2/` — load-bearing residuals (the most cited corpus)

1. **Master Doctrine & Implementation Cookbook** (`compass_artifact_wf-c2d78e2f...md`): the 12-moat audit, faculty roster (Hermes-3 8B + Llama-3.2 1B drafter + bge-small + AFM = ~5.6 GB resident), 10-stage SOAR replay, BLAKE3 Merkle chain, FSRS-6 epoch decay, AFM `@Generable` as structurer, Swift macro-static A2UI v0.9. **Largest single research artifact; cited by D1, D3, D4, D7, §3, §4.**
2. **`deep-research-report (4).md`**: KIVI vs TurboQuant decision, UniFFI 0.28→0.29.5 breaking changes, Apalis ETL specifics. **Cited by R14, W9.10, W9.25, W9.26, W9.27, W9.30, R16.**
3. **`deep-research-report (4) copy 2.md`**: critique of "over-indexing on parity" with Hermes/Claude. The moat is NOT "Hermes in SwiftUI" but "inspectable personal ontology + structured long-term memory." Hierarchical concept extraction, depth markers, emotional anchors, morning consolidation, brain-dump button. **Drives Doctrine §0 verdict + D6/D7/D8 deferrals.**
4. **`App Moats, AI Integration, and Master Plan.txt`**: provenance-plane substrate, ULID-keyed graph, DenseSlotMap arena, GRDB WAL + F_FULLFSYNC, 7-verb MCP, AFM `@Generable` for offloading, Hermes intercepts skills system, **BoltFFI 1000× speedup claim `[UNVERIFIED]`**, AnyView ban. **Cited by D1, D2, D3, D5, D6, D7, D8, D9, D12, §0 verdict, §1 four-planes, §6 #6.**
5. **`Epistemos Hackathon_ Deep Research Plan.txt`**: workspace-OS paradigm, Provenance Plane, A2UI v0.9 with VALIDATION_FAILED rejection, Night Brain, hierarchical concept extraction, SSM hardware acceleration, **BoltFFI 1000× claim `[UNVERIFIED]`**, MCP boundary spec.
6. **`deep-research-report (4) copy.md`**: SSM/hybrid models (Jamba, Nemotron, Mamba2-primed Qwen3-8B). **Used to gate W9.28 + D10 deferrals.** Correctly rejected as primary; SSM = memory sidecar only.

### `final_v3/` — load-bearing residuals (orthogonal to v2)

1. **`deep-research-report (4).md` (v3)**: the "Ambiguity Tax" framing — JSON-schema prompting + prompt industrialization (4-step recipe: strict format + template + rules + example) for >99 % JSON validity. Modular prompt trees (system/tools/memory/task split). Anthropic `cache_control` mechanics (90 % discount on cached subtrees, 5-min TTL, 1024-token minimum, 4-breakpoint cap). Tool Search defers ~85 % tokens. Ingestion pipeline (parsing → validation → auditing → feedback). **Directly informs N1 (Prompt Tree) — already SHIPPED via the 3-PR ladder.** **NOT yet absorbed: full provider-call optimization across all sites; Phase 3+ work.**

---

## §3 — Convergent claims (where 2+ corpora agree → likely already canonical)

| Convergent claim | Sources | Canonical absorption |
|---|---|---|
| Rust owns control plane (routing/policy/permissions) | All 4 corpora + PLAN_V2 §3.1 | DOCTRINE §3.1 + non-negotiable #6/#11 |
| MAS-vs-Pro dual build (sandbox + non-sandbox) | `advice/Claude paper.pdf` + `final/Privacy, Speed, SDK` + `final_v2/App Moats` | BUILD_MATRIX entire doc |
| Hermes is provider, NOT faculty (no architectural privilege) | `final/AI App Architecture Consensus` + `final_v2/App Moats` | DOCTRINE §2.2 (fifth-position ruling) |
| Closed A2UI catalog; no fallback inspector | `final_v2/Hackathon Plan` + `final_v2/Master Doctrine` + `final/rival-doctrine` (rejected as B-side) | DOCTRINE §2.3 + non-negotiable #4 |
| AFM `@Generable` as canonical structurer | `final_v2/deep-research-report (4)` + `final_v2/App Moats` | DOCTRINE §6 + STRUCTURING_AUDIT.md |
| Local-first + MAS-first; Pro deferred | `final/Privacy, Speed, SDK` + user memory `project_app_store_first_sequencing` | DOCTRINE §0 + BUILD_MATRIX + Phase S in PHASES.md |
| KIVI as opt-in flag, perplexity gate before default | `final_v2/deep-research-report (4)` + `final_v2/Master Doctrine` | DOCTRINE Bucket A + W9.30 in EXECUTION_MAP |
| 7-verb MCP graph boundary | `final_v2/App Moats` + `final_v2/Hackathon Plan` (Hermes manifesto names 6, v2 expanded to 7) | DOCTRINE §1 substrate plane interface (BUT D2 not implemented — see FUSED_AUDIT_VIEW Blocker #15) |
| BLAKE3 Merkle chain on OpLog | `final_v2/Master Doctrine` + `final_v2/App Moats` | D1 in EXECUTION_MAP — RESOLVED at `fe97e512` |
| Substrate durability (WAL + F_FULLFSYNC) | `final_v2/Master Doctrine` + `final_v2/App Moats` | D5 in EXECUTION_MAP — RESOLVED at `6d78593b` |

When these claims are convergent and absorbed: high confidence the canonical doctrine reflects them correctly.

---

## §4 — Diverging claims (where corpora disagree → fifth-position ruling absorbed which view)

| Tension | A view | B view | DOCTRINE ruling |
|---|---|---|---|
| Source of truth: AgentEvent (hot) vs MutationEnvelope (cold) | A: event bus is source (`final/AI App Architecture Consensus` Architect A) | B: provenance ledger is source (`final/rival-doctrine` Architect B) | §2.1 — **BOTH at different planes**. Hot path = AgentEvent for UI; cold path = MutationEnvelope for durable state. Conflating either way breaks the system. |
| Hermes: faculty (privileged) vs provider (equal) | A: faculty (`final/Hermes manifesto`) | B: provider equal to others (`final/rival-doctrine`) | §2.2 — **provider, not faculty**. Hermes gets dedicated UX (visual privilege) but no architectural privilege. |
| Fallback inspector for unknown A2UI schemas | A: allow degraded render | B: forbid; validation error | §2.3 — **forbidden**. Closed catalog. Unknown = `A2UIValidationFailure`. |
| First slice: horizontal pipeline vs vertical end-to-end | A: horizontal infrastructure first (`advice/Gpt paper`) | B: vertical end-to-end slice (`final/Hermes manifesto §III`) | §2.4 — **vertical first**. One slice that proves the spine, then horizontalize. |
| Cognition layer: 5 composable features vs 1 layer with 5 projections | A: composable (`advice/Perplexity paper`) | B: one ledger, five projections (`final_v2/App Moats`) | §2.5 — **one layer, five projections**. Provenance is the moat; splitting it splits the moat. |
| KIVI vs TurboQuant for KV quant | A: TurboQuant (`final_v2/deep-research-report (4)`) | B: KIVI first (`final_v2/Master Doctrine`) | DOCTRINE Bucket A: **KIVI first via opt-in flag; TurboQuant only if KIVI insufficient.** Mutually exclusive — pick one. |
| Three-lane memory model | A: durable + ephemeral + session-state lanes (`final_v2/deep-research-report (4) copy 2`) | B: one ClaimLedger with five projections (`final_v2/App Moats`) | §2.5 — rejects three-lane. Adopts hierarchical concept extraction + depth markers piece (D6) but rejects three-lane schema. |

When these are divergent: the DOCTRINE ruling is canonical. Read the rejected view only for historical understanding of why the chosen view won.

---

## §5 — What's NOT yet in canonical doctrine (load-bearing residuals; future-doctrine candidates)

Items the corpora promise but doctrine has NOT yet absorbed in actionable form:

1. **Dynamic few-shot prompting for local-model tool-calls** (`advice/Claude paper.pdf`) — mentioned in research but no execution-map item. Should be added when post-W9.25 grammar-masking work begins.
2. **Eposh memory decay (FSRS-6)** (`final_v2/Master Doctrine`) — D7 in EXECUTION_MAP but DEFERRED. The schema parameters (`epistemic_anchor`, `emotional_valence`, `cognitive_depth`, `salience_weight`) are research-phase only — NOT in any Claim struct in code.
3. **Nightly Metabolism + SleepGate consolidation** (`final_v2/Master Doctrine` + `final_v2/Hackathon Plan`) — D8 in EXECUTION_MAP but DEFERRED. Zero Swift consumers; no production wiring.
4. **Emotional anchors + structured JSON conversation histories** (`final_v2/App Moats`) — schema-designed but not wired to Swift UI. No emoji/valence scoring in Claim struct.
5. **MEMIT weight editing** (`final_v2/Hackathon Plan`) — research direction; not in any item.
6. **Loop Profiles in JSC/WASM sandboxes** (`final_v2/Hackathon Plan` + Hermes manifesto Part I §IV "editable brain") — speculative research; not spec'd in execution map.
7. **`epistemos-trace` CLI separate distribution** — D11 in EXECUTION_MAP, currently OPEN as Blocker (FUSED_AUDIT_VIEW §2 #18). Open Provenance Standard moat depends on it.
8. **BoltFFI 1000× speedup claim** (`final_v2/App Moats` + `final_v2/Hackathon Plan`) — explicitly `[UNVERIFIED]`. PLAN_V2 §22 covers BoltFFI strategy but speedup numbers stay marked unverified until measured. D12 in EXECUTION_MAP.
9. **Provenance plane primitives** (`final_v2/App Moats` + DOCTRINE §3) — the keystone. **100 % absent from code.** FUSED_AUDIT_VIEW §2 #19 = the largest unimplemented architectural debt.
10. **Schema-driven UI registry / `ViewRegistry`** (`final_v2/Master Doctrine` + Hermes manifesto Part I §V) — `StructureRegistry.swift` registers schemas but does NOT dispatch views. Doctrine §6 #4 closed catalog has no ViewRegistry-style runtime dispatch.

**Recommendation**: when an item from this list moves to "active priority", verify the relevant corpus passage hasn't been superseded by a newer drop, then promote into EXECUTION_MAP with explicit DoD + WRV + telemetry surface.

---

## §5.5 — Supplementary corpus drops: `/Downloads/{workspace, opt, ambient}/` (synced 2026-04-27)

A more recent research cluster centered on **how to build the Halo + Contextual Shadows feature** (canonical Phase H deferred work) at production-grade performance. Three sub-folders, distinct concerns, complementary findings.

### `/workspace/` — code-editor architectural lock + dual-editor workspace

- **`workspace_epistemos_code_verdict.md`** (in `70_design_implementation/`): the architectural lock for the code editor. Swift+TextKit2 owns the surface; **SwiftTreeSitter on the SwiftUI thread** for live syntax (the silent killer of Rust-FFI Tree-sitter is UTF-16↔UTF-8 mapping cost across the boundary, not the parsing itself); Rust **background brain** for project-wide symbols + RAG chunking; SourceKit-LSP for completion+diagnostics; Metal for visualization-only (minimap/diff overlays). Frames "Epistemos Code" as **Cognitive Execution Surface** with Provenance, not an Xcode clone. Decisive: "Stop researching. The architecture is bulletproof."
- **`workspace_gpt_workspace_architecture.md` + `_synthesis.md`** (in `70_design_implementation/`): dual-surface architecture — TextKit 2 native for **Prose**, Tiptap-in-WKWebView for **Document**, Raw Thoughts as run-scoped first-class artifacts. **Universal artifact envelope**: typed canonical body + projections (ProseMirror JSON canonical for Documents; Markdown shadow lossy; HTML for portable rendering; FTS5 over normalized `search_text` for retrieval). BlockNote as benchmark, Tiptap/ProseMirror as foundation.

### `/opt/` — deterministic performance program + 120fps editor

- **`perf_DETERMINISTIC_PERFORMANCE_PLAN.md`** (in `20_canonical_research/`) + **`perf_{CLAUDE_MD_ADDENDUM, CONTEXT_ESSENTIALS_APPEND, SPRINT0_KICKOFF}`** (in `40_canonical_prompts/`): 6-sprint × 12-week perf program. Sprint 0 (signposts + GRDB pragmas + LTO) → 1 (slotmap + SoA migration) → 2 (`phf` registries + `@ArtifactView` Swift macro) → 3 (Metal binary archive + Tree-sitter SoA highlight cache) → 4 (`substrate-rt` SPSC ring buffer; the variance sprint) → 5 (PGO + bumpalo arenas + mmap'd raw-thoughts log). **5 hard constraints**: NO hot-path serialization (>100 Hz events use `repr(C)` ring); NO main-thread Metal compilation (PSOs from `MTLBinaryArchive`); NO string-keyed dispatch in inner loops (phf or compile-time enum); NO allocation in render frames (bumpalo arenas reset per frame); EVERY optimization ships with a signpost + CI p99 assertion. **Does NOT touch `agent_core/`** — independent of Phase I.
- **`perf_invalidation_strategy.md`** (in `70_design_implementation/`): biggest measured Epistemos gain came from making **invalidation deterministic** (78×–167× incremental outline refresh; 35ms vs 150ms live invalidation floor), NOT from byte transport. Mutation envelopes + compiled query fingerprints + summary-first/visible-window-second/full-expansion-last pipeline + traffic-class split (interactive vs append-only). **Reaffirms BoltFFI 1000× as `[UNVERIFIED]`** — measured cost is on the consumer-side expansion path, not the transport.
- **`perf_editor_120fps_v1/v2/v3.md`** (in `70_design_implementation/`): three converging research dossiers on the same architecture. Replace `Binding<String>` with NSTextStorage delegate-driven incremental deltas (kills O(n) per-keystroke diff). Background actor for TreeSitterClient. Metal alpha-only glyph atlas + MSDF for sub-pixel crispness. Minimap as cached CALayer (`shouldRasterize=true`, `.onSetNeedsDisplay`). CADisplayLink keep-alive to prevent ProMotion downclock. `wait_until_scheduled` + triple-buffer instance buffers on M2+ direct mode. Specific bugs called out: macOS Sonoma+ `clipsToBounds=false` overpainting glyphs; `updateNSView` re-highlighting on every cursor move.
- **`perf_ffi_flatbuffers_research.md`** (in `70_design_implementation/`): theoretical model — control plane (UniFFI) vs data plane (FlatBuffers + zero-copy raw pointer projection); static compile-time SwiftUI routing replacing AnyView; Markov-chain probabilistic prefetching; MCP schemas as Rust static structs (procedural macros + `build.rs`); Tree-sitter AST atomic-pointer query path; mmap-backed SPSC ring with CADisplayLink pull-mode rendering. Heavy theory; some claims aspirational.

### `/ambient/` — V1 scope decision + Halo blueprint

- **`ambient_V1_DECISION.md`** (now in **`00_canonical_authority/`**): **single most decisive scoping doc in the entire research corpus.** V1 = sandboxed App Store with **Contextual Shadows + Halo as the only differentiator**; Pro/direct ships later for computer-use/agents/etc. **6-week roadmap.** **Performance budget table** (sub-25ms recall, <2ms MainActor, 60fps graph, <6ms ProMotion frame, 200ms debounce window). **Stack locked**: Model2Vec `potion-retrieval-32M` (256-dim, sub-1ms encode) + `usearch` 2.25+ HNSW (BF16, M=16, ef=64) + `tantivy` BM25 (title boost 2.0) + weighted RRF fusion (k=60, lex 1.2 / dense 1.0). **6-state Halo FSM**: Dormant → Sensing → Available → Open → EditingNote / SummarizingChat. **Apple Design Award angle** explicitly enumerated.
- **`ambient_swift_rust_metal_blueprint.md`** (in `70_design_implementation/`): hybrid architecture — Swift owns UI+Metal, Rust owns retrieval+parsing+ranking+indexing in-process via `cdylib`, UniFFI = control plane, **C-shim for zero-copy slabs + MTLBuffer wrapping** on hottest paths, optional XPC helper for risky/privilege-sensitive features (NOT for the hot path — UniFFI overhead tolerable; XPC overhead is not). FFI boundary policy table (UniFFI: config/handles/results/async/typed errors vs C shim: raw pointer+len+cap slabs; release callbacks; opaque handles). 7-milestone roadmap + 15-line code review checklist for FFI hardening.
- **`ambient_contextual_shadows_blueprint.txt`** (in `70_design_implementation/`): NSTextView dynamic caret tracking via `NSLayoutManager.boundingRect(forGlyphRange:in:)` projected through scrollView coordinate space; SwiftUI `.popover(attachmentAnchor:.rect(.bounds))` with note/chat segmented toggle; `.onContinuousHover` for live previews; nested `NSTextView` in popover for in-place edit of historical notes; `.contextMenu` summarize-this-chat. SemanticEngine actor wraps UniFFI; FFI calls via `withCheckedContinuation` on serial `userInitiated` DispatchQueue. ModelActor pattern for SwiftData @Query cascade prevention. **Mirror Speculative Decoding** (NPU draft model + GPU verification model = 2.8×–5.8× speedup) for local LLM acceleration. ARM NEON `vfmaq_f32` intrinsics in usearch (3.4×–3.7× over scalar) on Apple Silicon.

### Convergent across all three sub-folders (likely → canonical absorption)

- **Native macOS, no Electron.** Swift owns UI+Metal; Rust owns core algorithms; UniFFI = control plane; bulk data via C shim or shared MTLBuffer.
- **120fps ProMotion requires zero CPU-bound rendering** — Metal alpha glyph atlas + MSDF + CADisplayLink keep-alive + triple-buffered instance buffers + `wait_until_scheduled`.
- **Tree-sitter must be background-actor isolated** with immutable content snapshots; three-phase highlighting (sync fallback → async tree-sitter → high-latency LSP) for zero flicker.
- **`Binding<String>` for editor text is catastrophic** at scale; NSTextStorage with delegate-driven incremental deltas is the only viable shape.

### Divergent from current canonical doctrine (architectural tension to resolve)

- **V1 scope tension**: ambient_V1_DECISION says "ship Halo+Shadows alone for V1, Pro later"; current `MASTER_BUILD_PLAN.md §7` queue has 36+ V1.5 items. **Reconciliation**: V1 = MAS Halo+Shadows ship; V1.5 = post-V1 broader item set. `04_PHASES.md` should be updated.
- **BoltFFI 1000× claim**: still `[UNVERIFIED]` per `perf_invalidation_strategy.md` and prior `/final v2/` dossiers. Perf plan opts for narrow `substrate-rt` `repr(C)` ring buffer carve-out instead of BoltFFI-everywhere.
- **Code editor approach**: `workspace_epistemos_code_verdict` says abandon CodeEditSourceEditor for live syntax (FFI mapping cost is the silent killer); `perf_editor_120fps_v1/v2/v3` say upgrade-and-patch CodeEditSourceEditor 0.13.1+. **Resolution**: hybrid layer split (already in PLAN_V2 §23) is canonical; patch path lets you ship faster, verdict architecture wins long-term.

### NOT-yet-canonical residuals (additions to §5)

11. **Halo 6-state FSM** (V1_DECISION §"The state machine") — not in `03_EXECUTION_MAP.md`. Should anchor a Phase H entry.
12. **Performance budget table** (V1_DECISION + perf plan) — concrete numerics not codified anywhere in canonical doctrine. Append to `01_DOCTRINE.md §4`.
13. **5 deterministic-perf hard constraints** (perf plan §0.3) — should be performance non-negotiables addendum to `01_DOCTRINE.md §6`.
14. **NSTextStorage incremental delta pipeline** (perf editor 120fps cluster) — should be Phase 0 ship blocker for the code editor surface.
15. **Mirror Speculative Decoding (NPU+GPU)** (gemini ambient) — local LLM acceleration via dual-accelerator dispatch. Currently nowhere in plan tree.
16. **6-sprint perf plan integration** — Sprint 0 (signposts + GRDB pragmas + LTO) is high-value low-risk; should ship before more feature work lands.

---

## §6 — How to use this digest

1. Read this digest first when you're new to the project — it tells you what corpus exists and where to look.
2. Read the appropriate corpus folder when picking up an item that cites it (per `00_canonical_authority/05_RESEARCH_INDEX.md` reverse-index).
3. Read `EPISTEMOS_HERMES_MANIFESTO.md` (in `70_design_implementation/` and `50_research_corpus/final/`) for the strategic / aesthetic frame. It sets the tone for what "shipped well" means.
4. **Don't skip the corpus-specific docs** — this digest is navigation, not substitute. The originals win.

---

## §7 — `[UNVERIFIED]` markers (preserve when citing)

The corpus documents that introduced these markers preserved them honestly. Do not strip when citing.

- **BoltFFI 1000× speedup**: `final_v2/App Moats` + `final_v2/Hackathon Plan`. Explicitly marked unverified. PLAN_V2 §22.5 measurement protocol must run before any BoltFFI migration.
- **A2UI v0.9 envelope shape**: `final_v2/Hackathon Plan`. Schema needs cross-check against any A2UI implementation (D3 in EXECUTION_MAP).
- **MCP server discovery patterns**: portions of `advice/claudy research.md` cite April 2026 doc state; verify against current Claude Code docs before relying on field semantics.

---

## §5.6 — Master plans corpus + Downloads/jojo root expansion (synced 2026-04-27 — second pass)

User directive (2026-04-27): pull all research at `~/Downloads/` root + nested folders + `~/jojo/` root, prioritizing recency + topics (MAS, Pro mode, CLI, Hermes, agent integrations). Bulk-copy with content-hash dedup; originals untouched. Final corpus state: **440 files** in `_consolidated/` (up from 95).

### New tier subdirs under `50_research_corpus/`

| Subdir | Files | Content |
|---|---|---|
| `master_plans/` | 8 | The 8 master-plan-class docs (THESIS, MEGAPROMPT, MOAT, gap-closure, PLAN_V2_UPDATED, PHASE_I_GUIDE, master_plan_doc, harness-engineering-thesis). Synthesized into **`00_canonical_authority/MASTER_FUSION.md`** (the single checkable execution doc the user requested). |
| `downloads_root/` | 184 | Unique research from `~/Downloads/*.{md,txt}` after content-hash dedup (195 → 184). Includes Architecture Hardening, Cognitive Exoskeleton, Custom Metal Mamba 2 Implementation, Epistemos Definitive Security & Concurrency Failure Analysis, EW Agent System Verification Plan, Open Claw and Hermes Agent Analysis, Stateful Rotor implementation reference, full cap1..cap6 capabilities pack, moral.md series, unified.md series, all CMS-X variants. |
| `old_research/` | 41 | Topical research: EPISTEMOS-NORTH-STAR, EPISTEMOS-NANO-MASTER-TRAINING-GUIDE, Designing Epistemos Time Machine UI, Epistemos Instant Recall (Mamba+Quantized Vector Memory), Epistemos Omega Dual-Brain Hardware-Action Protocol, Local AI Agent Architecture Research, On-Device AI Training System Research, MLX Constrained Decoding, Mac AI Assistant Design Blueprint, Cognitive OS & Local Model Blueprint, App-Specific Training + Multi-Scale Model Family (Nano/Base/Pro), Legendary Nano Model. |
| `mass_research/` | 65 | Cross-folder research from `mass research folder` + `next batch of unsorted research` + `unsort3ed research` after dedup. Mostly capability-pack + unified-memory research. |
| `jojo_root/` | 3 | `epistemos-master-session-prompt.md`, `master research in quant.md`, `vector quant.md`. |
| `meta_analytical_pfc/` | 11 | Meta-analytical PFC research (cognitive control + attention allocation). |
| `audit_dir/` | 11 | `~/Downloads/audit/` deep-research artifacts. |
| `last_feature/`, `new_features/`, `new_make_sures/`, `soaar_research_mode/`, `livingbrain/`, `fluid_dir/` | 11 | Smaller topic clusters. |

### Master plans synthesis verdict

Two parallel Explore-agent passes (covering all 8 master plans + 218 topical research files) produced a structured digest. **Key findings**:

1. **The 8 master plans layer naturally** — see MASTER_FUSION §2 for the layering. Not duplicates: **THESIS + HARNESS** (why) → **master_plan_doc** (cognitive blueprint) → **PLAN_V2** (architecture/doctrine) → **MEGAPROMPT** (sprint operationalization) → **PHASE_I_GUIDE** (Phase I deep dive) → **gap-closure-plan** (Opus 4.6 audit) → **MOAT** (post-impl audit, 2026-04-27).
2. **Authoritative collapse**: MEGAPROMPT (action items, 7 workstreams × 17 days) + MOAT (verification oracle, file:line audit) is the canonical execution-pair; PLAN_V2 is the architectural appeal layer.
3. **5 hard blockers from gap-closure-plan** surfaced in MASTER_FUSION §6.9: training-data unwired, deploy-gate auto-passes, AX capture wrong app, no training run completed, 93% Epistemos-symbol-QA data mix.
4. **20 verified moats** from MOAT §2: Prompt Tree, AFMSessionPool, UndoableIntent, Visual Intelligence scaffold, Focus filters, MetalGraphView, FSRSDecayStore, ConversationStateClassifier, IntakeValve, NightBrain, Tiptap batching, Spotlight indexing, ControlWidget, voice I/O, Reasoning Trajectory, Halo, honest gating, Hermes orchestration, Swift 6 strict concurrency.
5. **17-model lineup** (MEGAPROMPT §1.1 — 6 MLX + 11 GGUF) is a roadmap deliverable; not yet shipped.

### Topical findings from 218-file scan

| Topic | Key sources | Status |
|---|---|---|
| **MAS / App Store / Pro mode** | PLAN_V2 §3.2/§3.4/§16, Omega protocol §"APP STORE DISTRIBUTION", `ambient_V1_DECISION.md` | V1 = sandboxed MAS with double-helper SMAppService; Pro = direct distribution post-V1. Halo + Shadows = sole differentiator. |
| **CLI integration** | CLAUDE-CODE-FIRST-START-PROMPT, EPISTEMOS-CODEX-PLAN, capability-tunnels.md, mcp-url-servers.md | Phase 1 stable runtime + Phase 1.5 capability handshake + Phase 2 compute steering. 5 orphaned tools (delegate_task, file_ops, memory, skills, web_fetch) need registration in `agent_core/src/tools/registry.rs` (30-min Hermes Phase 1). |
| **Hermes parity** | EPISTEMOS-HERMES-PARITY-PLAN | 5-phase closure plan; 20+ tools shipped vs Hermes 53. Memory + graph **exceed** Hermes; agent hierarchy **exceeds**. |
| **Agent system (Omega Dual-Brain)** | Epistemos Omega — Dual-Brain Hardware-Action Protocol | Reasoning Brain (DeepSeek-R1 32B 4-bit on GPU) + Device Action Agent (Gemma 3 1B on ANE via CoreML/Metal). **Mirror Speculative Decoding** (Apple ML Research, arXiv 2510.13161) gives 2.8×–5.8× speedups. **UI-TARS** (ByteDance) 61.6% ScreenSpotPro vs Claude 27.7%. **VLM2VLA** representing actions as natural language preserves 85%+ base VQA. **MoLoRA** per-app adapters. ANE 0 mW idle = perfect for 100ms polling watcher. **ODIA** (Overnight Distillation + In-Memory Adaptation) nightly LoRA training on execution traces. |
| **Memory architecture** | Epistemos Instant Recall, TurboQuant deep dive, Mamba-3 research | **Mamba-3** (March 2026): exponential-trapezoidal discretization, complex-valued SSM states, MIMO SSMs, **constant memory footprint** (no KV growth). Memory decay problem solved by **MemMamba** (threshold-triggered state summarization + cross-layer attention, 48% inference speedup). **Optimal stack**: Tier 1 Model2Vec (32K×256-dim, microseconds), Tier 2 EmbeddingGemma 308M (or NLContextualEmbedding), Tier 3 binary quantization (1-bit, 32× memory reduction) via `usearch` HNSW, Tier 4 Mamba-3 state injection. **Two-phase retrieval**: binary ANN top-100 (sub-ms) → float32 rescoring top-5 (2ms). **PolarQuant/QJL** are model-level KV optimizations, NOT index primitives — deferred to Phase 4. |
| **Training pipelines** | EPISTEMOS-NANO-MASTER-TRAINING-GUIDE, App-Specific Training + Multi-Scale Model Family | Phase 0 synthetic data via Claude Opus → Phase 1 MLX LoRA fine-tune (r=16, alpha=32, 2000 iters, batch 2) → Phase 2 per-app adapters (500 iters each: safari/terminal/mail/notes/finder) → Phase 3 CoreML ANE conversion (int8) → Phase 4 ODIA nightly loop. Multi-scale family: Nano 1B (ANE), Base 3B (GPU), Pro 7B+ (GPU + cloud fallback). |
| **UI/UX (Time Machine)** | Designing Epistemos Time Machine UI | Spatial Persistence (Memory Palace, hippocampal place cells) + Fluid Topological Morphing + Ambient Effects. 4-layer Metal shader pipeline: SDF Metaballs + Reaction-Diffusion (Gray-Scott) + Curl Noise particles + Volumetric Nebula. Material Point Method + strain energy minimization for delta visualization. CAMetalLayer (not MTKView) + zero-copy `MTLStorageModeShared`. <5% GPU compute, <50MB VRAM. |
| **Audit/hardening** | EPISTEMOS_MOAT, Architecture Hardening (AppSupervisor + EpistemosMode + FFI Safety + Inference Resilience), Epistemos Canonical Pattern Integrity Audit | 4 failure modes: capability drift, serial invariant violation, poisoned adaptation, mask instability. AppSupervisor "simplified" (polling not event-driven), EpistemosHealthMode "simplified" (no causal chain), AgentCircuitBreaker "near-canonical" but sticky failure counter, FFI catch_unwind "compromised" (panic=abort makes it no-op), Foundation Models Session "near-canonical" (no token budget guard), ThermalGuard "missing" entirely. |

### NEW NOT-yet-canonical residuals (additions to §5)

17. **Mirror Speculative Decoding NPU+GPU** for local LLM acceleration (Apple ML Research, arXiv 2510.13161) — 2.8×–5.8× wall-time speedup. Already noted in §5 #15 from `gemini ambient`; reinforced by Omega protocol.
18. **Dual-Brain (Reasoning GPU + Device Action ANE) hardware-action architecture** — Omega protocol locks DeepSeek-R1 32B 4-bit (Reasoning) + Gemma 3 1B fine-tuned (Device Action) with 100ms ANE visual verification loop.
19. **VLM2VLA natural-language action representation** — preserves 85%+ base VQA via UI-TARS pattern (representing AX selectors and CGClicks as natural language strings, not token IDs).
20. **MoLoRA per-app adapter routing** — Safari/Terminal/Mail/Notes/Finder LoRA adapters hot-swapped via NSWorkspace observer without reloading base model.
21. **ODIA nightly LoRA flywheel** — Day 1 user runs tasks → traces to SQLite → Night 1 LoRA training on today's data → Day 2 device agent has improved adapter. Gated on G.4 hard blocker (no training run has completed).
22. **Gap-closure 5 hard blockers** (G.1–G.5 in MASTER_FUSION §6.9) — training data unwired, deploy gate auto-passes, AX capture wrong app, no training run completed, 93% Epistemos-symbol-QA data mix. **None yet in `03_EXECUTION_MAP.md`** — should be added as W-band items.
23. **17-model `LocalTextModelID` enum** (MEGAPROMPT §1.1) — 6 MLX + 11 GGUF, with `ramRequirementQ4GB` + `ramRequirementQ8GB?` fields. Not in current code; required for WS1 sprint.
24. **Reasoning Trajectory Badge 5-bucket telemetry** (Efficient | Exploratory | Hesitating | Stuck | Failed) — shipped in `ReasoningTrajectoryBadge.swift` per MOAT §2.16, but not in canonical doctrine.
25. **Time Machine immersive temporal navigation** — 4-layer shader pipeline + spatial persistence metaphor + Material Point Method physics. Phase H+ deferred research; valuable.

### `[UNVERIFIED]` additions

- **VisualIntelligenceIntents.swift exists** — MOAT R6 says it does; Lane C reported not creating it. **Verify**: `ls Epistemos/Intents/Schemas/VisualIntelligenceIntents.swift`
- **5 major tools "already implemented but unregistered"** — Codex plan asserts; not independently verified. **Verify**: `grep -rn "delegate_task|file_ops|memory.rs|skills.rs|web_fetch" agent_core/src/tools/registry.rs`
- **PowerGate.shouldDefer() actually called from NightBrain** — function defined; call path not verified. **Verify**: `grep -rn "PowerGate.shouldDefer|PowerGate.canRunNow" Epistemos/`
- **Multi-turn PTF replay shipped** — ChatCoordinator:2216 comment says first-turn-only. **Verify**: read `ChatCoordinator.swift:2213-2249`
- **Mamba-3 beats Transformer at 220K context** — paper claim; Epistemos benchmark pending.
- **Sub-5ms meta-memory retrieval** — THESIS architectural claim; benchmark on real corpus pending.

---

## §8 — Last sync

- **2026-04-27 (initial)**: 4 Explore-agent passes (Advice/final/final v2/final v3 corpora) + manual full-read of `EPISTEMOS_HERMES_MANIFESTO.md`.
- **2026-04-27 (second pass)**: 2 additional Explore-agent passes — (1) 8 master-plan-class docs synthesized into `MASTER_FUSION.md`, (2) topical scan of 218 research files (old_research + downloads_root subset) covering MAS / Pro mode / CLI / Hermes / agents / memory / training / UI / audit. **Corpus expanded from 95 → 440 files.** New tier subdirs created. Originals untouched.

Re-sync this digest if a new corpus drop lands (e.g. `/Downloads/final v4/`) or if any rejected view in §4 is reopened by user / new doctrine ruling.
