---
state: cross-terminal-wiring-backlog
created_on: 2026-05-17
purpose: Comprehensive ledger of everything that was DEFERRED because of scope-lock isolation between the 9 T-terminals. No single terminal could touch outside its lane, so cross-wiring + user-facing surfacing + feature-to-feature connections all got pushed to a post-merge integration phase. This doc is that phase's master backlog.
sources:
  - docs/audits/UAS_ACS_PER_TERMINAL_PUNCH_LIST_2026_05_17.md (T3-authored per-terminal punch list)
  - docs/audits/POST_RUN_BCDEF_PER_TERMINAL_PUNCH_LIST_2026_05_17.md (archeology punch list for prior cycle)
  - docs/audits/MULTI_TERMINAL_ARCHEOLOGY_FINDINGS_2026_05_17.md
  - docs/CODEX_9_TERMINAL_PROMPTS_2026_05_16.md (scope locks per terminal)
  - docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md §4.A-I (sub-mission acceptance bars)
  - Per-terminal commit history (T1 65 / T2 21 / T3 65 / T4 65 / T5 13 / T6 38 / T7 28 / T8 11 / T9 37 commits)
authority: this doc is the SINGLE master backlog post-merge. Drives the integration phase that follows each terminal's PR landing.
---

# Cross-Terminal Wiring + User-Facing Surfacing Backlog — 2026-05-17

> **What this doc is.** Every T-terminal had a strict scope lock. That isolation
> let them work in parallel without conflicts, but it created an explicit deferral
> class: any work that crosses terminal boundaries was forbidden. The substrate
> primitives one terminal built can't be called by another terminal's code until
> AFTER merge, and the user-facing surfaces that depend on multiple terminals'
> work weren't allowed to be built by anyone in isolation.
>
> This doc catalogs every such deferred wiring task. Each row tells you exactly
> what code to write, where it goes, which terminal outputs it consumes, what
> user-facing surface it enables, and when its prerequisites are met.
>
> **This is the most important doc post-merge.** Without it, the substrate
> compiles + tests pass + nothing is user-visible. Codex's autonomous loops built
> the substrate; this backlog turns it into the running app.

## §1. How to read this doc

Every row has 8 columns:

| ID | Source(s) | Consumer | User Surface | Acceptance | Priority | Deps | Status |

- **ID**: stable identifier (`W-NN`) so this row can be referenced from commits / PRs / future docs.
- **Source(s)**: which terminal(s) produced the types / modules / functions this wiring consumes.
- **Consumer**: where the wiring code lives.
- **User Surface**: what becomes visible to the end user when this wiring lands (or "internal substrate" if not visible).
- **Acceptance**: measurable criterion ("≤ X / ≥ Y / matches Z" — no "looks good").
- **Priority**: P0 (user-blocking, ship-critical) · P1 (high-value user surface) · P2 (internal substrate) · P3 (research-tier, can defer).
- **Deps**: which OTHER W-NN rows must land first.
- **Status**: NOT-STARTED · IN-FLIGHT · PARTIAL · DONE.

The §2-§6 tables are organized by **theme** (substrate-to-product, agent-to-vault, etc.) so related wirings cluster. §7 has the dependency graph; §8 has the phase plan; §9 has the user-facing surface inventory.

## §2. Substrate-to-Product wirings (P0/P1 — the substrate must reach the running app)

The biggest scope-lock cost was: T3 built UAS-ACS, T1 built Tri-Fusion, T7 built eml_integration, T5 started EML-IR — all of these are typed Rust modules with tests, but NOTHING in the user-facing app calls them yet. The product is identical to `86f0ec84f` from the user's perspective until these wirings land.

