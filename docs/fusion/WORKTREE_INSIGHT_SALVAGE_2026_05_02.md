# Worktree Insight Salvage — 2026-05-02

> **NEW DOC — created 2026-05-02.** Filename: `WORKTREE_INSIGHT_SALVAGE_2026_05_02.md`. If your session can't find it, search by name. Sister docs: `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md`, `CODEX_FINAL_EXECUTION_PROMPT_2026_05_01.md`, `ALL_DOCS_INDEX_2026_05_02.md`. Mirrored into the active worktree's `docs/fusion/`. This is the answer to: **"Did I leave behind insight in any worktree that was never continued and just died out?"** Compiled by spawning 6 parallel survey agents — one per active worktree + one for the four `codex/*` branches that aren't checked out anywhere. Each agent embodied the worktree's original session perspective and read the worktree's *own* plan/progress/handoff/decision docs (NOT the main checkout's fusion canon).

This is a **read-mostly doc.** No code changes are required from reading it. Its purpose is to ensure no insight from any worktree dies silently as Epistemos consolidates into the final Core / Pro / Research tier matrix.

---

## TL;DR — The Stay-Stellar Checklist

If you only do ten things from this doc, these are the ones that protect the app from regression as the doctrine ships. Sorted by re-derivation cost if abandoned.

| # | Insight | Lives in | Cost if lost | Doctrine link |
|---|---|---|---|---|
| 1 | **Tool trait + `execute_v2` dispatch + `LEGACY_TO_V2_ALIASES` (56 entries, ~54 conversions remaining)** | `worktree:vigorous-goldberg-3a2d35/agent_core/src/tools/registry.rs` | 2–3 weeks reverse-engineering from 20+ separate commits | All — substrate the killer features ride on |
| 2 | **`Capability::BiometricSession { ttl_secs }` enum variant** in ExecutionReceipt | `worktree:vigorous-goldberg-3a2d35/agent_core/src/effect/receipt.rs` lines 44–54 | Sovereign Gate would re-derive a different shape and diverge from substrate | Doctrine §4.2 (Sovereign Gate) — **direct dependency** |
| 3 | **GBNF capture-routing classifier + centroid embedding + concept canonicalizer** | `worktree:vigorous-goldberg-3a2d35/agent_core/src/route/` (Phases 3A–3F), plus `agent_core/src/grammar/mod.rs` and `agent_core/schemas/route_capture.*.json` | Resonance Gate δ component would be re-derived; thresholds would drift | Doctrine §4.1 (Resonance Gate δ) — **direct dependency** |
| 4 | **§23–§27 PLAN_V2 architectural law** — code editor truth, 16ms agent streaming coalescing, graph zero-copy gating, 15 anti-patterns | `worktree:inspiring-heisenberg-ea9dc3` PLAN_V2.md sections | Future optimizations would violate established patterns; "do not optimize features that only exist in documentation" rule lost | Doctrine §2.2 (architectural invariants) — codifies them |
| 5 | **CODE_EDITOR_FEATURE_AUDIT.md** — single source of truth on what is verified live vs planned vs reverted (e.g., minimap is gone, outline navigator is live) | `codex/runtime-input-audit` branch (NOT checked out) | Re-work on already-deleted features; misinformation-driven editor decisions | Cross-cutting — affects every editor slice |
| 6 | **5 Laws + Phase I (Rust agent migration) MANDATORY pre-release** | `codex/runtime-memory-hardening` branch (NOT checked out), commit `6820f163` | Doctrine's Markov-blanket-via-Rust-ownership invariant loses its sequencing rationale | Doctrine §2.2.3 (Markov blanket) — provides the migration order |
| 7 | **Three-placement registry pattern** — Landing Farm + Graph Live Theater + Sidebar Skin = ONE `CompanionRegistry` projected through filters | `worktree:simulation/docs/simulation-mode/DOCTRINE.md` §3 | Pro UI rebuilt from scratch when Pro tier ships; surfaces fragment | Pro tier UX coherence |
| 8 | **Six new `AgentEvent` variants** — `SteerRequested`, `SummaryStarted`/`Delta`/`Completed`, `VaultCreated`, `VaultArchived` | `worktree:simulation/docs/simulation-mode/DOCTRINE.md` §11 v1.6 | Pro tier sidebar dispatch + multi-vault UI lose their canonical event protocol | Doctrine §4.1 emission events |
| 9 | **Honest-handle FFI pattern** (W9.21 PR4) — `Arc::into_raw` discipline, `catch_unwind` panic safety, single-owner per Rust object | `worktree:agent-a0550f9c` (`epistemos-shadow/src/honest_handle.rs` + `RustShadowFFIClient.swift`) | Every future Rust↔Swift boundary repeats the same design discovery | Doctrine §2.2.3 invariant — should be canonical FFI doctrine |
| 10 | **30-case heal-recovery eval methodology** + diagnostician.soul.md test fixture | `worktree:vigorous-goldberg-3a2d35/agent_core/src/bin/heal_eval.rs` | Resonance Gate verification testing rebuilt from generic patterns instead of substrate-specific ones | Doctrine §4.1 verification testing |

