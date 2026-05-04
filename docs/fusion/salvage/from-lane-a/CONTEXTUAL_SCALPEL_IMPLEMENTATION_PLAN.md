# Contextual Scalpel Implementation Plan
## Epistemos Neural OS Upgrade

**Date:** 2026-04-11  
**Status:** Ready for implementation  
**Primary scope:** shipping app, not deferred agent infrastructure  
**Estimated effort:** 2-4 weeks for the live note path, plus 1-2 weeks for broader surfacing

---

## Executive Summary

Epistemos already has the raw ingredients of a Neural OS:

- live note content in `NoteChatState`
- vault-wide semantic recall via `InstantRecallService`
- graph-neighborhood grounding via `GraphState` and `GraphStore`
- optional graph-memory enrichment via `GhostBrainCoauthor`

What it does **not** have yet is a single, surgical context assembly layer that decides:

- what context to pull
- how much of each source to include
- how to adapt the bundle to the user’s intent
- how to stay inside a strict budget without dumping the whole world into every prompt

The Contextual Scalpel is that layer.

The plan is to build a shared Swift service that assembles precise, task-shaped context packs for note AI first, then reuse it across other surfaces. This should make Epistemos feel less like “prompt + extra text” and more like a system that knows exactly what to surface, exactly when, with reflex-level precision.

---

## Research Alignment

The local research corpus sharpens this plan in three useful ways.

Primary iCloud anchor:

- `~/Library/Mobile Documents/com~apple~CloudDocs/Research got.md`

That note is the closest verified match to the requested Gemini research thread. It explicitly validates the five-pillar framing, uses Flash-MoE as the concrete existence proof for SSD-streamed MoE inference, and frames MiniMax/Kimi overseers as useful only if their outputs compile into executable structure rather than staying at the level of vague semantic intent.

### 1. The older “five pillars” training vision supports this, but does not replace it

The Gemini iCloud note says the five pillars are coherent, but it also makes the more important implementation point: the order matters.

The adjacent long-horizon training material in `old research/EPISTEMOS-NANO-MASTER-TRAINING-GUIDE.md` expands that strategy into five pillars:

- architecture + distillation
- app-specific meta-training
- general macOS device control
- reinforcement learning
- continuous self-improvement

The Contextual Scalpel is not a substitute for that broader roadmap. It is the shortest shipping-path move that strengthens pillar 2 immediately and creates cleaner diagnostics for pillar 5 later.

In plain terms:

- pillar 2 becomes stronger because the live app starts assembling context in a reflexive, note-aware, operation-aware way
- pillar 5 becomes more realistic because we can log which context bundles helped, which providers were dropped, and where budget was wasted

### 2. Flash-MoE validation argues for strict scope discipline

`~/Library/Mobile Documents/com~apple~CloudDocs/Research got.md` uses Flash-MoE as the concrete proof point: extremely large MoE systems can run on Apple Silicon by streaming only active experts from SSD, but the win depends on hard bandwidth discipline and hardware-aware execution.

The note also reinforces an Apple-Silicon-specific constraint that matters here: serial GPU -> SSD -> GPU pacing can outperform aggressive overlap because SSD reads and GPU compute compete for the same shared memory fabric.

That is strategically exciting, but it should not distort Phase 1.

So this plan explicitly assumes:

- no dependence on giant local MoE inference
- no dependency on SSD-streamed experts
- no “wait for future model runtime” blocker before improving note intelligence

The Contextual Scalpel should be model-agnostic and budget-aware now, so it improves the shipping Qwen plus Apple Intelligence path immediately and can later feed larger runtimes if the hardware stack evolves.

### 3. MiniMax and Kimi “overseer” ideas are inspiration for provider budgeting, not a Phase 1 agent system

The Gemini iCloud note is especially useful here because it asks the right question:

- does the Overseer output something executable at the kernel or systems level, or is it only producing semantic guidance?

That broader overseer pattern is useful as design inspiration, but the current shipping app should not reintroduce heavy orchestration just to assemble note context.

The right translation for the shipping app is narrower:

- let the Contextual Scalpel behave like an overseer for context providers
- assign each provider a budget and a role
- rank providers by intent and local relevance
- compose one prompt pack
- do not spawn a multi-agent loop

In other words, Phase 1 should “compile” intent into context selection and budget allocation the same way the Gemini note insists future overseer logic must compile into executable masks or dispatch structure.

This preserves the best idea from the research, namely explicit budgeting and specialization, while staying aligned with the real codebase and avoiding dependence on the retired Omega orchestration stack.

---

## Ground Truth

