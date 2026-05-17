# UI/UX Audit — Chat + Graph sub-trees sweep

- **Auditor**: Codex T6 (codex/t6-uiux-2026-05-16)
- **Date**: 2026-05-17 (iter 14)
- **Driver**: §4.C — user direction 2026-05-17: audit everything in
  T6 scope.
- **Surfaces under audit**:
  - `Epistemos/Views/Chat/*.swift` (25 files, 10,269 LOC)
  - `Epistemos/Views/Graph/*.swift` (18 files, 10,863 LOC)
- **Coverage to date**: ChatInputBar partially audited in iters 9/10
  (composer cloud-nudge, mic OS-gate). HologramSearchSidebar
  partially audited in iter 11 (graph-chat auto-escalate).
- **Verification mode**: Static scan + grep patterns.

## Chat sub-tree (25 files, 10,269 LOC)

### Size profile

Big files: `ChatInputBar` (1,782), `NotesMentionDropdown` (1,643),
`MessageBubble` (1,075), `TaggedMarkdownTextView` (978),
`ChatView` (888), `ArtifactBlockView` (574),
`ComposerReferenceBrowser` (509), `ChatSidebarView` (407),
`ModelAboutSheet` (285), `BTMView` (212), `DiffPreviewView` (204),
`ComposerCurrentAccessPlan` (193), `ProcessDisclosureViews` (190),
`ThinkingPopoverView` (194), `SlashCommandPopover` (180),
`ToolActivityNarrator` (170), `TodoSnapshotCard` (131),
`LiveActivityStrip` (123), `VRMLabelView` (124), several smaller.

### CLAUDE.md rule compliance

`grep -rE "\\btry!|^\s*print\\(|DispatchQueue\\.main\\.sync|ObservableObject\\b"` →
**zero hits.** ✅

### A11y coverage

| Count | File |
|---|---|
| 14 | ChatInputBar (already audited; banner / pill / mic-gate annotations) |
| 5 | MessageBubble |
| 3 | ChatView |
| 2 | VRMLabelView, ThinkingPopoverView, ContextWindowCompactBadge, ComposerMicButton, ChatSidebarView |
| 0 | 16 remaining files including TaggedMarkdownTextView (978 LOC, the chat-message rich-text renderer), NotesMentionDropdown (1,643 LOC), ArtifactBlockView (574), ComposerReferenceBrowser (509), ProcessDisclosureViews (190), DiffPreviewView (204), ModelAboutSheet (285) |

**P2 — same a11y-skew pattern as Settings + Notes sub-trees.**

### Per-file notes

- **ChatInputBar.swift** (1,782) — already partially audited; strong
  banner / nudge / pill / a11y discipline at 14 modifiers.
- **NotesMentionDropdown.swift** (1,643) — the @-mention surface
  for inserting note references into chat. Inline list with keyboard
  navigation likely; verify arrow-keys + Esc dismiss + a11y rotor.
  Worth dedicated read in iter 15.
- **MessageBubble.swift** (1,075) — the per-message rendering surface.
  5 a11y modifiers — handles the most-common case (message role,
  copy button, etc.). Code-block sub-surfaces / inline links worth a
  closer look in a dedicated iter.
- **TaggedMarkdownTextView.swift** (978) — markdown rendering with
  tag awareness. 0 a11y annotations on the rich-text view — depends
  on AttributedString / Text's platform defaults.
- **ChatView.swift** (888) — top-level chat surface; 3 a11y mods.
- **ComposerReferenceBrowser.swift** (509) — context attachment
  browser; 0 a11y.
- **ArtifactBlockView.swift** (574) — rendered artifact (image/code
  block / file). 0 a11y. Probably needs `.accessibilityLabel(...)`
  describing the artifact type + name.
- **ChatSidebarView.swift** (407) — chat history sidebar. 2 a11y mods.
- **ModelAboutSheet.swift** (285) — model-info pop-out; 0 a11y.
- **BTMView.swift** (212) — BTM-related surface; need to check what
  it is.
- **ProcessDisclosureViews.swift** (190) — disclosure UI for chat
  processes; 0 a11y on disclosure-state changes.
- **DiffPreviewView.swift** (204) — diff renderer; 0 a11y.
- **ContextWindowCompactBadge.swift** (60) +
  **ContextWindowIndicator.swift** (72) — small badges; 2 a11y
  modifiers each (compact one) — surface is small.
- **SlashCommandPopover.swift** (180) — slash-command picker. Worth
  a quick read in iter 15 — needs keyboard arrow + a11y rotor.
- **ThinkingPopoverView.swift** (194) + **ThinkingTrailView.swift**
  (85) — reasoning-trail UI. 2 a11y mods on popover; 0 on trail.
- **ToolActivityNarrator.swift** (170) — narrates live tool
  invocations (live status). 0 a11y — should announce via
  `.accessibilityAddTraits(.updatesFrequently)` or aria-live
  equivalent.
- **TodoSnapshotCard.swift** (131) — todo-list snapshot card.
- **LiveActivityStrip.swift** (123) — live status strip.
- **VRMLabelView.swift** (124) — VRM (Voice Reasoning Mode?) label.
  2 a11y mods.
