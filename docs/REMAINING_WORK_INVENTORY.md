# Remaining Work Inventory — when this is empty, the doc stack is done

Authored 2026-04-26 after the Wave 15 App Intents native expansion
pass. This is the canonical "what's left from the entire plan" doc:
when every item below is checked off, [WAVE_9_POLISH_AND_NATIVE.md]
+ [WAVE_13_MASTER_IMPLEMENTATION_PLAN.md] + the master plan + all
research drops can be archived. **Nothing here is research-only — every
remaining item has a verified API path or shipped scaffold to build on.**

## 🆕 2026-04-26 audit pass — 3 deep agents reported

Three parallel audit agents (perf-optimization, wire-up gaps,
build/test verification) confirmed:
- **Build status**: YELLOW. Build clean, 0 errors, 4 test suites
  passing (Sidecar 10/10, FSRS 6/6, ShadowVaultBootstrapper 5/5,
  EpdocPasteClassifier ~8). Rust FFI exports clean (7/7 shadow
  symbols).
- **Two blockers** at audit time:
  - Blocker #1 NoteEntity Spotlight donation — ✅ **fixed
    (9a91db3a)** — VaultIndexActor now donates typed NoteEntity
    batches alongside the legacy CSSearchableItem path.
  - Blocker #2 EpistemosControlWidget needs `.appex` extension
    target — still pending (xcodegen change).
- **Perf wins** (10 ranked) — top 3 closed in 4edb66b4
  (QuarantineArchive off-MainActor I/O), the rest land as Tier 1/2
  items below.
- **Wire-up gaps** (10 critical) — R3 VoicePrefs in Settings closed
  in 4edb66b4; the rest are R1/R2 + new R-series below.

Audit-driven additions to the remaining list (ranked by ROI):