These are the current facts in the codebase that this plan must respect.

### 1. The shipping note AI path already injects three kinds of context

`Epistemos/State/NoteChatState.swift` currently builds prompts from:

- the current note body
- `InstantRecallService` matches as `<related_notes>`
- a compact graph neighborhood via `buildGraphContext()`
- prior per-note chat turns as `<conversation_history>`

This means the product direction is already correct. The missing piece is better orchestration and budgeting, not a brand-new subsystem.

### 2. `InstantRecallService` is live and app-facing

`Epistemos/KnowledgeFusion/InstantRecallService.swift` fronts the current shipping recall path. `AppBootstrap` lazily hydrates it from live note snapshots instead of eagerly rebuilding it at launch.

This is important because `docs/PROGRESS.md` explicitly says not to casually merge:

- `InstantRecallService` / `epistemos-core` flat-binary instant recall
- `graph-engine` prepared retrieval runtime

For this plan, the canonical recall engine for UI-facing note context remains `InstantRecallService` unless a separate model-stack pass decides otherwise.

### 3. The old Omega orchestrator is not the backbone anymore

`Epistemos/Omega/Orchestrator/OrchestratorState.swift` is now a stub.  
`SESSION_SYNTHESIS_2026-04-09.md` also confirms `agent_core` is not linked in shipping builds.

So this upgrade must **not** assume:

- a live Rust orchestration loop
- agent-core-only memory systems
- shipping dependence on deferred agent UI

The Contextual Scalpel belongs in the shipping app stack, not in the retired orchestration stack.

### 4. Selection and cursor data already exist

The note editor bridge already has access to:

- selected text
- selection ranges
- cursor positions
- editor-local body state

Relevant anchors:

- `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`
- `Epistemos/Views/Notes/ProseEditorRepresentable2.swift`
- `Epistemos/Views/Notes/ProseTextView2.swift`

That means “surgical” context can be real, not metaphorical. We can assemble around:

- selected text
- current paragraph
- current section
- note tail
- immediate graph neighborhood

### 5. There is already a secondary graph-memory layer, but it should stay optional

`Epistemos/Omega/Knowledge/GhostBrainCoauthor.swift` and `AgentGraphMemory.swift` can enrich prompts with graph-derived memory, but they should be treated as secondary providers, not the foundation of the first implementation.

The shipping path should work even if Ghost Brain contributes nothing.

---

## Product Definition

### What the Contextual Scalpel is

A shared service that builds the smallest useful context pack for a given AI request.

It should answer:

1. What is the user trying to do?
2. Which local context matters most?
3. Which vault memories are worth spending budget on?
4. Which graph facts help instead of distract?
5. What should be omitted, deferred, or compressed?

### What “scalpel” means in practice

- For `rewrite` on a selection, prefer the selection and its immediate neighborhood, not the whole note.
- For `continueWriting`, prefer the note tail, recent section headings, and graph expansions.
- For `ask`, use a balanced blend of note content, recall hits, graph context, and recent chat history.
- For `summarize`, prioritize the relevant local slice and structural outline, not distant recall noise.
- For `analyze`, allow broader recall and graph context, but still enforce a hard budget.

### User-facing outcome

The system should feel like:

- it remembers relevant things before being asked
- it stops flooding prompts with irrelevant context
- it responds as if it understands where in the note the user is working
- it uses the graph and vault as supporting cognition, not decorative baggage

---

## Architecture Decision

### Decision

Build the Contextual Scalpel as a **shipping Swift service** that sits above live app services and below prompt assembly.

Recommended new type:

- `Epistemos/Engine/ContextualScalpelService.swift`

Recommended supporting models:

- `ContextAssemblyRequest`
- `ContextAssemblySection`
- `ContextAssemblyResult`
- `ContextIntentProfile`
- `ContextDiagnostics`

### First consumer

`NoteChatState` should be the first and only required consumer in Phase 1.

That keeps the initial integration:

- high-value
- measurable
- low-risk
- close to the existing shipping prompt path

### Core contract

```swift
struct ContextAssemblyRequest: Sendable {
    let surface: ContextSurface
    let operation: NotesOperation
    let noteId: String
    let noteTitle: String
    let noteBody: String
    let selectedText: String?
    let selectedRange: NSRange?
    let cursorLocation: Int?
    let userQuery: String
    let conversationHistory: [AssistantMessage]
    let tokenBudget: Int
}
```

```swift
struct ContextAssemblyResult: Sendable {
    let sections: [ContextAssemblySection]
    let prompt: String
    let diagnostics: ContextDiagnostics
}
```

### Provider order

