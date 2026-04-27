# Parallel Session Prompt — Epistemos implementation, no-collision

**Paste this entire document into a fresh Claude Code session running
in `/Users/jojo/Downloads/Epistemos`. It pins context, enforces
canonical alignment with all shipped plans, and lists the safe-to-edit
file ranges so two-three sessions can ship in parallel without
stepping on each other's commits.**

---

## 0 — Read these BEFORE any code changes (canonical, in order)

These docs are the **source of truth**; the codebase is the **derived
state**. If you ever feel a tension between the two, the docs win
unless they are flagged DRAFT.

1. `docs/REMAINING_WORK_INVENTORY.md` — *the* canonical "what's left"
   tracker. Tier 1 (XS/S, ship next), Tier 2 (M, 1-3 sessions each),
   Tier 3 (L, V1.5 candidates), Tier 4 (V1.5+ deferred). Plus the AR
   (audit-wire-up) and AP (audit-perf) item series.
2. `docs/WAVE_9_POLISH_AND_NATIVE.md` — high-level WHY: Wave 9 (Tier
   1-5 polish), Wave 10 (16-phase cognitive architecture from master
   plan), Wave 11 (App Intents + Trust + Eval + Auto/Manual mode),
   Wave 12 (Implementation Contract — version-pinned compass), Wave
   13 (master implementation plan with code snippets), Wave 14/15
   (App Intents native expansion: IndexedEntity, SnippetIntent,
   ControlWidget, etc).
3. `docs/WAVE_13_MASTER_IMPLEMENTATION_PLAN.md` — HOW: paste-ready
   code per phase with verified API line numbers from the macOS 26.4
   `.swiftinterface` files.
4. `docs/MASTER_SESSION_PROMPT.md` — session-startup protocol per
   `CLAUDE.md`.
5. `docs/AGENT_PROGRESS.md` + `docs/KNOWN_ISSUES_REGISTER.md` —
   build / V1 ship-gate state.
6. `CLAUDE.md` (project root) — non-negotiable constraints (no
   subprocess for inference, real APIs only, Swift 6 strict
   concurrency, GRDB pragma block, etc.).

The user's research corpus on disk is also canonical for ARCHITECTURAL
decisions — read these when a phase calls for design rationale:

### `~/Downloads/` root research drops (~/Downloads/*.md / *.txt)

- `compass_artifact_wf-0d84391a-...md` (2026-04-26 implementation
  contract — version-pinned crates, verified APIs)
- `compass_artifact_wf-5db24f87-...md` (App Intents beyond ten
  shortcuts on macOS 26 — the App Intents bible)
- `deep-research-report (2).md` (Doc 2 — the master-plan critique
  with the 4-layer architectural verdict)
- `deep-research-report (3).md` (App Intents research — fused into
  Wave 15)
- `Epistemos_ AI Cognitive Partner Analysis.txt` (Doc 1 — endorses
  master plan with hardware-native specifics)
- `master_plan_doc.md` (in `~/`, not `~/Downloads/`) — the user's 16-
  phase cognitive architecture
- `EPISTEMOS-FEATURE-SPEC.md`, `EPISTEMOS-CODEX-REMAINING.md`,
  `EPISTEMOS-CODEX-PLAN.md`, `EPISTEMOS-HERMES-PARITY-PLAN.md`,
  `EPISTEMOS-PLUGIN-PORTING-SPEC.md`
- `Architecture Hardening AppSupervisor, EpistemosMode, FFI Safety
  & Inference Resilience.md` (and the (1) variant)
- `Architecting a Resilient, Self-Healing macOS Personal Knowledge
  Management System_ Swift 6.2, Rust, and MLX Integration.md`
- `Cognitive Computing Capabilities for a Native macOS Personal
  Knowledge System.md`
- `Cognitive Exoskeleton Research Blueprint*.md` (multiple versions)
- `Custom Metal Mamba 2 Implementation for Epistemos Technical
  Specification.md`
- `CMS-X (final).md` + `CMS-X (v3).md` + `CMS-X Gemini.txt` + `CMS-X
  Perplexity A.md` + `CMS-X gemini V2.txt`

### `~/Downloads/` research subdirectories

- `~/Downloads/Advice/` — solo-dev best practices
- `~/Downloads/ambient/` — Halo / ambient retrieval research
- `~/Downloads/audit/` — past architectural audits
- `~/Downloads/final/` — final-pass research drops
- `~/Downloads/last feature after new agents/` —
  `LIVING_VAULT_ARCHITECTURE.md` + sprint-omega-5