| ID | Item | Source | Effort |
| -- | ---- | ------ | ------ |
| **AR1** | EpistemosControlWidget xcodegen `.appex` extension target | build/test agent Blocker #2 | M |
| **AR2** | ConversationStateClassifier wired into agent dispatch (replace naive transcript truncation in `agent_core/src/compaction.rs`) | wire-up agent gap #4 | M |
| **AR3** | SessionTelemetryClassifier replaces existing free-form summarizer call sites | wire-up agent gap #5 | S |
| **AR4** | Focus filter runtime guards (`forceLocalModelsOnly` / `lowDistraction` etc. read at runtime) | wire-up agent gap #6 | S |
| **AR5** | IntakeValve called from pasteboard handler (chat composer + Tiptap paste handler) | wire-up agent gap #7 | S |
| **AR6** | MetalGraphView reads CognitiveDepthOverlay for altitude/color per-node | wire-up agent gap #8 | M |
| **AR7** | FSRS "forgotten notes" sidebar / dashboard UI | wire-up agent gap #9 | M |
| **AR8** | ReasoningTrajectoryBadge placed next to session results in chat history | wire-up agent gap #10 | XS |
| **AP1** | Batch WKWebView `evaluateJavaScript` calls (perf Win #1: 100-150ms → 30-40ms paste-to-doc latency) | perf agent | M |
| **AP2** | Sidecar JSON full-object cache (CognitiveDepthOverlay reads only `depth` today; cache the entire decoded sidecar) | perf agent Win #2 | S |
| **AP4** | AFM session prewarm at app launch (perf Win #4: first-classify 200ms → 60ms) | perf agent | S |
| **AP5** | FSRSDecayStore: replace `DispatchQueue.sync` with `actor` (perf Win #5: 5× scan throughput) | perf agent | S |
| **AP6** | AFMSessionPool — share warm sessions across OntologyClassifier + IntakeValve + ConversationState (perf Win #6: 40% token reduction) | perf agent | M |
| **AP7** | Vault sidecar prefetch on app launch (perf Win #7: graph first-render 1000ms → 100-150ms) | perf agent | M |
| **AP8** | Tiptap JS-side debounce on `update` events (perf Win #8: -80% complexity-meter CPU) | perf agent | S |
| **AP9** | EpdocPasteClassifier: pre-compile Swift 6.2 `Regex` patterns once (perf Win #9: 8ms → 1ms paste classify) | perf agent | XS |
| **AP10** | ConversationStateClassifier rebuild off MainActor (perf Win #10: -300-400ms agent latency) | perf agent | S |

## ✅ Already shipped (do not re-do)

Foundation chain through Wave 15:
- W8.7 Halo vault crawl + Rust FFI binding + AppBootstrap wiring
- W9.1 + W9.1.b AVSpeechSynthesizer (TTS) + per-model voice persona
- W9.3 Reasoning Trajectory Badge
- W10.4 + W10.4-FIX BootstrapPacket wire-up + cache padding
- W10.10 NightBrain launchd plist + PowerGate + scheduler + AppBootstrap fallback
- W10.1 OntologyClassifier (Phase 1 AFM `@Generable`) + sidecar wire-up
- W10.8 CognitiveDepthOverlay (Phase 8 L1/L2/L3)
- W10.9 SessionTelemetryClassifier (Phase 9 `@Generable` distillation)
- W10.11 EpistemosSpeechAnalyzer (Phase 11 macOS 26 STT)
- W10.12 EpistemosSidecar substrate + 10 source-guard tests
- W10.14 IntakeValve (synchronous AFM intercept)
- W10.15 QuarantineArchive + AmbientRetrievalToggle
- W10.16 ConversationStateClassifier (real-time stenographer)
- W10.2 FSRSDecayState + 6 source-guard tests
- W11.1 Cognitive AppShortcuts (5 intents in the 10-cap catalogue)
- W11.4 + W15 VoicePreferences (Auto/Manual mode for 5 voice surfaces)
  + VoiceInputButton + VoicePreferencesSection
- W14 donate() on every cognitive intent + EpistemosFocusFilter
- W14.1 NoteEntity → IndexedEntity (Spotlight semantic search)
- W15.2 NotePreviewSnippet (inline rich Spotlight previews)
- W15.3 EpistemosControlWidget (Tahoe Control Center quick capture)
- W15.4 supportedModes migration on all cognitive intents

---

## 🟡 Remaining — sequenced by ROI / blocking-other-items

### Tier 1 — XS / S items, ship next session (~1-2 hr each)

| ID | Item | Why now | Effort |
| -- | ---- | ------- | ------ |
| **R1** | Wire `ReadAloudButton` into agent chat-message bubbles | TTS foundation done (W9.1); needs the call site in `ChatView` / wherever assistant messages render. Honour `VoicePreferences.shared.agentResponseTTS` (auto = speak on stream completion; manual = button only). | XS |
| **R2** | Wire `VoiceInputButton` into chat composer + note editor | Symmetric to R1 — ChatView composer's `TextField` + the prose editor's text input both gain a mic button. | XS |
| **R3** | Wire `VoicePreferencesSection` into Settings | One Form section drop into `Settings/SettingsView` (or wherever Settings is composed). | XS |
| **R4** | `OpenNoteIntent` + `TargetContentProvidingIntent` | Declarative SwiftUI nav per Wave 15 modern API replacements. Needs a SwiftUI router for note URLs. | S |
| **R5** | `UndoableIntent` on destructive ops (DeleteNote, ArchiveThought) | XS per intent; system Cmd-Z works from Spotlight + extensions. | S |
| **R6** | Visual Intelligence schema scaffold (`@AppIntent(schema: .visualIntelligence.semanticContentSearch)` + `IntentValueQuery<SemanticContentDescriptor, NoteEntity>`) | Forward-compat for screenshot search; ships against macOS 26+. | S |

### Tier 2 — M items, 1-3 sessions each

| ID | Item | Notes | Effort |
| -- | ---- | ----- | ------ |
| **R7** | App Intents Extension target (`EpistemosWidgets.appex` / `EpistemosAppIntents.appex`) | xcodegen wiring for a separate bundle so widgets render in Control Center + cold-start drops to ~300 ms. Requires: app group entitlement, shared GRDB store via WAL, Rust dylib in `Contents/Frameworks/` shared via `@rpath`. | M |
| **R8** | NightBrainHelper executable target | Companion to W10.10 LaunchAgent — separate macOS executable in `Contents/MacOS/NightBrainHelper` so launchd's 03:00 wake actually does work. xcodegen target + matches the plist `BundleProgram` path. | M |
| **R9** | `ChatEntity` + `ThoughtEntity` (or `BrainDumpEntity`) conforming to `IndexedEntity` | Same pattern as W14.1 NoteEntity. Needs lightweight value-type shadow entities mirroring SDChat / QuarantineEntry. | M |
| **R10** | OntologyClassifier ↔ EntityExtractor migration | Replace the naive keyword path in `Epistemos/Graph/EntityExtractor.swift` with `OntologyClassifier.classifyAndPersist`. Behind the `OntologyClassifier.shared.readiness() == .available` gate. | M |
| **R11** | `ConversationStateClassifier` integration into agent dispatch | After every user turn, rebuild `ConversationState` and pass it to the next prompt instead of the full transcript. Replaces the naive truncation in `agent_core/src/compaction.rs`. | M |
| **R12** | FSRS-6 GRDB persistence + Rust crate wire-up | Add `fsrs = "5.2.0"` to `epistemos-core/Cargo.toml`; mirror `FSRSDecayRow` in Rust; UniFFI bridge so the in-memory Swift store has a real persistence layer. | M |
| **R13** | sqlite-vec + petgraph foundation | Add `sqlite-vec = "0.1.9"` + `petgraph = "0.8.2"` to `epistemos-core/Cargo.toml`; vec0 virtual table + StableDiGraph projection per the Wave 13 §"Phase 8" code snippet. | M |

### Tier 3 — L items, 3-7 sessions each

| ID | Item | Notes | Effort |
| -- | ---- | ----- | ------ |
| **R14** | UniFFI 0.28 → 0.29.5 bump + Issue #2818 SwiftPM target separation | Compass-recommended; deferred as high-risk dedicated session. Requires regenerating bindings + verifying the patch-uniffi-bindings.py post-processor still applies cleanly. | L |
| **R15** | Benchmark harness | AFM `@Generable` round-trip latency + MLX Qwen3 0.6B 4-bit tok/s under thermal pressure + sqlite-vec KNN at 100 k vectors + UniFFI callback throughput. Compass §"three things to do this week" item #2. | L |
| **R16** | Phase 13 ETL Rust crawler (apalis-sqlite + ignore + xxh3) | Background job that converts loose `.md` / PDF → structured sidecar via AFM 3B with the hardcoded code-file exclusion list. Extends W8.7 ShadowVaultBootstrapper. | L |

### Tier 4 — V1.5+ (deferred per master plan)

These are explicitly scoped to V1.5 and beyond. Listed for completeness:

- W9.21 Honest FFI (`Arc::into_raw` + `~Copyable` wrappers)
- W9.22 Typestate Islands for MLX/subprocess lifecycles
- W9.23 Bit-packed circuit breaker
- W9.24 Metal zero-copy graph buffers (`makeBuffer(bytesNoCopy:)`)
- W9.25 Grammar-constrained logit masking (mlx-swift-structured)
- W9.26 B-tree text rope (`crop` crate + UTF-16 metrics)
- W9.27 Append-only OpLog + replay (event-sourced graph)
- W9.28 Blelloch scan in Metal for Mamba-2 prefill
- W9.29 Thermal-aware breaker throttling
- W9.30 KIVI per-channel/per-token KV quantisation
- W9.6 Cost dashboard + per-session budget gate
- W9.7 Vault sidebar selector
- W9.8 Approval modal (PausedForApproval surface)
- W9.10 TurboQuant KV cache compression
- W9.11 Create ML personalized embeddings
- W9.12 Orphan Knowledge Rediscovery (Night Brain digest)
- W9.13 Daily Notes UI + FSRS surfacing
- W9.14 Block References + Transclusion
- W9.15 Static compile-time view routing macro

---

## 🎯 Pre-TestFlight ship gates (orthogonal — needed for V1)

These are NOT in the Wave 9-15 feature roadmap; they're release-mechanics
gates from the V1 ship plan. **All three must close before submission.**

| Gate | Item | Effort |
| ---- | ---- | ------ |
| P0-2 | Reliability fresh baseline (re-run 5-gate suite post-Phase-R) | ~2 hr |
| P0-3 | TestFlight submission metadata (screenshots, App Review notes — `MAS_APP_REVIEW_NOTES.md` already drafted) | ~4 hr |
| P0-4 | mas-sandbox feature-gating spot-check (`agent_core/src/tools/registry.rs` + `omega-mcp/src/pty.rs`) | ~30 min |

---

## How to use this doc

1. After every implementation session, mark the items shipped at the top.
2. When **Tier 1 + Tier 2 are both empty** AND **all 3 pre-TestFlight gates close**, V1 is shippable.
3. Tier 3 items can land after V1 ships; they're V1.5 work that improves
   the substrate without blocking release.
4. Tier 4 is explicitly future work — listed so we don't lose track of
   the research, but **NOT a release blocker**.

The other plan docs ([WAVE_9_POLISH_AND_NATIVE.md], [WAVE_13_MASTER_IMPLEMENTATION_PLAN.md])
remain canonical for **WHY** + **HOW** (architectural rationale + paste-ready
code snippets). This doc is canonical for **WHAT IS LEFT**.

When this `## 🟡 Remaining` list shrinks to zero, you can `git rm` the
plan docs + the entire `~/Downloads/` research corpus — every load-bearing
fact has been folded into the codebase + commit history at that point.
