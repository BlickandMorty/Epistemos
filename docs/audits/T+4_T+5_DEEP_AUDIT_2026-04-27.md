# T+4 + T+5 Deep Audit — End-to-End Wiring Verification

**Date**: 2026-04-27
**Audit floor**: ac8c6d28
**Scope**: Verify "shipped pre-cutoff" claims for T+4.5 / T+4.6 / T+4.9 + T+5 V0/V1 dual-system question + drift queue (Q2/Q3/Q4)
**Verdict**: 🔴 **MULTIPLE CRITICAL INTEGRATION GAPS** between scaffolded substrate and end-to-end production behavior

This audit was triggered when the user pushed back on premature "verified shipped" calls. Findings confirm those calls were based on file existence + symbol presence, not on production wiring.

---

## Critical findings

### F1 — `.epdoc` Document NSDocument has NO window presentation

**File**: `Epistemos/Engine/EpdocDocument.swift`

**Gap**: `EpdocDocument: NSDocument` implements `read(from:ofType:)` + `fileWrapper(ofType:)` correctly (round-trip tested). BUT it has **NO** `makeWindowControllers()` override + NO SwiftUI `DocumentGroup` scene wiring. When a user double-clicks a `.epdoc` file in Finder, NSDocument loads the package into memory and **NO window is presented**.

**Severity**: 🔴 BLOCKING — feature is invisible to users.

### F2 — No "File > Open Document" menu item

**File**: `Epistemos/App/EpistemosApp.swift` lines 960–1055 (`EpistemosCommands`)

**Gap**: No menu command invokes `NSDocumentController.shared.openDocument(_:)`. There is no programmatic way to trigger document open from inside the app. Combined with F1, the entire `.epdoc` open path is unreachable.

**Severity**: 🔴 BLOCKING.

### F3 — Tiptap bundle staging unverified

**Path**: `Epistemos/Resources/Editor/` — directory does NOT exist on disk

**Gap**: `build-tiptap-bundle.sh` (line 92) targets this path; project.yml line 100 registers it as a `preBuildScript`. But the destination directory is not present. Either the build was never successfully run OR the directory is created at xcodebuild time but not committed. At runtime, `EpdocEditorURLSchemeHandler` will fail with 404 when WKWebView requests `epistemos-doc:///editor.html`.

**Severity**: 🟡 medium-high — actual state depends on whether xcodebuild run produces the directory; needs runtime smoke verification.

### F4 — `contentDidChange` data is silently DROPPED

**File**: `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift` lines 97–101

**Gap**: The `EpdocEditorChromeController.handleBridgeMessage(_:)` switch has:
```swift
case .contentDidChange:
    break  // for future diff-tracking instrumentation
```
Tiptap's `onUpdate` hook fires correctly, posts via `WKScriptMessageHandler`, decodes via `EpdocBridgeMessage`, reaches the controller — and then **the JSON payload is discarded**. The connection from "user types" to "anything happens" does not exist.

**Severity**: 🔴 BLOCKING — keystrokes are non-persistent in the canonical Tiptap path.

### F5 — `EpdocEditorSavePipeline` is orphan code

**File**: `Epistemos/Engine/EpdocEditorBridge.swift` lines 350–377

**Gap**: `EpdocEditorSavePipeline` is defined as a 300ms-debounced save pipeline taking an arbitrary `save: @MainActor (Data) -> Void` closure. **Zero production call sites construct it.** The pipeline is well-designed but never instantiated.

**Severity**: 🔴 BLOCKING — even if F4 were fixed, there's no debouncer wired in.

### F6 — `ProseMirrorMarkdownProjector` orphan

**File**: `Epistemos/Models/ProseMirrorMarkdownProjector.swift`

**Gap**: Projector exists with `static func project(_ doc:)` + `static func project(jsonData:)`. **Never called from any save path.** `EpdocPackage.shadowMarkdown` is a `Data?` slot that stays nil/stale.

**Severity**: 🟡 medium — implementation plan §151 says "Markdown shadow regenerates from canonical on every save"; not honored.

### F7 — `search_blocks.jsonl` projector does NOT exist at all

