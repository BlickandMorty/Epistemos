# Master Research Index — 2026-05-02

> **NEW DOC — created 2026-05-02.** Filename: `MASTER_RESEARCH_INDEX_2026_05_02.md`. Search by name if older session indexes don't list it. Sister docs: `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md`, `CODEX_FINAL_EXECUTION_PROMPT_2026_05_01.md`, `WORKTREE_INSIGHT_SALVAGE_2026_05_02.md`, `CANON_GAPS_AND_ADDENDA_2026_05_02.md`, `CODEX_DELIBERATION_PROMPT_2026_05_02.md`, `ALL_DOCS_INDEX_2026_05_02.md`. Mirrored into the active worktree.

> **Purpose.** When Codex hits any concept, feature, mini-task, or term — look it up here. This index maps every load-bearing concept to (a) its canonical source on disk, (b) supporting / cross-reference docs, (c) code anchors with absolute paths, (d) tier classification, and (e) one load-bearing claim quoted verbatim. **Compiled from 8 parallel deep-scans** of all 7 worktrees + 5 unindexed Downloads research roots + the Quick Capture standalone canon (~470 KB) + ~60 external research files.
>
> **The user's instruction:** "It must research my disk in my laptop for research related to any concept or mini task it runs into… should be accurate." Use this index to find what's on disk. Open the canonical source first. Cross-reference only when the canonical doesn't answer.

---

## 0. Honest Discoveries (read first — these correct prior canon)

These are findings the deep-scan surfaced that **contradict or sharpen** earlier docs. Codex should treat these as authoritative over older claims.

| # | Finding | Source | Why it matters |
|---|---|---|---|
| H1 | **Lane A is NOT "mostly merged."** It has **601 unmerged commits** ahead of main, all on the N1 Prompt Tree track, including a 270-line `PROMPT_AS_DATA_SPEC.md` and full PTF (Prompt Tree Format) implementation behind `EPISTEMOS_PROMPT_TREE=1` flag. The fusion review's "mostly merged" classification was incorrect. | `git log $(git merge-base lane-A main)..lane-A \| wc -l` confirmed 601 | Phase R pre-merge planning needs to include N1 substrate; the orphan `agent_core/src/session_insights.rs` blocker is real |
| H2 | **Hermes-parity uses plain markdown prompts, NOT NousResearch ChatML XML.** `agent_core/src/prompts.rs` opens with `BASE_SYSTEM_PROMPT = r#"You are Epistemos…"#` — no `<\|im_start\|>` markers. | `worktree:hermes-parity/agent_core/src/prompts.rs` lines 53-57 | Doctrine Annex A.12's reference to NousResearch ChatML applies to **future** Pro Hermes subprocess work, not current code |
| H3 | **Apple Intelligence fallback is real, not placeholder.** Multiple Swift services (`AppleIntelligenceService.swift`, `InferenceState.swift`, `CloudKnowledgeDistillationService.swift`) reference `apple_intelligence` / `apple-intelligence` as a real provider variant. | `worktree:hermes-parity/Epistemos/Engine/AppleIntelligenceService.swift` | When TriageService recommends fallback to Apple Intelligence, it's a real path |
| H4 | **Error classifier IS wired into agent_loop** (earlier worry that it might be dead code is unfounded). `worktree:hermes-parity/agent_core/src/error_classifier.rs` is imported by `agent_loop.rs` line 10. 100+ patterns active. | `worktree:hermes-parity/agent_core/src/agent_loop.rs:10` | Salvage §2.4 risk is closed |
| H5 | **Quick Capture standalone canon has 5 monster docs totaling ~430 KB**, not just `PLAN.md` + `FINAL_SYNTHESIS.md`. Three previously-unindexed: `BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md`, `LIVE_FILES_AND_SUBSTRATE_ADDENDUM.md`, `OBSCURA_BROWSER_ADDENDUM.md`. Plus BUILDER_PROMPT, CATCHUP_PROMPT, AUDIT_PROMPT, INDEX, README. | `/Users/jojo/Documents/Epistemos-QuickCapture/` | Codex must read FINAL_SYNTHESIS first; it corrects PLAN.md and rewrites Wave 6 sequencing |
| H6 | **Six v1.6 `AgentEvent` variants are NOT yet in main's enum.** They are documented in simulation worktree's DOCTRINE.md §11 v1.6 + IMPLEMENTATION.md but the Rust enum at `worktree:simulation/agent_core/src/events.rs` only enumerates the original 32 variants. The six new ones (`SteerRequested`, `SummaryStarted/Delta/Completed`, `VaultCreated`, `VaultArchived`) are forward-references for S6 patches. | `worktree:simulation/agent_core/src/events.rs` lines 272–499 | Pro tier sidebar dispatch + multi-vault UI need these added before they ship |
| H7 | **W9.21 PR4 honest-handle is "claimed shipped" but Swift still binds legacy surface.** `RustShadowFFIClient.swift:39` uses legacy `shadow_open_at` returning `Int32`, not the new handle FFI. The honest_handle.rs module is orphan scaffolding. | `worktree:agent-a0550f9c` audit pass #1 finding | The pattern is correct; the wiring is incomplete. Don't claim it shipped. |
| H8 | **D-series doctrine primitives D1, D3, D11 are absent from codebase.** D1 BLAKE3 chain, D3 A2UI catalog, D11 epistemos-trace CLI are all specified in canonical audit log but not implemented. W9.27 OpLog schema is missing `prev_hash BLAKE3` column AND missing `PRAGMA journal_mode = WAL` + `fcntl(F_FULLFSYNC)`. | `worktree:agent-a0550f9c/docs/CANONICAL_AUDIT_LOG.md` | Salvage map's "OpLog Merkle chain shipped" needs verification — chain may be partial |
| H9 | **CODE_EDITOR_FEATURE_AUDIT.md found drift on every editor feature.** Minimap reverted (line 1232 comment "Minimap removed — outline navigator replaces it"), search bar UI exists but `performSearch()` is stub, semantic sidebar code exists but gated to false (line 291 never visible), status bar replaced by EditorBreadcrumbBar, persisted prefs 5/6 active. | `worktree:inspiring-heisenberg-ea9dc3/CODE_EDITOR_FEATURE_AUDIT.md` | Editor work must verify against live code; doc claims drift fast |
| H10 | **Quick Capture worktree LEGACY_TO_V2_ALIASES has ~56 entries, ~54 conversions remaining.** Only `TodoHandler` (Phase 2G-4a canary) is converted. The rest (24 files, ~54 `impl ToolHandler` blocks) need the macro from Phase 2G-4d. No standalone migration guide exists — pattern lives only in commit messages. | `worktree:vigorous-goldberg-3a2d35/agent_core/src/tools/registry.rs` | Stay-stellar #1; needs `agent_core/docs/TOOL_MIGRATION_STATUS.md` |

---

## 1. Truth-Router and Authority Order

**Authority hierarchy (when sources disagree):**

| Order | Layer | Canonical files |
|---|---|---|
| 1 | Current code + passing logs | `git log`, test outputs, `/tmp/epistemos-*-test-*.log` |
| 2 | Repo authority docs | `/Users/jojo/Downloads/Epistemos/AGENTS.md`, `CLAUDE.md`, `docs/architecture/PLAN_V2.md`, `docs/architecture/BOLTFFI_AUDIT_2026_04_15.md`, `docs/_consolidated/00_canonical_authority/{MASTER_FUSION, MASTER_BUILD_PLAN, RESEARCH_INDEX_BY_FEATURE, EDITOR_VERDICT_TIPTAP_VS_APPFLOWY, CODEX_VERIFIED_STATE_2026_04_25, MASTER_HARDENING_AND_HARNESS_PLAN, IMPLEMENTATION_PLAN_FROM_ADVICE, ANTI_DRIFT_SYSTEM, 00_AUTHORITY_AND_ANTI_DRIFT, 01_DOCTRINE, 02_BUILD_MATRIX, 03_EXECUTION_MAP, NEXT_SESSION_BOOTSTRAP, ambient_V1_DECISION}.md`, `docs/APP_ISSUES_AUTO_FIX.md`, `docs/APP_STORE_RELEASE_COMPLETION_STATUS_2026_04_24.md` |
| 3 | April 30 fusion canon | `docs/fusion/{README_START_HERE, CANONICAL_SOURCE_MAP_AND_GATE_REGISTER, BUILDER_EXECUTION_PROMPT, CODEX_ACTIVE_OVERSEER_KIMI_PROMPT, FUSED_IMPLEMENTATION_QUEUE, KIMI_*}_2026_04_30.md` + `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` |
| 4 | May 2 doctrine packet | `docs/fusion/{EPISTEMOS_FINAL_DOCTRINE_2026_05_01, CODEX_FINAL_EXECUTION_PROMPT_2026_05_01, WORKTREE_INSIGHT_SALVAGE_2026_05_02, CANON_GAPS_AND_ADDENDA_2026_05_02, CODEX_DELIBERATION_PROMPT_2026_05_02, ALL_DOCS_INDEX_2026_05_02, MASTER_RESEARCH_INDEX_2026_05_02}.md` |
| 4.5 | Quick Capture standalone canon | `/Users/jojo/Documents/Epistemos-QuickCapture/{FINAL_SYNTHESIS, PLAN, OBSCURA_BROWSER_ADDENDUM, LIVE_FILES_AND_SUBSTRATE_ADDENDUM, BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM, INDEX, README, BUILDER_PROMPT, CATCHUP_PROMPT, AUDIT_PROMPT}.md` (FINAL_SYNTHESIS wins conflicts) |
| 5 | Kimi research depth (donor) | `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive/` (88 files) |
| 5.5 | External research depth | `/Users/jojo/Downloads/{ambient, final, final v2, final v3, Advice}/`, `/Users/jojo/Downloads/Pasted markdown.md` |
| 6 | Worktree code | donor only, never raw-merge |

