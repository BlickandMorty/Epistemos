# UI/UX Audit — Graph-chat auto-escalation (Hologram inspector)

- **Auditor**: Codex T6 (codex/t6-uiux-2026-05-16)
- **Date**: 2026-05-17 (iter 11)
- **Driver**: §4.C — closes the iter-9 P2-3 carry-over.
- **Trigger commit**: `f5f50d0ac` (2026-05-13 19:38, **5 minutes after**
  the note-ask fix `3a43066df`) — *fix(graph-chat): auto-escalate
  agent-intent inspector queries to main chat with tools.*
- **Surface under audit**:
  - `Epistemos/Views/Graph/HologramSearchSidebar.swift:950-1010+` —
    `sendGraphChatMessage()` prelude.
- **Verification mode**: Static. iter-1 env constraints unchanged.

## Context

The iter-9 audit of `3a43066df` (note-ask escalation) noted P2-3
*"Graph chat surfaces explicitly deferred per the commit body — sidebar
+ dialogue need similar treatment."* That note read the
`3a43066df` commit body literally — and the body did say graph was
deferred. **But the graph-chat fix landed 5 minutes later in
`f5f50d0ac`**. Iter 11 closes this loose end.

## What this fix does

`sendGraphChatMessage` in `HologramSearchSidebar.swift:950+` gains a
prelude that mirrors `NoteDetailWorkspaceView.submitToolbarAskInline`:

1. Trim the chat-input text and bail-fast on empty / mid-stream.
2. Compute `isCloudProvider` via
   `inference.effectiveChatSurfaceSelection(for:)`.
3. Classify via `ChatCapability.predictIntent(text:, isCloudProvider:)`.
4. If predicted intent is `.agent` or `.research`:
   - Clear `inspectorState.chatInput`.
   - `bootstrap.chatState.startNewChat()`.
   - Attach the selected graph node as a `ContextAttachment` via
     `graphNodeContextAttachment`.
   - `ui.setActivePanel(.home)`.
   - Route through `MainChatSubmissionRouter.submit(...)`.
5. Non-agent intents stay on the existing inline `triageService.
   streamGeneral` path.

## Strengths preserved

- **Mirror discipline**: identical pattern to note-ask escalation
  (iter 9), including the same comment block explaining the
  TriageService-can't-dispatch-app-tools structural reason. UX
  uniformity across two surfaces — users see the same panel-switch
  behavior whether they're in a note or in the graph inspector.
- **Graph rendering integrity**: the Metal graph view + node layout
  + edges stay untouched per the commit body's user directive *"graph
  rendering must NOT be disrupted."* Only the chat composer's send
  behavior changes; the user can navigate back via the sidebar graph
  button with graph state preserved.
- **Note-typed nodes carry full body**; other node types still
  escalate (just without node-specific inline context). Honest
  fallback.
- **`isChatStreaming` guard** at the prelude entry prevents
  mid-stream re-route.

## Findings

### P0 / P1

None.

### P2 — defer (mirrors iter 9 P2s)

**P2-1 — Silent panel switch.**
Same as note-ask P2-1 (iter 9). The user types in the inspector chat
and the UI snaps to home. A "Sent to main chat — agent tools needed"
toast at the new chat row would clarify, especially for users who
opened the inspector specifically to keep the graph visible.

**P2-2 — Classifier accuracy is load-bearing.**
Same `ChatCapability.predictIntent` heuristic; same misclassification
risk. NLP-classifier sub-mission still warranted.

**P2-3 — Non-note-typed node attachments lose context.**
The commit body acknowledges: "other node types still escalate, just
without node-specific context." So a query like "find papers about
this person" against a person-typed graph node escalates, but the
target person identity is lost. Worth tracking — a generic
"GraphNodeRef" attachment carrying the node's id + label + type
would preserve identity even without full body. Defer to a graph
attachment sub-mission.

### P3 — observations

- **P3-1** — The note-ask commit body said graph-chat was "deferred."
  The follow-up landed in the same wave but the body wasn't
  retro-edited. Future audit retros should cross-reference timestamps
  before treating "deferred" claims as authoritative. Recorded as a
  process lesson, not a code defect.

## Action taken this iter

- Filed this audit doc.
- **No code edits.** Closes iter-9 P2-3 carry-over.

## Iter 1-11 surface coverage

| iter | feature | doc |
|---|---|---|
| 1-10 | (per prior recap) | … |
| 11 | Graph-chat auto-escalate (closes iter-9 P2-3) | this doc |

## Carry-overs

- P2-1 toast pattern for both auto-escalate sites (note-ask + graph
  inspector — fix once, reuse the same component).
- P2-2 classifier-accuracy audit.
- P2-3 generic `GraphNodeRef` attachment for non-note-typed nodes.

## Status

Driver-listed surfaces (items 1-2, 9, 10) fully audited.
Recursive-window UI commits with non-trivial functional changes —
all audited.
Visual polish commits (glass/blur/wallpaper) — deferred until
computer-use MCP available.
Remaining audit backlog gated on T1-T5 sibling-terminal landings to
`origin/main` (none yet as of this iter).