**Gap**: `EpdocPackage.searchBlocksJSONL: Data?` slot exists. **No code converts ProseMirror JSON to one-block-per-line JSONL.** No projector class, no helper, nothing. T+4.4 (readable_blocks schema) shipped without the producer that would feed it.

**Severity**: 🔴 BLOCKING — the FTS index has no data source for `.epdoc` documents.

### F8 — `ReadableBlocksIndex.replaceAllForArtifact()` never called from production

**File**: `Epistemos/Sync/ReadableBlocksIndex.swift` line 252

**Gap**: Only test call sites in `EpistemosTests/ReadableBlocksIndexTests.swift` lines 84, 170. **Zero production callers.** Combined with F7, the `readable_blocks` table stays empty for `.epdoc` documents in production.

**Severity**: 🔴 BLOCKING.

### F9 — `MutationEnvelope` never emitted from production

**File**: `Epistemos/Models/MutationEnvelope.swift`

**Gap**: T+4.8 deliberation brief explicitly noted "ship the type only; T+13 wires call sites." But the gap is real today — no production code instantiates `MutationEnvelope` on `.epdoc` save (or any other mutation event). NSDocument autosave still uses NSNotification semantics.

**Severity**: 🟡 medium — type is correct + parity-tested; call-site rewiring deferred to T+13.

### F10 — No `os_signpost` instrumentation on `.epdoc` save path

**Gap**: HaloEditorBridge has `halo.editorTextDidChange` signpost (`HaloEditorBridge.swift:75-83`). The `.epdoc` save pipeline (handler, debouncer, NSDocument.fileWrapper, projection regeneration, FTS update) has no signpost coverage. Performance budget (`< 16 ms` typing latency p99 per `ambient_V1_DECISION.md`) cannot be measured.

**Severity**: 🟡 medium — non-blocking but blocks measurement.

### F11 — No end-to-end integration test

**Gap**: Per-component tests exist (EpdocPackageTests, EpdocDocumentTests, EpdocEditorBridgeTests, ReadableBlocksIndexTests). **None exercise the full keystroke → save → FTS pipeline.** Component boundaries are tested; integration between components is not.

**Severity**: 🟡 medium — without integration test, regressions in any of the bridges would silently break the user-visible feature.

### F12 — V0 vs V1 recall systems still parallel

(Already known from T+5 audit, restated here for completeness.)

`ContextualShadowsState/Button/Panel` (SwiftUI struct) is wired in production via `AppBootstrap.swift:802` + `ChatInputBar.swift:75` + `ProseEditorRepresentable2.swift:915`. `HaloController/HaloButton/ShadowPanel/ShadowPanelController` (NSPanel + 6-state FSM, doctrine-canonical) ships but `ShadowPanelController` is only referenced in tests. T+5 fixes (`shadow_warm()` + trailing-edge anchor) shipped to V1 path which isn't on production hot path.