---

## 2. Substrate Spine and Architectural Invariants

### Substrate spine
**Canonical:** `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` — current code truth for every spine layer.

```
TypedArtifact → MutationEnvelope → RunEventLog / AgentEvent / GraphEvent → Halo / Graph / Theater / Audit projections
```

**Code anchors:**
- `Epistemos/Models/MutationEnvelope.swift` (Swift, includes `Sensitivity` enum line 88, field line 293)
- `agent_core/src/mutations/envelope.rs` (Rust mirror)
- `EpistemosTests/MutationEnvelopeParityTests.swift` (parity tests)
- `Epistemos/Engine/TextCapturePipeline.swift` (vertical slice)

### Architectural invariants (every tier)
**Canonical:** `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §2.2.

1. Zero-copy unified memory (Apple Silicon UMA, `MTLBuffer.storageModeShared`, IOSurface)
2. Single-binary in-process substrate (UniFFI hop pattern; subprocess for inference forbidden)
3. Markov blanket via Rust ownership (borrow checker = organizational closure)
4. Tiered determinism (state transitions logged + hashed, not every byte of inference)
5. (pending merge per `CANON_GAPS_AND_ADDENDA` C5) Canonical state is the only source of truth — visuals project, never invent

**Honest-handle FFI doctrine (canonical pattern):**
- `worktree:agent-a0550f9c/epistemos-shadow/src/honest_handle.rs` lines 73-100 — `Arc::into_raw` discipline + `panic::catch_unwind(AssertUnwindSafe(...))` panic safety
- `worktree:agent-a0550f9c/Epistemos/Engine/RustShadowFFIClient.swift` (clean 321-line consumer; but legacy line 39 still bound — see H7)

### Three-tier ship model
**Canonical:** doctrine §3 + §5. `Core` (App Store) + `Pro` (Developer ID + Notarization) + `Research` (Developer ID + private framework loading). Confirmed locked by user 2026-05-02.

### WRV doctrine (Wired + Reachable + Visible + Verified)
**Status:** staged in `docs/fusion/CANON_GAPS_AND_ADDENDA_2026_05_02.md` C1. Not yet in doctrine. Mentioned across `docs/audits/MASTER_HARDENING_WIRING_AUDIT.md` ("init-time gate GREEN; 4k-line runtime fluidity unproven") and `docs/fusion/KIMI_FUSION_REVIEW_2026_04_30.md` ("recommended first three slices").

### SCOPE-Rex / Rex naming
**Canonical:** doctrine §4.1 Annex A.1. `Epistemos` = product, `Rex` = Rust kernel (`agent_core` becoming Rex), `SCOPE-Rex` = full runtime (Sparse-feature, Claim-graph, Ontology, Proof, Execution).

**Donor research:** `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive/scope_rex_final_architecture.md` (definitive architecture, 31 research dimensions).

### ACS five-layer recursion
**Canonical:** doctrine Annex A.4 (Cell → Tissue → Organ → Organism → Ecosystem with tier mapping).
**Donor research:** `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive/acs_meta_layer.md`.

---

## 3. The Three Killer Features

### 3.1 Resonance Gate (Σ signature)
**Canonical:** doctrine §4.1.
**Donor research:** `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive/epistemos_resonance_gate.md`.

7-field Σ signature: `Σ(x) = [τ truth, δ direction, π prime/composite/gap, ρ resonance, κ KAM, η evidence, λ residency]`. Target <100µs/token.

**Code dependencies (canonical sources Codex must import):**
| Σ component | Source |
|---|---|
| δ direction | `worktree:vigorous-goldberg-3a2d35/agent_core/src/capture/routing/` (Phases 3A–3F) — GBNF + centroid + canonicalizer |
| η evidence | `worktree:vigorous-goldberg-3a2d35/agent_core/src/heal/` — Try-Heal-Retry + 30-case eval |
| Provenance | `worktree:vigorous-goldberg-3a2d35/agent_core/src/effect/{dispatcher,receipt,*_applier}.rs` |
| Σ event taxonomy | `worktree:inspiring-heisenberg-ea9dc3/Epistemos/Engine/Log.swift` (`Log.agentStreaming` signposts) + `Bridge/StreamingDelegate.swift` |
| Σ batching | doctrine Annex A.2 (T0–T2 hot path) + `worktree:inspiring-heisenberg-ea9dc3/docs/architecture/PLAN_V2.md` §24 (16ms coalescing) |
| Audit trail | `worktree:simulation/agent_core/src/audit/origin.rs` (three-class AuditOrigin enum) |
| 9 claim types | doctrine §4.1: `Equation, Inequality, Causal, Definition, Empirical, CodeInvariant, Prime, Composite, Gap` |
| 5 directional operators | doctrine §4.1: `upward, downward, sideways, inward, on-itself` |

### 3.2 Sovereign Gate (Touch ID, biometric)
**Canonical:** doctrine §4.2 + Annex A.7.
**Donor research:** `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive/EPISTEMOS_RESEARCH_LANDSLIDE.md` Part I §1.1 (LAContext snippet); `/Users/jojo/Documents/Epistemos-QuickCapture/BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md` §1 (Wave 9 biometric authority via Secure Enclave).

**Action-class matrix:** Trivial / Reversible / Sensitive (15-min grace) / Destructive (every time + passcode) / Sovereign (every time + Secure Enclave seal). Current Rust seed: `agent_core/src/sovereign/mod.rs`; generated requirement transport remains open.

**Capability enum (Codex must import, do not redesign):**
- `worktree:vigorous-goldberg-3a2d35/agent_core/src/effect/receipt.rs` lines 44–54: `Capability::BiometricSession { ttl_secs }` ALREADY EXISTS as canonical type.

**Auth routes:** MacBook Touch ID + Magic Keyboard + iPhone-as-key + Apple Watch unlock — all native via `LocalAuthentication.LAContext`.

**Single entrypoint (must be):** `Epistemos/Sovereign/SovereignGate.swift` (new file). NEVER duplicate `LAContext` calls elsewhere.

### 3.3 Freeform Pulse + Residency Rail
**Canonical:** doctrine §4.3 + Annex A.3 (L0–L7 residency).
**Halo dependency:** doctrine §7 build-order; current state: V0 mounted, V1 awaiting protected-path gate.

**Code:** `Epistemos/Engine/HaloController.swift` (debounce machinery), `HaloEditorBridge.swift`, `ShadowSearchService.swift`.

**Halo V1 stack reference:** doctrine §4.3 (now in canon gaps C6) — 6-state FSM + Model2Vec + usearch + Tantivy + RRF + non-activating NSPanel + 25ms latency budget. Stack rationale at `docs/_consolidated/00_canonical_authority/ambient_V1_DECISION.md` and `docs/fusion/KIMI_FUSION_REVIEW_2026_04_30.md`.
**Donor research:** `/Users/jojo/Downloads/ambient/EPISTEMOS_V1_DECISION.md`, `/Users/jojo/Downloads/ambient/claude ambient.md` (THE implementation bible — 100+ code stubs, hard performance targets), `/Users/jojo/Downloads/ambient/HaloController.swift` (reference impl), `/Users/jojo/Downloads/ambient/epistemos_shadow.rs` (Rust retrieval engine).

---

## 4. Quick Capture / Substrate Runtime (50+ commits, 470 KB canon)

**Worktree:** `vigorous-goldberg-3a2d35`. **Standalone canon:** `/Users/jojo/Documents/Epistemos-QuickCapture/`.

### Reading order (Codex)
1. `/Users/jojo/Documents/Epistemos-QuickCapture/FINAL_SYNTHESIS.md` (52 KB, **wins all conflicts**) — 8 corrections, two breakthroughs (Live File Compiler + Reflective Loop), four-tier weight class system, 10-state machine, 7-layer privacy stack, corrected wave sequencing
2. `/Users/jojo/Documents/Epistemos-QuickCapture/PLAN.md` (244 KB, canonical for Waves 0–5 only)
3. Per-wave addendum (skip if not active wave):
   - `OBSCURA_BROWSER_ADDENDUM.md` (62 KB, Wave 6)
   - `LIVE_FILES_AND_SUBSTRATE_ADDENDUM.md` (67 KB, Waves 7–8)
   - `BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md` (44 KB, Waves 9–11)

### Stay-stellar substrate (must salvage)
| Concept | Code anchor | Lines / structure |
|---|---|---|
| Tool trait + execute_v2 + 56 aliases | `worktree:vigorous-goldberg-3a2d35/agent_core/src/tools/registry.rs` | LEGACY_TO_V2_ALIASES table; ~54 conversions remaining |
| ExecutionReceipt + Capability enum | `worktree:vigorous-goldberg-3a2d35/agent_core/src/effect/receipt.rs` | ULID call_id, plan_hash, input_hash, output_hash, Ed25519 placeholder, Capability::{VaultPath, NetworkHost, BiometricSession, Other} |
| IntentDispatcher + sub-appliers | `…/agent_core/src/effect/{dispatcher, concept_applier, memory_applier, vault_applier}.rs` | Single entry routing intent → sub-applier; short-circuits noop/abort |
| Heal loop + Try-Heal-Retry + 30-case eval | `…/agent_core/src/heal/{mod.rs (29KB), log.rs (20KB), breaker.rs}` + `…/agent_core/src/bin/heal_eval.rs` | Diagnostician trait; circuit-breaker pattern; test fixtures embedded |
| Universal undo log + TTL classes | `…/agent_core/src/undo/mod.rs` (350 lines) | DEFAULT_TTL=24h; AUTO_RESEARCH_TTL=7d; lazy eviction; pre-computed inverse; WAL+synchronous=NORMAL |
| Semantic cache | `…/agent_core/src/cache/mod.rs` (350 lines) | Exact match (SHA256) + semantic (cosine ≥0.97 over N=256); per-tool TTL: capture=60s, search=5min, summarize=24h, default=60s |
| Capture routing classifier (GBNF + centroid + canonicalizer) | `…/agent_core/src/capture/routing/` Phases 3A-3F + `…/agent_core/src/format/capture.rs` | Variant A (centroid ≥0.85) → B (GBNF closed-vocab ≥0.75) → C (concept-anchored) → D (defer); intents: `place \| merge \| create_folder \| defer` |
| Concept canonicalizer | `…/agent_core/src/route/concept_alias.rs` | Deterministic; alias table |
| Skill discovery (Phase 12.5) | `…/agent_core/src/skill_discovery/mod.rs` | Three conditions (novel, ≤8s latency, no undo within 24h) + 4 repeats/week threshold + `proposed_skills/` drafts |
| BrowserEngine trait | `…/agent_core/src/browser_engine/mod.rs` (16KB) | WebKit (MAS) / Obscura (Pro experimental) / Mock (test) / Remote (fallback) — see OBSCURA_BROWSER_ADDENDUM.md for full design |
| NightBrain idle scheduler | `epistemos-core/src/scheduler/nightbrain.rs` (200 lines) | Every 30 min; eligibility = flagged notes + plugged in + no agent + 1–5 AM + ≥12h cooldown |
| Model Workspace Protocol | commit `a6683f8e` | Numbered folders + Markdown step files as filesystem-as-substrate state machine |

### New concepts from FINAL_SYNTHESIS.md (corrections to PLAN.md)
| Concept | Section | Description |
|---|---|---|
| **Live File Compiler** (BREAKTHROUGH) | §1 | Markdown → Parser → Intent → LivePlan.v1 (YAML) → Policy/Capability validation → Signed plan → Runner. The compiled, signed plan executes, NEVER the markdown. |
| **Reflective Loop** (NEW) | §2 | 7-layer substrate cycle: Reflex → Attention → Executive → Immune → Motor → Memory → Metabolism. Each layer has defined input/output/verification gate. Layer 7 (NightBrain) runs overnight against accumulated Layer 6 trace. |
| **Cognitive Weight class system** | §3 | 4-tier: `soft_memory [0–0.30]` / `preferred_context [0.31–0.60]` / `strong_project_anchor [0.61–0.85]` / `policy_grade [0.86–1.00]`. Only policy-grade can constrain tools, gated by schema + capability + diff + signed plan hash + revocation path. *"Semantic Gravity pulls attention; Policy Authority controls action."* |
| **10-state Live File state machine** | §4 | Static → LiveCandidate → Compiled → Eligible → Running → {Paused \| Completed \| Quarantined} → Suspended. Each is a different execution authority. |
| **Privacy stack (7 layers)** | §5 | Reflex (local cache) / Attention (Eidos in-process) / Executive (local compile) / Immune (deterministic local auth) / Motor (in-process/sandboxed browser) / Memory (encrypted RunEventLog) / Metabolism (differentially-private aggregates). Moat: one process = one trust boundary. |
| **Corrected wave sequencing** | §6 | Wave 5 stabilize → Wave 6 substrate (Eidos + BrowserEngine + deno_core) → Wave 7 Live Files (boring) → Wave 8 auto-research (safe mutation). Out of order = fragile. |
| **Stateful Rotor** | LIVE_FILES §1 | Sub-5ms event-driven scheduling with thermal/battery/budget gating |
| **Vector Universe manifold** | LIVE_FILES §4 | Dense vectors + sparse lexical + schema AST + task queue + conditions + permissions + citations + freshness decay |
| **Eidos Plus deliberation engine** | LIVE_FILES §8 | Wave 8 deliberation with model teams (optimistic/pessimist/neutral panels) + research jury + Karpathy-style overnight loops |

### Pro-only (Obscura / deno_core / Eidos)
**Canonical source:** `/Users/jojo/Documents/Epistemos-QuickCapture/OBSCURA_BROWSER_ADDENDUM.md` (62 KB, 12 sections).

| Concept | Section | Description |
|---|---|---|
| BrowserEngine trait | §1, §3 | Polymorphic adapter: WebKit baseline (MAS, Apple-native sandboxed), Obscura (Pro Rust-native V8 stealth, ephemeral spawn), Mock (tests), RemoteBrowser (fallback). NEVER single-vendor. |
| deno_core for Pro JS | §4 | NOT Deno binary or Node.js — deno_core in-process library with capability-gated ops (no subprocess, unrestricted FS/network/shell/AppleScript/launchctl). Playwright/Puppeteer compat via in-bundle shim. |
| Eidos search engine | §6 | Agent-native search: vault HNSW index + Metal-accelerated cosine kernel (~31× CPU at scale) + speculative crawl + closed result schema. Returns *control vectors* (typed authority annotations from Live Files), not just chunks. |
| Stealth posture | §8 | Anti-fingerprinting + 3,520-domain telemetry blackhole |

### Biometric / Tamagotchi / Brain Export (Waves 9–11)
**Canonical:** `/Users/jojo/Documents/Epistemos-QuickCapture/BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md`.

| Concept | Section | Description |
|---|---|---|
| Biometric authority via Secure Enclave | §1 | Scope-bounded, TTL-bounded session-authority token. Required for: irreversible actions, system-prompt edits, capability changes, low-conf reset, Brain Artifact load, Tier-3 unlock, policy-grade promotion, Cloud-Off override |
| Confidence Meter + 70% re-learn | §2 | Biometric-triggered diagnose-first re-learn pattern |
| Tamagotchi Pixel/Tactical mode duality | §3 | Same agent, two visual modes: Pixel (avatar + animation + emote) or Tactical (info-dense pills). Sub-agent capability inheritance is *narrowing only*, never inflation. A2A "phone" channel between agents. |
| Cloud-as-Teacher Distillation Lab | §4 | PII sluice gate + catastrophic-forgetting eval gate. Prevents model memorization of user data. |
| Brain Export | §5 | Signed Brain Artifact bundle: weights + compiled scaffold + test report + license keying. Continued Epistemos subscription = "stay in app" lock-in. |

---

## 5. Halo / Contextual Shadows / Recall

### Status (current code truth)
- **V0:** production-mounted with `ShadowSearchService` backend route. Tests at `EpistemosTests/HaloUITests.swift`, `ContextualShadowsStateTests.swift`.
- **V1:** open behind protected-path gate. Code exists but not mounted.

### Code anchors
- `Epistemos/Engine/HaloController.swift` (@MainActor @Observable, 6-state FSM)
- `Epistemos/Engine/HaloEditorBridge.swift` (NSTextView delegate)
- `Epistemos/Engine/ShadowSearchService.swift` (ShadowFFI search wrapper)
- `epistemos-shadow/` crate (45 tests, 7 clippy warnings post-hardening)
- `Epistemos/KnowledgeFusion/InstantRecallService.swift` (Swift fallback)

### Stack reference (canonical)
6-state FSM `dormant → watching → encoding → searching → available → open` + trailing-edge debounce (200ms) + Model2Vec potion-retrieval-32M + usearch HNSW with bf16 + Tantivy BM25 + weighted RRF (k=60, lex_weight=1.2) + non-activating NSPanel + Metal display-link + 25ms end-to-end recall latency budget.

### Authoritative docs
| Doc | Path | Role |
|---|---|---|
| Halo V1 decision | `/Users/jojo/Downloads/Epistemos/docs/_consolidated/00_canonical_authority/ambient_V1_DECISION.md` AND `/Users/jojo/Downloads/ambient/EPISTEMOS_V1_DECISION.md` | Architectural verdict, performance budget |
| Implementation bible | `/Users/jojo/Downloads/ambient/claude ambient.md` (63 KB) | 100+ code stubs, hard performance targets, library validation |
| Reference Halo controller | `/Users/jojo/Downloads/ambient/HaloController.swift` (21 KB) | @Observable, debounce, NSPanel non-activating, @Query cascade avoidance |
| Reference Rust shadow | `/Users/jojo/Downloads/ambient/epistemos_shadow.rs` (23 KB) | ShadowSearchService actor, usearch lifecycle, Tantivy BM25, RRF |
| Wiring audit | `/Users/jojo/Downloads/Epistemos/docs/audits/AMBIENT_RECALL_WIRING_PLAN.md` | V0 surface proof + gap analysis |
| Halo Master Plan | `worktree:agent-a0550f9c/docs/AMBIENT_RECALL_HALO_MASTER_PLAN.md` (2026-04-24, design-locked, execution-blocked on Phase R) | "Ship one feature so well it feels inevitable" |
| Honest gaps | `/Users/jojo/Downloads/Pasted markdown.md` Part 1 (C1-C4) + `/Users/jojo/Downloads/ambient/deep-research-report (2).md` | C1: editor → debounce → encode → Rust HNSW → sidebar UI is THE missing connector |
| Gemini parallel design | `/Users/jojo/Downloads/ambient/gemini ambient.txt` (41 KB) | Validation of claude ambient claims; agent-routing additions |

---

## 6. Hermes / Pro Tunnels / MCP

### Status
**Worktree:** `hermes-parity` (HEAD `465a3c30`). 28 tools registered (22 Hermes-parity + 6 PKM-specific). Provider chain delegated to Swift TriageService. Session persistence with FTS5. Credential rotation pool. Error classifier with 100+ patterns.

### 28 tools (canonical list)
22 Hermes-parity (Phase 1-2): file_ops, web_fetch, memory, skills, todo, clarify, code_execution, computer_use (Swift-delegate stub), think, chunk_reduce, workspace_search, process_registry, vault_search, vault_read, vault_write, bash_execute, web_search, delegate_task, error_classifier, title_generator, rate_limit_tracker, workflow_executor.

6 PKM-specific (Phase 7): graph_query, note_template, note_linker, research_digest, citation_extractor, markdown_table.

### Code anchors
| Subsystem | Path |
|---|---|
| Tool registry | `worktree:hermes-parity/agent_core/src/tools/registry.rs` |
| Note tools | `worktree:hermes-parity/agent_core/src/tools/note_tools.rs` |
| Graph query tool | `worktree:hermes-parity/agent_core/src/tools/graph_query.rs` |
| Computer-use stub | `worktree:hermes-parity/agent_core/src/tools/computer_use.rs` |
| Session persistence | `worktree:hermes-parity/agent_core/src/session_persistence.rs` |
| Credential pool | `worktree:hermes-parity/agent_core/src/credential_pool.rs` |
| Error classifier | `worktree:hermes-parity/agent_core/src/error_classifier.rs` |
| Rate limit tracker | `worktree:hermes-parity/agent_core/src/rate_limit_tracker.rs` |
| Prompts (plain markdown, NOT ChatML) | `worktree:hermes-parity/agent_core/src/prompts.rs` lines 53-57 |
| Bridge (provider-failed callback) | `worktree:hermes-parity/agent_core/src/bridge.rs` lines 82-128 |

### Design docs
| Doc | Status |
|---|---|
| `worktree:hermes-parity/docs/PHASE_I_IMPLEMENTATION_GUIDE.md` (800 lines) | Canonical implementation spec for Rust agent runtime |
| `worktree:hermes-parity/PHASE9_AUDIT.md` | **Canonical** honest gap assessment (B+ grade, 3 HIGH issues) |
| `worktree:hermes-parity/CODEX_REVIEW_REPORT.md` | **Canonical** v2 audit post-Phase 8 |
| `worktree:hermes-parity/docs/HERMES_PARITY_REPORT.md` | Superseded by Phase 8-9 work |
| `worktree:hermes-parity/docs/sprint-sessions/sprint-agent-3-mcp.md` | MCP integration plan, **not yet complete** |
| `worktree:hermes-parity/docs/DECISIONS.md` | Architecture decisions log (D-001 through D-013) |

### Session persistence schema
```sql
CREATE TABLE checkpoints (
  session_id TEXT NOT NULL,
  turn_number INTEGER NOT NULL,
  messages_json TEXT NOT NULL,
  usage_json TEXT NOT NULL,
  created_at TEXT DEFAULT (datetime('now')),
  active_provider TEXT,
  active_key_index INTEGER,
  PRIMARY KEY (session_id, turn_number)
);
```
+ FTS5 virtual table over `messages_json` with INSERT/UPDATE/DELETE triggers. **Better than Hermes flat JSONL.** `active_provider` + `active_key_index` enable resuming with different API key pool state.

### MCP / omega-mcp crate
- `omega-mcp/` (131 tests, 13 clippy warnings)
- JSON-RPC over stdio + Streamable HTTP
- MCP discovery, tool advertisement, capability negotiation
- **Stub for execution**: `agent_core/src/tools/registry.rs` line 815: `// TODO: Load server config and establish connection`
- Sprint plan at `worktree:hermes-parity/docs/sprint-sessions/sprint-agent-3-mcp.md`: make `omega-mcp` authoritative; add `vault_search`, `vault_read`, `vault_write`, `vault_graph_query`; harden AX-first computer-use; close execution seam for DeviceAgentService