- `~/Downloads/mass research folder/` — bulk research backlog
- `~/Downloads/meta-analytical-pfc/` — meta research patterns
- `~/Downloads/new features/` — `Cognitive Computing Capabilities
  for a Native macOS Personal Knowledge System.md`,
  `EPISTEMOS_DETERMINISTIC_PERF_PLAN.md`, `Epistemos Performance
  Optimization Roadmap.txt`, `claude opt 2.md`
- `~/Downloads/new make sures/` — verification checklists
- `~/Downloads/next batch of unsorted research/` — newer drops
- `~/Downloads/old research/` — prior-cycle research (still
  canonical for past decisions)
- `~/Downloads/opt/` — performance optimization plans

For deep dives on specific topics, also consult:
- `~/Downloads/arc8.txt` (typestate islands, bit-packed circuit
  breaker, honest FFI)
- `~/Downloads/sw.txt` (Metal zero-copy, B-tree text rope)
- `~/Downloads/Metal Mamba 2 Research Prompt.txt` (Blelloch scan)
- `~/Downloads/MLX Constrained Decoding Research.md` (grammar-
  constrained logit masking)
- `~/Downloads/Epistemos Graph Engine Optimal Performance
  Roadmap.md` (graph perf wins)
- `~/Downloads/vector quant.md` (KIVI per-channel KV quantisation)
- `~/Downloads/cap5_night_brain.md` (orphan + FSRS sources)

---

## 1 — DO NOT TOUCH these files (active in the primary session)

The primary session (`feature/landing-liquid-wave` branch HEAD) is
actively editing these. Editing them in your session will create merge
conflicts.

```
Epistemos/Engine/AFMSessionPool.swift                (just shipped)
Epistemos/Engine/FSRSDecayState.swift                (just shipped — actor)
Epistemos/Engine/IntakeValve.swift
Epistemos/Engine/SessionTelemetryClassifier.swift
Epistemos/Engine/ConversationStateClassifier.swift
Epistemos/Engine/QuarantineArchive.swift
Epistemos/Engine/CognitiveDepthOverlay.swift         (LRU bound just shipped)
Epistemos/Engine/EpistemosSidecar.swift
Epistemos/Graph/OntologyClassifier.swift
Epistemos/Views/Chat/MessageBubble.swift             (R1 ReadAloud just wired)
Epistemos/Views/Chat/ChatInputBar.swift              (R2 VoiceInput just wired)
Epistemos/Views/Sessions/SessionListView.swift       (AR8 just wired)
Epistemos/App/AppBootstrap.swift                     (AP4 launch prewarm)
Epistemos/Sync/VaultIndexActor.swift
Epistemos/Sync/NoteEntitySpotlightIndexer.swift
Epistemos/Intents/Schemas/CognitiveIntents.swift
Epistemos/Intents/Schemas/EpistemosFocusFilters.swift
Epistemos/Intents/Schemas/NotePreviewSnippet.swift
Epistemos/Intents/Schemas/EpistemosControlWidget.swift
Epistemos/Intents/Entities/NoteEntity+IndexedEntity.swift
Epistemos/Views/Settings/CognitiveSettingsSection.swift
Epistemos/Views/Settings/VoicePreferencesSection.swift
Epistemos/Views/Shared/ReadAloudButton.swift
Epistemos/Views/Shared/VoiceInputButton.swift
Epistemos/Views/Shared/ReasoningTrajectoryBadge.swift
Epistemos/Views/Shared/ModelVoicePickerSection.swift
Epistemos/State/PowerGate.swift
Epistemos/State/NightBrainScheduler.swift
docs/REMAINING_WORK_INVENTORY.md
docs/WAVE_9_POLISH_AND_NATIVE.md
docs/WAVE_13_MASTER_IMPLEMENTATION_PLAN.md
docs/PARALLEL_SESSION_PROMPT.md  (this file)
```

---

## 2 — SAFE to work on in your session

Pick **one of the three lanes below** so two parallel sessions don't
collide with each other either. Lanes are mutually exclusive — never
work on more than one at a time.

### LANE A — UI / Graph (no agent_core touches; no Tiptap touches)

These files are **not touched** by the primary session and don't share
any with each other. Pick all three; they're independent.