The five killer-feature dependencies (#2, #3, #6, #8, #10) are the ones that would force Codex to **redesign substrate** when implementing the doctrine. Salvage those as deliberation-brief docs first.

---

## 1. agent-a0550f9c (locked) — Audit Pass #3 + OpLog hardening

**Mission:** Sustained research + architecture pass for Epistemos release hardening across three audit passes. Built code editor redesign with AI features, shipped foundational FFI infrastructure, validated canonical plan to finish FFI multi-turn continuity, thinking UI, local model safety, context retrieval, tool execution.

**Closed and merged:**
- W9.27 PR3 — BLAKE3 Merkle chain on OpLog (commit `fe97e512`)
- D1 — BLAKE3 chain appended on initial write + reopen-resume
- D4 — Faculty roster fallback (`4c0c7e17`): Hermes 4.3 36B demoted to ≥32GB opt-in; Qwen 3 8B fallback for 16GB
- Audit pass #3 canonical fusion (`6cd47481`)

**Abandoned insight (still mid-flight in dirty files):**

| # | Insight | File | Status | Tier | Action |
|---|---|---|---|---|---|
| 1.1 | Honest-handle FFI pattern | `epistemos-shadow/src/honest_handle.rs` (770 lines), `Epistemos/Engine/RustShadowFFIClient.swift` (321 lines) | Code complete, undocumented as reusable doctrine | Core | **Salvage now** — generalize as canonical FFI ownership pattern across all Rust↔Swift boundaries |
| 1.2 | Weighted context engine (5-factor scoring: `semantic*0.35 + nodeWeight*0.25 + complexity*0.20 + connection*0.15 + recency*0.05`) | `HANDOFF_SESSION_2026-04-07.md`, `WeightedContextEngine.swift`, `CodeComplexityAnalyzer` | Designed, possibly compiled, ship status unclear | Pro | Salvage later — verify compile, ship in Pro bundle after code editor lands |
| 1.3 | FFI opportunity matrix doctrine — KEEP/TUNE/BATCH/ZERO-COPY/REWRITE/REMOVE classification | `FFI_OPPORTUNITY_MATRIX.md` | Strategic guidance documented; tactical optimizations never scheduled | Both | Keep as reference; implement only when profiling justifies |
| 1.4 | Local model safety — unified `ModelSupervisor` with admission control before load, eviction on memory pressure, explicit refusal instead of silent swap death | `RELEASE_HARDENING_CANONICAL_PLAN_2026-04-20.md` §1.3 | Diagnosed but deferred to post-release | Core | **Salvage now** — required before Core ships |
| 1.5 | FFI multi-turn message continuity — native message array instead of XML flattening | Same plan §1.4; touches `agent_core/src/bridge.rs`, `agent_loop.rs`, `context_loader.rs` | Identified P1 architectural debt; never started | All | **Salvage now** — blocks tool-call continuity, prompt caching, thinking-signature preservation |
| 1.6 | Contextual Scalpel — neural OS context assembly layer | `CONTEXTUAL_SCALPEL_IMPLEMENTATION_PLAN.md` | Architectural design complete; no code | Pro / Research | Salvage later — basic note context first; full budget-aware ranking is research |
| 1.7 | Inline thinking UI (in-bubble auto-expand/collapse vs detached popover) | Plan §1.5 | Requirement accepted; deferred | All | Salvage later — promote when designers approve |
| 1.8 | OpLog projection / export / replay segments beyond chain verification | Substrate ready (PR1–PR4B closed); projection layer not scheduled | open | Research | Defer indefinitely — substrate is solid |
| 1.9 | Faculty-roster intelligent routing (specialty-based, not just fallback) | D4 fallback shipped; deeper specialization not scheduled | open | Pro / Research | Defer — fallback solves the immediate problem |

**Critical:** Insights #1.1, #1.4, #1.5 are the load-bearing items. The honest-handle pattern is invisible to anyone reading main, but it's the canonical Rust↔Swift ownership rule for the whole codebase.

---

## 2. hermes-parity — 28 tools + provider chain + session persistence

**Mission:** Port Hermes agent infrastructure to native Rust (`agent_core` crate), then extend with PKM-specific tools. Final state: 95%+ production parity with Hermes on agent infrastructure, 28 registered tools.

**Closed:** 22 Hermes-parity tools + 6 PKM-specific tools (graph_query, note_template, note_linker, research_digest, citation_extractor, markdown_table). Provider chain delegated to Swift `TriageService` callback. SQLite session persistence with FTS5. Credential rotation pool.

**Abandoned insight:**

| # | Insight | File | Status | Tier | Action |
|---|---|---|---|---|---|
| 2.1 | **Hermes prompt format** — does it use NousResearch ChatML XML? Plain markdown prompts found in `agent_core/src/prompts.rs`; no `<\|im_start\|>` blocks; no `HermesPrompt` builder | `agent_core/src/prompts.rs` | **Gap** — Pro tier may need to ship a `HermesPrompt` encoder matching Hermes v0.7.0 if NousResearch ChatML is required | Pro | Decide explicitly: do we need ChatML for Pro? If yes, scaffold the encoder. If no, document that Hermes-as-orchestrator uses plain prompts. |
| 2.2 | **Session persistence schema design** — `(session_id, turn_number)` PK + FTS5 enables turn-level resume + cross-session search; **better than Hermes flat JSONL** | `agent_core/src/session_persistence.rs` lines 54–101 | Production-quality, undocumented for handoff | Pro | **Salvage now** — copy schema diagram + design rationale into Pro tier wiki before consolidation. `active_provider` + `active_key_index` fields enable resuming with different API key pool state — critical for fallback |
| 2.3 | **Credential rotation pattern** — round-robin with per-session reset, distinguishes "temporarily exhausted" vs "permanently exhausted" | `agent_core/src/credential_pool.rs` | **Gap: no Keychain integration.** Credentials are plain `Vec<String>` in memory. Hermes uses macOS Keychain; this codebase does not. | Pro | **Risk** — wire `CredentialManager` into `AgentEventDelegate` callback. Document that credentials must be loaded from Keychain into the pool before `register_pool()` is called. |
| 2.4 | **Error classifier — 100+ patterns** across 6 categories (billing, transient, context overflow, auth, disconnect, Chinese provider) | Mentioned in `CODEX_REVIEW_REPORT.md`; **may not be wired into agent_loop** — `error_classifier.rs` not in registry | **Possibly dead code** — verify whether it ships | Pro | **Salvage now** — verify file exists, register in `registry.rs`, wire into agent_loop. If not, this is Phase 8 hardening work that's stranded. |
| 2.5 | **Apple Intelligence fallback** in TriageService | Commit `5755f421` "P0 fixes: session UUIDs, TriageService fallback, Apple Intelligence" | **Unclear** — is `apple_intelligence` a real `Provider` variant or placeholder string? | Both | Clarify — if placeholder, that's a gap; if real, document the on-device escalation path |
| 2.6 | **Rate-limit tracker `parse_duration_str()`** — accepts "1s", "60s", "1m", "5m30s" — flexible parsing buried in test-only code | `agent_core/src/rate_limit_tracker.rs` lines 167–179 | Shipped but Core-tier salvage missed | Both | Extract `parse_duration_str()` into public utility; Core tier can display backoff timers even if it can't enforce waits |
| 2.7 | Computer-use tool — Swift-delegated stub | `agent_core/src/tools/computer_use.rs` (91 lines) | Intentional placeholder — no gap | Pro | Document as "Swift-delegate boundary" so future readers don't add a Rust impl |
| 2.8 | MCP server tool stub — discovery works, execution not connected | `agent_core/src/tools/registry.rs` line 815 (`// TODO: Load server config and establish connection`) | Half-finished | Pro | Salvage when MCP tunnels ship in Pro |
| 2.9 | Per-tool call counts in session metrics | `agent_core/src/session_insights.rs` line 271 (`// TODO`) | Diagnostic feature, low priority | Pro | Defer |

**Critical risk:** Insights #2.2 and #2.4 — losing the session persistence schema knowledge means Pro tier flat-files like Hermes. Losing the error classifier wiring (if it really is unregistered) means 100+ pattern coverage is dead code in Phase 8 hardening.

---

## 3. inspiring-heisenberg-ea9dc3 — Sessions 0–6, benchmarks, BoltFFI, syntax-core

**Mission:** Across 7 sessions, harden Epistemos Phase 7 → measurable, benchmarked, release-scoped. Establish truth (audits), instrument FFI (signposts + criterion), harden concurrency (Swift 6), prototype typed buffers (BoltFFI graph), build syntax-core scaffolding, instrument agent streaming. Sessions 7+ never started — all gated on benchmarks.

**Closed:** Editor doc-truth audit, benchmark harness (`graph_ffi_baselines.rs`, `parse_baselines.rs`), Swift 6 hardening (6 force-unwraps + 1 isFinite guard removed), BoltFFI typed-buffer prototype (behind `bolt-graph` flag), syntax-core scaffolding (tree-sitter + ropey + token registry + generation counter), streaming instrumentation (`Log.agentStreaming` signposts), three runtime fixes (beach ball / pinned inspector freeze / Vec drop crash).

**Abandoned insight (this is the architectural-law worktree):**

| # | Insight | File | Status | Tier | Action |
|---|---|---|---|---|---|
| 3.1 | **§23 Code Editor Architecture Truth** — TextKit 2 + SwiftTreeSitter + Rust + SourceKit-LSP; Metal **prohibited** for text rendering; viewport-scoped tokenization mandatory; `SyntaxTokenSpan` is 12 bytes flat `#[repr(C)]` | `worktree:inspiring-heisenberg-ea9dc3/docs/architecture/PLAN_V2.md` §23 | Architectural law; not all wired to Swift yet | Core | **Salvage now** — these are the editor invariants the doctrine §2.2 inherits. Reference them; do not let Codex re-derive |
| 3.2 | **§24 Agent Streaming Data Plane — 16ms token coalescing is the FIRST optimization, not transport change.** Reduce 100–300 events/sec → ~60 events/sec; never coalesce errors / approvals / completions | `PLAN_V2.md` §24 + `Log.agentStreaming` signposts | Spec exists; coalescing not implemented | All | **Salvage now** — the Resonance Gate's Σ emission must batch at 60Hz, not per-token. Same pattern. |
| 3.3 | **§25 Graph Zero-Copy** — triple-buffered `MTLBuffer.storageModeShared` + struct-of-arrays. **Deferred until Session 3 typed-buffer proves copy is the bottleneck.** | `PLAN_V2.md` §25, `graph-engine/src/bolt_bridge.rs` | Decision gate locked; no benchmarks yet | Research | Defer — but document that BoltFFI typed-buffer is in production-by-flag awaiting comparative benchmark |
| 3.4 | **§26 Future-session conditionals** — Sessions 7+ authorized only if their prerequisite benchmarks justify them | `PLAN_V2.md` §26 | Sessions 7+ never started | Research | Honor the gate — do not start optimization sessions without first reading the benchmark JSON |
| 3.5 | **§27 Anti-Pattern Register — 15 explicit prohibitions.** Most load-bearing: "Do not optimize features that only exist in documentation. Verify code first, then optimize." | `PLAN_V2.md` §27 | Architectural law; not enforced via tooling | All | **Salvage now** — this is the spirit of doctrine §2.2.4 (tiered determinism). Reference §27 in deliberation briefs |
| 3.6 | **`Log.agentStreaming` event taxonomy** — `thinkingDelta`, `textDelta`, `toolStarted`, `toolCompleted`, `turnStarted`, `complete`, `error` already instrumented at delegate + coordinator | `Epistemos/Bridge/StreamingDelegate.swift`, `Epistemos/App/ChatCoordinator.swift`, `Epistemos/Engine/Log.swift` | Live in main | All | The Resonance Gate's Σ emission can ride this taxonomy — it's already there |
| 3.7 | **syntax-core crate — complete scaffolding, NO Swift bridge** | `worktree:inspiring-heisenberg-ea9dc3/syntax-core/` | Crate compiles + tests pass; `cargo test -p syntax-core` green; no `#[no_mangle]` exports | Pro | **Salvage when Pro editor ships** — export FFI surface, integrate into `CodeEditorView.swift` behind a feature flag |
| 3.8 | **BoltFFI typed-buffer prototype** behind `bolt-graph` feature flag | `graph-engine/src/bolt_bridge.rs` + `Cargo.toml` | Zero coordinate drift verified; never benchmarked vs C FFI in production | Pro | Defer — run comparative benchmarks before any production switch |
| 3.9 | **Three runtime-fix root causes** (transferable patterns): | `graph_engine_free_prepared_retrieval_candidates` (Vec drop), `force_alive` flag (idle-skip bypass), `Task.detached` for embedding KNN | All shipped | Core | The patterns matter: **(a)** every manual `Vec::from_raw_parts` boundary is a future crash unless you use `Box::into_raw`/`Box::from_raw`; **(b)** any continuous-state UI feature needs a `force_alive` opt-out from idle skip; **(c)** any expensive Rust FFI call >100ms must move off-main |
| 3.10 | **Swift 6 concurrency audit narrowly scoped** — full strict-concurrency mode never run | Session 2 commit `76ae58a6` | 6 force-unwraps + 1 NaN guard removed | Core | Salvage when Swift 6 strict mode is enabled — actor isolation holes likely remain in callbacks |

**Critical:** §23–§27 PLAN_V2 sections are the **architectural law** the doctrine inherits. Anti-pattern register is the operational discipline. The benchmark harness is the measurement foundation. Without these, every future optimization is speculative.

---

## 4. simulation (frozen) — Highest design density Pro donor

**Mission (DOCTRINE.md verdict):** *"Make Epistemos's architectural depth visible and felt in 60 seconds through a deterministic visual projection of session state."* The moat is a **typed cognitive substrate made visible** — pixel-art companions physically embody real agent runtimes; sub-agent dispatches show as spawn animations; memory retrievals as graph node pulses; hand-offs as scrolls passing between companions; approval gates physically block execution.

**Closed:** S0–S11 — perf-gate substrate, CompanionRegistry + activity hysteresis, AgentEvent normalization + replay, honesty audit ledger, Theater Metal renderer, Landing Farm, knowledge-brick Notes Sidebar, Graph Live Theater multi-room, Companion creation, Hermes graph faculty + opulent landing ritual, animated raster atlas pipeline, adapter gift-box (`.epbox` + Mailroom).

**Documented design that hasn't been absorbed into main canon:**

| # | Insight | DOCTRINE ref | Status | Tier | Action |
|---|---|---|---|---|---|
| 4.1 | **Three-placement registry pattern** — Landing Farm + Graph Live Theater + Sidebar Skin = ONE `CompanionRegistry` projected through three filters | DOCTRINE §3.1–§3.6 | Canonical, load-bearing, NOT in main | Core (Landing) + Pro (Sidebar) + Core (Graph) | **Salvage now** — lift the unification pattern into main's architecture docs |
| 4.2 | **Body grammar (Block / Sage / Orb + Hermes Snake)** — parameterized composition (aspect, legs, antennae, eye_treatment) | DOCTRINE §5 | Specified, S10 ships atlases | Core | Already in S10; ensure main ingests the 6-quad composition contract |
| 4.3 | **Adapter gift-box (`.epbox` + Mailroom)** — manifest.json + content/ + preview/ + provenance.json; nine box types; honesty-bound unwrap timing (animation duration ≥ apply duration) | DOCTRINE §7 + IMPL S11 | Designed; not in main | Pro | Salvage when Pro ships |
| 4.4 | **Six new `AgentEvent` variants** — `SteerRequested`, `SummaryStarted`, `SummaryDelta`, `SummaryCompleted`, `VaultCreated`, `VaultArchived` | DOCTRINE §11 v1.6 | Defined; **NOT in main's `AgentEvent` enum** | Pro | **Salvage when Pro ships** — these unlock the dispatch panel + multi-vault UI; they ARE the event protocol the simulation worktree's UI runs on |
| 4.5 | **Honesty rules / audit ledger** — three classes of allowed animation (event-driven, idle ambient, state-transition); every FrameDelta carries `AuditOrigin::CosmeticIdle` or `event:<id>` | DOCTRINE §9 + Invariant I-5 | Implemented in S3 | Core | Already landed; ensure main's audit ledger remains intact. **This is the enforcement mechanism that keeps animations from lying.** |
| 4.6 | **Activity hysteresis** — Active / Recent (30s) / Dormant (>30s, ≤7d) / Parked (>7d) | DOCTRINE §3.2 + §3.3.1 | Implemented in S1 | Core | Already landed |
| 4.7 | **Multi-vault hierarchy** — `Company/<name>/vaults/<Model>/vaults/<Companion>/vault.toml + notes/**` | DOCTRINE §3.4 | Designed; not in main | Pro | Salvage when Pro sidebar ships |
| 4.8 | **Knowledge-brick design language** — typography (NY semibold / SF Pro Text / SF Compact Rounded), density (12pt indent step / 22pt tree row / 32pt agent leaf), motion (220ms spring / 180ms pulse), pixel-art only at agent leaves + mascot pin | DOCTRINE §3.4.3 | Specified; not in main | Pro | **Salvage when Pro ships** — without this, the Pro sidebar feels like a generic SwiftUI panel, not the cognitive workspace |
| 4.9 | **Provider-brand icon system (LobeHub)** — `Tools/branding_pipeline/fetch_lobe_icons.py`; pixel-art mascot vs smooth-vector brand split; provenance.json with category | DOCTRINE §10.4–§10.7 + S5.6 | Pipeline exists | Core | Already in main; ensure validator + provenance gates remain tight |
| 4.10 | **Opulent landing ritual** — 7-phase canonical Hermes (fade / wordmark / caduceus emerges / ASCII portrait / pulse / glare / scene fade) | DOCTRINE §8.2 + IMPL S9 | Designed; uses NousResearch canonical assets | Pro | Salvage when Pro ships — this is Hermes's signature moment |
| 4.11 | **Hermes graph faculty** — privileged role; not a normal companion; coils above graph plane, separate atlas, gold/bronze palette, NY Bold Italic in sidebar ("Hermes' Vault") | DOCTRINE §8 | Architected | Pro | Salvage when Pro ships — Hermes is a *role* not a variant |
| 4.12 | **Pixel-art mascot system** — bit-perfect per I-16 (nearest-neighbor, integer scale, snap-to-pixel, no MSAA, no bilinear, no sub-pixel motion) at 20pt agent leaves + 32pt mascot pin | DOCTRINE §3.4.3 + §5.6 | S10 atlas | Pro | Already in S10; ensure main's sidebar mascot rendering adheres to I-16 |

**Critical Pro-tier risk if forgotten:** Losing the **three-placement registry pattern** (#4.1) means Pro rebuilds the sidebar separately from graph theater separately from landing — fragmenting the visual experience. Losing the **knowledge-brick design language** (#4.8) means the Pro sidebar reads as a utility panel rather than the cognitive workspace centerpiece. Losing the **adapter unwrap honesty** (#4.3) means Pro animations start lying — a corrosion of the moat.

---

## 5. vigorous-goldberg-3a2d35 — Quick Capture Phases 0–12.5 (highest density)

**Mission:** Build the substrate layer (Phases 0–12.5) — the foundational agent runtime enabling multi-tool composition, intent-effect state machine, universal undo, heal-loop recovery, capture routing classification, and skill discovery. Turn Quick Capture research (grammar-bound local inference, self-healing tool chains, filesystem as orchestration substrate) into shipping runtime infrastructure.

**Closed:** All 12.5 phases — memory format (.mem), semantic cache (per-tool TTL), variant runner + circuit breaker, native Tool trait, ToolRegistry::execute_v2 dispatch, 56-entry alias table, capture routing (centroid + GBNF + concept canonicalizer), heal loop + 30-case eval, skill discovery, NightBrain idle scheduler, Intent→Effect bridge, universal undo log, IntentDispatcher + sub-appliers, BrowserEngine trait scaffold, ExecutionReceipt with capabilities + Ed25519 placeholder.

**Abandoned insight (the longest list — 50+ commits, lots of substrate):**

| # | Insight | File | Status | Tier | Action |
|---|---|---|---|---|---|
| 5.1 | **`Tool` trait + `execute_v2` dispatch + `LEGACY_TO_V2_ALIASES` (56 entries; ~54 `impl ToolHandler` blocks remain to convert)** | `worktree:vigorous-goldberg-3a2d35/agent_core/src/tools/registry.rs`, `mod.rs` | Two-layer dispatch live; conversion incomplete | Core | **Salvage now** — write `agent_core/docs/TOOL_MIGRATION_STATUS.md` listing the 56 aliases + status + macro pattern. **#1 stay-stellar item.** |
| 5.2 | **`ExecutionReceipt` + `Capability` enum INCLUDES `BiometricSession { ttl_secs }`** — directly maps to Sovereign Gate | `agent_core/src/effect/receipt.rs` lines 44–54 | Implemented; HmacSha256 placeholder; Ed25519 is canonical | Both | **Salvage now** — Sovereign Gate must import this enum, not re-derive. **#2 stay-stellar item.** |
| 5.3 | **Capture routing classifier — GBNF grammar + centroid embedding + concept canonicalizer** | `agent_core/src/route/` (Phases 3A–3F), `agent_core/src/grammar/mod.rs`, `agent_core/schemas/route_capture.input.v1.json`, `agent_core/schemas/route_capture.output.v1.json` | Route grammar is compiled from JSON Schema in Rust, not stored as a standalone `.gbnf` file | Both | **Salvage now** — preserve the schemas + compiler path before extracting any standalone grammar artifact. Resonance Gate δ component depends on this. **#3 stay-stellar item.** |
| 5.4 | **Universal undo log — TTL classes** (24h default, 7d for auto-research wins) + lazy eviction + WAL durability + pre-computed inverse | `agent_core/src/undo/mod.rs` (350 lines) | Live in worktree | Both | Salvage as substrate spec — TTL rationale must survive |
| 5.5 | **Semantic cache** — exact (SHA256) + semantic (cosine ≥0.97 over N=256 most-recent); per-tool-family TTLs (capture=60s, search=5min, summarize=24h) | `agent_core/src/cache/mod.rs` (350 lines) | Heuristic TTLs, never benchmarked | Core | Document strategy + measure actual hit rates per tool |
| 5.6 | **Heal loop — 30-case eval methodology** + Try-Heal-Retry + Diagnostician trait | `agent_core/src/heal/mod.rs`, `agent_core/src/bin/heal_eval.rs`; the 30 cases are **embedded in heal_eval, not documented** | Live | Core | **Salvage now** — extract test fixtures to `agent_core/tests/heal_loop_fixtures.md`. Resonance Gate verification testing should reuse this. **#10 stay-stellar item.** |
| 5.7 | **Skill discovery — Phase 12.5** — three conditions (novel composition, latency budget ≤8s, no undo within 24h) + 4 repeats/week threshold + `proposed_skills/` drafts + NightBrain weekly digest | `agent_core/src/skill_discovery/mod.rs`, `agent_core/src/format/skill.rs` | Live | Both | Document policy — Resonance Gate's learning output is here |
| 5.8 | **`BrowserEngine` trait** — adapters: WebKit (MAS), Obscura (Pro stealth, ephemeral spawn), Mock (test), Remote | `agent_core/src/browser_engine/mod.rs` (150 lines) | Trait live; Obscura experimental | Pro / Research | Lift adapter guide; do not ship Obscura as default |
| 5.9 | **NightBrain idle scheduler** — every 30 min eval; eligibility: flagged notes, plugged in, no agent running, 1–5 AM, ≥12h cooldown | `epistemos-core/src/scheduler/nightbrain.rs` | Live | Core | Document scheduling policy — autonomy discipline |
| 5.10 | **Model Workspace Protocol orchestrator** (commit `a6683f8e`) — numbered folders + Markdown step files as filesystem-as-substrate state machine | No standalone design doc | Implemented | Both | Document the folder naming scheme + step-file format before NightBrain runs proliferate |
| 5.11 | **Phase 13+ never had a roadmap** — phase terminology transitioned to "Wave" terminology mid-project | — | gap | — | Create `agent_core/docs/PHASE_TO_WAVE_MAPPING.md` so future agents don't get confused |
| 5.12 | **Honest substrate vs main substrate divergence — merge strategy doc missing** | — | gap | — | Create `agent_core/docs/MERGE_STRATEGY.md` listing which subsystems are ready to extract vs Wave-6+ proto |

**Direct doctrine connections (SAVE THESE — they are stay-stellar items):**

- **`Capability::BiometricSession` → Sovereign Gate (§4.2):** Don't redesign the action-class capability shape. Import from `effect/receipt.rs`.
- **`ExecutionReceipt` Ed25519 + capabilities → Resonance Gate (§4.1) provenance trail:** The signed call_id + plan_hash + input_hash + output_hash IS the tamper-evident chain. Migrate from HmacSha256 to Ed25519 with SigningKey trait.
- **GBNF capture-routing classifier → Resonance Gate δ component:** The grammar + centroid + canonicalizer ARE the direction computation. Don't build a parallel system.
- **30-case heal eval → Resonance Gate verification testing:** Same Try-Heal-Retry methodology. Same fixture pattern.
- **Skill discovery output → Resonance Gate's learning loop:** Discovered skills bias the routing system; the Gate's attention layer should respect skill frequency.

---

## 6. Codex/* branches — NOT checked out in any worktree (easiest to forget)

These four `codex/*` branches exist on the repo but are not in any worktree. Their work **never landed on main**. They are the easiest to abandon silently.

| Branch | Commits ahead main | Status | Top insight | Tier | Action |
|---|---|---|---|---|---|
| **`codex/runtime-input-audit`** | 324 (DIVERGED) | Last commit 2026-04-24 | App Store input validation + vault write authorization + attachment paths + `CODE_EDITOR_FEATURE_AUDIT.md` (single source of truth on what's verified live vs planned vs reverted, e.g. minimap is gone, outline navigator is live) | Core | **CHERRY-PICK NOW** — 30 commits inform Sovereign Gate audit trail; CODE_EDITOR_FEATURE_AUDIT.md prevents misinformation-driven rework |
| **`codex/runtime-memory-hardening`** | 750 commits | Last commit 2026-04-03 | **5 Laws** (measure before cut / new crate not refactor / identity first / UniFFI until profiled / Python out-of-process immediately) + Phase I (Rust agent migration) marked **pre-release MANDATORY** + zero-copy mmap vault search + per-phase research backing (commit `6820f163`, `35669655`) | Both | **CHERRY-PICK AFTER DELIBERATION BRIEF** — these 5 Laws are the operational form of doctrine §2.2.3 (Markov blanket via Rust ownership). Lift the laws + Phase I mandate into the doctrine; don't merge the 750 code commits raw |
| **`codex/release-stabilization-and-runtime-hardening`** | 669 commits | Last commit 2026-03-28 | RunPod modernization, ODIA training corpus sync, EventStore cleanup, "release audit workflow and final handoff" commit | Core | **VERIFY SUPERSEDED** — confirm training is in a separate repo. If unique work lives here, cherry-pick; otherwise archive |
| **`codex/post-audit-feature-work`** | 762 commits | Last commit 2026-04-04 | **`recipe_cache`** (commit `c217b266`): SQLite-backed tool result caching, SHA-256 keying, TTL=7d, LRU=10K, uncacheable list (bash, write_file, delete, terminal, computer_use). Plus light-mode UI polish, graph physics master controls | Pro | **CHERRY-PICK `recipe_cache` ONLY** — standalone, test-covered, perf-relevant. Defer graph physics + light-mode polish to post-release |

**Critical:** `codex/runtime-input-audit` and `codex/runtime-memory-hardening` are the most at risk for silent abandonment. The first holds App Store hardening that informs the Sovereign Gate. The second holds the 5 Laws and the Phase I mandate that codify the Markov-blanket-via-Rust-ownership invariant.

---

## 7. Doctrine ↔ Worktree dependency map

For each doctrine feature, the canonical implementation source.

### Resonance Gate (Σ signature) — doctrine §4.1

| Σ component | Source worktree → file |
|---|---|
| τ (truth) | substrate-core enums; T0–T2 verification ladder lives in concept (no canonical impl yet) |
| **δ (direction)** | `vigorous-goldberg-3a2d35` capture routing classifier — GBNF + centroid + canonicalizer (see §5.3) |
| π (prime/composite/gap) | claim-graph in-degree analysis — substrate work pending; reference Annex A.13 |
| ρ (resonance) | spectral / eigenvector centrality — research only (Annex A.2) |
| κ (KAM stability) | activation FFT — research only |
| η (evidence) | `vigorous-goldberg-3a2d35` heal-loop evidence-supremacy pattern (see §5.6) |
| λ (residency) | L0–L7 governor — concept doc only (Annex A.3) |
| **Emission events** | `inspiring-heisenberg-ea9dc3` `Log.agentStreaming` taxonomy + 16ms coalescing rule (see §3.6, §3.2) |
| **Provenance trail** | `vigorous-goldberg-3a2d35` `ExecutionReceipt` + Ed25519 + capabilities (see §5.2) |
| **Verification testing** | `vigorous-goldberg-3a2d35` 30-case heal eval (see §5.6) |
| **Audit ledger** | `simulation` honesty rules + three-class audit origin (see §4.5) |

### Sovereign Gate — doctrine §4.2

| Sovereign Gate piece | Source |
|---|---|
| **Action-class enum (Trivial / Reversible / Sensitive / Destructive / Sovereign)** | New work; reference `MutationEnvelope.Sensitivity` (already in main) — extend, don't parallel |
| **Capability emission** | `vigorous-goldberg-3a2d35` `Capability::BiometricSession` enum — direct import (§5.2) |
| Auth routes (Touch ID / Magic Keyboard / iPhone-as-key / Apple Watch) | `LocalAuthentication` natively; doctrine Annex A.7 |
| **Audit trail** | `simulation` honesty audit ledger pattern (§4.5) |
| Secure Enclave key sealing | New work; doctrine Annex A.7 |
| Grace-period state machine | `vigorous-goldberg-3a2d35` undo log TTL pattern (§5.4) — reuse the lazy-eviction + WAL discipline |

### Freeform Pulse + Residency Rail — doctrine §4.3

| Pulse + Rail piece | Source |
|---|---|
| Pulse local-model drafts | Existing `HaloController` debounce machinery (main); MLX-Swift inference |
| Pulse stabilization | `inspiring-heisenberg-ea9dc3` 16ms agent streaming coalescing (§3.2) — apply same pattern |
| Pulse syntax-aware suggestions | `inspiring-heisenberg-ea9dc3` syntax-core scaffolding (§3.7) — Pro-tier path |
| **Rail spatial model (L0–L7)** | `simulation` multi-vault hierarchy + knowledge-brick design language (§4.7, §4.8) |
| Rail visual identity | `simulation` body grammar + pixel-art mascot system (§4.2, §4.12) |
| Rail event protocol | `simulation` six new `AgentEvent` variants (§4.4) |

### Architectural invariants — doctrine §2.2

| Invariant | Source canon |
|---|---|
| Zero-copy unified memory | doctrine Annex A.10; `inspiring-heisenberg-ea9dc3` §25 graph zero-copy gating |
| Single-binary in-process | `vigorous-goldberg-3a2d35` Quick Capture pattern (UniFFI hop into same process); doctrine §2.2.2 |
| **Markov blanket via Rust ownership** | `agent-a0550f9c` honest-handle pattern (§1.1); `codex/runtime-memory-hardening` 5 Laws (§6) |
| Tiered determinism | `inspiring-heisenberg-ea9dc3` §27 anti-pattern register (§3.5); 5-tier T0–T4 ladder (Annex A.2) |

---

## 8. What Codex should add to canon (deliberation-brief targets)

These are the doc-only deliverables that protect the salvage. **Each is a write-only deliberation brief; no code change required.** Recommended order:

1. **`agent_core/docs/TOOL_MIGRATION_STATUS.md`** — table of 56 aliases × conversion status × native impl file × priority. Macro pattern reference. (Salvages §5.1.)
2. **`agent_core/docs/EXECUTION_RECEIPT_DOCTRINE_MAPPING.md`** — receipt schema; map `Capability` variants to doctrine gates; Ed25519 migration plan. (Salvages §5.2 → Sovereign Gate.)
3. **`agent_core/data/schemas/capture_intent.gbnf`** — extract the GBNF grammar from inline Rust code into a standalone artifact. Plus `agent_core/docs/CAPTURE_ROUTING_CLASSIFIER.md` documenting the variant ladder + thresholds + concept canonicalizer rules. (Salvages §5.3 → Resonance Gate δ.)
4. **`agent_core/tests/heal_loop_fixtures.md`** — extract the 30 test cases from `heal_eval.rs` into a documented fixture library. (Salvages §5.6 → Resonance Gate verification.)
5. **`docs/architecture/HONEST_HANDLE_FFI_DOCTRINE.md`** — generalize the `Arc::into_raw` + `catch_unwind` + single-owner pattern as the canonical Rust↔Swift ownership rule. (Salvages §1.1.)
6. **`docs/architecture/FIVE_LAWS_AND_PHASE_I.md`** — extract the 5 Laws + Phase I (Rust agent migration MANDATORY pre-release) from `codex/runtime-memory-hardening` commit `6820f163` into prose. (Salvages §6 runtime-memory-hardening.)
7. **`docs/architecture/PLAN_V2_SECTIONS_23_27.md`** — port `inspiring-heisenberg-ea9dc3`'s §23–§27 PLAN_V2 sections into main's `docs/architecture/PLAN_V2.md` if not already there. **Critically — the §27 anti-pattern register.** (Salvages §3.1, §3.2, §3.5.)
8. **`docs/architecture/AGENT_EVENT_VARIANTS_v1.6.md`** — list the six new `AgentEvent` variants from `simulation` DOCTRINE §11 and pre-register them in main's enum so Pro tier doesn't duplicate the protocol. (Salvages §4.4 → Pulse + Rail event protocol.)
9. **Cherry-pick `codex/runtime-input-audit`** with a deliberation brief — App Store hardening + `CODE_EDITOR_FEATURE_AUDIT.md` is read-then-cherry-pick. (Salvages §6 runtime-input-audit.)
10. **Cherry-pick `recipe_cache` (commit `c217b266`) from `codex/post-audit-feature-work`** with a small deliberation brief. (Salvages §6 post-audit-feature-work.)

If you only do **#2, #3, #4, #5, #6, #7** the doctrine's three killer features land with substrate dependencies satisfied, and the architectural invariants have a written enforcement record.

---

## 8.5 Local-stream truncation / flush fix — preservation watch *(C12, merged 2026-05-05)*

**File:** `Epistemos/LocalAgent/IncrementalToolCallDetector.swift` (exists on main + worktrees `quirky-pascal-135a98`, `hermes-parity`, `simulation`)

**Status:** Known fix that prevents premature EOF / token truncation on the local-stream path during tool-call detection. Currently shipping on main.

**Risk:** Any future refactor of `agent_loop.rs`, the Anthropic streaming bridge, or the tool-call detector could regress this. The original master plan flagged "preserve and reapply local-stream truncation/perf fixes" as a P0 stabilization concern.

**Action before patching the streaming path or `IncrementalToolCallDetector`:**

1. Run `EpistemosTests/IncrementalToolCallDetectorTests.swift` and capture green log.
2. Manual test: trigger a long-streaming local-MLX response with embedded tool calls; verify no EOF truncation.
3. After the patch: re-run both. Any regression is P0.

**Tier:** Core (Pro / Research inherit the same path).

**Deliberation-brief instruction:** any agent_loop or streaming-path slice MUST include this preservation note in its brief.

---

## 9. Bottom line

**The app is stellar — but the substrate research that makes it stellar is fragmented across 7 worktrees and 4 unmerged Codex branches.** Six of those (every worktree except the active `quirky-pascal-135a98`) hold load-bearing insight that has not been promoted into main's canon. Two of the four `codex/*` branches (input-audit, memory-hardening) hold release-blocking and doctrine-shaping work that **has never landed**.

Salvage is doc work, not code work. Every item in §8 is a write-only deliberation brief that crystallizes substrate that already exists. Doing them in order means:

- Codex implementing the **Sovereign Gate** finds `Capability::BiometricSession` ready to import.
- Codex implementing the **Resonance Gate** finds the GBNF grammar, the 30-case verification methodology, and the Σ event taxonomy ready to consume.
- Codex implementing **Pulse + Rail** finds the syntax-core crate, multi-vault hierarchy, body grammar, knowledge-brick language, and six new `AgentEvent` variants pre-registered.
- Codex enforcing the **architectural invariants** finds the honest-handle FFI doctrine, the 5 Laws, and the §27 anti-pattern register written down.

The final tier matrix ships better, faster, and stays stellar — because no agent has to re-derive what a previous agent already figured out.
