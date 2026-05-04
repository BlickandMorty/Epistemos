# Research Fusion Notes - Epistemos - 2026-04-30

> **Scope:** Phase 0 synthesis only. No source changes. No merges. No stash pops.
> **Floor:** `ac8c6d28` on `feature/landing-liquid-wave`.
> **Inputs:** `KIMI_FUSION_REVIEW_2026_04_30.md`, `WORKTREE_INVENTORY_2026_04_30.md`, repo authority docs, April 30 fusion packet, targeted external research.

## 1. Authority Hierarchy

Use this order when sources conflict:

1. Current repo code and fresh passing logs.
2. `AGENTS.md`, `CLAUDE.md`, `PLAN_V2.md`, `BOLTFFI_AUDIT_2026_04_15.md`, `CODEX_VERIFIED_STATE_2026_04_25.md`, and canonical consolidated authority docs.
3. April 30 fusion packet in `docs/fusion/` and `/Users/jojo/Downloads/*_2026_04_30.md`.
4. Worktrees as donor evidence only.
5. Older research and external notes as inspiration only.

Core/MAS safety wins over novelty. Typed substrate wins over raw UI demos. Current code wins over speculative research.

## 2. Source Hierarchy And Active Meaning

| Source cluster | Authority | Active meaning | Handling |
|---|---:|---|---|
| Main repo at `ac8c6d28` | Highest | Active floor, but dirty with 503 modified and 789 untracked status entries | Do not overwrite. Audit first. |
| `AGENTS.md` / `CLAUDE.md` | Highest process authority | Minimal fixes, test-first, no protected-path edits, no Pro leakage | Enforce on every slice. |
| `PLAN_V2.md` | High | Current architecture direction and sequencing | Use as architecture guardrail. |
| `BOLTFFI_AUDIT_2026_04_15.md` | High | BoltFFI remains gated until benchmark and parity proof | Do not enable prototype. |
| `CODEX_VERIFIED_STATE_2026_04_25.md` | High | Marks recoverable-but-unverified work, stash risk, and verified state | Treat stashes as suspect. |
| April 30 fusion packet | High | Current fusion execution frame | Use, but require fresh evidence before implementation. |
| Quick Capture worktree | Donor | Rich capture/agent patterns | Extract narrow slices only. |
| Simulation/Theater worktree | Donor | Event replay and Pro Theater concepts | Core-safe event patterns only; Theater is Pro. |
| Hermes worktree | Donor | Provider chain, tool parity, session persistence | Pro-only unless explicitly Core-safe. |
| Honest Handle worktree | Donor | FFI safety ideas | Defer until benchmark and safety brief. |
| Inspiring-Heisenberg worktree | Donor | Benchmark harness, BoltFFI prototype, Swift 6 fixes | Extract benchmark harness first. |

## 3. Superseded Or Missing Names

These names appear in older prompts or context but are not active authority at the expected repo paths:

| Name | Status | Current handling |
|---|---|---|
| `MASTER_FUSION_OVERLAY_2026_04_30.md` | Not found at expected path | Superseded by repo-local fusion packet and April 30 Downloads docs. |
| `MASTER_BUILD_PLAN_OVERLAY_2026_04_30.md` | Not found at expected path | Do not block on it. |
| `WORKTREE_FUSION_PROTOCOL.md` | Not found at expected path | Current gate protocol is in `CODEX_ACTIVE_OVERSEER_KIMI_PROMPT_2026_04_30.md`. |
| `QUICK_CAPTURE_TO_MAIN_MERGE_PLAN.md` | Not found at expected path | Do not treat Quick Capture as a merge target. |
| `QC/FINAL_SYNTHESIS.md` | Not found at expected path | Use worktree log/status plus current main evidence instead. |
| "No subprocesses ever" claims | Superseded | Correct rule is no hot-path subprocesses in Core/MAS; Pro tunnels may exist behind gates. |
| BoltFFI 1000x claims | Unverified | Treat as research until benchmark harness proves parity and speed. |
| ANE/private activation steering/infinite context claims | Research-only | Not Core/MAS implementation material. |