1. **AR4 Focus filter runtime guards** — read
   `EpistemosFocusKeys.forceLocalModelsOnly` /
   `EpistemosFocusKeys.lowDistraction` /
   `EpistemosFocusKeys.muteHaloRecallChip` /
   `EpistemosFocusKeys.agentInterruptsDisabled` from
   `Epistemos/Intents/Schemas/EpistemosFocusFilters.swift`
   (keys-constants only — DO NOT EDIT that file).
   Add runtime guards to:
   - `Epistemos/State/ModelRouterState.swift` (or wherever model
     selection happens) — when `forceLocalModelsOnly == true` and the
     user picks a cloud model, fall back to local with a one-line
     "Focus" badge in the model picker explaining why.
   - `Epistemos/Views/Halo/HaloButton.swift` — hide the chip when
     `muteHaloRecallChip == true`.
   - The agent-suggestion popup view (`Epistemos/Views/Omega/` likely
     candidate) — gate proactive suggestions on
     `agentInterruptsDisabled == false`.
   - `Epistemos/Views/Landing/LandingView.swift` if there's a
     "low-distraction mode" CSS class — toggle off when
     `lowDistraction == true`.
   Effort: S. **Touch only the read sites; never the keys file.**

2. **AR6 MetalGraphView depth integration** —
   `Epistemos/Views/Graph/MetalGraphView.swift` (the only file you
   touch here). Read `CognitiveDepthOverlay.shared.altitude(for:)`,
   `radiusScale(for:)`, `colorTint(for:)` per node draw. The overlay
   API is stable — DO NOT EDIT `Epistemos/Engine/CognitiveDepthOverlay.swift`.
   Effort: M.

3. **AR7 FSRS forgotten-notes UI** — entirely NEW file
   `Epistemos/Views/Sessions/FSRSReviewSidebar.swift`. Read
   `FSRSDecayStore.shared.topAtRisk(...)` (it's an `actor` now per
   AP5 — call sites are `await store.topAtRisk(...)`). Render a
   sidebar / sheet listing high-risk notes with a "Reviewed" button
   that calls `store.recordReview(noteId:grade:)`.
   Effort: M.

### LANE B — Tiptap / JS bundle (no Swift outside the bridge)

Touch ONLY `js-editor/src/**` and `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift`.
The chrome view is borderline — coordinate via PR review if you also
need to add new bridge messages.

1. **AP1 WKWebView `evaluateJavaScript` batching** — `js-editor/src/`
   side: a window-attached batcher that coalesces 3-5 commands into
   one `webkit.messageHandlers.epdoc.postMessage` per CADisplayLink
   tick. Swift side: `EpdocEditorChromeView.swift` Coordinator's
   `evaluate(_:)` enqueues into a `CADisplayLink`-driven flush. Per
   the perf agent: 3-4 JS evals per paste → 1; latency 100-150 ms →
   30-40 ms.

2. **AP8 Tiptap JS-side debounce on `update` events** — pure JS work
   in `js-editor/src/extensions/`. `editor.on('update', …)` currently
   fires per-keystroke; wrap in 200ms debounce so the bridge sees ~5
   contentDidChange messages per second of typing (down from ~50). Per
   the perf agent: -80% complexity-meter CPU.

3. **AR5 IntakeValve in Tiptap paste handler** — new file
   `js-editor/src/extensions/paste-classifier-bridge.ts`. Tiptap's
   paste handler calls `webkit.messageHandlers.epdoc.postMessage({
   type: 'classifyPaste', text: pastedText })` over the bridge.
   Swift-side handler (already in `EpdocEditorChromeController` /
   `Coordinator`) calls
   `IntakeValve.shared.classifyAndRoute(pastedText, anchor:
   QuarantineAnchor(contextKind: "note", contextId: noteId))` —
   already shipped. The .ts file is the bridge that wires the JS
   paste event to the existing Swift API.

### LANE C — Intent additions (no shared-state touches)

These add NEW intent files without modifying existing intents. The
primary session is touching `Epistemos/Intents/Schemas/CognitiveIntents.swift`
and `EpistemosShortcutsProvider.swift` actively — DO NOT TOUCH those.
Add NEW files alongside.

1. **R5 UndoableIntent on destructive ops** — new file
   `Epistemos/Intents/Schemas/UndoableNoteIntents.swift`. Define
   `DeleteNoteIntent` + `ArchiveNoteIntent` conforming to
   `AppIntent` + the new macOS 26 `UndoableIntent` protocol
   (`AppIntents.swiftinterface` line 1395). `perform()` records the
   undo via `UndoManager` (system-supplied via the protocol). System
   Cmd-Z then works from Spotlight + extensions. **DO NOT register
   in EpistemosShortcutsProvider** (10-cap is full); the intents are
   discoverable in Shortcuts.app + Spotlight without consuming a
   slot.
   Effort: S.

