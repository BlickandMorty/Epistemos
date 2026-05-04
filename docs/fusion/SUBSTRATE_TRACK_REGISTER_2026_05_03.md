# Epistemos Substrate Track Register — 2026-05-03

> **Canonical feature register.** Every feature track in the Substrate is
> listed here exactly once with status, tier, hackathon priority, and a
> pointer to its canonical master-index section. **Vocabulary discipline:**
> "the Substrate" = the project as a whole; "Track" (T0–T15) = a feature
> area; "Lane A/B" = git branches (existing master-index convention,
> unchanged); "Phase" = a sub-step within a Track.

---

## 0. The 16 tracks at a glance

```
┌───────────────────────────────────────────────────────────────────────┐
│ ZONE A — SUBSTRATE FOUNDATION (the scaffolding)                       │
│   T0  Substrate Unification (Kernel + DAG + XPC Mastery)              │
│   T1  Foundation Substrate (TypedArtifact, MutationEnvelope, etc.)    │
│   T2  Provenance + Sovereign Gate                                     │
│   T3  Privacy / Hardening / Subprocess Audit                          │
├───────────────────────────────────────────────────────────────────────┤
│ ZONE B — KILLER FEATURES (the differentiation)                        │
│   T4  Resonance Gate (K3 ternary truth)                               │
│   T5  Hermes Agent + Multi-CLI                  [HACKATHON BLOCK A]   │
│   T6  Simulation Mode v1.6 + Companion Farm     [HACKATHON BLOCK B]   │
├───────────────────────────────────────────────────────────────────────┤
│ ZONE C — SURFACE (what users touch)                                   │
│   T7  Local Model / MLX-Swift / Mamba-2 SSM                           │
│   T8  Halo / Contextual Shadows / RRF Fusion / Vault Index            │
│   T9  Code Editor / Tiptap / KaTeX / LSP                              │
│   T10 Graph Engine / Spatial / Cluster / Search                       │
│   T11 UX / Landing Wave / Approval Modal / Visual Chain               │
├───────────────────────────────────────────────────────────────────────┤
│ ZONE D — DEPLOYMENT + RESEARCH (the future)                           │
│   T12 App Store Release / Phase R / Phase S                           │
│   T13 Multi-Agent / ACS Ecosystem (Codex + Claude + Kimi + Gemini)    │
│   T14 Ternary / Research Tier (Sherry, KV-Direct, WBO-6)              │
│   T15 ANE Direct Path / KV Implantation                               │
└───────────────────────────────────────────────────────────────────────┘
```

**Substrate-total roll-up (rough %): ~30%.** Foundation tracks (T1, T7-T10) are
mostly done. Differentiation tracks (T4-T6) are 0-80% with the hackathon
unlocking T5+T6 to demo-able. T0 Substrate Unification has doctrine written
but implementation paused for hackathon.

---

## 1. Zone A — Substrate Foundation

### T0 — Substrate Unification (Cognitive Kernel + DAG + XPC Mastery + Schema-First GenUI)

| | |
|---|---|
| **Status** | ~5% (doctrine written across 6 docs; partial implementation only via existing Artifact + ArtifactBlockView; full dispatchers not started) |
| **Tier** | All (foundation everything else rides on) |
| **Hackathon** | Paused; resume after hackathon ships. Hermes Expert Mode (slices 1-8 / 2026-05-03) ships per-command renderers under explicit `GENUI-DEFER` per `COGNITIVE_GENUI_DOCTRINE` §6 — they migrate to dispatcher when G.3 lands. |
| **Master index ref** | §23 Substrate Unification Doctrine |
| **Four sub-tracks** | (1) Cognitive Kernel = Phases 1-7. (2) Cognitive DAG = Phase 8.A–H. (3) XPC Mastery = Phases X.1–X.5 (woven into Phases 1-7). (4) **Schema-First GenUI** = Phases G.1–G.6 (unifies render layer; previously got lost — now explicit) |
| **Canonical docs** | `COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md`, `COGNITIVE_DAG_DOCTRINE_2026_05_03.md`, `XPC_MASTERY_DOCTRINE_2026_05_03.md`, `XPC_RESEARCH_INTAKE_2026_05_04.md`, `COGNITIVE_GENUI_DOCTRINE_2026_05_03.md`, `PROCESSES_AND_RUNTIMES_AUDIT_2026_05_03.md`, `CODEX_DAG_RADAR_HANDOFF_2026_05_03.md` |
| **Why it matters** | Three compositions in sequence: kernel collapses 5 fragmented loops → 1 Rust kernel; DAG collapses 7 subsystems → 1 typed schema; GenUI dispatcher collapses N per-command renderers → 1 schema-first registry; XPC Mastery is the process-boundary discipline that makes all of them ship to MAS as defense-in-depth, not as "just compiles" |