## 4. Gate Model

### 4.1 Core / MAS

Core is the Mac App Store compatible product surface. It can include:

- Native SwiftUI/AppKit UX.
- TextKit 2 note editing.
- Tiptap-in-WKWebView `.epdoc` documents where already established.
- SwiftData, vault sync, Spotlight-safe indexing, App Intents, menu-bar capture.
- Local model routing when shipped without private APIs or hidden cloud fallback.
- Typed substrate: `TypedArtifact`, `MutationEnvelope`, `RunEventLog`, `AgentEvent`, `GraphEvent`.
- Halo and Contextual Shadows if they are local, debounced, provenance-rich, and performance-safe.

Core must not include Hermes subprocess UX, CLI passthrough, MCP URL/stdio tunnels, Docker, Simulation Theater, computer-use automation, private Apple APIs, or research-only neural-kernel claims.

### 4.2 Pro / Direct Distribution

Pro can include:

- Hermes parity, CLI passthrough, MCP tunnels, provider chain tooling.
- Simulation Theater, companion/Theater UI, graph live theater.
- Process registry and subprocess orchestration.
- Explicit capability-gated integrations that are not MAS-safe.

Pro work must compile out of MAS builds and must not leak symbols, entitlements, or runtime paths into App Store artifacts.

### 4.3 Research Only

Research-only until proven:

- BoltFFI production switch.
- Neural-kernel / infinite-context / activation-steering ideas.
- Private ANE access.
- Any massive FFI handle rewrite.
- Any graph-engine physics/render change without benchmark and parity evidence.

## 5. Halo And Contextual Shadows

### Current evidence

Main contains:

- `Epistemos/Engine/HaloController.swift`
- `Epistemos/Engine/HaloEditorBridge.swift`
- `Epistemos/Engine/ShadowSearchService.swift`
- `Epistemos/Views/Recall/ContextualShadowsPanel.swift`
- `Epistemos/Views/Halo/ShadowPanel.swift`
- `EpistemosTests/HaloControllerTests.swift`
- `EpistemosTests/HaloUITests.swift`
- `EpistemosTests/ContextualShadowsStateTests.swift`

The canonical V1 shape is a six-state local recall loop:

`dormant -> watching -> encoding -> searching -> available -> open`

The loop must be debounced, local, provenance-rich, and visible without turning the note editor into a fragile hot path.

### Nuance to preserve

- Halo is not merely search UI. It is ambient recall with state, debounce, provenance, and panel presentation.
- Existing `HaloController` and `HaloEditorBridge` should be reused if they are valid.
- `Pasted markdown.md` claims live debounce -> encode -> search -> panel wiring may still be incomplete. Treat this as a hypothesis requiring fresh repo evidence, not as a proven defect.

### Missing evidence

- Current call graph from text edit event to `HaloController`.
- Current call graph from `HaloController` to `ShadowSearchService`.
- Runtime proof that the panel appears with real note context.
- Performance proof that typing remains smooth and no per-keystroke SwiftUI cascade occurs.

## 6. Quick Capture

### Current evidence

Main contains:

- `Epistemos/Views/Capture/QuickCaptureView.swift`
- `Epistemos/Intents/Custom/NoteActionIntents.swift`
- `QuickCaptureIntent` evidence in the current app.

The Quick Capture worktree contains 50+ commits including Tool trait work, route capture classifier, semantic cache, ExecutionReceipt, universal undo, NightBrain idle scheduling, heal loop, and BrowserEngine trait work.

### Nuance to preserve

Quick Capture is sibling-canonical, not a branch to merge. The safe shape is:

`capture input -> TypedArtifact -> MutationEnvelope -> RunEventLog -> graph/index projection`

The worktree's parallel `ToolRegistry::execute_v2` and vault assumptions must not flatten into main without substrate alignment.

### Missing evidence

- Whether current `QuickCaptureView` emits a typed artifact.
- Whether it writes a durable `MutationEnvelope`.
- Whether the created artifact becomes a graph node/index entry.
- Whether undo/provenance can map to the existing mutation model.

## 7. Raw Thoughts And Provenance