### External research
- `/Users/jojo/Downloads/final/EPISTEMOS_HERMES_MANIFESTO.md` (paradigm-setter)
- `/Users/jojo/Downloads/final/Episdemo Master Architecture Brief + Claude Brainstorm Prompt.md` (provider architecture)
- `/Users/jojo/Downloads/final/Building Epistemos x Hermes Hackathon.txt` (D1-D10 dossier, rmcp + base62 + tokio broadcast)
- `/Users/jojo/Downloads/final/executive sumaries/epistemos-rival-doctrine.md` (provenance-first correction)
- `/Users/jojo/Downloads/Advice/{claude advice, Gpt paper, Perplexity paper}.md` (multi-provider architecture)
- `docs/_consolidated/20_canonical_research/HERMES_INTEGRATION_RESEARCH.md` (10-file Fast Pack + 30-file Deep Pack curated)
- `docs/_consolidated/20_canonical_research/FUSED_AGENT_ENGINEERING_REPORT.md` (root-cause: tool-load failures via silent check_fn returning False)

---

## 7. Code Editor / TextKit / syntax-core

### §23-§27 PLAN_V2 architectural law
**Canonical:** `worktree:inspiring-heisenberg-ea9dc3/docs/architecture/PLAN_V2.md` §23-§27.

