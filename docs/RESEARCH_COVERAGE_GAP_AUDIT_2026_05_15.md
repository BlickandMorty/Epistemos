# Research Coverage Gap Audit — 2026-05-15
**Scope:** 4 parallel agents swept the entire research corpus (`docs/fusion/` 406 docs + `docs/` 197 docs + `/Users/jojo/Documents/Epistemos-QuickCapture/` standalone canon + `docs/fusion/jordan's research/GPT Research/` Helios crates) for concepts that ARE in the research but ARE NOT in the current canonical doc cocktail.
**Authority:** Sits at rank 5 of the authority chain, just below `HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md`. Each gap row is actionable.
**Net finding:** 31 genuine gaps. **6 are V1-affecting BLOCKERS**, 11 are post-V1 HIGH-priority, 9 are MEDIUM/architecture-relevant, 5 are LOW/operational. Most striking pattern: a **complete user-product Wave 7-11 layer** (Live Files → Confidence Meter → Tamagotchi modes → Cloud-as-Teacher → Brain Export) is scattered across two QC addenda with zero canonical citations.

---

> **PASS 2 follow-up (2026-05-15):** A deeper 6-agent sweep into `docs/_consolidated/` (531 files), `docs/audits/` (74), personal-research depth, `docs/fusion/salvage/` (138), long-tail plans, and older research packs produced **37 additional confirmed gaps** (5 NEW BLOCKERS — Specialties registry · ArtifactKind + ProvenanceBlock · vault import stall · Residency Governor rate-distortion · Hermes XPC decision). See [`docs/RESEARCH_COVERAGE_GAP_AUDIT_PASS2_2026_05_15.md`](RESEARCH_COVERAGE_GAP_AUDIT_PASS2_2026_05_15.md) — sibling doc, reads as an extension to this one. Combined total: 68 actionable items across the full corpus.

## 0. How to read this doc

Each row has 4 columns:
- **Concept** — the named primitive/feature/doctrine
- **Source** — exact doc + section/quote so you can verify it yourself
- **Severity** — BLOCKER (V1 ship affected) / HIGH (post-V1 important) / MEDIUM / LOW
- **Destination** — where it should live (existing doc / new backlog row / "research-tier defer")

**Verification protocol used by the agents:** every reported gap was confirmed via grep against the 6 canonical doc cocktail. If a concept appears anywhere in the canon, it was NOT reported as a gap regardless of how shallow the citation was.

---

## 1. BLOCKER — V1 MAS-shippable surface affected

These 6 items affect what users see in V1 MAS submission OR represent direct security/UX risk. **All 6 should be triaged before V1 submission** — most can be resolved by an explicit "in scope" or "deferred to V1.x" decision rather than implementation.

### B-1. Live Files (Wave 7 substrate primitive)
- **Source:** `/Users/jojo/Documents/Epistemos-QuickCapture/LIVE_FILES_AND_SUBSTRATE_ADDENDUM.md` §4, §6
- **What it is:** Unified Swift + Rust + Metal substrate primitive — every file is a live, deliberation-enabled artifact (state machine + agent-driven mutation + daily-review embedding). The addendum positions Live Files as Wave 7 — **prerequisite to Tamagotchi/Brain-Export Waves**.
- **Why it matters for V1:** The MAS plan + Hermes 2.0 + no-compromise docs never name Live Files as a feature, even though `LIVE_FILE_COMPILER_DOCTRINE_2026_05_04.md` is cited in the doctrine corpus and `Wave 7.10` (KaTeXSnippets / W7.7 Tiptap snippet bridge) is referenced in the audit register.
- **Destination:** Add §3.x row to `MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` Atlas. Decide: V1 surface (e.g. daily-review embedding visible) vs deferred-to-V1.x. The `LIVE_FILE_COMPILER_DOCTRINE` already names B.9 NightBrain integration.
- **Status (2026-05-16):** ✅ DECISION RECORDED — **V1.1 defer (recommended)**. Substrate doctrine LANDED in `MASTER_FUSION §3.14`; user-visible feature surface <30% complete. Full decision rationale + 2 user-override alternatives in `MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md` §10 Compromises Recorded. **User input requested**: confirm V1.1 defer OR override to V1 demo / Pro-only.