| ID | Source(s) | Consumer | User Surface | Acceptance | Priority | Deps | Status |
|---|---|---|---|---|---|---|---|
| **W-01** | T3 (`agent_core/src/uas/address.rs`) | `agent_core/src/storage/vault.rs` (vault notes get a UasAddress on insert/retrieve) | none directly; enables every UasKind-aware feature downstream | `vault.rs::hybrid_search()` returns `Vec<(UasAddress, Note)>`; round-trip property test on 50-note vault | P1 | merge T3 + T4 | NOT-STARTED |
| **W-02** | T3 (`UasKind` enum) | `agent_core/src/agent_runtime/` (every agent trace tagged with `UasKind::AgentTrace`) | enables replayable agent runs in run timeline | T2's `RunEventLog` event records carry `UasAddress { kind: UasKind::AgentTrace, ... }`; replay UI can reconstruct trace from address alone | P1 | merge T2 + T3 | NOT-STARTED |
| **W-03** | T3 (`AcsAnchor` type + `anchor_registry.rs`) | `agent_core/src/provenance/ledger.rs::ClaimLedger` | Provenance Console shows anchored claims with theorem tags | every `Claim` stored in `ClaimLedger` carries an `AcsAnchor`; Provenance Console UI displays the theorem tag column | P1 | merge T3 | NOT-STARTED |
| **W-04** | T3 (`page_gather/{helios_page,sketch_topk,residual_rescore,escalation_policy}.rs`) | `agent_core/src/storage/vault.rs` (vault retrieval uses sketch→residual→exact escalation) | F-VaultRecall-50 PASS becomes credible by using shadow-first paging on actual notes | `vault.rs::hybrid_search()` invokes `EscalationPolicy::escalate(query_sketch, query_residual, corpus)`; uses `EscalationVerdict` to decide read path; benchmark shows ≥ 40% read-amplification reduction vs naive scan | P1 | merge T3 + T4; W-01 | NOT-STARTED |
| **W-05** | T3 (`active_assembly/{packet,selector}.rs`) | `agent_core/src/agent_runtime/` (agent loop only activates relevant packets per Active Assembly selector) | none directly; cuts agent latency by skipping irrelevant tool surfaces | `agent_runtime` calls `Selector::pull(query_packet, available_packets)` before dispatching; assembly-PASS within WBO budget | P2 | merge T2 + T3 | NOT-STARTED |
| **W-06** | T1 (`agent_core/src/tri_fusion/mod.rs` + `LocalToolGrammar` Tri-Fusion mutation grammar) | `agent_core/src/agent_runtime/` (local models emit Tri-Fusion mutations as typed tool calls) | model-authored note edits appear as structured operations in Epdoc with provenance badge | `agent_runtime` parses `TriFusionMutation` from model output; Epdoc receiver renders structured-mutation cards; LocalAgentPromptBuilder emits at least one Tri-Fusion mutation in a real chat turn | P1 | merge T1 + T2 | NOT-STARTED |
| **W-07** | T7 (`agent_core/src/research/eml_integration/observatory.rs`) | Settings → Diagnostics → "EML energy live readout" row (T7 prompt §4.B B.2 already named this) | user sees live energy signal as a diagnostic; explains "why the model picked X" | new `EmlObservatoryHealthRow.swift`; reads observatory state via FFI; auto-refreshes 1 Hz | P2 | merge T7 | NOT-STARTED |
| **W-08** | T7 (`eml_integration/potential.rs`) | `Epistemos/LocalAgent/ConfidenceRouter.swift` (router uses energy potential as a routing signal) | model selection is more accurate; user sees fewer "wrong model picked" outcomes | ConfidenceRouter reads `EmlPotential::compute(query)` before dispatching; A/B routing test shows ≥ 5% accuracy improvement on a fixture corpus | P2 | merge T2 + T7 | NOT-STARTED |
| **W-09** | T5 (`agent_core/src/research/scan_ir/`) | T3's F-SemiseparableBlockScan harness (`agent_core/tests/ssd_block_scan_correctness.rs`) | none directly; tightens substrate floor for SSM/Mamba-2 work | T3's iter-53 test refactored to consume `ScanIR::SemiseparableBlock { ... }` from T5's lane; correctness held | P3 | merge T5 (Phase B3+ done) + T3 | NOT-STARTED |
| **W-10** | T3 (UAS-ACS canonical doc + 12 falsifier docs) | Settings → Diagnostics → "UAS-ACS substrate health" row | user sees substrate health: which falsifiers PASS, which substrate-floor, which deferred | new `UasAcsHealthRow.swift`; reads falsifier statuses via FFI; clickable to per-gate detail; tied to `docs/falsifiers/` rows | P1 | merge T3 | NOT-STARTED |

## §3. Agent + Model wirings (P0 — local-agent excellence per §4.F)

T2 built AgentBlueprint UI + run timeline + per-model grammars in agent_runtime. But the **UI wiring to backend** has gaps that scope-lock prevented closing:

| ID | Source(s) | Consumer | User Surface | Acceptance | Priority | Deps | Status |
|---|---|---|---|---|---|---|---|
| **W-11** | T2 (`Epistemos/Views/Settings/ActiveConstellationRow.swift`) | LIVE state binding from `ConfidenceRouter` + `MLXInferenceService` | user sees which model is hot/warm/cold per-role in real time; constellation comes alive | row updates ≤ 500 ms after model state changes; per-model state = cold·warm·hot; per-model role = code·reasoning·quick·toolCaller·trivial·vision | P0 | merge T2 | PARTIAL (row exists; live binding may be incomplete) |
| **W-12** | T2 (per-model native grammars in `agent_runtime/function_call.rs` + `prompt_format.rs`) | model picker UI in Settings | per-model agent badges: HONEST (strict grammar PASS) · EXPERIMENTAL (soft guidance only) · OFF (no agent support) | every local model in picker shows a badge; click reveals which grammar primitives the model honors; cross-link to MODEL_GRAMMAR_MATRIX_2026_05_17.md | P0 | merge T2 | NOT-STARTED |
| **W-13** | earlier commit `15cc2ced4` (UserDefaults flag `epistemos.localAgent.powerUserMode` + LocalModelInfrastructure.swift effective threshold) | Settings → Inference → "Power-user mode" toggle UI | user can flip power-user mode without `defaults write` from terminal | new SwiftUI `Toggle` in Inference settings; persists to UserDefaults; relaunch hint shown; cross-link to ISSUE-2026-05-16-015 | P0 | none | NOT-STARTED |
| **W-14** | T2 (`agent_runtime/function_call.rs` AnswerPacket emission) | `Epistemos/Bridge/StreamingDelegate.swift` (every chat reply emits a typed AnswerPacket visible in RunEventLog + Provenance Console) | user sees AnswerPacket claim_kind + citations + confidence in every reply; UI badge per kind | every chat reply in `SDChat` has at least one persisted AnswerPacket; `AnswerPacketHealthRow` shows non-zero emission count | P0 | merge T2 | PARTIAL (T2 wired core but verify against per-message persistence) |
| **W-15** | T2 (`AgentBlueprint.swift` + `AgentBlueprintSettingsView.swift`) | Settings → Agent → AgentBlueprint creation flow | user opens Settings, picks "Create Agent", picks role/scope/tools/approval, runs first agent | end-to-end: create AgentBlueprint → MissionPacket → run → AgentEvent stream → AnswerPacket visible in chat | P0 | merge T2 | PARTIAL (UI built; integration test may be missing) |
| **W-16** | T2 (`AgentRunTimelineView.swift` + RunEventLog) | replay-from-log UI control | user clicks "replay" on any agent run; sees same sequence reconstruct from RunEventLog | replay button; reads events; renders identical timeline; deterministic | P1 | W-15 | NOT-STARTED |
| **W-17** | T2 (`LocalAgentDiagnostics.swift`) + `agent_core::agent_runtime::diagnostics` | Settings → Diagnostics → "Local agent diagnostics" row | user sees per-model load times, idle-unload events, schema-drift counter, hot-swap count | row aggregates 6 metrics; clickable for per-metric history; refresh ≤ 1 Hz | P1 | merge T2 | PARTIAL (row + service exist; verify metric population) |
| **W-18** | T2 + T7 (EML observatory + agent runtime confidence) | AgentRunTimelineView shows model-emitted confidence per turn | user sees model's self-reported confidence per generation step; explains rejection/escalation | per-event confidence column in timeline; tied to AnswerPacket.confidence field | P2 | W-08 + W-15 | NOT-STARTED |

## §4. Vault retrieval honesty (P0 — F-VaultRecall-50 acceptance + Vault Context Contract)

T4 built `agent_core/src/retrieval/` + extended `vault.rs` + provenance cards in NoteChatSidebar. The Vault Context Contract was authored but enforcement at every retrieval entry point is the cross-wiring:

| ID | Source(s) | Consumer | User Surface | Acceptance | Priority | Deps | Status |
|---|---|---|---|---|---|---|---|
| **W-19** | T4 (`Epistemos/Sync/RRFFusionQuery.swift` extended) | `Epistemos/App/ChatCoordinator.swift` (Vault Context Contract enforced at prompt-build seam) | the "first 7 irrelevant notes" failure becomes IMPOSSIBLE; trace visible in chat reply | ChatCoordinator never builds a context pack with `LIMIT N` from index order; every retrieval emits a trace to RunEventLog; F-VaultRecall-50 PASS conditions met | P0 | merge T4 | PARTIAL (T4 implemented; ChatCoordinator integration may not be complete) |
| **W-20** | T4 (provenance card UI in `Epistemos/Views/Notes/NoteChatSidebar.swift`) | Halo / Shadow panel + ChatInputBar autocomplete + every search result surface | every vault search result shows lexical/semantic/graph/recency badges; user understands WHY each note was selected | provenance cards rendered in ≥ 3 surfaces (NoteChatSidebar + Halo panel + ChatInputBar); per-card cross-link to source contract row | P0 | merge T4 + T6 | PARTIAL (NoteChatSidebar done; other surfaces pending) |
| **W-21** | T4 (`F-VaultRecall-50` baseline + tests) | Settings → Diagnostics → "Vault recall health" row | user sees: % top-1 exact-title hit · % top-5 paraphrase hit · % synthesis 2-note citation · % adversarial reject | row aggregates 4 metrics; refresh on every vault index update; clickable to per-query breakdown | P1 | merge T4 | NOT-STARTED |
| **W-22** | T4 (extended `hybrid_search`) + T3 (`UasAddress`) | retrieval returns `Vec<UasAddress>` instead of `Vec<NoteId>` | downstream consumers (agent context, Halo panel, ChatInputBar) get typed addresses with kind metadata | breaking change: every consumer migrates; cargo lib floor ≥ 1671 maintained | P1 | merge T3 + T4; W-01 | NOT-STARTED |
| **W-23** | T4 (Vault Context Contract doctrine) | all retrieval entry points in Swift (not just ChatCoordinator) | every retrieval honors the 10 contract rules: never enumerate first N, always full-manifest, 50-200 candidates, hybrid signals, MMR diversity, visible trace, etc. | rg "LIMIT" + "first.*notes" across Swift code returns 0 hits in prod paths; CI gate prevents regression | P1 | merge T4 + T6 | NOT-STARTED |