The service should assemble from these providers in descending priority:

1. local edit context
2. note-structural context
3. instant recall context
4. graph-neighborhood context
5. conversation-history context
6. ghost-brain context
7. temporal-memory context later

### Budget policy

Use a hard budget and explicit section ranking.

Recommended early rule:

- reserve budget for the user request first
- reserve budget for current-note context second
- spend the remainder on recall and graph context
- drop low-signal providers entirely instead of truncating everything evenly

Also apply head-tail placement for high-value sections to reduce lost-in-the-middle effects.

---

## Intent Profiles

The Contextual Scalpel should use operation-shaped weights, not one universal blend.

### `rewrite` / `grammarFix`

Primary inputs:

- selected text
- paragraph around selection
- optional current section heading

De-emphasize:

- instant recall
- graph context
- chat history

Reason:

These operations are local transforms, not cross-vault reasoning tasks.

### `summarize`

Primary inputs:

- selected text or current section
- structural headings
- limited note-wide framing

Optional:

- one or two recall hits only if the request explicitly implies comparison or synthesis

### `continueWriting`

Primary inputs:

- note tail
- active section heading chain
- current note graph neighbors
- optional continuation hints from Ghost Brain

### `ask`

Primary inputs:

- note slice relevant to the query
- top recall hits
- graph neighbors
- recent conversation turns

### `outline` / `expand` / `analyze`

Primary inputs:

- larger note slice
- note structure
- recall hits
- graph context

Optional:

- Ghost Brain enrichment if it produces meaningful nodes inside budget

---

## Phase Plan

## Phase 0 — Baseline and Safety Harness

**Goal:** protect current behavior before changing prompt assembly.

### Work

- Add failing Swift Testing coverage for the current note chat prompt path.
- Freeze existing behavior around:
  - empty notes
  - no-recall cases
  - duplicate recall matches
  - graphless notes
  - selection-driven operations
- Add lightweight diagnostics so we can compare:
  - prompt size
  - section count
  - recall hit count
  - graph node count

### Files

- new `EpistemosTests/ContextualScalpelBaselineTests.swift`
- update or add focused note-chat tests around `NoteChatState`

### Exit criteria

- We can prove no regressions in basic note chat assembly before swapping in the new service.

---

## Phase 1 — Shared Contextual Scalpel for Note Chat

**Goal:** replace ad hoc prompt assembly in `NoteChatState` with one service.

### Work

- Create `ContextualScalpelService`.
- Move logic now spread across:
  - `conversationHistoryPrompt()`
  - `instantRecallContext(for:)`
  - `buildGraphContext()`
  - parts of `buildPrompt(...)`
  into a single assembly pipeline.
- Introduce a typed request/result model.
- Keep `InstantRecallService` as the only vault recall engine in this phase.
- Keep Ghost Brain optional and best-effort.

### Integration approach

Minimal first pass:

- `NoteChatState` builds a `ContextAssemblyRequest`
- `ContextualScalpelService` returns the final sections and prompt
- `TriageService` call sites stay unchanged

Recommended injection path:

- instantiate in `AppBootstrap`
- inject via `withAppEnvironment(_:)`
- consume from `NoteChatState`

### Files

- new `Epistemos/Engine/ContextualScalpelService.swift`
- update `Epistemos/App/AppBootstrap.swift`
- update `Epistemos/App/AppEnvironment.swift`
- update `Epistemos/State/NoteChatState.swift`

### Exit criteria

- Note chat uses one shared assembly pipeline.
- Prompt size is measurable and bounded.
- No regressions in streaming or inline response behavior.

---

## Phase 1.5 — True Surgical Inputs: Selection and Cursor Awareness

**Goal:** make the service aware of where the user is actually working.

### Work

- Pass selection text, selection range, and cursor location into `ContextAssemblyRequest`.
- For context-menu operations, use the real selected text and its neighborhood.
- For toolbar asks, capture the live cursor and active paragraph if there is no selection.

### Recommended order

Start with the least invasive route:

- use `NoteEditorViewFinder` in `NoteDetailWorkspaceView` to snapshot selection and cursor for note-chat submission

Only move deeper into `Coordinator2` if that proves insufficient.

This keeps the first pass minimal and avoids unnecessary editor refactors.

### Files

- update `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`
- optional later update to `Epistemos/Views/Notes/ProseEditorRepresentable2.swift`

### Exit criteria

- `rewrite`, `summarize`, and related context-menu operations are local and surgical.
- `continueWriting` and toolbar ask flows can use cursor-aware note slices.

---

## Phase 2 — Contextual Shadows on the Live Note Surface