- **ComposerCurrentAccessPlan.swift** (193) — access-plan composer.
- **ComposerMicButton.swift** (81) — already mic-gated per iter 9.
- **EditorSkillChips.swift** (56) — skill chips row.

## Graph sub-tree (18 files, 10,863 LOC)

### Size profile

Big files: `MetalGraphView` (2,646), `HologramOverlay` (2,059),
`HologramSearchSidebar` (1,138), `GraphForceSettings` (1,126),
`NodeInspectorState` (870), `HologramNodeInspector` (816),
`PinnedInspector` (512), `GraphFloatingControls` (348),
`HologramController` (290), `RelationshipBrowser` (234),
`GraphFolderPage` (178), `QueryResultsView` (177),
`GraphFirstOpenTitle` (150), `GraphWorkspaceContainer` (128).

### CLAUDE.md rule compliance

`grep -rE "\\btry!|^\s*print\\(|DispatchQueue\\.main\\.sync|ObservableObject\\b"`
→ **zero hits.** ✅

### A11y coverage

| Count | File |
|---|---|
| 9 | GraphFloatingControls (zoom/pan/reset buttons) |
| 2 | HologramSearchSidebar, GraphForceSettings |
| 0 | 15 remaining including MetalGraphView, HologramOverlay, HologramNodeInspector, NodeInspectorState, PinnedInspector, RelationshipBrowser, QueryResultsView, GraphWorkspaceContainer |

**MetalGraphView** is by far the largest (2,646 LOC) and renders the
node-link graph via Metal compute shaders. A custom-rendered
Metal surface is inherently a11y-opaque to VoiceOver; an
`AccessibilityRepresentation` mapping each rendered node to a
synthetic accessibility element is the canonical way to bridge.
Worth flagging as a sub-mission.

### Per-file notes

- **MetalGraphView.swift** (2,646) — Metal-rendered graph canvas. No
  text-equivalent surface for VoiceOver. **High-impact P2**: graph
  view is a primary navigation surface; non-sighted users cannot
  explore it.
- **HologramOverlay.swift** (2,059) — overlay surfaces atop the
  graph (blur transitions, etc.). Three RCA-tagged transition fixes
  audited in iter 7. Full structural read deferred.
- **HologramSearchSidebar.swift** (1,138) — node-inspector sidebar.
  Auto-escalate prelude audited in iter 11. Other surfaces (search
  field, results list, chat thread) untouched here.
- **GraphForceSettings.swift** (1,126) — force-simulation tuning
  panel. 2 a11y mods.
- **NodeInspectorState.swift** (870) — view-model for
  HologramNodeInspector.
- **HologramNodeInspector.swift** (816) — node-detail inspector;
  rendered by HologramSearchSidebar.
- **PinnedInspector.swift** (512) — pinned inspector floater.
- **GraphFloatingControls.swift** (348) — zoom/pan/reset controls
  + recenter. 9 a11y modifiers — strongest in Graph sub-tree.
- **HologramController.swift** (290) — controller for hologram
  view-model.
- **RelationshipBrowser.swift** (234) — relationship-browser panel.
- **GraphFolderPage.swift** (178) — folder-as-page renderer.
- **QueryResultsView.swift** (177) — query-results pane.
- **GraphFirstOpenTitle.swift** (150) — onboarding title overlay.
- **GraphWorkspaceContainer.swift** (128) — outer container.

## Findings summary

### P0 / P1

None.

### P2 — defer (cross-cutting)

- **A11y gap (Chat + Graph)**: 31 of 43 combined files have zero
  a11y annotations. ToolActivityNarrator + LiveActivityStrip + the
  rich-text renderers (TaggedMarkdownTextView, MessageBubble inner
  surfaces) need `.accessibilityAddTraits(.updatesFrequently)` and
  explicit labels respectively.
- **MetalGraphView a11y bridge**: Metal-rendered graph is invisible
  to VoiceOver. Sub-mission scope: synthesize an
  `AccessibilityRepresentation` mapping nodes → labels +
  relationships → traversal.
- **AIPartner-like inline disclosures**: ArtifactBlockView +
  inline rich text + diff previews all lack textual disclosure
  beyond platform defaults.

### Per-file deep audits queued for iter 15+

- NotesMentionDropdown (1,643) — keyboard nav + a11y rotor.
- MessageBubble (1,075) — code-block + link sub-surfaces.
- MetalGraphView (2,646) — Metal a11y bridge proposal.
- HologramSearchSidebar / HologramNodeInspector (1,954 combined) —
  full structural read.

## Action taken this iter

- Filed this audit doc.
- **No code edits.** Cross-cutting patterns + queue for iter 15+.

## Coverage update

- Settings (33 files / 13,264 LOC): swept iter 12 + 7 deep audits.
- Notes (43 files / 33,941 LOC): swept iter 13 + 4 partial.
- Chat (25 files / 10,269 LOC): swept this iter + 1 partial.
- Graph (18 files / 10,863 LOC): swept this iter + 1 partial.
- Halo (3 files): fully audited iter 4.
- Remaining sub-trees (~37 files, mostly small): iter 15.