## §5. Cognitive DAG + Provenance wirings (P1 — user-visible substrate)

The cognitive DAG and provenance ledger were extended by T3, but UI surfaces haven't been wired:

| ID | Source(s) | Consumer | User Surface | Acceptance | Priority | Deps | Status |
|---|---|---|---|---|---|---|---|
| **W-24** | T3 (`UasAddress` + `AcsAnchor` types) | `agent_core/src/cognitive_dag/node.rs` (every DAG node carries a UasAddress + AcsAnchor) | DAG nodes inspectable in graph visualizer with theorem tag + residency tier | every NodeKind variant has an optional `uas: Option<UasAddress>` + `anchor: Option<AcsAnchor>` field; serialization round-trip test | P1 | merge T3 | NOT-STARTED |
| **W-25** | T3 (`AcsAnchor`) + Provenance Console | Provenance Console renders ACS anchor column | user sees theorem tag + plane coord + residency tier per provenance row | new ACS-anchor column in Provenance Console; sortable by theorem tag; clickable to per-anchor detail | P1 | W-03 + W-24 | NOT-STARTED |
| **W-26** | existing `agent_core/src/cognitive_dag/` (substrate already shipped) | new Cognitive DAG visualizer in `Epistemos/Views/Graph/` | user opens "Cognitive DAG" tab; sees live graph of NodeKinds + EdgeKinds with resonance walks | Cognitive Weight Class doctrine §4.1 tier discipline observed; nodes color-coded by NodeKind; edges by EdgeKind; resonance walk animation | P1 | merge T3 + T6 | NOT-STARTED |
| **W-27** | T3 (`agent_core/src/scope_rex/answer_packet.rs`) + T2 (AnswerPacket emission) | chat-row Swift code surfaces AnswerPacket badge | user sees per-emission badge in every chat row: claim_kind (synthesis / empirical / mathematical / causal / speculative) + confidence (verified / plausible / speculative / blocked) | per-row badge; cross-link to AnswerPacket detail; tied to W-14 | P0 | W-14 + merge T2 + T3 + T6 | NOT-STARTED |
| **W-28** | T3 (`ResidencyTier` enum: Current App / Verified Floor / Capability Ceiling) | Settings + Cognitive Weight Class badges + DAG node colors | user sees which features are ship-claimed vs research-tier vs gated; honest doctrine | every research-tier feature has a ResidencyTier indicator; substrate-floor PASS badges; cargo `--features research` gate respected | P1 | merge T3 + T6 | NOT-STARTED |

## §6. UI surface unification (P1 — T6 audited but didn't wire backend features TO UI)

T6 fixed 30+ UI bugs but explicitly stayed out of backend-to-UI wiring (per scope lock). These are the wirings that turn backend completeness into user-facing reality:

| ID | Source(s) | Consumer | User Surface | Acceptance | Priority | Deps | Status |
|---|---|---|---|---|---|---|---|
| **W-29** | T2 (AnswerPacketHealthRow exists) + T1 (Tri-Fusion emission) + T7 (EML observatory) | unified "Substrate Health" panel in Settings | user opens "Substrate Health" and sees: agent runtime status · model constellation · vault recall metrics · EML energy · UAS-ACS falsifiers · cognitive DAG counts · provenance ledger growth | new panel with 7+ health rows; auto-refresh; gracefully degrades if subsystem unavailable | P1 | most other W rows | NOT-STARTED |
| **W-30** | All UI surfaces touched by T6 | Cognitive Weight Class badges per `COGNITIVE_WEIGHT_CLASS_DOCTRINE_2026_05_04.md` | user sees W1-W4 weight badges on every cognitive surface (light / medium / heavy / extreme) | every cognitive feature surfaces a W-tier badge; consistent visual language across Settings · Chat · Notes · Graph | P2 | merge T6 | NOT-STARTED |
| **W-31** | T6 (Ambient Frequencies polish + audiophile upgrades) | Settings → Audio diagnostics surface | user sees export gain · master volume · live-player chain · A/V health | unified audio diagnostics panel; cross-link to UI_UX_AmbientFrequencies audit docs | P3 | merge T6 | NOT-STARTED |
| **W-32** | per-feature feature flags (some have UserDefaults flags, no UI) | Settings → Experimental Features panel | user can flip experimental features without `defaults write` | EPISTEMOS_RRF_FUSION_V1, EPISTEMOS_GRAPH_INDEX_CHATS, epistemos.localAgent.powerUserMode, and any others get a unified Settings panel | P1 | none | NOT-STARTED |
| **W-33** | T9 (drift catches + audit-of-audit cycles) | Settings → Diagnostics → "Substrate Drift Monitor" row | user sees if any commit on main introduces drift caught by T9-style heuristics | row reads from a drift-monitor service; alerts if drift detected; cross-link to docs/coordination/ | P2 | merge T9 | NOT-STARTED |

## §7. Biometric lock integration (GATED — only fires after T1+T2+T6 land)

T8 wrote the full Phase 0 doctrine but Phase B is gated. When the gate opens, these wirings fire:

| ID | Source(s) | Consumer | User Surface | Acceptance | Priority | Deps | Status |
|---|---|---|---|---|---|---|---|
| **W-34** | T8 (BIOMETRIC_LOCK_DOCTRINE) + T3 (UasAddress residency tier) | new `Epistemos/Engine/BiometricLockService.swift` wrapping LocalAuthentication | user can lock any note / chat / code-block / vault behind Touch ID | service lands; lock state column + migration per entity; round-trip test | P3 | W-01 + W-24 + GATE | NOT-STARTED |
| **W-35** | T8 doctrine + T2 (macaroons) | extend `agent_core/src/cognitive_dag/macaroons.rs` with `LockedContentGate` constraint | locked content cannot reach AgentLoop context BY CONSTRUCTION | property test: locked entity's content never appears in agent prompt; failclosed on missing lock-state lookup | P3 | W-34 + merge T2 + T3 | NOT-STARTED |
| **W-36** | T8 doctrine + T4 (SearchIndexService.fusedSearch) | retrieval filters locked items | locked notes invisible in search unless unlocked under bounded capability | property test: search returns 0 hits on locked content; index-isolation by construction | P3 | W-34 + W-19 | NOT-STARTED |
| **W-37** | T8 doctrine | UI: lock badge + unlock sheet (LAContext) + locked-items placeholder | user can lock any lockable entity from context menu; placeholder shows "🔒 N locked items" in lists | UI rendered across NoteChatSidebar · NotesSidebar · MessageBubble · ArtifactBlockView · EpdocEditor | P3 | W-34 + merge T6 | NOT-STARTED |
| **W-38** | T8 doctrine (Spotlight integration) | `Epistemos/Engine/SpotlightIndexer.swift` + `NoteEntitySpotlightIndexer.swift` | locked content NEVER appears in Spotlight | property test: deindex on lock toggle; CSSearchableItem + NoteEntity surfaces respect lock state | P3 | W-34 + merge T6 | NOT-STARTED |
| **W-39** | T8 doctrine (recovery flow) | recovery-code printable view + Keychain rewrap | user can recover lock access if biometric fails / device replaced | recovery code ≥ 128 bits entropy; printable view; Keychain rewrap on success | P3 | W-34 | NOT-STARTED |

## §8. Optional / Research-tier wirings (P3 — capability ceiling)

These ARE useful but are gated on T3 Phase C / T5 Phase C / hardware validation. Include for completeness:

| ID | Source(s) | Consumer | User Surface | Acceptance | Priority | Deps | Status |
|---|---|---|---|---|---|---|---|
| **W-40** | T5 (eml/ulp_oracle.rs partial) + T7 (`eval_real` runtime) | F-ULP-Oracle harness | research-tier; surfaces "arithmetic verification floor" in Diagnostics | T7 publishes `eval_real(point: f64) -> f64`; T3 wires into harness; max ULP ≤ 2 fp16 in [0.5, 2.0] over 412k+2k points in ≤ 90 s | P3 | merge T5 + T7 | NOT-STARTED |
| **W-41** | Swift / Metal lane (5 .metal kernels deferred per T3 punch list §9) | live agent inference path | user gets actually-faster local inference once Metal kernels land (Mamba-2, page-gather, controller-pack, packet-router-1bit, local-recall-island, semiseparable-block-scan) | per-kernel Metal correctness vs CPU ref + per-kernel performance gate | P3 | T3 Phase C + Apple-platform external work | NOT-STARTED |
| **W-42** | T3 (F-KV-Direct-Gate harness) + Swift integration test | live Qwen 3 8B at 128k context with SSD cold-spill | research-tier; demonstrates the V6.1 substrate's KV-Direct claim | peak RAM < 13 GB on 16 GB rig; D_KL/token < 0.08; decode ≥ 10 tok/s | P3 | merge T3; T3 Phase C | NOT-STARTED |
| **W-43** | T3 (F-70B-Cocktail composition study) | research doc only | research-tier; ceiling falsifier per §4.G | composition harness runs end-to-end; primary bottleneck identified | P3 | W-41 + W-42 | NOT-STARTED |
| **W-44** | T5 (6 IR primitives: EML / Tropical / Scan / Operator / Info / Geometry) | hyperdynamic_schemas (T1) carries IR-typed expressions | research-tier; Tri-Fusion content fabric can carry IR-typed math natively | each IR has property tests; Tri-Fusion ABI accepts IR-typed expressions; example notebook demonstrating EML-IR → Lean cert | P3 | merge T1 + T5 (Phase B done) | NOT-STARTED |
| **W-45** | T5 (per-IR Lean schema authority) | every typed schema in the app | research-tier; Lean proofs of major identities | Lean files compile; each IR has at least one identity proved | P3 | merge T5 (Phase C done) | NOT-STARTED |
| **W-46** | T23B (`docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md` + validator shape doc) | future Rust/Python artifact validator harness | internal substrate; prevents loose logs from becoming falsifier witness artifacts | validator parses the single schema fragment, enforces cross-gate axis floors, proves falsifier enum/map alignment, checks artifact reference paths, checks canonical witness filenames with the WBO-only JSONL exception, checks JSONL row shape, prompt IDs, token IDs, and indices, checks threshold operator and unit token rules, checks homogeneous sample arrays, checks digest measurement shape, checks anomaly severity enums, checks blocking anomalies affect pass, checks anomaly axis/pass effects, enforces classified-null measurement semantics, rejects notes payload smuggling, checks notes inspection tokens, loads hardware mapping, verifies migration-note completeness, verifies the negative-catalog count, rejects negative examples, and fails replay-ineligible artifacts before any handbook row can promote | P3 | T23B docs; implementation owner TBD | NOT-STARTED |

## §9. User-facing surface inventory (the "this is what the user sees" list)

When the W-NN rows above land, here's the user-facing experience that emerges. This is what "making the substrate visible" actually means in product terms:

| User Surface | Backed by | Status when this lands |
|---|---|---|
| **Vault search "Why this note?" provenance card** | W-19 + W-20 + W-22 | every search result shows lexical · semantic · graph · recency badges; user understands why each note was selected |
| **F-VaultRecall-50 PASS visible in Settings** | W-21 | user sees vault recall health (≥ 95% top-1 exact-title etc.) as a Diagnostics row |
| **"First 7 irrelevant notes" failure becomes impossible** | W-19 + W-23 | the original user complaint becomes structurally impossible across all retrieval paths |
| **Agent constellation live status** | W-11 + W-12 | Settings → Inference → Active Constellation row shows which model is hot/warm/cold per-role in real time |
| **Per-model agent badges (HONEST / EXPERIMENTAL / OFF)** | W-12 | model picker UI shows per-model badge so user knows which models are real agents vs soft-guidance only |
| **Power-user mode toggle** | W-13 | Settings UI control instead of `defaults write` |
| **AnswerPacket badge per chat row** | W-14 + W-27 | every chat reply shows claim_kind + confidence + citations as a badge |
| **AgentBlueprint creation flow** | W-15 | user opens Settings, creates an Agent (name + role + scope + tools + approval mode), runs first mission, sees output |
| **Agent run timeline + replay** | W-15 + W-16 | user sees plan → search → tool → approve → output; can click "replay" to reconstruct from RunEventLog |
| **Local agent diagnostics** | W-17 | per-model load times, idle-unload events, schema-drift counter, hot-swap count |
| **Model emission confidence** | W-18 | per-event confidence visible in timeline |
| **EML energy live readout** | W-07 | Settings → Diagnostics → "EML energy live readout" row (T7's deliverable surfaced) |
| **UAS-ACS substrate health** | W-10 + W-28 | Settings shows which falsifiers PASS, which substrate-floor, which deferred |
| **Cognitive DAG visualization** | W-26 | "Cognitive DAG" tab in Graph; live nodes + edges; resonance walks |
| **Provenance Console ACS-anchor column** | W-03 + W-25 | claims sortable by theorem tag |
| **Tri-Fusion structured-mutation cards in Epdoc** | W-06 | model-authored note edits appear as structured operations with provenance badge |
| **Substrate Health unified panel** | W-29 | one Settings panel surfaces all subsystem health in one place |
| **Cognitive Weight Class badges everywhere** | W-30 | W1-W4 badges on every cognitive surface |
| **Experimental Features panel** | W-32 | unified Settings panel for per-feature flags |
| **Substrate Drift Monitor** | W-33 | Diagnostics row catches T9-style drift on main |
| **Biometric lock badges + unlock sheets** | W-34 + W-37 | every lockable surface has lock affordance; unlock via Touch ID |
| **Locked content invisible everywhere** | W-35 + W-36 + W-38 | locked notes/chats/code/vaults invisible in search · agent context · Spotlight by construction |
| **Biometric recovery** | W-39 | printable recovery code; Keychain rewrap |

## §10. Dependency graph

Major dependency clusters (read top-to-bottom; later items wait for earlier):

```
                                ┌──────────────────────────┐
                                │ merge T1/T2/T3/T4/T6/T7  │
                                │   (base wave)            │
                                └────────────┬─────────────┘
                                             │
                       ┌─────────────────────┼─────────────────────┐
                       │                     │                     │
                       ▼                     ▼                     ▼
              W-01 (UAS↔vault)      W-13 (power-user UI)    W-21 (vault health row)
                       │                     │                     │
                       ▼                     │                     ▼
              W-04 (page-gather↔vault)       │             W-29 (Substrate Health panel)
                       │                     │                     ▲
                       ▼                     │                     │
              W-22 (vault returns UasAddr)   │             ┌───────┴──────┐
                       │                     │             │              │
                       ▼                     ▼             │              │
              W-19+W-20+W-23 (Vault Context Contract everywhere)          │
                                             │                            │
                                             │     W-07+W-10+W-11+W-14    │
                                             ▼     (Settings rows)        │
                                       W-15 (AgentBlueprint UI)           │
                                             │                            │
                                             ▼                            │
                                       W-16 (replay UI)                   │
                                                                          │
                       ┌──────────────────────────────────────────────────┘
                       │
                       ▼
              W-08+W-18 (EML→ConfidenceRouter; EML confidence in timeline)
              W-25+W-26 (Provenance Console ACS column; Cognitive DAG visualizer)
              W-30 (Weight Class badges)
              W-32+W-33 (Experimental + Drift Monitor)

              ╔══════════════════════════════════════╗
              ║  GATE: T1 + T2 + T6 all landed       ║
              ║  on main with PRs merged             ║
              ╚══════════════════════════════════════╝
                       │
                       ▼
              W-34 (BiometricLockService)
                       │
                       ▼
              W-35+W-36+W-37+W-38+W-39 (lock surfaces everywhere; recovery)

              ╔══════════════════════════════════════╗
              ║  Research-tier (multi-week, gated)   ║
              ╚══════════════════════════════════════╝
                       │
                       ▼
              W-09 (Scan-IR↔SemiseparableBlockScan)
              W-40 (F-ULP-Oracle PASS)
              W-41 (5 Metal kernels)
              W-42 (F-KV-Direct-Gate PASS)
              W-43 (F-70B-Cocktail composition)
              W-44+W-45 (6 IR primitives + Lean proofs)
```

## §11. Phase plan — WHEN to do each wave

Per the user's directive: do this work *when* terminals are done with what they can do. The phase plan:

### Phase Δ — Merge wave (now)

Land each terminal's PR onto main per the safety-order from prior planning (T9 → T8 → T5 → T3 → T7 → T1 → T4 → T6 → T2). After each merge:
- Verify cargo lib floor ≥ 1671 holds
- Verify xcodebuild green
- Mark each W-NN row's deps as satisfied
- T9 catches any drift before next merge

### Phase ε — Substrate-to-product wave (week 1 post-merge)

Land **P0 user-blocking wirings**:
- W-11 ConfidenceRouter live binding to ActiveConstellationRow
- W-12 per-model agent badges in model picker
- W-13 power-user mode toggle UI
- W-14 AnswerPacket runtime emission verification + per-row badge
- W-15 AgentBlueprint creation flow end-to-end test
- W-19 ChatCoordinator Vault Context Contract enforcement
- W-20 provenance cards in remaining search surfaces (Halo, ChatInputBar)

Acceptance: a fresh user opens the app, picks a model, asks a question that touches the vault, sees: vault search trace with provenance cards · model picked based on task class · AnswerPacket badge on reply · no "first 7 notes" failure · constellation row shows hot model. **The substrate is no longer invisible.**

### Phase ζ — Substrate-visibility wave (week 2 post-merge)

Land **P1 user-visible substrate wirings**:
- W-01 UasAddress on vault notes
- W-04 page-gather wired to vault retrieval
- W-07 EML observatory health row
- W-10 UAS-ACS substrate health row
- W-21 vault recall health row
- W-22 vault returns Vec<UasAddress>
- W-23 Vault Context Contract enforced everywhere
- W-29 unified Substrate Health panel
- W-32 Experimental Features panel
- W-25+W-26+W-27 ACS column / DAG visualizer / AnswerPacket badge
- W-30 Weight Class badges

Acceptance: user opens Settings → Diagnostics and sees ALL major substrate health surfaces in one place. The architecture is inspectable to the end user.

### Phase η — Biometric gate opens

Once T1 + T2 + T6 each have a landed PR, T8's gate auto-opens. T8's Phase B implementation begins per the T8 driver prompt. The W-34 through W-39 rows fire in T8's lane.

### Phase θ — Internal / research-tier (month 2+)

Land **P2 + P3 wirings** as bandwidth allows:
- W-02 UasAddress in agent traces
- W-03 AcsAnchor in ClaimLedger
- W-05 Active Assembly in agent_runtime
- W-08 EML potential in ConfidenceRouter
- W-09 Scan-IR consumer
- W-17+W-18 diagnostics + confidence in timeline
- W-24+W-28 DAG node UAS/ACS + ResidencyTier indicator
- W-31 Audio diagnostics
- W-33 Drift Monitor

### Phase ι — Capability ceiling (month 3-6)

- W-40 F-ULP-Oracle PASS
- W-41 5 Metal kernels
- W-42 F-KV-Direct-Gate PASS
- W-43 F-70B-Cocktail composition
- W-44+W-45 6 IR primitives + Lean proofs

## §12. Status tracking discipline

Every commit that lands a W-NN row MUST update its status here. The format:

```
W-NN: NOT-STARTED → IN-FLIGHT  // commit <sha>
W-NN: IN-FLIGHT → PARTIAL      // commit <sha>: <slice description>
W-NN: PARTIAL → DONE           // commit <sha>: acceptance bar met; cross-link to acceptance test
```

A row is **DONE** ONLY when:
1. The cited code path exists on `main` (verified via git checkout main && rg/grep)
2. The acceptance bar is measurable (cargo test or Swift test exercising the wiring)
3. The user-facing surface (if any) is screenshot-verified via computer-use
4. No regression to baseline cargo / xcodebuild

This doc is **append-only for new rows** + **mutable for status column** — so it stays current as the integration progresses.

## §13. Cross-references

- **T3 per-terminal punch list** (current cycle deferrals by terminal): `docs/audits/UAS_ACS_PER_TERMINAL_PUNCH_LIST_2026_05_17.md`
- **RUN-cycle punch list** (prior cycle): `docs/audits/POST_RUN_BCDEF_PER_TERMINAL_PUNCH_LIST_2026_05_17.md`
- **Archeology findings**: `docs/audits/MULTI_TERMINAL_ARCHEOLOGY_FINDINGS_2026_05_17.md`
- **9-terminal driver scope locks**: `docs/CODEX_9_TERMINAL_PROMPTS_2026_05_16.md`
- **Sub-mission acceptance bars**: `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md` §4.A through §4.I
- **MAS_FUSION 43-row atlas**: `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md`
- **Cognitive Weight Class doctrine**: `docs/fusion/COGNITIVE_WEIGHT_CLASS_DOCTRINE_2026_05_04.md`
- **APP_ISSUES**: `docs/APP_ISSUES_AUTO_FIX.md` (ISSUE-2026-05-16-015 spans W-11/12/13/14)
- **T8 biometric doctrine** (Phase 0 reference for W-34 through W-39): `docs/fusion/BIOMETRIC_LOCK_DOCTRINE_2026_05_17.md` (on T8 branch — pending merge)

## §14. The "don't lose this" reminder

This backlog **only exists because of scope-lock**. Each terminal individually shipped real work; none of them could shipthe wiring between their work and the next terminal's work or the wiring to the user-facing surface. Without this doc, the substrate is permanently invisible and the user's intuition ("everything feels like docs") stays true.

The wiring phase is what turns "47K LOC of compiling substrate" into "the substrate is the moat" — the museum-piece-bar promise from the deep-investigation prompt's Manifesto. **Don't merge and then walk away.** Land the merges, then immediately enter Phase ε. The substrate is only as visible as the user-facing surfaces that consume it.

---

*Authored 2026-05-17 in response to the user's directive: "make sure u are keeping track of all the things we did not do because of forcing them to be isolated. make sure its comprehensive to make sure that you build merge and connect and wire and code the user facing stuff and connection between features when they are done with what they can do." This doc is the comprehensive ledger that directive asks for.*