### B-2. Brain Export (Wave 11 — the YC pitch / Sovereign-AI moat)
- **Source:** `~/Documents/Epistemos-QuickCapture/BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md` §5 + §6.3
- **What it is:** Portable Brain Artifact export = companion + memory + procedural skills + identity. The "stay in the app" lock-in / productization layer. **Zero canonical mentions.**
- **Why it matters for V1:** The MAS app SHIPS the substrate that produces a Brain (Soul/Skill/Episode/Semantic schemas LANDED at `agent_core/schemas/` + Rust mirror at `agent_core/src/schemas/mod.rs` 687 lines, commit `33e1a5dcb`). With no export surface, schema, or distribution doctrine, V1 ships a half-feature.
- **Destination:** `HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md` §7.3 (new MAS-allowed tool: `brain.export`). Or explicitly defer to V1.1 with that decision documented in the Compromises Recorded table.
- **Status (2026-05-16):** ✅ DECISION RECORDED — **V1.1 defer (recommended), no V1 placeholder**. Substrate schemas LANDED (commit `33e1a5dcb`, 687 LOC) but `brain.export` tool + portable format spec + distribution doctrine all missing. Full decision rationale + 2 user-override alternatives in `MAS_COMPLETE_FUSION` §10 Compromises Recorded. **User input requested**: confirm V1.1 defer OR override to V1 minimal-JSON-export.