| Section | Coverage |
|---|---|
| §23 | Code Editor Architecture Truth + Syntax Data Plane. CodeEditSourceEditor 0.15.2, O(n) string binding ≤100KB acceptable. Prose editor better-architected. syntax-core crate (tree-sitter 0.25 + ropey 1.6 OR crop). Viewport-scoped tokenization mandatory. **Metal prohibited for text rendering** unless benchmarks prove otherwise. |
| §24 | Agent Streaming Data Plane. **16ms token coalescing is FIRST optimization, not transport change.** Reduce 100-300 events/sec → ~60/sec. Never coalesce errors / approvals / completions. SPSC ring buffer or pull-based polling at frame boundaries. |
| §25 | Graph Zero-Copy Rendering. Triple-buffered MTLBuffer with `.storageModeShared`. Struct-of-Arrays. **Deferred until Session 3 typed-buffer proves copy is bottleneck.** |
| §26 | Implementation Sessions. Sessions 0-6 done. Sessions 7+ gated on benchmarks. |
| §27 | **Anti-Pattern Register — 15 prohibitions verbatim.** Most load-bearing: "Do not optimize features that only exist in documentation. Verify code first, then optimize." |

### syntax-core crate (Pro-tier scaffolding)
**Path:** `worktree:inspiring-heisenberg-ea9dc3/syntax-core/`. Tests pass; **no FFI exports to Swift yet**.

**FFI data shapes (`#[repr(C)]`, all compile-time size-asserted):**
```rust
SyntaxDocumentHandle  16B  doc_id:u64 + generation:u64
SyntaxEditDelta       48B  doc_id, from_gen, to_gen, byte_offset, old_len, new_len
SyntaxViewportRequest 24B  doc_id, generation, utf16_start, utf16_end
SyntaxTokenSpan       12B  utf16_start:u32, utf16_len:u16, kind_id:u16, flags:u8, _pad:[3]
SyntaxFoldRange       24B  byte_start, byte_end, kind_id:u16, _pad:[6]
SyntaxDiagnosticRange 24B  byte_start, byte_end, severity:u8, _pad:[7]
SyntaxSnapshotStats   --   doc_id, gen, node_count, error_count, parse_time_us
```

**Files:**
- `syntax-core/src/lib.rs` — public API surface
- `syntax-core/src/rope_bridge.rs` — ropey ↔ tree-sitter `TSInput` integration via `parser.parse_with_options` + chunk-by-chunk reading
- `syntax-core/src/token_registry.rs` — capture-name → u16 kind ID via `FxHashMap`
- `syntax-core/src/generation.rs` — `AtomicU64` counter for stale-parse cancellation
- `syntax-core/benches/parse_baselines.rs` — initial parse 50K-line Rust file <100ms; reparse single-char <1ms

### Code editor doc-truth audit
**Canonical:** `worktree:inspiring-heisenberg-ea9dc3/CODE_EDITOR_FEATURE_AUDIT.md`. See H9 above for drift table.

### Other code anchors
- `Epistemos/Views/Notes/CodeEditorView.swift` (CodeEditSourceEditor host)
- `Epistemos/Views/Notes/CodeLineGutter.swift`
- `Epistemos/Engine/SwiftTreeSitterLiveHighlighter.swift` (15 language bindings)
- `Epistemos/Views/Notes/ProseEditor*.swift` — **PROTECTED PATH**, do not edit
- `Epistemos/Engine/EpdocDocument.swift` (NSDocument subclass for `.epdoc`)

### .epdoc / Documents / Readable Blocks
- `Epistemos/Engine/EpdocDocument.swift`
- `Epistemos/Sync/ReadableBlocksProjector.swift`
- `Epistemos/Sync/ReadableBlocksIndex.swift`
- Verdict: TextKit 2 + Tiptap-in-WKWebView locked per `docs/_consolidated/00_canonical_authority/EDITOR_VERDICT_TIPTAP_VS_APPFLOWY.md`

