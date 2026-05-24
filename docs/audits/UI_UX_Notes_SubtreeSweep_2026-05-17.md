# UI/UX Audit — Notes sub-tree sweep (consolidated)

- **Auditor**: Codex T6 (codex/t6-uiux-2026-05-16)
- **Date**: 2026-05-17 (iter 13)
- **Driver**: §4.C — user direction 2026-05-17: audit everything in
  T6 scope.
- **Surface under audit**: all 43 files in `Epistemos/Views/Notes/`
  (33,941 LOC total).
- **Coverage to date**: iters 6, 7, 9, 10 covered fragments of
  NoteDetailWorkspaceView (ask bar + auto-escalate), VaultOrganizerView
  (folder-name match tooltip), and ProseTextView2 (reparse debounce).
- **Verification mode**: Static scan + grep-driven pattern detection.

## Size profile

| Range | Count |
|---|---|
| <100 LOC | 4 |
| 100-500 LOC | 22 |
| 500-1000 LOC | 7 |
| 1000-2000 LOC | 5 |
| >2000 LOC | 5 |
| **Total** | **43 / 33,941 LOC** |

Five files >2000 LOC carry the majority of complexity:
`CodeEditorView` (4,863), `NoteDetailWorkspaceView` (3,769),
`NotesSidebar` (3,442), `ProseTextView2` (2,517),
`ProseEditorRepresentable2` (1,595).

## Cross-cutting findings

### CC-1 — `try!`, `print(`, `DispatchQueue.main.sync` are absent ✅

CLAUDE.md project rules forbid these in production paths. Grep across
the 43 files turns up **zero hits** for any of them. The only flagged
hard-fail is a single `preconditionFailure("Invalid outline regex: ...")`
at `OutlineNavigatorView.swift:163` — a developer-error guard on a
literal regex pattern, not a runtime user condition. Acceptable.

### CC-2 — A11y coverage is heavily skewed.

Grep for `accessibilityLabel|Value|Hint|Element|Action`:

| Count | File |
|---|---|
| 13 | NotesSidebar (large, complex tree view) |
| 6 | DiffSheetView |
| 5 | NoteDetailWorkspaceView |
| 2 | VaultOrganizerView, VaultChangesPanel |
| 1 | VersionTimeline |
| **0** | **37 files** including ProseTextView2, ProseEditorView, ProseEditorRepresentable2, OutlineNavigatorView, CodeEditorView, ModelInvolvementSheet, MarkdownContentStorage, AIPartnerControlPanel, AIPartnerService, AIPartnerInlineView, MarkdownEditorCommands, NoteWindowManager, FocusedResponsePanel, NoteBacklinksPanel, NoteTableOfContents, TransclusionOverlayManager2, etc. |

This is broader than the Settings sub-tree gap. ProseTextView2 (the
core editor surface) and CodeEditorView (the 4,863-LOC code editor)
both have zero explicit a11y annotations. NSTextView /
CodeEditSourceEditor honor the platform a11y defaults, but custom
overlays (gutters, suggestion ghost text, transclusion overlays,
breadcrumbs) lack explicit roles + labels.

**Verdict**: another systemic P2. A dedicated "Notes editor
accessibility pass" sub-mission is warranted, scoped to:
- ProseTextView2 selection / cursor announcements
- Gutter / indentation-guide a11y roles
- AIPartnerInlineView ghost-text disclosure to VoiceOver
- Outline navigator headings as a11y rotor

### CC-3 — File-size bloat: five >2K LOC files.

The five mega-files together account for ~16,000 LOC (47% of the
sub-tree). A refactor into per-feature files would improve audit /
review velocity. Not in §4.C scope; record as a process observation.

## Per-file notes

Highlights (skipping files already audited in iter 6/7/9/10):

- **AIPartnerControlPanel.swift** (702) — preset (calm/frequent/
  aggressive) + granular sliders for suggestion frequency/depth/
  context weighting. SwiftUI sliders without `.accessibilityValue`
  formatted strings → P2.
- **AIPartnerService.swift** (1,043) — service / view-model layer
  (uses Combine `import Combine` per the header; standard SwiftUI
  observation patterns).
- **AIPartnerInlineView.swift** (729) — ghost-text rendering inside
  NSTextView for AI suggestions. **Ghost text is not
  VoiceOver-disclosed** — users who can't see the suggestion never
  hear that the AI proposed something.
- **BlockPropertySheet.swift** (113) — pop-out sheet for block
  properties; small.
- **BlockRefAutocomplete2.swift** (328) — block-ref autocomplete
  popup; check that arrow keys navigate suggestions (Tab/Space + a11y
  rotor are platform defaults for `Picker` / `List`).