**Severity**: 🟡 architectural decision queued (task #29) for T+13.

---

## T+4.9 graph edges status

`GraphEdgeType.producedDuring/.generatedBy/.derivedFrom/.summarizes` cases are declared at `Epistemos/Models/GraphTypes.swift:264-281`. The 14-case enum covers all 7 ArtifactKinds via `mapsToArtifactKind()` bridge.

**Production edge emission**: not verified in this audit. Agent runs would need to actually emit `producedDuring(artifact, run)` edges into the graph during execution. T+13 hardening covers this; not blocking T+4 ship.

---

## T+8 Code editor status (per parallel survey)

Architecture LOCKED + foundation working. ~40% of T+8 spec is shipped:

**Shipped:**
- `CodeEditorView.swift` (3,992 LOC, fully functional via CodeEditSourceEditor 0.15.2)
- `SyntaxCoreService.swift` (130 LOC, production-wired but opt-in via `EPISTEMOS_USE_SYNTAX_CORE` env flag)
- `LiveCodeEditorController` + `SyntaxCoreLiveHighlighter` (tests pass)
- SwiftTreeSitter 0.25.0 SPM dep
- LSP transport layer (JSON-RPC codec at `LSPMessage.swift`)
- `os_signpost` (3 intervals — minimal)

**Phase-S polish gaps (~2-day work each):**
- Theme-aware line gutter rendering (state exists, CATextLayer pool doesn't)
- `Binding<String>` 300ms debounce (spec'd, not implemented)
- Outline cache + diff (hash-based)
- Viewport-scoped syntax highlighting (Patch 6 BLOCKED — primary path still uses CodeEditSourceEditor's internal pipeline)

**Pro / phase-K+ deferred:**
- Code folding UI + Rust FFI (spec written at `FEATURE_SPEC_TOC_AND_FOLDING.md`)
- Symbol TOC strip
- SourceKit-LSP subprocess integration

**T+8 deliberation brief**: separate file at `docs/audits/deliberation/T+8_workspace_dual_editor_deliberation_20260427.md`.

---

## Drift queue status

| Q | Item | Status |
|---|---|---|
| Q1 | §3.5 doctrine refresh post-T+4.8 | ✅ closed (MutationEnvelope shipped T+4.8) |
| Q2 | §6 V1.10 promote 🟡 → ✅ | ⏳ post-consolidation-commit |
| Q3 | WS2.1 4-mode vs 5-mode enum reconciliation | ⏳ T+13 |
| Q4 | WS1.1 ~42 models vs 17 spec | ⏳ T+13 / T+15.8 |

---

## Action plan (priority order)

### Tier 1 — Block production .epdoc end-to-end (must fix before T+4 ship)

1. **Fix F4 + F5**: change `EpdocEditorChromeView.swift:97-101` to forward `contentDidChange` to a save pipeline; instantiate the pipeline in `EpdocEditorChromeController`.
2. **Build F7**: ProseMirror → readable-block-row projector. Convert content.pm.json → `[ReadableBlock]`. Save the JSONL slot in package + feed into `ReadableBlocksIndex`.
3. **Fix F8**: wire save pipeline → `ReadableBlocksIndex.replaceAllForArtifact()`. Closes the FTS update gap.
4. **Add F11 smoke harness**: Swift integration test exercising the data plumbing (create .epdoc → mutate content → assert FTS visibility + manifest hash + projection regeneration).

### Tier 2 — User-visible Document feature

5. **Fix F1**: `EpdocDocument.makeWindowControllers()` presents `EpdocEditorChromeView` in a hosted SwiftUI window.
6. **Fix F2**: Add File > Open Document menu in `EpistemosCommands`. Verify `NSDocumentController` opens .epdoc files.
7. **Verify F3**: Confirm `Epistemos/Resources/Editor/` is created by xcodebuild (run a build; if not, fix the build script).

### Tier 3 — Polish

8. **F6**: regenerate `shadow.md` on save (call `ProseMirrorMarkdownProjector.project(jsonData:)`).
9. **F9**: emit `MutationEnvelope` on save. Defer to T+13.
10. **F10**: add `os_signpost` to save pipeline (`epdoc.bridge.tx`, `epdoc.save`, `epdoc.projections`, `epdoc.fts`).

### Tier 4 — T+8 polish (per workspace_epistemos_code_verdict.md Phase S)

11. Theme-aware line gutter (6 hrs)
12. `Binding<String>` 300ms debouncing (2 hrs)
13. Outline cache + diff (4 hrs)
14. Viewport-scoped highlighting (1 day, unblocks Patch 6)
15. Code folding (2 days, includes Rust FFI)
16. Symbol TOC strip (1 day)

### Tier 5 — Architectural decisions

17. V0 → V1 recall system migration (task #29) — T+13.
18. Drift Q2/Q3/Q4 close — T+13.

---

## What this session ships next

Per user direction "literally all three approaches":

- **(a) Deep audit** ✅ this document
- **(b) Smoke harness** → `EpistemosTests/EpdocEndToEndSmokeTests.swift` (next)
- **(c) T+8 before T+6** → T+8 deliberation brief + select Phase-S polish items

Tier 1 wiring fixes (F4/F5/F7/F8) ship in this session. Tier 2 NSDocument window + File>Open menu surface for user review (UX-load-bearing).