---

## 8. Streaming / FFI / BoltFFI

### §24 Agent Streaming Data Plane
See §7 above. 16ms coalescing is the first optimization.

### Honest-handle FFI pattern (canonical doctrine)
- `worktree:agent-a0550f9c/epistemos-shadow/src/honest_handle.rs` (770 lines) — `Arc::into_raw` + `Arc::increment_strong_count` + `Arc::decrement_strong_count` + `panic::catch_unwind(AssertUnwindSafe(...))` panic→null translation
- `worktree:agent-a0550f9c/Epistemos/Engine/RustShadowFFIClient.swift` (321 lines) — Swift consumer wrapping raw handle in `final class`; `init` takes ownership via `shadow_handle_open_at`; `deinit` releases via `shadow_handle_release`

### FFI opportunity matrix (8 boundaries audited)
**Canonical:** `worktree:agent-a0550f9c/FFI_OPPORTUNITY_MATRIX.md`.

| Boundary | Verdict | Reason |
|---|---|---|
| Graph control/render | KEEP | Tiny payloads, work-dominated |
| Rust graph label search | KEEP | |
| BTK subscription | BATCH | Zero-copy transport but row-by-row materialize |
| BTK queries | TUNE | Newline-separated IDs; could switch to typed buffer |
| Block edit | KEEP | |
| Markdown parser | KEEP | |
| Embedding push | KEEP | |
| Knowledge-core shadow ring | ZERO-COPY (after live UI consumes) | Currently shadow-only |

### BoltFFI typed-buffer prototype
**Path:** `worktree:inspiring-heisenberg-ea9dc3/graph-engine/src/bolt_bridge.rs` behind `bolt-graph` feature flag. **Never benchmarked vs C FFI in production.**

```rust
#[repr(C)]
pub struct BoltNodeRecord {
  id_ptr: *const u8, id_len: u32,
  label_ptr: *const u8, label_len: u32,
  node_type: u8,
  x: f32, y: f32,
  size: f32,
  color_rgba: u32,
}
#[repr(C)]
pub struct BoltEdgeRecord {
  source_idx: u32, target_idx: u32,
  edge_type: u8, weight: f32,
}
```

Functions: `bolt_graph_load_nodes`, `bolt_graph_load_edges`, `bolt_graph_query_positions`. All wrapped in `panic::catch_unwind`. String extraction via `bolt_str(ptr, len)` returns `""` on null/invalid UTF-8.

### Streaming instrumentation (Session 6)
**Canonical:** `worktree:inspiring-heisenberg-ea9dc3/Epistemos/Engine/Log.swift` line 71.
```swift
static let agentStreaming = OSSignposter(subsystem: "com.epistemos", category: "agent-streaming")
```
Plus categories: `appPerf`, `notesPerf`, `vaultPerf`, `graphPerf`, `ffiPerf`.

`StreamingDelegate` (`Epistemos/Bridge/StreamingDelegate.swift`) signposts: `onThinkingDelta`, `onTextDelta`, `onToolInputDelta`, `onToolStarted`, `onToolCompleted`, `onSubagentSpawned`, `onPermissionRequired`, `onContextCompacting`, `onContextCompacted`, `onTurnStarted`, `onComplete`, `onError`.

`AgentStreamEvent` enum: 12 cases at `StreamingDelegate.swift:144-156`.

### Local-stream truncation/flush fix (preservation watch)
- `Epistemos/LocalAgent/IncrementalToolCallDetector.swift` (main + 3 worktrees)
- `EpistemosTests/IncrementalToolCallDetectorTests.swift`
- Fix prevents premature EOF / token truncation on local-stream path during tool-call detection. Per CANON_GAPS C12 — preserve through any agent_loop refactor.

---

## 9. Local Model / MLX Inference

### Stack
- **Local text generation:** GGUF primary
- **Helper / embeddings / adaptation / Apple-native auxiliary:** MLX (mlx-swift, mlx-swift-lm)
- **Cloud:** Anthropic (URLSession + thinking blocks preserved on `tool_use`), OpenAI (URLSession), Perplexity (Sonar Pro)
- **Apple:** Foundation Models (AFM) when available + AFMSessionPool warm pool (800ms→140ms, 5.7× cut)

### Mamba-2 SSM (already wired)
- `Epistemos/Engine/MetalRuntimeManager.swift` — Mamba-2 GPU compute
- `Epistemos/Shaders/Mamba2/{direct_conv, elementwise_ssm_helpers, inter_chunk_scan, segsum_stable}.metal` — Q=128 chunks, 32KB threadgroup, no Decoupled Lookback
- Phase 1A complete: save/load/resume/staleness wired (per project memory)

### KIVI KV cache
**Status:** opt-in, blocked on MLX metallib runtime. Unit tests pass.

### Local model safety (DEFERRED, per release hardening §1.3)
**Canonical:** `worktree:agent-a0550f9c/docs/architecture/RELEASE_HARDENING_CANONICAL_PLAN_2026-04-20.md` §1.3.
> "Do not merely hide big models from the picker and call it fixed. The user must get an honest 'this model cannot load safely on this machine right now' error."
- Unified `ModelSupervisor` actor: admission control before load, eviction on memory pressure, explicit refusal instead of swap death
- Files to touch: `MLXInferenceService`, `InferenceState`, app shell memory-pressure listener

### Faculty roster fallback (D4)
**Canonical:** `worktree:agent-a0550f9c` commit `4c0c7e17`.
- Hermes 4.3 36B → demoted to ≥32GB opt-in (memory budget violation)
- Qwen 3 8B → safe fallback for 16GB Macs
- Hermes 3.x 8B (~3.5 GB Q4_K_M) — primary local target per dossier

### ConfidenceRouter
**Path:** `Epistemos/LocalAgent/ConfidenceRouter.swift`. Routes between Claude Haiku 4.5 (fast helper, default) and Qwen3-4B (local fallback). Cost recorded in `reasoning_metrics`.

### Helper-model summariser (simulation §3.4.5)
Helper model produces one-line live summary for active agent in dispatch panel. Cadence: every 2s while streaming + on animation transitions; stops on Idle; 30s cache.

### Continual learning
**Canonical:** doctrine Annex A.5 + `docs/architecture/ADAPTATION_SUBSYSTEM_SPEC_v1.md`.

| Method | QLoRA | Continual learning | Status |
|---|---|---|---|
| **QOFT (OFTv2)** | ✅ native | ✅ orthogonal | **Recommended production** |
| **QDoRA** | ✅ native | ✅ high | Practical deployments |
| **QPiSSA** | ✅ convert | ✅ high | Best accuracy |
| OSFT | ❌ | ✅ ~20-task | Pro R&D only |
| PSOFT | ❌ | ❌ single-task only | Pro R&D only |
| coSO | ❌ | ✅ no LLM yet | Pro R&D only |

Adapter capacity 128GB MacBook ~3,100 at r=8; switching <1ms.

**Donor research:** `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive/osft_psoft_coso_fusion.md`.

---

## 10. Graph Engine and Motion

### Status
`graph-engine/` crate — **2,508 tests** (largest crate). 12 modified files in main's dirty diff = **HIGH RISK** (`graph-engine/src/knowledge_core/store.rs` +808 lines, force/edge_trim/motion/curl/waves/engine/bolt_bridge/simulation/types/renderer/lib.rs).

### Code anchors
- `graph-engine/src/knowledge_core/store.rs` (massive new store impl, unaudited)
- `graph-engine/src/{forces, edge_trim, motion/{curl, waves}, engine, simulation, types, renderer, lib}.rs`
- `graph-engine/benches/graph_ffi_baselines.rs` (criterion baselines: 100/500/1000/5000 nodes)
- `Epistemos/Views/Graph/MetalGraphView.swift` — **PROTECTED PATH**
- `Epistemos/Views/Graph/HologramController.swift` — **PROTECTED PATH**

### Graph motion overlay
**Canonical:** `docs/_consolidated/20_canonical_research/GRAPH_WAVES_AUDIT.md` (2026-04-24, second-pass synthesis vs `graph-engine/`).

Edge trimming (r0 + gap), velocity inheritance EMA α=0.72, WaveEvent rings (Gaussian shell, 8-cap, 1/√r falloff, oldest-evict), temporal envelope retire <5%, 16px origin clamp, mass formula, semi-implicit Euler.

### Three runtime fixes (Session 6 worktree)
**Canonical:** `worktree:inspiring-heisenberg-ea9dc3/docs/APP_ISSUES_AUTO_FIX.md`.

| Issue | Root cause | Fix |
|---|---|---|
| ISSUE-2026-04-06-002 Beach ball (P1) | `recompute_semantic_neighbors` O(n²×768) on main, ~2s for 1131 nodes | Move to `Task.detached(.utility)` + `parking_lot::Mutex<Vec<(u32,u32,f32)>>` |
| ISSUE-2026-04-04-001 Vec drop crash (P0) | `Vec::from_raw_parts(ptr, count, count)` allocator mismatch on `graph_engine_free_prepared_retrieval_candidates` | `into_boxed_slice` + `Box::into_raw` / `Box::from_raw` symmetry |
| ISSUE-2026-04-06-001 Pinned inspector freeze (P2) | Idle skip stops `update_camera()` after 3 frames; pinned panel reads stale `node_screen_pos()` | Added `force_alive` flag; bypass idle skip when pinned panels exist |

---

## 11. Simulation / Theater (Pro Design DNA — FROZEN)