### T1 — Foundation Substrate

| | |
|---|---|
| **Status** | ~done (TypedArtifact, MutationEnvelope, RunEventLog, AgentEvent, GraphEvent landed; Halo / Graph / Theater / Audit projections wired) |
| **Tier** | All |
| **Hackathon** | Foundation — never paused |
| **Master index ref** | §2 Substrate Spine + Architectural Invariants |
| **Canonical docs** | `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §2.2, `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` |
| **Code anchors** | `Epistemos/Models/MutationEnvelope.swift` (line 88 `Sensitivity`, line 293 field), `agent_core/src/mutations/envelope.rs`, `EpistemosTests/MutationEnvelopeParityTests.swift`, `Epistemos/Engine/TextCapturePipeline.swift` |
| **Architectural invariants** | (1) Zero-copy UMA, (2) single-binary in-process, (3) Markov blanket via Rust ownership, (4) tiered determinism, (5) C5 visuals project never invent |

### T2 — Provenance + Sovereign Gate

| | |
|---|---|
| **Status** | ~70% (PR1-PR44 AgentEvent instrumentation closed; Sovereign Gate single-LAContext owner verified; MutationEnvelope sensitivity field shipped; Provenance Console UI is the remaining MAS feature trio gap) |
| **Tier** | All (Sovereign Gate biometrics in Core; Provenance Console is Core surface) |
| **Hackathon** | Provenance Console is hackathon-blocking (closes MAS feature trio) |
| **Master index ref** | §3.2 Sovereign Gate, §13 Privacy / Telemetry / Security |
| **Canonical docs** | `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §4.2 + Annex A.7, donor `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive/EPISTEMOS_RESEARCH_LANDSLIDE.md` Part I §1.1 |
| **Code anchors** | `Epistemos/Sovereign/SovereignGate.swift` (single LAContext owner), `agent_core/src/sovereign/mod.rs`, `agent_core/src/effect/receipt.rs:44-54` (`Capability::BiometricSession { ttl_secs }`), `agent_core/src/events/` (`AgentEvent` canonical enum) |
| **Action-class matrix** | Trivial / Reversible / Sensitive (15-min grace) / Destructive (every time + passcode) / Sovereign (every time + Secure Enclave seal) |

### T3 — Privacy / Hardening / Subprocess Audit

| | |
|---|---|
| **Status** | ~done (subprocess hardening with 24-vector denylist, `harden_cli_subprocess` helpers across 10 spawn sites, no UserDefaults secrets, Keychain for API keys) |
| **Tier** | All |
| **Hackathon** | Foundation — never paused |
| **Master index ref** | §13 Privacy / Telemetry / Security |
| **Canonical docs** | `CLAUDE.md` Subprocess Hardening section, `docs/fusion/PROCESSES_AND_RUNTIMES_AUDIT_2026_05_03.md` |
| **Code anchors** | `agent_core/src/security.rs` (`harden_cli_subprocess`, `harden_cli_subprocess_extending`, `harden_cli_subprocess_std`), 10 spawn sites in agent_core listed in audit doc §2.3 |
| **Tests** | 4 in security.rs covering LD_PRELOAD + DEBUG don't leak through; PATH preservation; allowlist/denylist disjoint invariant; doctrine-named-vector presence |

---

## 2. Zone B — Killer Features

### T4 — Resonance Gate (K3 ternary truth)