### Current evidence

Main contains:

- `Epistemos/Models/MutationEnvelope.swift`
- `agent_core/src/mutations/envelope.rs`
- `EpistemosTests/MutationEnvelopeParityTests.swift`
- `RunEventLog` and Merkle-chain claims from verified state / worktree history.

The active substrate spine is:

`TypedArtifact -> MutationEnvelope -> RunEventLog -> AgentEvent -> GraphEvent -> Halo / Graph / Theater / Audit`

### Nuance to preserve

- UI success must not emit before durable commit succeeds.
- Provenance must remain append-only and auditable.
- Raw Thoughts are not loose markdown shadows; they should become typed artifacts with event-backed provenance.
- BLAKE3/Merkle integrity is high-value but must be verified in current code before being treated as shipped.

### Missing evidence

- Fresh build/test logs for `MutationEnvelopeParityTests`.
- End-to-end proof from UI action to durable event log to graph projection.
- A current inventory of dirty `agent_core` mutation/log files before touching them.

## 8. Hermes / CLI / MCP

### Current evidence

Hermes parity worktree contains provider-chain, session persistence, error classifier, process registry, and tool registration work. Older research also discusses CLI/MCP tunnels.

### Gate decision

Hermes, CLI passthrough, MCP URL/stdio tunnels, Docker, subprocess orchestration, and computer-use style automation are Pro/direct-distribution only. They are not Core/MAS.

### Nuance to preserve

- Some patterns may be Core-safe if separated from subprocess behavior, for example rate-limit tracking or provider metadata.
- Tool registry gap analysis is useful, but implementation must be behind explicit capability gates.
- MAS builds must compile without Pro-only symbols and entitlements.

### Missing evidence

- A symbol/compile audit proving Pro-only code is excluded from MAS.
- Current Settings/UI path for provider chain configuration.
- Runtime proof that subprocess permissions are explicit and auditable.

## 9. Code Editor And Documents

### Current evidence

Main contains:

- `Epistemos/Engine/SwiftTreeSitterLiveHighlighter.swift`
- `Epistemos/Views/Notes/CodeEditorView.swift`
- `Epistemos/Views/Notes/CodeLineGutter.swift`
- `Epistemos/Engine/EpdocDocument.swift`
- `Epistemos/Engine/EpdocEditorBridge.swift`
- `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift`
- `Epistemos/Views/Epdoc/EpdocKaTeXPreview.swift`
- `.epdoc` related tests in `EpistemosTests/`.

### Locked direction

- Notes stay native TextKit 2.
- Code editor direction is TextKit 2 surface + SwiftTreeSitter live highlighting + Rust background brain + SourceKit-LSP.
- `.epdoc` stays Tiptap-in-WKWebView for V1.5; do not replace with CodeEditSourceEditor, Flutter, or AppFlowy.

### Missing evidence

- Current test status for `.epdoc` Info.plist/UTType registration.
- Current live highlighter runtime behavior on large files.
- UTF-8 to UTF-16 range mapping stress tests.

## 10. Missing Evidence Before Any Implementation

The next gate cannot open until these exist:

1. Fresh `git status --short -uall` snapshot after Phase 0 docs.
2. Fresh protected-path audit for `ProseEditor*.swift`, `MetalGraphView.swift`, `HologramController.swift`, and graph physics/render internals.
3. Build/test floor logs for current dirty main.
4. `cargo test` logs for `graph-engine` and `agent_core` if either is in scope.
5. Fresh Halo call-site audit before any Halo code edit.
6. Fresh Quick Capture current-code audit before any Quick Capture extraction.
7. Clear Core/Pro/Research classification for every planned slice.
8. Rollback plan for each slice.

## 11. Red Lines

- No raw worktree merges.
- No code edits before deliberation gate approval.
- No protected-path edits without explicit Codex approval.
- No Pro-only features in Core/MAS.
- No graph-engine dirty diff work without dedicated benchmark/parity brief.
- No stash pop without explicit Codex authorization.
- No staging, committing, or branch operations in Phase 0.
- No release-ready or shipped claim without repeated zero-fail verification.