- **CodeEditorView.swift** (4,863) — **deferred** for dedicated iter
  14 (largest Notes file).
- **CodeAskBar.swift** (606) — sibling of the note ask bar; auto-
  escalate behavior likely mirrors iter 9's audit. Worth a spot-read
  in a follow-up iter.
- **CodeLineGutter.swift** (285) — line gutter rendering.
- **DiffSheetView.swift** (1,019) — diff viewer pop-out; **6 a11y
  modifiers** — best a11y discipline in Notes outside NotesSidebar.
  Worth a structural look in a follow-up iter.
- **EditorBreadcrumbBar.swift** (325) — breadcrumb path. 0 a11y.
- **FocusedResponsePanel.swift** (503) — response-panel rendering;
  presentation surface for streaming chat output.
- **HexViewerView.swift** (175) — hex viewer for binary files.
- **InlineResponseHighlighter.swift** (525) — inline streaming highlighter.
- **LineBreakdownPanel.swift** (344) — per-line breakdown.
- **LineDiff.swift** (268) — pure data view of line diffs.
- **MarkdownContentStorage.swift** (1,219) — likely backing-store
  glue (NSTextStorage subclass). Defer.
- **MarkdownEditorCommands.swift** (740) — command bar; large surface.
- **MarkdownEditorStyle.swift** (421) — style/theme tokens.
- **MarkdownLayoutFragment.swift** (46) — TextKit2 fragment renderer.
- **ModelInvolvementSheet.swift** (964) — model-involvement audit
  sheet. Worth a spot-read in iter 14.
- **ModelVaultBrowserSheet.swift** (526) — model-vault browser.
- **ModelVaultsSidebarSection.swift** (1,243) — large sidebar
  section.
- **NoteBacklinksPanel.swift** (189) — backlinks pane.
- **NoteChatSidebar.swift** (137) — chat sidebar for notes.
- **NoteDetailWorkspaceView.swift** (3,769) — **already partially
  audited iters 6, 9.** P2 carry-overs there. Deferred for completeness.
- **NoteImageProcessor.swift** (97) — image-in-note processor.
- **NoteTableOfContents.swift** (345) — TOC pane.
- **NoteWindowManager.swift** (711) — per-window state mgr.
- **NotesBrowserView.swift** (18) — trivial.
- **NotesSidebar.swift** (3,442) — **deferred** for dedicated iter 14.
  Largest sidebar; **13 a11y modifiers** (best in Notes).
- **OutlineNavigatorView.swift** (852) — outline tree; the
  `preconditionFailure` at line 163 is the only hard-fail in the
  sub-tree. Acceptable developer guard.
- **PageEditorCache.swift** (171) — editor cache.
- **ProseEditorRepresentable2.swift** (1,595) — TextKit 2 bridge.
- **ProseEditorView.swift** (551) — outer shell of the editor.
- **ProseTextView2.swift** (2,517) — **partially audited iter 10**
  for the reparse-debounce add-on. Larger surface (selection,
  highlighting, transclusion overlay coordination) untouched here.
  Defer for iter 14.
- **SegmentedIndentationGuideView.swift** (381) — indentation guides.
- **TransclusionOverlayManager2.swift** (356) — transclusion overlay.
- **VaultChangesPanel.swift** (162) — vault change list.
- **VaultOrganizerView.swift** (841) — **already partially audited
  iter 7** (folder-name tooltip).
- **VersionTimeline.swift** (126) — version timeline.
- **WeightedContextEngine.swift** (506) — context-weighting engine.
- **WritingToolsBridge.swift** (19) — bridge stub.

## Findings summary

### P0 / P1

None.

### P2 — defer

- **CC-2 (a11y gap)**: dedicated "Notes editor accessibility pass"
  sub-mission. Largest target.
- **AIPartnerInlineView ghost-text VoiceOver disclosure**: AI
  suggestions invisible to non-sighted users.
- **Five >2K LOC files**: refactor into per-feature files for
  future-audit-velocity. Process improvement.

### Per-file deep audits queued

- iter 14a: NotesSidebar (3,442 LOC)
- iter 14b: CodeEditorView (4,863 LOC)
- iter 14c: ProseTextView2 + ProseEditorRepresentable2 (4,112 LOC combined)
- iter 14d: NoteDetailWorkspaceView remainder (3,769 LOC)
- iter 14e: ModelInvolvementSheet, MarkdownEditorCommands, ModelVaultsSidebarSection (3,000+ LOC combined)

## Action taken this iter

- Filed this audit doc.
- **No code edits.** Cross-cutting findings; per-file deep audits
  queued for iter 14+.

## Carry-overs

- CC-2 + per-file deep-read queue above.
- Notes sub-tree is genuinely massive; iter 14+ will land
  consolidated big-file audits in batches.