| | |
|---|---|
| **Status** | ~80% (jumped from 0% this session: Rust seed + Swift mirror + UI shell + FFI bridge committed `06230e8d`, `e03fb890`, `07e33fed`; mounting into production surface deferred to post-hackathon M1) |
| **Tier** | Core |
| **Hackathon** | Mount into chat or Halo surface = post-hackathon M1; current state acceptable for hackathon demo |
| **Master index ref** | §3.1 Resonance Gate (Σ signature) |
| **Canonical docs** | `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §4.1, donor `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive/epistemos_resonance_gate.md` |
| **Code anchors** | `agent_core/src/resonance/{mod,tau,pi,lambda}.rs` (committed `06230e8d` + `07e33fed`), `Epistemos/Engine/ResonanceService.swift`, `Epistemos/Views/Resonance/{ResonanceChip,ResonanceLegendView}.swift`, `agent_core/tests/resonance_seed.rs` (30 tests green) |
| **7-field Σ** | `Σ(x) = [τ truth, δ direction, π prime/composite/gap, ρ resonance, κ KAM, η evidence, λ residency]` — target <100µs/token |
| **9 claim types** | Equation, Inequality, Causal, Definition, Empirical, CodeInvariant, Prime, Composite, Gap |

### T5 — Hermes Agent + Multi-CLI Integration

| | |
|---|---|
| **Status** | UI shell ~80% (Hermes Expert Mode landing surface complete with sigil + hero typewriter + terminal + palette + Sovereign Gate routing + provenance + 7 commands routing through Artifact pipeline). RUNTIME ~5% — the actual Hermes agent (canonical `agent_core::hermes` Rust kernel module per `COGNITIVE_KERNEL_DOCTRINE` Phase 2) doesn't exist yet; UI calls into a stub that hands `/ask` to MainChatSubmissionRouter. ~30 commands echo inline behind `GENUI-DEFER` markers. |
| **Tier** | Core (parser + dispatcher + UI) + Pro (CLI passthrough — feature-gated, deferred per MAS-First Focus Doctrine) |
| **Hackathon** | ABANDONED 2026-05-03; recovery sequence per `CANONICAL_RECOVERY_PLAN_2026_05_03.md`: Stage A.4 (GenUI G.3 migration of Expert Mode renderers) + Stage B.1 (Hermes-in-Rust runtime) close the gap structurally |
| **Master index ref** | §6 Hermes / Pro Tunnels / MCP |
| **Canonical docs** | `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` Annex A.12 (NousResearch ChatML reference; applies to FUTURE Pro Hermes subprocess work, NOT current code per H2) |
| **Code anchors** | `Epistemos/LocalAgent/HermesCommandDispatcher.swift` (master 36-variant `HermesParsedCommand` sum + `parseCore` router), `Epistemos/LocalAgent/Hermes{Calc,Help,Status,Tokens,Cost,Think,SessionOps,Parameter,Persona,ConfigToggle,Notebook,UIDisplay,VaultFile}Command(s).swift` (13 parser files) |
| **Acceptance bar** | `/help core` → Core slate; `/calc 2*pi` → 6.28...; `/ask <q>` → cloud via Hermes through ProviderXPC with provenance row; `/run <cmd>` (Pro) → CLI passthrough with AgentEvent; switch provider in Settings → next `/ask` uses new provider |
| **Hermes-in-Rust target** | Eventually port to `agent_core::hermes` (kernel doctrine Phase 2) — 5 sub-modules: prompt_format, function_call, skills, procedural_memory, self_evolution |

### T6 — Simulation Mode v1.6 + Companion Farm

| | |
|---|---|
| **Status** | UI shell ~50%: Companion Farm visible on landing as default home surface; CompanionState + CompanionModel SwiftData spine wired; CompanionView with TimelineView breathing; 4-step Creation wizard; Delete + Restore + Adapter sheets with canonical Sovereign Gate routing; NotesSidebarSkin component built (not yet wired into Notes panel); 7 of 15 invariants implemented (I-1, I-5, I-6, I-10, I-11, I-12, I-13, I-14). ASSETS ~0%: companions render as SF Symbols (`figure.stand.dress`, `circle.fill`, etc.) — DOCTRINE specifies custom-drawn body grammars. ADAPTER LoRA SWAP ~0%: pure cosmetic gift-box animation; no actual MLX-Swift LoRA hot-swap (depends on `COGNITIVE_DAG_DOCTRINE` §B.1 research spike). |
| **Tier** | Core |
| **Hackathon** | ABANDONED 2026-05-03; recovery sequence per `CANONICAL_RECOVERY_PLAN_2026_05_03.md`: Stage E (`SIMULATION_ASSETS_DOCTRINE` + custom-drawn body renderers) + Stage D.3 (LoRA-light companions research spike) close the gap structurally |
| **Master index ref** | §11 Simulation / Theater (Pro Design DNA — FROZEN) |
| **Canonical docs** | `simulation` worktree DOCTRINE.md + IMPLEMENTATION.md, donor `/Users/jojo/Documents/Epistemos-QuickCapture/BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md` |
| **Three placements** | Landing Farm (DEFAULT APP VIEW) / Graph Live Theater / Notes Sidebar Skin |
| **Body grammar** | Block / Sage / Orb + Hermes Snake; adapter gift-box per I-11 |
| **2026-05-04 specificity lock** | User intent is actual Tamagotchi-style companion creatures, not SF Symbols, generic orbs, or static cards. Landing gets deterministic idle walking/roaming inside the farm; Graph gets companion-presence projection later from the same registry. Search `tamagotchi`, `avatar`, `creature`, `walk`, `roam`, `wander`, and `CompanionView` before every T6 slice. |
| **Acceptance bar** | App opens → Landing Farm visible by default with companions idle-breathing; Settings → Companions → Create New Companion → 4-step wizard → companion appears in Farm; long-press companion → Delete sheet → Touch ID via canonical Sovereign Gate → fade animation → AgentEvent; trash/archive → restore within window with same Sovereign Gate; LoRA adapter → unwrap animation duration ≥ apply duration; Notes Sidebar shows companion presence reacting to AgentEvent stream; reduce-motion → static pose + state badge; pixel-identical replay given same event log + seed |
| **15 invariants** | I-1 through I-15 in DOCTRINE.md (single base substrate, cosmetic_idle TimelineView, deterministic PRNG keyed by `(session_id, agent_id, event_id)`, accessibility reduce-motion fallback, ModelProfile mapping, etc.) |

---

## 3. Zone C — Surface (what users touch)

### T7 — Local Model / MLX-Swift / Mamba-2 SSM

| | |
|---|---|
| **Status** | ~done (MLX-Swift in-process; 4-bit Qwen base; idle unload optimization; Mamba-2 cache save/load/resume/staleness; local mlx-swift-lm fork solves cache access) |
| **Tier** | Core (in-process per CLAUDE.md NO SIDECAR) |
| **Hackathon** | Foundation — never paused |
| **Master index ref** | §9 Local Model / MLX Inference |
| **Code anchors** | `Epistemos/Engine/MLXInferenceService.swift`, `Epistemos/Engine/MetalRuntimeManager.swift` (deepUnload with 14-pipeline cache), 4 Mamba-2 Metal kernels at `Epistemos/Shaders/Mamba2/` |
| **Memory budget** | 16GB Mac: ~10-11GB realistic for weights+KV; 4-bit 7-8B is the sweet spot |
| **Idle unload** | 16GB: 6→4s, 24GB: 10→6s, 36GB: 20→10s, larger: 30→15s |

### T8 — Halo / Contextual Shadows / RRF Fusion / Vault Index

| | |
|---|---|
| **Status** | ~done (W8.4 + W8.7 shipped: BM25 + HNSW shadow index, RRF cross-index fusion at k=60, Spotlight indexing, ReadableBlocks index with vault_id column, fusion query with 3 CTEs + UNION ALL + recency boost, Phase 6 observability UI) |
| **Tier** | Core |
| **Hackathon** | Foundation — never paused |
| **Master index ref** | §3.3 Freeform Pulse + Residency Rail, §5 Halo / Contextual Shadows / Recall |
| **Code anchors** | `Epistemos/Engine/HaloController.swift`, `Epistemos/Engine/ShadowSearchService.swift`, `Epistemos/Engine/{Stub,Rust}ShadowFFIClient.swift`, `Epistemos/Engine/ShadowVaultBootstrapper.swift`, `Epistemos/Sync/RRFFusionQuery.swift` (k=60 source: `epistemos-shadow/src/backend/rrf.rs:22 RRF_K_DEFAULT`), `EpistemosTests/RRFFusionQueryTests.swift` (7 tests), `EpistemosTests/SearchIndexServiceFusionTests.swift` (9 tests) |

### T9 — Code Editor / Tiptap / KaTeX / LSP

| | |
|---|---|
| **Status** | ~done with one MAS-blocker (Tiptap WKWebView editor + KaTeX preview + content-hash gated bundle build; `LSPServerProcess.swift:120` is a Pro-only subprocess that should migrate to in-process Rust LSP for Core) |
| **Tier** | Core (editor) + Pro (LSP today, target Core) |
| **Hackathon** | Foundation — never paused |
| **Master index ref** | §7 Code Editor / TextKit / syntax-core |
| **Code anchors** | `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift` (Tiptap shell), `js-editor/` (esbuild source, content-hash gated on package-lock.json), `Epistemos/Engine/EpdocPasteClassifier.swift`, `Epistemos/Engine/EpdocBlockTemplateStore.swift`, `Epistemos/Engine/LSPServerProcess.swift` (the one Swift Process() to migrate) |
| **MAS migration** | LSP subprocess → in-process Rust via `tower-lsp` / `lsp-server` + `tree-sitter` (kernel doctrine recommended Phase 4.5) |

### T10 — Graph Engine / Spatial / Cluster / Search

| | |
|---|---|
| **Status** | ~done (graph-engine Rust crate, GraphEngine.swift, semantic clustering parallelized via DispatchQueue.concurrentPerform with lock-free slot-fill, ~3-4× faster on 6P+4E M2 Pro) |
| **Tier** | Core |
| **Hackathon** | Foundation — never paused |
| **Master index ref** | §10 Graph Engine and Motion |
| **Code anchors** | `graph-engine/` Rust crate, `Epistemos/Graph/GraphEngine.swift`, `Epistemos/Graph/SemanticClusterService.swift` (lines 69-156 parallelized embeddings), `Epistemos/Graph/EntityExtractor.swift`, `Epistemos/Graph/OntologyClassifier.swift` |

### T11 — UX / Landing Wave / Approval Modal / Visual Chain

| | |
|---|---|
| **Status** | ~in progress (LandingWave Metal renderer + ASCII liquid-wave + compact flat search bar SF Mono 14pt/~520pt landed; ApprovalModalView migrated from Timer.publish to TimelineView(.periodic); 100+ doc visual audit chain canon respected) |
| **Tier** | Core |
| **Hackathon** | Foundation — never paused; LandingFarmView for T6 ships during hackathon |
| **Master index ref** | §17 UX Posture and Surfaces |
| **Code anchors** | `Epistemos/Views/Landing/Wave/{LandingWaveMetalView,LandingWaveRenderer,LandingWaveGlyphAtlas}.swift`, `Epistemos/Views/Approval/ApprovalModalView.swift`, donor canon at `docs/visual-audit/` (100+ docs across 12 tiers — MUST reference before visual changes per memory) |

---

## 4. Zone D — Deployment + Research

### T12 — App Store Release / Phase R / Phase S

| | |
|---|---|
| **Status** | ~in progress (Phase S has 9 sub-phases + 6 hard exit criteria; deployment profiles split AppStore vs Pro at PolicyProfile enum; CI tests both builds; Phase R hardens Resource Runtime with canonical IDs + verified-before-claim pipeline) |
| **Tier** | Core (App Store) + Pro (Developer ID) + Research (Developer ID + private framework) |
| **Hackathon** | Critical path — App Store Release is the hackathon ship target |
| **Master index ref** | §12 App Store Release / Phase R / Phase S |
| **Canonical docs** | `docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md` §1.6 + §1.7 + Appendix F + Phase S, `docs/APP_STORE_RELEASE_COMPLETION_STATUS_2026_04_24.md` |
| **Deployment profiles** | App Store = Bounded Intelligence OS (no shell, review-safe, keeps agent + tools + local + cloud models); Pro = Full Autonomy OS (shell, Docker, CLI reuse, iMessage, long-horizon) |

### T13 — Multi-Agent / ACS Ecosystem (Codex + Claude + Kimi + Gemini)

| | |
|---|---|
| **Status** | tooling phase (4-model advice council shipped 2026-04-22 consensus on Developer ID + schema-first GenUI + UniFFI primary; orchestrator session 2026-04-27 ran §1.5 origin-baseline + 4-agent corpus synthesis + 3 Blockers shipped) |
| **Tier** | Tooling (used during development; not user-facing) |
| **Hackathon** | Codex paused for hackathon prioritization (per `project_hackathon_focus_2026_05_03`) |
| **Master index ref** | §14 Multi-Agent / ACS Ecosystem |
| **Canonical docs** | `docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md`, `project_orchestrator_session_2026_04_27.md` |

### T14 — Ternary / Research Tier (Sherry, KV-Direct, WBO-6)

| | |
|---|---|
| **Status** | gated (WBO-6 inequality module exists at `agent_core/src/wbo6/` per audit; lattice + sketch modules also in tree; Sherry 1.25-bit ternary deferred; KV-Direct gate Week-0 experiment not yet run; ANE Direct Path is T15) |
| **Tier** | Research (behind `cfg(feature = "research")` flag) |
| **Hackathon** | Deferred — gated behind kernel doctrine landing first |
| **Master index ref** | §15 Ternary Substrate / Research Tier |
| **Canonical docs** | `docs/fusion/jordan's research/UNIVERSAL_PLASTICITY.md`, `docs/fusion/jordan's research/SELF_TUNING.md`, donor GPT/Kimi research |
| **Code anchors** | `agent_core/src/wbo6/` (verify canonical vs Kimi/GPT mockup), `agent_core/src/lattice/`, `agent_core/src/sketch/` (Phase 1 audit deliverable) |
| **Week-0 KV-Direct decision rule** | D_KL = 0 + token_match = 100% + peak_RAM ≥ 8× lower → PASS; FAIL → audit before any L1 work |

### T15 — ANE Direct Path / KV Implantation

| | |
|---|---|
| **Status** | gated (research only; no implementation; Apple Neural Engine direct access is private framework territory) |
| **Tier** | Research (Developer ID + private framework loading) |
| **Hackathon** | Deferred — outside MAS-eligible scope |
| **Master index ref** | §16 ANE Direct Path / KV Implantation (Research only) |

---

## 5. Cross-cutting concerns (not their own tracks)

These are concerns that touch multiple tracks. Captured here so they're not lost.

| Concern | Touches | Doctrine ref |
|---|---|---|
| **XPC Mastery** | T0, T2, T5, T12 | `XPC_MASTERY_DOCTRINE_2026_05_03.md` + `XPC_RESEARCH_INTAKE_2026_05_04.md` (5-service decomposition, no-compromise bundled trust spine, symmetric code-signing validation, per-service entitlements, capability-token IPC, sandbox-within-sandbox for WASM, audit trail across XPC, Secure Enclave attestation, MAS/Pro separation, process recycling, IOSurface zero-copy, DAG integration) |
| **Schema-First GenUI** | T0, T2, T4, T5, T6, T11 | `COGNITIVE_GENUI_DOCTRINE_2026_05_03.md` (typed `GenUIPayload` + `GenUISchema` + `GenUIDispatcher` registry; producers emit payloads, dispatcher routes by schema, renderers know nothing about producers; Phases G.1-G.6, 24-day cost ceiling, deferral-list discipline so it doesn't get lost) |
| **Capability Lattice** | T0, T2, T3, T5, T12 | `EPISTEMOS_RECONCEPTUALIZATION_2026_05_03.md` §3 — Core / Pro / Research / Both / All |
| **Cognitive DAG schema** | T0, T1, T2, T4, T5, T6 | `COGNITIVE_DAG_DOCTRINE_2026_05_03.md` — every subsystem becomes a traversal pattern |
| **Zero-copy UMA** | T1, T7, T8, T9, T10 | doctrine §2.2 invariant 1 |
| **Sovereign Gate single-owner** | T2, T5, T6, T12 | `Epistemos/Sovereign/SovereignGate.swift` — never duplicated |
| **AgentEvent provenance** | T1, T2, T4, T5, T6 | `agent_core::events::AgentEvent` — single canonical enum |

---

## 6. How to use this register

- **When user asks "where am I at"** → quote the Substrate-total roll-up (~30%) plus the Zone-level pulse
- **When user names a feature** → look it up here, find the Track number, point at the canonical master-index section
- **When you ship work** → update the Status row and the % on the affected Track; add a row to `CANON_GAPS_AND_ADDENDA_2026_05_02.md` if status diverges from doctrine
- **When you spawn a Codex prompt** → enumerate which Tracks it touches so the prompt is scope-bounded
- **When user proposes a new feature** → first ask "does this fit an existing Track or is it Track 16+?" — most "new features" actually fit T4-T11

---

## Appendix A — Cross-references

```
docs/fusion/SUBSTRATE_TRACK_REGISTER_2026_05_03.md      ← this doc (canonical feature register)
docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md         (authority order + per-feature canon paths)
docs/fusion/COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md     (T0 stage 1)
docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md        (T0 stage 2)
docs/fusion/XPC_MASTERY_DOCTRINE_2026_05_03.md          (T0 cross-cut + Zone D ship enabler)
docs/fusion/XPC_RESEARCH_INTAKE_2026_05_04.md           (required no-compromise sidecar for XPC / sandbox / ExtensionKit / biometrics)
docs/fusion/PROCESSES_AND_RUNTIMES_AUDIT_2026_05_03.md  (ground truth)
docs/fusion/EPISTEMOS_FUSION_HANDOFF_2026_05_03.md      (Kimi/GPT as reference framing)
docs/fusion/EPISTEMOS_RECONCEPTUALIZATION_2026_05_03.md (substrate framing + capability lattice)
docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md      (foundational doctrine)
CLAUDE.md                                                (NON-NEGOTIABLE constraints)
```