**Goal:** expose the assembly engine visually, not just in hidden prompts.

### Work

- Reuse the same candidate ranking pipeline to surface top contextual items while writing.
- Show a compact note-sidecar or shadow strip with:
  - related notes
  - graph-linked concepts
  - optionally one “why this appeared” explanation
- Debounce aggressively and do not reintroduce per-keystroke SwiftUI churn.

### Important rule

Do **not** switch recall backends here.  
Stay on `InstantRecallService` until the separate retrieval-path decision is made.

### Likely files

- new `Epistemos/Views/Notes/ContextualShadowsView.swift`
- update `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`
- optional update `Epistemos/KnowledgeFusion/InstantRecallService.swift` for diagnostics only

### Exit criteria

- Users can see what the system is surfacing.
- The visual layer uses the same ranked sections as the prompt layer.
- Idle editing remains smooth.

---

## Phase 3 — Cross-Surface Reuse

**Goal:** make the Contextual Scalpel the app’s shared context operating layer.

### Candidate adopters

- `Epistemos/State/DialogueChatState.swift`
- `Epistemos/Engine/NoteInsightService.swift`
- `Epistemos/State/WorkspaceSummaryService.swift`

### Work

- Generalize the request model beyond note-chat-only assumptions.
- Add surface-specific intent profiles.
- Reuse the service for:
  - note insights
  - workspace synthesis
  - richer home/dialogue chat grounding

### Exit criteria

- One context operating layer serves multiple user-facing surfaces.
- Surface-specific prompts differ by intent profile, not by ad hoc copy-pasted builders.

---

## Phase 4 — Optional Deeper Memory Upgrades

**Goal:** expand from “smart context packing” into “Neural OS memory routing.”

### Optional additions

- temporal recall
- contradiction-aware recall
- belief-drift or Time Machine hooks
- ported neural-cache concepts from `agent_core`, but only into shipping crates

### Hard rule

Do not make this phase a prerequisite for shipping Phase 1 or Phase 2.

This is where more ambitious memory work belongs, not at the foundation.

---

## File-Level Implementation Map

### New files

- `Epistemos/Engine/ContextualScalpelService.swift`
- `EpistemosTests/ContextualScalpelTests.swift`
- optional `Epistemos/Views/Notes/ContextualShadowsView.swift`

### Primary modified files

- `Epistemos/State/NoteChatState.swift`
- `Epistemos/App/AppBootstrap.swift`
- `Epistemos/App/AppEnvironment.swift`
- `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`

### Optional modified files later

- `Epistemos/Views/Notes/ProseEditorRepresentable2.swift`
- `Epistemos/KnowledgeFusion/InstantRecallService.swift`
- `Epistemos/Omega/Knowledge/GhostBrainCoauthor.swift`

---

## Testing Strategy

Every implementation phase should start with failing tests.

### Swift tests to add

- selection rewrite includes selected text and not unrelated recall noise
- empty note produces a valid prompt
- duplicate recall matches are deduplicated
- graphless note does not emit empty graph scaffolding
- prompt budget enforcement drops low-priority sections cleanly
- continue-writing prefers note tail over unrelated vault recall
- ask/analyze allows broader recall than rewrite/summarize

### Runtime checks

- no `loadBody()` calls introduced into SwiftUI body evaluation
- no per-keystroke disk reads
- no streaming regressions in inline AI insertion
- no divider-protection regressions

### Performance targets

- no new work on every keystroke without debounce
- recall search latency stays within current practical thresholds
- prompt assembly remains fast enough for immediate submit with no visible lag

---

## Success Metrics

The upgrade is working if:

- prompt context becomes smaller and more relevant
- transform operations behave locally instead of dragging in vault noise
- ask/analyze responses become more grounded in the right note and graph neighborhood
- contextual shadows feel like involuntary recall, not a search UI
- the same service can power multiple surfaces without copy-pasted prompt builders

---

## Non-Goals

This plan does **not** do the following:

- revive the retired Omega orchestrator
- depend on `agent_core` being linked into shipping builds
- merge instant recall with prepared retrieval prematurely
- introduce a new subprocess, sidecar, or agent loop
- replace the note chat streaming stack
- refactor adjacent editor architecture without clear need

---

## Key Design Principle

Epistemos does not need more context.

It needs better judgment about context.

The Contextual Scalpel should be the first shared layer that turns the app’s existing memory systems into a real cognitive operating surface:

- precise instead of broad
- live instead of batchy
- budgeted instead of bloated
- grounded instead of decorative

That is the right Neural OS upgrade for the shipping product.