**Worktree:** `simulation` — frozen per user directive. Pro-tier donor only. **Highest design density.**

### DOCTRINE.md v1.6 (17 sections, 148 KB)
**Path:** `worktree:simulation/docs/simulation-mode/DOCTRINE.md`.

Sections covered:
- §1 13 Non-Negotiable Invariants (I-1 to I-15 + I-16 bit-perfect pixel rendering contract)
- §3 Three-Placement Companion System (Landing Farm + Graph Live Theater + Notes Sidebar = projection of single CompanionRegistry)
  - §3.2 Landing Farm: 6 visual states (Active/Recent/Dormant/Parked/Just-acquired/Errored), per-companion ±32px walking with seeded PRNG
  - §3.3 Graph Live Theater: hysteresis, 30s idle exit, multi-room viewport tiling, overview vs drill-in
  - §3.4 Notes Sidebar: knowledge-brick design language (typography NY/SF Pro/SF Compact Rounded, density 12pt/22pt/32pt, motion 220ms/180ms/140ms), multi-vault hierarchy
- §5 Body Grammar: Block (parameterized: aspect/legs/antennae/eye_treatment) / Sage (tall humanoid) / Orb (spherical) / Snake (Hermes-only)
- §7 Adapter Gift-Box (`.epbox` package: manifest.json + content/ + preview/ + provenance.json; 9 box types; honesty-bound unwrap timing)
- §8 Hermes graph faculty + opulent landing ritual (7-phase, 4.4s, NousResearch canonical assets, gold halo, ASCII portrait, snake coil)
- §9 Honesty rules (3-class allowed-animation: event-driven / cosmetic-idle / state-transition)
- §10 Atlas pipeline (Character DNA → AI concept → Aseprite refinement → auto-slice → CI validation; LobeHub provider icons; pixel-art vs smooth-vector split)
- §11 Event Schema (32-variant `AgentEvent` enum + **6 new v1.6 variants forward-referenced**: `SteerRequested`, `SummaryStarted`, `SummaryDelta`, `SummaryCompleted`, `VaultCreated`, `VaultArchived` — H6)
- §12 Performance Budgets (≤5ms p99 Metal frame, ≤1ms reducer, ≤50µs UniFFI, ≤5µs ring buffer, ≤10ms FTS5 p95, ≤300MB idle, ≤6GB active, ≤50MB VRAM, ≤500ms Fast-tier inference p95)
- §13 App Store / Pro Profile Distinction (`#if EPISTEMOS_PROFILE_PRO` gates)
- §14 Anti-Drift Rules (15 forbidden code patterns + 5 forbidden doc patterns)

### IMPLEMENTATION.md v1.6
**Path:** `worktree:simulation/docs/simulation-mode/IMPLEMENTATION.md`.

Slices S0-S11 all committed:
- S0: perf-gate substrate
- S1: CompanionRegistry + activity hysteresis (Active/Recent/Dormant/Parked)
- S2: AgentEvent normalization + replay infrastructure
- S3: Honesty audit ledger (`AuditOrigin` enum at `worktree:simulation/agent_core/src/audit/origin.rs`)
- S4: Theater Metal renderer (placeholder geometry, perf baseline)
- S5: Landing Farm placement
- S5.6: Provider Brand Icon System (LobeHub `@lobehub/icons-static-svg` + 18 providers + dual-source Hermes)
- S6: Notes Sidebar (knowledge-brick + multi-toggle + multi-vault + helper-model summariser)
- S7: Graph Live Theater (multi-room viewport tiling)
- S8: Companion creation flow (8 atomic steps)
- S9: Hermes graph faculty + opulent landing ritual
- S10: Animated raster atlas pipeline (V1 sprites; bit-perfect I-16 enforced)
- S11: Adapter gift-box `.epbox` + Mailroom

### Code anchors
- `worktree:simulation/agent_core/src/companions/registry.rs` (CompanionRegistry, 350+ lines)
- `worktree:simulation/agent_core/src/audit/origin.rs` (three-class AuditOrigin)
- `worktree:simulation/agent_core/src/adapters/epbox.rs` (gift-box parser, 400+ lines)
- `worktree:simulation/agent_core/src/events.rs` lines 272-499 (32 variants; 6 new v1.6 NOT YET in code — H6)

### Character DNA docs
- `worktree:simulation/docs/simulation-mode/character-dna/{block_compact, block_wide, hermes_snake, orb, sage}.md`

### I-16 bit-perfect contract (pixel-art only)
- `MTLSamplerMinMagFilter.nearest` (both)
- Integer scale only (1×, 2×, 3×, 4×)
- Snap-to-pixel in vertex shader
- MSAA off
- SVG paths orthogonal only (M, L, H, V, Z) — no Bezier/arc/circle/ellipse
- Halos as separate additive-blend quads with pre-rasterized textures (never Gaussian blur)
- LobeHub smooth-vector brand icons exempt from I-16 (different category)

---

## 12. App Store Release / Phase R / Phase S

### Canonical tracker
**Path:** `/Users/jojo/Downloads/Epistemos/docs/APP_STORE_RELEASE_COMPLETION_STATUS_2026_04_24.md` (also at `docs/_consolidated/30_canonical_operational/`).

App Store profile: bounded execution only — chat, bounded agent, local MLX, Apple Intelligence, user-key cloud, vault/search/note tools. NO shell, Bash, Docker, CLI, iMessage, background agents.

Pro: full autonomy; shared code profile-gated not forked. Per-build entitlement matrix.

### Resource Runtime / grants / verified writes (Phase R)
**Status:** lives on `codex/runtime-input-audit` branch — **324 commits ahead of main, NEVER MERGED**. Per WORKTREE_INSIGHT_SALVAGE §6, recommended cherry-pick now.