### B-3. Confidence Meter + 70%-Triggered Re-Learn
- **Source:** `~/Documents/Epistemos-QuickCapture/BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md` §2
- **What it is:** First-class biometric-gated re-learn trigger when confidence drops below 70%. The user-facing **honesty surface** for MAS — distinct from `SovereignGate` (action-class biometric).
- **Why it matters for V1:** MAS reviewers will look for "how does the user know the AI is being honest about uncertainty?" Without the Confidence Meter, the answer is "they don't, except via cited sources in chat."
- **Destination:** Add to `MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md` §B (new B.10 row) OR `HERMES_AGENT_CORE_2_0_DESIGN` §13.5.5 (new acceptance test #8 covering 70%-threshold re-learn).
- **Status (2026-05-16):** ✅ DECISION RECORDED — **V1 ship SIMPLE form (recommended)**, V1.1 ship FULL form. V1 = `ConfidenceBadge` on LLMResponse render path using existing token-logprob / `agent_core::routing` confidence signal (no biometric, no `LocalAuthentication.framework`). V1.1 = biometric gating + auto-re-learn loop + SovereignGate integration. Full decision rationale + 2 user-override alternatives in `MAS_COMPLETE_FUSION` §10 Compromises Recorded. **User input requested**: confirm V1 simple-form OR override to V1.1-defer-entire / V1-full-with-biometric.

### B-4. Pixel Mode vs Tactical Mode duality
- **Source:** `~/Documents/Epistemos-QuickCapture/BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md` §3.1
- **What it is:** UX-shape duality — agent presents as either Pixel (Tamagotchi sprite) or Tactical (terminal-grid). Sub-agent dispatch with capability inheritance (§3.3) + accessory system (§3.6).
- **Why it matters for V1:** Canon names the Tamagotchi *sprite atlas* (G3 / Simulation v1.6 — LANDED) but the **Pixel↔Tactical toggle** is the actual UX shape. Without it, the sprite atlas is unused product surface.
- **Destination:** `HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md` §UI (new section). Either ship Pixel mode in V1 (Tactical post-V1) or explicit V1.1 deferral.
- **Status (2026-05-16):** ✅ DECISION RECORDED — **V1.1 defer (recommended), V1 keeps sprite-as-accent only**. Sprite atlas LANDED (G3/Sim v1.6); user-facing Mode toggle UX + sub-agent dispatch with capability inheritance + accessory system are all V1.1. Full decision rationale + 2 user-override alternatives in `MAS_COMPLETE_FUSION` §10 Compromises Recorded. **User input requested**: confirm V1.1 defer OR override to V1 hidden-toggle / Pixel-only-V1.

### B-5. BrowserEngine trait + deno_core MAS/Pro split (V1 architecture decision)
- **Source:** `~/Documents/Epistemos-QuickCapture/OBSCURA_BROWSER_ADDENDUM.md` §1.2 + `FINAL_SYNTHESIS.md` §0 row 6
- **What it is:** `BrowserEngine` trait abstracts the web-fetching path. MAS gets WebKit/native-capture-only adapter (no arbitrary JS runtime); Pro gets capability-gated `deno_core` ops. **Cocktail mentions neither.**
- **Why it matters for V1:** If MAS ships any web-fetching tool path beyond `WKWebView` (e.g., `web.search`, `web.extract`, `web.crawl`, `web.fetch` — all currently in the 30-tool MAS allowlist), the architecture is undefined. Could trigger App Review issue if reviewers ask "how does this work in the sandbox?"
- **Destination:** **MUST resolve before V1 submission.** Add explicit decision row to `MAS_COMPLETE_FUSION` §0 (immutable rules) declaring "MAS web tools use `WKWebView`-backed `BrowserEngine` adapter only; deno_core / Obscura geometry preserved but explicitly Pro-only."
- **Status (2026-05-16):** ✅ RESOLVED. Decision landed as immutable rule 6 in `MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md` §0. Current-code reconciliation: MAS web tools are HTTP-only (`agent_core/src/tools/web.rs` + `web_fetch.rs` via `reqwest`), `WKWebView` usage is confined to Epdoc + KaTeX (not agent tools), and `deno_core` / Obscura are absent from main (per `B3_OBSCURA_BROWSER_LIFT_TARGETS_2026_05_05.md` Pro-only routing). Rule wording made HTTP-fetch primary and `WKWebView` future-secondary so it matches reality rather than implying current code uses `WKWebView` for agent web tools.

### B-6. Hermes-parity salvage: error classifier + Keychain credential rotation + session-persistence schema
- **Source:** `docs/fusion/WORKTREE_INSIGHT_SALVAGE_2026_05_02.md` §2 insights #2.2-#2.4
- **What it is:** 3 load-bearing items from the `hermes-parity` worktree:
  - `agent_core/src/credential_pool.rs` — explicit "Risk: no Keychain integration" flag
  - `agent_core/src/error_classifier.rs` — 100+ pattern classifier; per `MASTER_RESEARCH_INDEX` H4 it IS wired into `agent_loop.rs:10`, but unverified live
  - `agent_core/src/session_persistence.rs` — schema unverified
- **Why it matters for V1:** If Pro/MAS ships without verified Keychain wiring for credential pool, secrets could land in `Vec<String>` in memory. Direct security risk. Error classifier unwired = bad UX on agent failures.
- **Destination:** Phase A.0 (new) "Hermes-parity salvage verification" — explicit `cargo test` + caller-chain grep for all 3 modules. Wire findings to audit register if anything's actually broken.
- **Status (2026-05-16):** ✅ VERIFIED — **NOT A V1 BLOCKER**. Caller-chain grep + `lib.rs` reading shows:
  - `credential_pool.rs` (264 LOC, Apr 23): **DEAD FILE** — not declared in `agent_core/src/lib.rs`, so not compiled into the crate. `rg "use crate::credential_pool|CredentialPool"` returns only self-references inside the file. Zero Keychain code. The audited risk ("secrets land in `Vec<String>` in memory") cannot materialize because the module isn't part of the build.
  - `error_classifier.rs` (375 LOC, May 15): **ORPHAN** — declared `pub mod error_classifier;` at `lib.rs:21` so it compiles, and 7 unit tests pass (`cargo test --lib error_classifier` → 7 passed), but `rg "use crate::error_classifier|error_classifier::|ErrorClassifier"` across `agent_core/src/` returns zero production call-sites. The audit's claim "per `MASTER_RESEARCH_INDEX` H4 it IS wired into `agent_loop.rs:10`" is FALSE in current main.
  - `session_persistence.rs` (508 LOC, Apr 23): **DEAD FILE** — not declared in `lib.rs`, not compiled. `rg "SessionPersistence::|session_persistence::|use crate::session_persistence"` returns only self-references inside the file's own test block.
  - Audit register row created at `docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md` Dead-Code Orphan Inventory (this commit, B-6 follow-up — see ORPHAN-HERMES-SALVAGE-001) surfaces the next decision: **wire** these modules into real code paths (matches the original `hermes-parity` salvage intent), **formally mark as scaffolding** with a drift gate (matches the existing inventory's V1 policy of "do not delete before v1.0 ships"), or **delete** the dead files. None of the three options is V1-blocking. Decision deferred to a separate slice — this verification surfaces the finding without locking in a disposition.

---

## 2. HIGH — post-V1 important / ship-polish / queued user-reported

### H-1. ISSUE-2026-05-12-011 Main thread hangs at startup (969 ms + 3182 ms)
- **Source:** `docs/APP_ISSUES_AUTO_FIX.md:180-227`. Status: Open, P2. Needs Instruments Time Profiler.
- **Why HIGH:** 3-second hang after `app_became_active` is user-visible. V1 polish floor.
- **Destination:** `MAS_COMPLETE_FUSION` §A (new A.0.1 row) or audit register.
- **Status (2026-05-16):** ✅ SURFACED — **operator action required**. Phase A.7 row added to `MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md` with full Instruments Time Profiler reproduction recipe + 4 ranked hypotheses + likely fixes per hypothesis + acceptance bar (≤500ms main-thread occupancy matching `RuntimeDiagnosticsMonitor` watchdog). APP_ISSUES status flipped from `Open` to `Operator-required (Instruments trace pending)`. Claude cannot drive Instruments autonomously; falling through to next autonomous slice.

### H-2. ISSUE-2026-04-21-004 Idle memory regression (~500 MB)
- **Source:** `docs/APP_ISSUES_AUTO_FIX.md:2419-2475`. Status: Investigating since April; no root-cause.
- **Why HIGH:** Pre-existing P0/P1 regression still unresolved.
- **Destination:** Phase A.0.2 row — Instruments Allocations profile required.
- **Status (2026-05-16):** ✅ SURFACED — **operator action required**. Phase A.8 row added to `MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md` with full Instruments Allocations reproduction recipe + 6 ranked hypotheses (AppleHybridEmbeddingLookup eager-load · PreparedRetrievalRuntimeConfiguration retained descriptors · SwiftData `@Query` caches · MLX tokenizer/model retention · ShmPool TTL eviction not firing · Tantivy writer heap regression) + likely fixes per hypothesis + acceptance bar (≤200 MB idle RSS, 4× improvement from current 500 MB). APP_ISSUES status flipped Investigating → Operator-required (Allocations trace pending). Claude cannot drive Instruments autonomously.

### H-3. Local Engineering Agent / Attach-Note-To-Chat (RCA13 P9)
- **Source:** `docs/audits/LOCAL_ENGINEERING_AGENT_DESIGN_2026_05_10.md`. Referenced 16× in audit register as P9 design ticket, ZERO references in `MAS_COMPLETE_FUSION` / `HERMES_AGENT_CORE_2_0_DESIGN`.
- **What it is:** "Attach note to chat → in-place edit with provenance" — MAS-shippable hero V1 capability per the design doc.
- **Destination:** `HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md` §7.1 (add `edit_note_block` / `EditPage` macaroon to MAS-allowed tools). OR `MAS_COMPLETE_FUSION` §B.10 new row.
- **Status (2026-05-16):** ✅ DECISION RECORDED — **V1.1 defer for full feature (recommended); V1 ships read-only attach-note stub.** Macaroon primitives EXIST at `agent_core/src/cognitive_dag/macaroons.rs` + `dispatch.rs`; missing tool layer + single-use semantic + ledger integration. Design doc itself still marked AWAITING_USER_SIGNOFF. Full decision + 2 user-override alternatives in `MAS_COMPLETE_FUSION` §10 Compromises Recorded (paired with PASS 2 B2-H6). **User input requested**: confirm V1.1 defer OR override to full V1 / Pro-only.

### H-4. Overseer hierarchy (Planner / Guardrail / Critique / Budget)
- **Source:** `docs/fusion/research/OVERSEER_AND_AGENT_HIERARCHY.md` + `docs/fusion/research/kimi-latest/hermes_gateway_architecture.md` §L6
- **What it is:** Overseer-as-role-decomposition doctrine (4 cooperating responsibilities) distinct from Overseer-as-feature.
- **Destination:** `HERMES_AGENT_CORE_2_0_DESIGN` §multi-overseer (new) — informs Pro post-V1 architecture.
- **Status (2026-05-16):** ✅ RESOLVED. Landed as new `HERMES_AGENT_CORE_2_0_DESIGN §13.7 "Multi-Overseer hierarchy — 4-role decomposition of policy enforcement"`. Section covers: explicit framing as role taxonomy within `GovernedExecutor` (§5) rather than separate Overseer-as-feature · 4-role table (Planner / Guardrail / Critique / Budget) with what-it-produces + what-it-consumes per role · single-turn cooperation pipeline showing role firing order (Planner → Budget → Guardrail pre-execution → tool runs → Critique post-execution) · NOT-replacement boundaries (not separate from SCOPE-Rex which is the mechanism, not separate from ProviderRouter which is the dispatch point, not a sub-agent hierarchy) · mapping table from each role to existing primitives (Planner ↔ MissionPacket+ProviderRouter; Guardrail ↔ SovereignGate+SCOPE-Rex+Capability Lease+ephemeral tokens B2-H20; Critique ↔ ClaimLedger+spectral detection §13.5.8+SAE §3.36; Budget ↔ pricing.rs+SpendDashboard §B2-H14) · explicit VSM cross-link (B2-H9 — Overseer-4 = VSM S3+S4+S5 instantiation in Hermes) · V1 scope (roles exist implicitly today, V1.x makes them typed `OverseerRole` enum). Closes the "Overseer-as-role-decomposition is missing from canon" framing without overriding §5 SCOPE-Rex.

### H-5. Adaptation Subsystem + Compute Steering specs
- **Source:** `docs/fusion/research/ADAPTATION_SUBSYSTEM_SPEC_v1.md` + `COMPUTE_STEERING_SPEC_v1.md`
- **What it is:** Schema-first policies for LoRA / OFTv2 / KV / expert-budget dispatch (`adapt_session_id`, `compute_budget`, `compute_profile`, canary validation, micro-TTT).
- **Destination:** `MASTER_FUSION` §3.x (new) — schema-first foundation for adapter features.

### H-6. GTM / Distribution / Pricing playbook
- **Source:** `docs/fusion/research/EPISTEMOS-RESEARCH-REFERENCE-v2.md` §1 + `landslide_dim09_monetization.md`
- **What it is:** Explicit pricing ladder (Free → $79/yr Pro → $9/mo → $199 Lifetime → $39/yr Education), Lemon Squeezy + Sparkle 2 + DMG distribution, Product Hunt / HN / r/macapps targets, Cursor/Linear/DevonThink/Obsidian comparator.
- **Destination:** New doc `docs/GTM_DISTRIBUTION_PRICING_PLAYBOOK_2026_05_15.md` (or addendum to MASTER_FUSION §scope).

### H-7. GRPO (Group-Relative Policy Optimization)
- **Source:** `docs/fusion/jordan's research/uasa.agent.final.md` §6.2.3 — MLX-Swift pseudocode for rule-based-reward GRPO on Apple Silicon.
- **What it is:** Local-RL training path; companion to OFTv2 QLoRA.
- **Destination:** `MASTER_FUSION` §continual-learning row (add GRPO alongside OFTv2 / DSC / coSO).

### H-8. MLA (Multi-Head Latent Attention) + TransMLA retrofit
- **Source:** `docs/fusion/jordan's research/uasa.agent.final.md` §3.3 — DeepSeek's low-rank KV compression with decoupled RoPE.
- **What it is:** Local-inference unlock alongside KIVI / MiniKV / TurboQuant.
- **Destination:** `MASTER_FUSION` §local-inference row.

### H-9. Run Ledger — cryptographic attestation per thought
- **Source:** `docs/fusion/jordan's research/uasa.agent.final.md` §1.3
- **What it is:** Per-token/per-thought cryptographic attestation lineage. Distinct from `ClaimLedger` (which tracks claims, not tokens) and `.epbundle` (provenance ledger snapshot).
- **Destination:** `MASTER_FUSION` §provenance row (add Run Ledger as token-level primitive separate from claim-level ClaimLedger).

### H-10. Auto-research loops (Karpathy pattern)
- **Source:** `~/Documents/Epistemos-QuickCapture/LIVE_FILES_AND_SUBSTRATE_ADDENDUM.md` §5
- **What it is:** Vault-applied auto-research with "wins applied / wins not applied / discoveries to investigate" daily-report shape.
- **Destination:** `HERMES_AGENT_CORE_2_0_DESIGN` §13.5 distillation (new test #8) OR NightBrain task body.

### H-11. Obscura (browser engine) + deno_core (Pro JS sandbox)
- **Source:** `~/Documents/Epistemos-QuickCapture/OBSCURA_BROWSER_ADDENDUM.md` §3-§6
- **What it is:** Library-embedded browser + in-process JS execution as the Pro-tier capability layer.
- **Destination:** Covered by B-5 above for the MAS decision; Pro-side post-V1.

---

## 3. MEDIUM — architecture-relevant

### M-1. Eidos search engine (Wave 6, neural search)
- **Source:** `OBSCURA_BROWSER_ADDENDUM.md` §6. Tantivy + bge embeddings + Metal cosine on 4096-vector centroids, <1ms; agent-native, Exa.ai analog for local-first.
- **Status in canon:** Eidos name-drops in `MASTER_FUSION` (5x) and `MAS_COMPLETE_FUSION` (1x) but the Tantivy+bge+Metal-cosine architecture is not specified.
- **Destination:** `MASTER_FUSION` §3.x — Eidos as named neural-search-engine (separate from Eidos-as-companion).

### M-2. Eidos Plus deliberation engine
- **Source:** `LIVE_FILES_AND_SUBSTRATE_ADDENDUM.md` §8
- **What it is:** Auto-research deliberation engine that runs the Karpathy loops (H-10).
- **Destination:** Same as H-10 — bundled together as the auto-research surface.

### M-3. Cloud-as-Teacher distillation lab
- **Source:** `BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md` §4
- **What it is:** Bidirectional flow — cloud teacher → local student with catastrophic-forgetting guards; eval-gated, user-visible.
- **Destination:** `HERMES_AGENT_CORE_2_0_DESIGN` §13.5 (distillation has a teacher slot; surface it as Cloud-as-Teacher with eval gating).

### M-4. Hopfield / attractor / hypervector memory
- **Source:** `docs/fusion/jordan's research/uasa.agent.final.md` §4 — "Three-Layer Memory Hierarchy"
- **What it is:** Modern Hopfield + Kuramoto oscillators + hyperdimensional computing as research-tier memory primitive distinct from KV/Mamba.
- **Destination:** `MASTER_FUSION` research-tier row.

### M-5. The Reflective Loop (7-layer cognitive cycle)
- **Source:** `~/Documents/Epistemos-QuickCapture/FINAL_SYNTHESIS.md` §2
- **What it is:** 7-layer substrate-wide cognitive cycle (Reflex / Attention / Executive / Immune / Motor / Memory / Metabolism). Distinct from "Hermes loop" or "agent loop".
- **Destination:** `HERMES_AGENT_CORE_2_0_DESIGN` §3 (layered architecture) — informs Wave 3 SCOPE-Rex governance design.

### M-6. ISSUE-2026-05-11-002 Graph selected-neighbor push-out physics
- **Source:** `docs/APP_ISSUES_AUTO_FIX.md:801-843`. Partially Fixed; selected-neighbor push-out physics open, deferred to "Phase B compute kernels".
- **Why MEDIUM:** P2 graph UX, user-reported. Graph is V1 product surface.
- **Destination:** `MAS_COMPLETE_FUSION` §C or canonical graph plan.

### M-7. ISSUE-2026-05-12-008 + ISSUE-2026-05-12-009 First-note-open hang + Sidebar/graph slow open
- **Source:** `docs/APP_ISSUES_AUTO_FIX.md:616-665, 668-716`. ProjectionCache module scaffolded; live wiring pending.
- **Destination:** Phase C wiring task or audit register.

### M-8. Executive UI / NASA Open MCT / SCADA ISA-101 / DSKY Verb-Noun
- **Source:** `docs/fusion/research/icloud-loose/landslide_dim10_executive_ui.md`
- **What it is:** Synthesis of NASA DSKY Verb-Noun grammar, Open MCT composable telemetry, ISA-101 HMI standards, Crew Dragon supervision UX, trust-calibration patterns — direct design principles for Provenance Console / Halo / agent-oversight surfaces.
- **Destination:** New doc `docs/EXECUTIVE_UI_OVERSIGHT_DESIGN_PRINCIPLES_2026_05_15.md` OR addendum to Provenance Console doctrine.

### M-9. Dirty-diff stash inventory + protected-path guardrails
- **Source:** `docs/fusion/DIRTY_DIFF_STABILIZATION_AUDIT_2026_04_30.md` §"Stash Inventory" + §"Protected-Path Guardrail"
- **What it is:** 4 outstanding stashes (`stash@{0..3}`) with "Do not pop" decisions + 3 protected paths (`ProseEditor*.swift`, `MetalGraphView.swift`, `HologramController.swift`) that must stay clean.
- **Destination:** Add to `NEW_SESSION_HANDOFF_2026_05_15.md` §3 (immutable rules) or §10.5 (per-session startup protocol).

---

## 4. LOW — operational / drift-tracking / character DNA

### L-1. Character DNA specs (Block/Sage/Orb/Hermes Snake bodies)
- **Source:** `docs/fusion/simulation/character-dna/{block_compact,block_wide,sage,orb,hermes_snake}.md`
- **Destination:** Post-V1 (Simulation v1.7+); pointer from `MASTER_FUSION` Wave G3.

### L-2. V6.2 state: rendered FULL / VRMLabelView per-bubble binding
- **Source:** `docs/audits/V6_2_PER_BUBBLE_BINDING_RESEARCH_2026_05_12.md` — `AWAITING_USER_SIGNOFF_BEFORE_IMPLEMENTING`.
- **Destination:** `MASTER_FUSION` Wave C or V6.2 own backlog.

### L-3. Graph Toolbar — Cursor Force + Shape Bound buttons
- **Source:** `docs/audits/GRAPH_TOOLBAR_CURSOR_FORCE_SHAPE_BOUND_SPEC_2026_05_12.md` — `AWAITING_USER_SIGNOFF_BEFORE_IMPLEMENTING`.
- **Destination:** Post-V1 backlog row.

### L-4. MASTER_FUSION §6 Wave B/C/D NOT-STARTED items
- **Source:** `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` §5 + §3.x rows tagged `NOT-STARTED` (e.g., 10-state Live-File machine §3.14, BiometricWriteGate §322ff, two-tier biometric cache, donor-distilled student per V6.1).
- **Destination:** Already in MASTER_FUSION; needs explicit link from `NEW_SESSION_HANDOFF` §10 so future sessions don't miss them.

### L-5. BUILDER_PROMPT / AUDIT_PROMPT as launchable artifacts
- **Source:** `~/Documents/Epistemos-QuickCapture/{BUILDER_PROMPT,AUDIT_PROMPT}.md` (per INDEX §"How to launch the builder")
- **What it is:** Two ~20 KB prompts designed to be pasted into fresh Claude Code terminals.
- **Destination:** One-line pointer in `NEW_SESSION_HANDOFF` §10.7 (Implementation prompts).

---

## 5. Decision matrix — what to do NOW vs DEFER

### Triage for V1 ship (do this before MAS submission)

| Item | Decision required |
|---|---|
| **B-5 BrowserEngine MAS/Pro decision** | ✅ RESOLVED 2026-05-16 — `MAS_COMPLETE_FUSION` §0 rule 6 declares HTTP-fetch + `WKWebView`-only for MAS, `deno_core` / Obscura Pro-only |
| **B-6 Hermes-parity salvage verification** | ✅ VERIFIED 2026-05-16 — NOT A V1 BLOCKER. `credential_pool.rs` + `session_persistence.rs` are dead files (not in `lib.rs`, uncompiled); `error_classifier.rs` compiles + 7 tests pass but has zero production callers. Audited risk cannot materialize. Follow-up orphan-disposition decision tracked separately. |
| **B-1 / B-2 / B-3 / B-4 Wave 7-11 user-product items** | ✅ DECISIONS RECORDED 2026-05-16 — all 4 rows landed in `MAS_COMPLETE_FUSION` §10 Compromises Recorded. Recommended paths: B-1 V1.1 defer · B-2 V1.1 defer · B-3 V1 simple form + V1.1 full form · B-4 V1.1 defer. Each row carries 2 user-override alternatives. **User input requested** to confirm/override. |
| **H-1 / H-2 startup hang + memory regression** | RUNTIME: 2 user-action profiling tasks; route through Phase A |
| **H-3 Local Engineering Agent / Attach-Note-To-Chat** | ✅ DECISION RECORDED 2026-05-16 — V1.1 defer (recommended), V1 ships read-only `note.attach_readonly` stub. See `MAS_COMPLETE_FUSION §10` (H-3 / B2-H6 row) for full alternatives. |

### Triage for V1.1 / post-V1 (route into Hermes 2.0 6-week plan)

| Item | Route to |
|---|---|
| H-4 Overseer hierarchy | ✅ RESOLVED 2026-05-16 — landed as Hermes 2.0 §13.7 with 4-role decomposition (Planner / Guardrail / Critique / Budget) + cooperation pipeline + mapping to existing primitives + VSM cross-link. |
| H-5 Adaptation Subsystem + Compute Steering | MASTER_FUSION §3.x + new B-row |
| H-7 GRPO | MASTER_FUSION §continual-learning |
| H-8 MLA | MASTER_FUSION §local-inference |
| H-9 Run Ledger | MASTER_FUSION §provenance |
| H-10 / M-2 Auto-research + Eidos Plus | Hermes 2.0 §13.5 distillation test #8 OR NightBrain task body |
| M-3 Cloud-as-Teacher | Hermes 2.0 §13.5 + B.9 NightBrain |
| M-1 Eidos search | MASTER_FUSION §3.x neural-search-engine |
| M-5 Reflective Loop | Hermes 2.0 §3 architecture |
| M-8 Executive UI design principles | New doc `docs/EXECUTIVE_UI_OVERSIGHT_DESIGN_PRINCIPLES_2026_05_15.md` |
| M-9 Dirty-diff stash + protected paths | NEW_SESSION_HANDOFF §3 |

### Triage for post-V1.x (research-tier / queue)

| Item | Route to |
|---|---|
| M-4 Hopfield / attractor memory | MASTER_FUSION research-tier |
| M-6 / M-7 Graph + sidebar perf issues | Audit register MEDIUM-priority |
| L-1 Character DNA specs | Wave G3 pointer |
| L-2 / L-3 V6.2 binding + Graph toolbar | Sign-off-pending backlog |
| L-4 NOT-STARTED items | Already in MASTER_FUSION; cross-ref from handoff |
| L-5 BUILDER/AUDIT prompts | NEW_SESSION_HANDOFF §10.7 pointer |

### H-6 GTM / Distribution / Pricing — DEFER

Not directly ship-blocking IF V1 is MAS-only. Surface in a new dedicated doc when post-MAS distribution decisions need to be made (Lemon Squeezy / Sparkle / Pro pricing tier).

---

## 6. The 4-canonical-doc-update path

To close all 31 gaps without creating new sprawl, update **4 existing docs** + write **1 new doc**:

### 6.1. `MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` §3 Concept Atlas (add 9 rows)
- B-1 Live Files (substrate primitive)
- B-2 Brain Export (productization layer)
- B-3 Confidence Meter + 70%-Triggered Re-Learn
- B-4 Pixel Mode vs Tactical Mode duality
- H-5 Adaptation Subsystem + Compute Steering schemas
- H-7 GRPO (alongside OFTv2 in continual-learning)
- H-8 MLA (alongside KIVI in local-inference)
- H-9 Run Ledger (alongside ClaimLedger in provenance)
- M-1 Eidos search engine (distinct from Eidos companion)
- M-4 Hopfield / hypervector memory (research-tier)

### 6.2. `MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md` (add to Phase A + decision tracker)
- Phase A.0 — Hermes-parity salvage verification (B-6)
- §0 immutable rules — MAS BrowserEngine adapter decision (B-5)
- Compromises Recorded — Wave 7-11 V1 vs V1.1 decisions (B-1 / B-2 / B-3 / B-4)
- §A — H-1 + H-2 profiling tasks
- §B.10 (new row) — H-3 Local Engineering Agent / Attach-Note-To-Chat (V1 hero or V1.1)
- §C — M-6 + M-7 graph + sidebar perf

### 6.3. `HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md` (add sections)
- §7.1 add `brain.export` MAS-allowed tool (B-2 if V1)
- §7.1 add `edit_note_block` / `EditPage` macaroon (H-3)
- §multi-overseer (new) — H-4 Overseer hierarchy
- §13.5 distillation §13.5.x — H-10 Auto-research + M-2 Eidos Plus + M-3 Cloud-as-Teacher
- §3 architecture annotation — M-5 Reflective Loop

### 6.4. `NEW_SESSION_HANDOFF_2026_05_15.md`
- §3 add M-9 protected-paths rule + dirty-diff stash list
- §10.5 add L-4 MASTER_FUSION NOT-STARTED items cross-ref
- §10.7 add L-5 BUILDER_PROMPT / AUDIT_PROMPT pointers

### 6.5. New: `docs/EXECUTIVE_UI_OVERSIGHT_DESIGN_PRINCIPLES_2026_05_15.md` (M-8)
Synthesize NASA DSKY Verb-Noun + Open MCT + ISA-101 + Crew Dragon for the Provenance Console / Halo / agent-oversight UI design discipline.

### 6.6. New (deferred until post-MAS): `docs/GTM_DISTRIBUTION_PRICING_PLAYBOOK_2026_05_15.md` (H-6)

---

## 7. What this audit found that was already covered (and is fine)

To prove the audit was honest and not over-reporting, here's what was already in canon (do NOT re-add):
- Hermes / Hermes namespace removed / LocalAgent + Runtime canonical naming
- Variant Ladder (full 6-tier doctrine + 30-tool registry)
- Cognitive DAG / Cognitive Kernel / Cognitive Weight Class W1 / Cognitive GenUI
- Honest Handle FFI Doctrine
- Live File Compiler Doctrine (name-only in cocktail, full doc separately)
- F-ULP-Oracle / EML universal operator
- AnswerPacket emission (V6.2 channel SHIPPED at `7a00db484` → `e639b6bb4`)
- A2UI catalog (name-only; 24 components deferred)
- Sovereign Gate 5 classes
- NeMoCLAW / OpenCLAW MAS doctrine
- Resonance Σ-signature (full surface)
- NightBrain 10 tasks (4 shipped, 6 pending)
- Tamagotchi / Biometric / Brain-Export (mentioned in MASTER_FUSION; specifics in gap rows above)
- Compass Artifact's 12-moat audit
- RunEventLog
- MutationEnvelope + schemas Phase 1 + Phase 2 (`33e1a5dcb`)
- FSRS-6 daily-review
- Helios V5 W1-W26 + E1-E7 + H1-H17 + PCF-1..10 substrate LANDED
- V6.1 5-plane formalism (canonical target only)
- V6.2 8-stage falsifier order
- KIVI / OFTv2 / KV implantation / Glass Pipe / Weight Surgery
- Ternary Bonsai / BitNet / T-MAC / Sparse Ternary GEMM
- Halo V1 6-state FSM + Halo Shadow index (W8.4 / W8.7 SHIPPED)
- Simulation v1.6 LANDED; v1.7+ deferred
- Quick Capture as concept + 25-file salvage triage

---

## 8. Bottom line

**The current canonical cocktail is honest and comprehensive — but 31 specific items leaked.** Half are research-tier and can wait. The 6 BLOCKERS plus 3 user-reported HIGH-severity issues (H-1, H-2, H-3) are the ones that should be triaged before V1 MAS submission. Most are **decisions, not implementations** — you can resolve them by routing each to V1 / V1.1 / Pro / post-V1 in 30 minutes of explicit doc updates.

The Wave 7-11 user-product layer (Live Files → Confidence Meter → Tamagotchi modes → Cloud-as-Teacher → Brain Export) is the most striking pattern: a complete product layer that's scattered across two QC addenda with zero canonical citations. **Decide which of these ship in V1 vs V1.1** — that's the single highest-leverage decision in the gap inventory.

---

*— End of Research Coverage Gap Audit. 31 gaps, 4 search agents, all 6 canonical docs grep-verified, every gap routable.*