2. **R6 Visual Intelligence schema scaffold** — new file
   `Epistemos/Intents/Schemas/VisualIntelligenceIntents.swift`.
   `@AppIntent(schema: .visualIntelligence.semanticContentSearch)`
   + `IntentValueQuery<SemanticContentDescriptor, NoteEntity>`. The
   trigger surface is iPhone-only on macOS 26.0 today (per compass
   artifact wf-5db24f87) but ships against macOS 26+ for forward
   compatibility — the moment Apple lights up Visual Intelligence on
   Mac (rumored 26.x), the intent surfaces with zero additional
   work. Effort: S.

---

## 3 — Hard rules (NEVER violate)

Per the project's `CLAUDE.md`:

- **NO SIDECAR for INFERENCE.** All inference in-process via Rust FFI
  or MLX-Swift. Hermes subprocess is for ORCHESTRATION, not
  inference.
- **REAL APIs ONLY.** Every cloud endpoint verified against provider
  docs. No fake features.
- **HONEST CAPABILITY GATING.** Local models get fast/thinking/research.
  Cloud models get agent/liveAgent.
- **Zero test regressions** against the 2,679-test suite.
- **PRESERVE THINKING BLOCKS.** When stop_reason is "tool_use", pass
  the ENTIRE content array back including thinking blocks +
  signatures.
- **STREAM EVERYTHING.** Forward every token to the delegate
  immediately. No buffering.
- **AGENT DECIDES TERMINATION.** max_turns is a safety rail.
- **API keys in macOS Keychain**, NEVER UserDefaults.
- **Use `@Observable`, not `ObservableObject`.**
- **Use Swift Testing (`@Test`, `#expect`)** for new tests.
- **All inference on background actors** — never block @MainActor.
- **Every unsafe block gets `// SAFETY:` comment**.
- **No `try!`, no force-unwraps, no `print()`** in production paths.
- **DispatchQueue.main.async in UniFFI callbacks**, NEVER `.sync`
  (deadlock).
- **Only commit when the user explicitly asks** unless the
  per-task-type rules in `CLAUDE.md` override.
- **Never edit .xcodeproj directly** — use xcodegen (project.yml).
- **Don't bump uniffi past 0.28** without dedicated session per
  Wave 13 §"UniFFI status" — 0.30/0.31 break method-checksums.

## 4 — Build / verify contract per commit

After every commit:
```bash
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 \
  | grep -E "( error:|BUILD SUCCEEDED|BUILD FAILED)" \
  | grep -v "HologramOverlay\|VaultIndexActor\|associated value\|build-rust\|module map" \
  | head
```

Tests for the touched layer:
```bash
xcodebuild test -scheme Epistemos -destination 'platform=macOS' \
  -only-testing:EpistemosTests/<YourSuite> 2>&1 | grep -E "(✔|✘|TEST SUCCEEDED|TEST FAILED|error:)" | head
```

If you change `Epistemos/Engine/FSRSDecayState.swift` semantics (you
shouldn't — it's actor-isolated now), re-run
`-only-testing:EpistemosTests/FSRSDecayStateTests` and confirm 6/6
still pass. Same for `EpistemosSidecarTests` (10 tests),
`ShadowVaultBootstrapperTests` (5 tests),
`EpdocPasteClassifierTests` (~8 tests).

## 5 — Commit message contract (per `CLAUDE.md`)

```
phase4(<wave-id>): <imperative summary, ≤80 chars>

<2-3 paragraph body explaining WHY + the canonical reference (Wave 9 / Wave 13
§"…", or the master plan phase, or compass artifact section). Always
include the source-of-truth doc + section quoted in the commit.>

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

Match the existing format from any recent commit (`git log --oneline
-10`).

## 6 — Sync rhythm

- Every commit: push to the branch so the primary session sees it via
  `git fetch`.
- If you find drift (a doc claim that doesn't match shipped code),
  flag it in the commit message + add a `[Drift]` note to
  `docs/REMAINING_WORK_INVENTORY.md`.
- DO NOT close items in `REMAINING_WORK_INVENTORY.md` directly —
  signal completion via the commit message and let the primary
  session reconcile the inventory in its next sweep.

---

## 7 — When you're done with your lane

Reply in a SINGLE message:
1. The lane you took (A / B / C)
2. The commit hashes you shipped
3. Anything you discovered that the primary session needs to know
4. Whether your tests / build are green

The primary session will reconcile your work into
`REMAINING_WORK_INVENTORY.md` and the plan docs.

Pin this file open in your editor while you work; refer back to §1
(do-not-touch list) before every Edit / Write call.