Specifically: `47fd03fe` "fix(release): expose writable attachment paths"; vault write authorization pipeline; attachment path exposure; sandbox grant seeding; CODE_EDITOR_FEATURE_AUDIT.md (single source of truth on what's verified live vs planned vs reverted — minimap gone, outline navigator live).

### PromptTree / N1 (Lane A)
**Status:** **601 unmerged commits** on `lane-A` (H1).

- `/Users/jojo/Downloads/Epistemos-laneA/docs/PROMPT_AS_DATA_SPEC.md` (270 lines) — JSPF (JSON-Schema Prompt Format) + PTF (Prompt Tree Format) at `<vault>/.epistemos/prompts/<session>/<turn>/`. Anthropic prompt-cache 4 breakpoints, 90% discount, 5-min TTL, 1024-token min. Relocation Trick: 7%→84% cache-hit rate.
- `Epistemos/Views/Cost/CostDashboardView.swift` (NEW, 317 lines, W9.6) — `cached_tokens_share` counter
- `Epistemos/Views/Approval/ApprovalModalView.swift` (NEW, 162 lines, W9.8) — SwiftUI tool approval flow
- New Swift files: `PromptTree.swift`, `PromptRenderer.swift`, `PromptCache.swift`, `PromptTreePersister.swift`
- **Substrate blocker:** orphan `agent_core/src/session_insights.rs` (655 LOC, full test suite, never declared in `lib.rs`)

### Pre-release evidence package (CANON_GAPS C11, staged)
Workflow matrix + regression suite + App Store metadata + manual dogfood + submission checklist + Phase R closure + Phase S closure (TestFlight / metadata / submission).

### MAS hardening canonical state
**Canonical:** `docs/audits/MASTER_HARDENING_WIRING_AUDIT.md` (2026-04-28). Sections 16-23 cover: MAS privacy/computer-use boundary (BLOCKER), Contextual Shadows V0 (HIGH), Instant Recall large-vault p95 (MEDIUM), Raw Thoughts default-on UI (HIGH), Code editor 4k-line fluidity (HIGH), Derived index staleness (HIGH), Deterministic mutation envelopes (HIGH).

---

## 13. Privacy / Telemetry / Security

### Privacy stack (7 layers per FINAL_SYNTHESIS §5)
Reflex (local cache) → Attention (Eidos in-process) → Executive (local compile) → Immune (deterministic local auth) → Motor (in-process/sandboxed browser) → Memory (encrypted RunEventLog) → Metabolism (differentially-private aggregates).

**Moat:** one process = one trust boundary.

### Security / threat scanning
- `agent_core/src/security.rs` — 75+ regex rules from Hermes + OpenClaw; `ThreatCategory` (6 classes), `ApprovalScope` (Auto/Once/Session/Always/Deny), Severity levels
- `Epistemos/Omega/CSISafeguard.swift`
- App Store privacy: `docs/audits/PRIVACY_APP_STORE_AUDIT.md`

### TCC / sandbox
- `Epistemos/Omega/TCCPermissionState.swift`
- `Epistemos/Omega/OmegaPermissions.swift`
- `Epistemos/AppStoreComputerUseStubs.swift`

### Telemetry policy (CANON_GAPS C13, staged)
- Captured (allowed): timestamps, modifier states, anonymized event types, failure categories, aggregate latency, feature flag enablement, OS/app version, hardware class
- Forbidden: typed text content, note bodies, code, message bodies, file contents, file paths (paths leak structure), search query strings, vault content, screenshots, AX tree contents, microphone audio
- Retention: local-only ring buffer (7 days runtime, 30 days crash logs)
- Cloud upload: explicit per-channel opt-in; default OFF

### Secrets
- API keys in macOS Keychain (`SecItemAdd` / `SecItemCopyMatching`), NEVER UserDefaults
- Per CANON_GAPS C2/C3: BYOK cloud OFF by default + no silent cloud fallback / escalation

---

## 14. Multi-Agent / ACS Ecosystem

### NeMoCLAW / OpenCLAW
**Canonical:** doctrine Annex A.8.

Sub-agents called "claws" each control specific app/domain. Coordination via resonance-based orchestration (each claw reports Σ signature; orchestrator routes by direction + KAM stability), explicitly avoiding self-attribution bias.

REP mesh + CRDT synchronization make claws horizontally distributable across processes / devices / users (Research only — Ecosystem layer of ACS).

**Single-claw in Core. Multi-claw + REP mesh in Research.** Multi-agent on M4 Max tops out at ~10–15 concurrent 7B agents via work-stealing.

### Honest scheduling stack (Annex A.4)
| Mechanism | Latency | Use case | Percentage |
|---|---|---|---|
| Work-stealing (Rayon/Tokio) | ~10-100 ns | Default hot path | **99%** |
| Priority queue | 50-100 ns | User-facing | 0.9% |
| Competitive allocation | 1-100 ms | Agent role selection (NOT per-task) | 0.1% |

Notch-Delta lateral inhibition is **10¹²× too slow** for actual task routing.

### Symphony OS / KIVI / KV virtualization
**Canonical:** doctrine Annex A.9. KV cache as virtualized file system with per-conversation namespace and snapshot/restore semantics. KIVI = project's existing partial implementation, opt-in, blocked on MLX metallib runtime.

### Deep Deliberation jury (Pro)
**Canonical:** `/Users/jojo/Documents/Epistemos-QuickCapture/LIVE_FILES_AND_SUBSTRATE_ADDENDUM.md` §8 (Eidos Plus deliberation engine).

---

## 15. Ternary Substrate / Research Tier

### Sherry 1.25-bit packing (verified)
**Canonical:** doctrine Annex A.5.
**Donor:** `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive/{ternary_spectral_architecture, ternary_code_scaffolds, ternary_reconceptualization}.md`.

Hong Huang et al. (City University of Hong Kong, Tencent, McGill), January 2026. Code at `github.com/Tencent/AngelSlim`. 3:4 fine-grained sparsity within every block of 4 weights. Each 4-weight block packs into 5 bits (4-bit index + 1-bit sign) = 1.25 bits per weight. 1B LLaMA-3.2: zero accuracy loss, 25% bit savings, 10% speedup.

### BitNet b1.58 (verified)
Microsoft, 2B params, production. {-1, 0, +1} weights. 58.5% information density gain vs binary.

### Engram O(1) hash recall (partial)
DeepSeek V4 Preview (April 24, 2026). Hashed N-gram embeddings for static knowledge with O(1) recall. Sparsity Allocation Law: 20-25% to memory, 75-80% to compute.

### Birkhoff Polytope mHC (UNVERIFIED)
Theoretical conjecture. No literature found. Treat as Forbidden tier.

### "3059× speedup" claim (UNVERIFIED)
Sherry actually achieves 10-18% over other ternary baselines on CPU. The 3059× figure is unsupported (likely vs unoptimized FP32 CPU baseline).

### iPhone 17 Pro Max benchmarks (PROJECTIONS, not measured)
iPhone 17 doesn't exist yet. The numbers in Kimi research are projections.

### 6 mathematical pillars (doctrine Annex A.2 + §4.1)
Kleene K3 ternary logic / Laplace-Beltrami spectral geometry / rate-distortion / Koopman operator / resonance eigenvector / KAM stability.

---

## 16. ANE Direct Path / KV Implantation (Research only)

### Direct ANE access
**Canonical:** doctrine Annex A.11.
**Donor:** `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive/EPISTEMOS_ANE_GLASS_BALL_ASSESSMENT.md`.

`AppleNeuralEngine.framework` is private but loadable via `cs.disable-library-validation` (NOT `com.apple.private`):
1. `dlopen` or `NSBundle` load
2. Method swizzling / direct message send to `_ANEClient`, `_ANECompiler`, `_ANEInMemoryModelDescriptor`
3. MIL (Machine Learning Intermediate Language) compilation to E5 binaries
4. IOSurface-based zero-copy I/O between GPU and ANE

ANE per-core state is not exposed — best telemetry: power/frequency via IOKit/SMC channels.

### KV cache implantation
**Canonical:** doctrine Annex A.10.
**Donor:** `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive/EPISTEMOS_UNIFIED_MEMORY_CONTROL_ROOM.md`.

`MTLBuffer(options: .storageModeShared)` + `buffer.contents()` gives direct `UnsafeMutableRawPointer`. Enables: raw memory hex dump of GPU tensor, live weight patching, KV cache pre-loading (implant), attention mask manipulation, activation interception, command buffer inspection.

NOT enabled: ANE silicon internals (still black box), kernel-level paging (SIP), in-place MLX ops (MLX avoids by design).

### Activation steering (Anthropic 2024 SAE research)
SAE (Sparse Autoencoder) features for "Golden Gate Bridge", "sycophantic praise", "deceptive language". Research-tier Glass Ball / Executive Console.

---

## 17. UX Posture and Surfaces

### One composer, two modes (CANON_GAPS C4, staged)
- Chat mode + Agent mode share same input affordance
- Effort axis (fast / thinking / research / agent / liveAgent) separate from mode
- Tools = capabilities at agent layer (Sovereign Gate gates them), NOT a third UX mode

### Tamagotchi Pixel/Tactical mode duality (Pro)
**Canonical:** `/Users/jojo/Documents/Epistemos-QuickCapture/BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md` §3.

### Inline thinking UI (DEFERRED)
Per `worktree:agent-a0550f9c/docs/architecture/RELEASE_HARDENING_CANONICAL_PLAN_2026-04-20.md` §1.5 + §2 Deferred. Current: `ThinkingPopoverView` detached. Target: inline, in-bubble, auto-expand during thinking, auto-collapse on first answer token.

### ApprovalModalView (W9.8, Lane A)
SwiftUI sheet modal for tool approval flow. Wired to StreamingDelegate → PendingApproval → RustAgentBridge.resolveApproval callback.

### Knowledge-brick design language
**Canonical:** simulation DOCTRINE.md §3.4.3. Pro-tier sidebar UX. NY semibold title, SF Pro Text picker, SF Compact Rounded agent leaves; 12pt indent / 22pt row / 32pt agent leaf / 28pt model header; 220ms spring expand / 180ms pulse / 140ms toggle.

### EditorBreadcrumbBar
Replaces removed status bar (per H9 audit).

---

## 18. Codex Branches (UNMERGED — easiest to forget)

| Branch | Commits ahead | Status | Top insight | Action |
|---|---|---|---|---|
| **`codex/runtime-input-audit`** | 324 | DIVERGED, 2026-04-24 | App Store input validation + vault write authorization + CODE_EDITOR_FEATURE_AUDIT.md | **Cherry-pick now** |
| **`codex/runtime-memory-hardening`** | 750 commits | 2026-04-03 | **5 Laws** (measure before cut / new crate not refactor / identity first / UniFFI until profiled / Python out-of-process) + **Phase I Rust agent migration MANDATORY pre-release** + zero-copy mmap vault search | **Cherry-pick docs only after deliberation brief** |
| **`codex/release-stabilization-and-runtime-hardening`** | 669 commits | 2026-03-28 | RunPod modernization, ODIA training corpus sync, EventStore cleanup | **Verify superseded** before archiving |
| **`codex/post-audit-feature-work`** | 762 commits | 2026-04-04 | **`recipe_cache`** (commit `c217b266`): SQLite tool result caching, SHA-256 keying, TTL=7d, LRU=10K | **Cherry-pick `recipe_cache` only**; defer light-mode polish |

**Inspection:** `git log codex/<branch> --oneline -30 main..codex/<branch>` from main checkout root.

---

## 19. Operational Prompts and Indices

| Doc | Path | Role |
|---|---|---|
| Truth-router (NEW) | `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` | Three-tier ship model + killer features + invariants |
| Codex overseer (NEW) | `docs/fusion/CODEX_FINAL_EXECUTION_PROMPT_2026_05_01.md` | Tier-aware / killer-feature / biometric work |
| Worktree salvage (NEW) | `docs/fusion/WORKTREE_INSIGHT_SALVAGE_2026_05_02.md` | 10 stay-stellar items + per-worktree state |
| Canon gaps (NEW) | `docs/fusion/CANON_GAPS_AND_ADDENDA_2026_05_02.md` | 15 gaps + 3 bonus findings + pre-drafted addenda |
| Codex deliberation prompt (NEW) | `docs/fusion/CODEX_DELIBERATION_PROMPT_2026_05_02.md` | Non-interrupting deliberation request |
| All docs index (NEW) | `docs/fusion/ALL_DOCS_INDEX_2026_05_02.md` | 91+ absolute-path links |
| Master research index (THIS DOC) | `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md` | Concept → canonical source mapping |
| April 30 builder | `docs/fusion/BUILDER_EXECUTION_PROMPT_2026_04_30.md` | Phase 0 + deliberation template |
| April 30 source map | `docs/fusion/CANONICAL_SOURCE_MAP_AND_GATE_REGISTER_2026_04_30.md` | What each source can decide |
| April 30 fused queue | `docs/fusion/FUSED_IMPLEMENTATION_QUEUE_2026_04_30.md` | 9-item queue |
| April 30 Kimi prompts | `docs/fusion/KIMI_RESEARCH_AND_FUSION_PROMPT_2026_04_30.md` + `KIMI_SESSION_CONTEXT_2026_04_30.md` | Kimi session inputs |
| Kimi review output | `docs/fusion/KIMI_FUSION_REVIEW_2026_04_30.md` (+ ADDENDUM) | Kimi's audit |
| Worktree inventory | `docs/fusion/WORKTREE_INVENTORY_2026_04_30.md` | Branch/dirty/lane info (note: Lane A "mostly merged" claim is wrong — H1) |
| Build/test floor | `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md` | Phase 0 floor results |
| Codex Manifesto | `docs/_consolidated/30_canonical_operational/CODEX_MANIFESTO.md` | **Verbose Doc-First Protocol** — two-tier corpus search (~/Downloads/ Tier 1 raw research, docs/ Tier 2 distilled). Doc-first searches; CODEX_PROMPT_CHAIN sections; VISION_BACKLOG; phase implementations |

---

## 20. By-Worktree Quick Reference

| Worktree | Branch | Purpose | Top docs |
|---|---|---|---|
| **main** (`/Users/jojo/Downloads/Epistemos`) | `feature/landing-liquid-wave` | Active substrate spine + Halo V0 + R15/R16 closures + landing wave | All `docs/`; `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` |
| **Lane A** (`/Users/jojo/Downloads/Epistemos-laneA`) | `lane-A` | **N1 Prompt Tree (601 unmerged commits — H1)** | `docs/PROMPT_AS_DATA_SPEC.md`, `docs/plan/prompts/N1_prompt_tree.md` |
| **agent-a0550f9c** (locked) | `worktree-agent-a0550f9c` | Audit pass #3 + W9.21-W9.27 hardening | `docs/CANONICAL_AUDIT_LOG.md`, `docs/architecture/RELEASE_HARDENING_CANONICAL_PLAN_2026-04-20.md`, `FFI_OPPORTUNITY_MATRIX.md`, `docs/AMBIENT_RECALL_HALO_MASTER_PLAN.md`, `HANDOFF_SESSION_2026-04-07.md` |
| **hermes-parity** | `worktree-hermes-parity` | 28-tool Hermes parity + provider chain + session/credential | `docs/PHASE_I_IMPLEMENTATION_GUIDE.md`, `PHASE9_AUDIT.md`, `CODEX_REVIEW_REPORT.md`, `docs/DECISIONS.md`, `docs/sprint-sessions/sprint-agent-3-mcp.md` |
| **inspiring-heisenberg-ea9dc3** | `claude/inspiring-heisenberg-ea9dc3` | §23-§27 PLAN_V2 + benchmark harness + syntax-core + Sessions 0-6 + 3 runtime fixes | `docs/architecture/PLAN_V2.md` §23-§27, `CODE_EDITOR_FEATURE_AUDIT.md`, `docs/APP_ISSUES_AUTO_FIX.md`, `syntax-core/` crate |
| **simulation** (FROZEN) | `worktree-simulation` | Pro design DNA — DOCTRINE v1.6 + IMPLEMENTATION v1.6 + S0-S11 | `docs/simulation-mode/DOCTRINE.md`, `docs/simulation-mode/IMPLEMENTATION.md`, `docs/simulation-mode/character-dna/*.md` |
| **vigorous-goldberg-3a2d35** | `claude/vigorous-goldberg-3a2d35` | Quick Capture phases 0-12.5 (50+ commits) | `docs/QUICK_CAPTURE_IMPLEMENTATION_PLAN.md` + `/Users/jojo/Documents/Epistemos-QuickCapture/` (separate canon) |
| **quirky-pascal-135a98** (THIS) | `claude/quirky-pascal-135a98` | Current Claude session — fusion canon work | `docs/fusion/` (mirror of main's fusion folder) |

---

## 21. External Research Roots Quick Reference

| Folder | Verdict | Entry point | Top docs (load-bearing) |
|---|---|---|---|
| `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive/` (88 files) | High-value research depth | scope_rex / acs_meta_layer / resonance_gate | EPISTEMOS_NO_COMPROMISE_ARCHITECTURE, EPISTEMOS_RESEARCH_LANDSLIDE, epistemos_resonance_gate, EPISTEMOS_MASTER_ARCHITECTURE, scope_rex_final_architecture, acs_meta_layer, ternary_spectral_architecture, ternary_code_scaffolds, osft_psoft_coso_fusion, EPISTEMOS_ANE_GLASS_BALL_ASSESSMENT, EPISTEMOS_UNIFIED_MEMORY_CONTROL_ROOM, uasa_memory_breakthrough |
| `/Users/jojo/Downloads/ambient/` (6 core files) | **High-value canon donor** | EPISTEMOS_V1_DECISION.md (performance budget) | claude ambient.md (THE implementation bible, 63 KB), gemini ambient.txt, HaloController.swift, epistemos_shadow.rs, deep-research-report (2).md |
| `/Users/jojo/Downloads/final/` (14 docs) | Partial value (manifestos + early planning) | EPISTEMOS_HERMES_MANIFESTO.md (paradigm) | Episdemo Master Architecture Brief, Building Epistemos x Hermes Hackathon.txt, executive sumaries/epistemos-rival-doctrine.md |
| `/Users/jojo/Downloads/final v2/` (6 docs) | Partial value; superseded by v3 | (defer to v3) | App Moats AI Integration Master Plan.txt, Epistemos Hackathon Deep Research Plan.txt |
| `/Users/jojo/Downloads/final v3/` (7 docs) | **High-value MASTER REFERENCE** | EPISTEMOS_MOAT_AND_OPTIMIZATION_MASTER.md (shipped moats) | Epistemos AI Cognitive Partner Analysis.txt, deep-research-report (4).md (latest audit) |
| `/Users/jojo/Downloads/Advice/` (5 docs) | Cross-cutting validation | claude advice.md (architecture layers) | Gpt paper.md, Perplexity paper.md, claudy research.md |
| `/Users/jojo/Downloads/Pasted markdown.md` | High-value canvas (honest gaps) | Part 1 (C1-C4 critical, P1-P7 partial) | C1: editor → debounce → encode → Rust HNSW → sidebar UI is THE missing connector |
| `/Users/jojo/Documents/Epistemos-QuickCapture/` (10 files) | **Standalone canon for Quick Capture** | FINAL_SYNTHESIS.md (wins conflicts) | PLAN.md (244 KB Waves 0-5), OBSCURA_BROWSER_ADDENDUM.md (62 KB Wave 6), LIVE_FILES_AND_SUBSTRATE_ADDENDUM.md (67 KB Waves 7-8), BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md (44 KB Waves 9-11) |

---

## 22. How to Use This Index (operating rule)

When Codex hits a concept or term:

1. **Ctrl-F this doc first.** Concepts are organized by domain (§2 substrate / §3 killer features / §4 Quick Capture / §5 Halo / §6 Hermes / §7 editor / §8 streaming / etc.).
2. **Read the canonical source** named for that concept. Don't read everything — read what's named "Canonical."
3. **Cross-reference** only when canonical doesn't answer. Each entry lists "Donor research" / "External research" pointers.
4. **Trust the Honest Discoveries (§0)** over older docs they correct.
5. **Verify against current code.** Authority order §1: code wins over docs. If a doc claims X is shipped and grep says no, doc is wrong (see H7, H8).
6. **For per-worktree material**, use §20 quick reference. For external research, use §21.
7. **Don't read everything.** The user explicitly said "should be accurate" not exhaustive. Time-box to what the slice needs.

If you hit a concept this index doesn't list: surface it in `docs/fusion/oversight/CODEX_DELIBERATION_RESPONSE_2026_05_02.md` so the index can be extended in the next merge pass.

### 22.1 Research-first validation protocol

The user's research corpus is presumed high-signal and architecturally
intentional. This is not a "big design only" ritual. For every concept, task,
deliberation, build card, refactor, reroute/reduction, bug fix, dependency
choice, deletion, simplification, or "simple" code change:

1. Search local canon first: this master index, then the canonical source it
   names, then `rg` over `docs/`, `docs/_consolidated/`,
   `docs/fusion/`, relevant worktree docs, and external research roots only
   when the index points there.
2. Use semantic expansion, not only literal terms. Example: "zero-copy" also
   means Apple Silicon UMA, `MTLBuffer.storageModeShared`, IOSurface,
   in-process, single-binary, no hot-path subprocess, no tensor copies,
   deterministic/provenance-linked state transitions, direct/bare-metal path,
   and "as complex as a brain, as simple as an app, as fast as a jet."
   Treat these as philosophy terms as much as implementation terms: they point
   to the shortest safe path from intent to execution, not merely a memory API.
3. If local docs give a structured approach, follow it unless current code/logs
   disprove it.
4. If local docs do not answer, or if a coding task depends on current API,
   package, OS, model, security, App Store, or framework behavior, do a targeted
   web validation pass using primary/official sources where possible. The web
   pass validates or updates the local plan; it does not replace the local
   canon.
5. Match depth to risk: simple edits get a quick local pass, while
   architecture, security, performance, agent-routing, substrate, or release
   work gets deeper local retrieval before coding.
6. Delegated Claude/Kimi/Codex handoffs must include the relevant local canon
   paths, semantic search terms, and any unresolved external-validation need.
   Do not hand an agent a generic task if the user's research already gives the
   map.
7. Keep it useful: search smartly, quote only the load-bearing claim or path,
   and stop reading once the slice has enough evidence to act safely.
