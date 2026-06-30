# Plan 2 Agent Handoff Audit (2026-06-29)

Purpose: give the next Plan 2/editor agent a no-bullshit record of what changed, what was stale, and what still needs
runtime proof. This file is an addendum to `PROMPT_PLAN_2_EDITOR.md`, `EDITOR_CANONICAL_PLAN_2026_06_27.md`, and
`PROMPT_PLAN_UPGRADE_AUDIT_2026_06_29.md`.

## Bottom Line

The previous "all three prompts are contradiction-free" claim was too shallow. The prompts had upgrade notices, but
the supporting Plan 2 research canon/codepacks still contained stale instructions that could send an agent down the
wrong path. Those were patched at the source.

Agent 2 should treat this as the current editor handoff:

- Markdown-on-disk is the one truth.
- Markdown documents open in the normal prose/edit experience by default; Source is an explicit lens, not the default.
- The visible markdown controls must expose three user-facing modes: Edit/Prose, Preview, and Source.
- Source for `.md` is MarkEdit, with MarkEdit's full MD chrome/settings/features reachable.
- Code files use MarkEdit/CoreEditor as the engine, but the CODE chrome reproduces the v1 minimal Epistemos look.
- HTML Workspace editable source panes use MarkEdit/CoreEditor too (`MarkEditCodeEditorRepresentable`), not the
  AppKit/NSTextView `HTMLWorkspaceCodeEditor`, SwiftUI `TextEditor`, or another bespoke code pane. This is a
  2026-06-30 owner lock after the AppKit path visibly regressed to blank source pixels.
- The old code editor is kept as a v1-legacy fallback in Settings plus a MarkEdit-surface toggle. Do not delete it.
- Goose note work in Plan 2 is context plumbing only. The live Goose chat/agent UI is Plan 1's reskinned WebView.
- Plan 2 owns the PDFKit viewer. Plan 3 owns PDF parsing and the `source_pdf` handoff.

## 2026-06-30 Addendum — HTML Workspace Source Editor Lock

After runtime proof, the HTML Workspace source editor decision changed: editable HTML/CSS/JS/Data panes are part of
the MarkEdit/CoreEditor Source lane. The source pane must mount `MarkEditCodeEditorRepresentable` and share the app
code-editor preferences for font, wrapping, invisibles, spaces, tabs, and line gutter. Do not reintroduce
`HTMLWorkspaceCodeEditor(` or `TextEditor(` inside `HTMLWorkspaceEditorView.swift`; those paths are now stale and
source-guarded. Read-only DOM/route/asset outline panes may remain native read-only views.

Current proof artifact from the MarkEdit source-pane run:
`/tmp/epistemos-htmlworkspace-markedit-source-proof.png`.

## Files Patched In This Audit

- `docs/prompts/PROMPT_PLAN_2_EDITOR.md`
- `docs/prompts/PROMPT_PLAN_3_CAPABILITIES.md`
- `docs/research/EDITOR_CANONICAL_PLAN_2026_06_27.md`
- `docs/research/MARKEDIT_EMBED_CODEPACK_2026_06_27.md`
- `docs/research/GOOSE_MINICHAT_CODEPACK_2026_06_27.md`
- `docs/research/TOLARIA_SUPERSEDE_RESEARCH_2026_06_27.md`
- `docs/research/EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md`
- `docs/research/PLAN_3_CAPABILITIES_2026_06_28.md`
- `docs/research/PROMPT_PLAN_UPGRADE_AUDIT_2026_06_29.md`

Plan 1 was checked for consistency with Option 1: native frame only, Goose chat/rest stay WebView, no native chat.

## Contradictions Fixed

1. **Stop condition contradiction**
   - Bad: Plan 2/3 loop mode said never stop, but tail lines said stop when build sequence/order completes.
   - Fixed: owner stop only; completion rolls into hardening, owed/unspecced work, and re-verification.

2. **Native minichat / Phase-0 gate**
   - Bad: `GOOSE_MINICHAT_CODEPACK` and the editor canon still recommended native SwiftUI minichat and Phase-0/§7
     sign-off gating.
   - Fixed: Plan 2 builds editor-side note-context plumbing only. Plan 1 owns live Goose WebView/reskin UI.

3. **Old code editor deletion**
   - Bad: `TOLARIA_SUPERSEDE_RESEARCH` and old verification specs still said to delete old code editor files.
   - Fixed: keep `WebKitCodeEditorView`/legacy code path reachable as v1 fallback. Deletion needs a later explicit
     owner-approved cleanup.

4. **MarkEdit settings inert**
   - Bad: MarkEdit settings were described as present-but-inert behind a flag.
   - Fixed: that is historical first-slice language only. Final acceptance requires full MarkEdit settings/features
     reachable under Source/MD.

5. **Stale fixed line numbers for `.md` route**
   - Bad: docs pointed at `CodeEditorView.swift:706` and said `.md` routes to Prose.
   - Fixed: verify current code first. The binding requirement is that `.md` can open in Source via explicit lens
     toggle while preserving Prose/Edit default behavior.

6. **MD theme exception**
   - Bad: MarkEdit codepack said MD should stay on MarkEdit's own theme.
   - Fixed: MD preserves MarkEdit layout/chrome/settings, but auto-maps Epistemos light/dark/accent into the MarkEdit
     source surface so the whole app has one theme.

7. **Plan 3 PDF ownership blur**
   - Bad: Plan 3 wording implied it might own the PDF viewer.
   - Fixed: Plan 3 owns parse + `source_pdf` storage/link/affordance. Plan 2 owns the PDFKit viewer.

## Owner-Visible Issues Agent 2 Must Not Lose

The user's latest editor complaints are implementation acceptance criteria, not just doc polish:

- `.md` should open in the prose/edit experience, not source.
- There must be an obvious way back to prose/edit from Source.
- The mode control should expose Edit/Preview/Source as three distinct choices.
- Preview must not merely replace or hide the source/prose route. It should be a real preview mode.
- Source view for markdown must feel like the real MarkEdit app, including MarkEdit toolbar/settings/toggles.
- Code Source must not blindly use full MarkEdit toolbar; it must use the v1 minimal Epistemos chrome on MarkEdit
  engine, with preview/LSP/Outline grafted back.
- App theme must auto-apply to MarkEdit/CoreEditor, Epdoc, and HTML Workspace.
- Epdoc must remain markdown-safe: canonical writer is JS `getMarkdown()`, not the lossy projector.

## Native/Theme Research Saved For Agent 2

The Goose native-web reskin loop produced editor-relevant findings that are now part of Plan 2:

- There are two token sources that must stay value-identical:
  - Swift/native/editor-web: `Epistemos/Theme/EpistemosTheme.swift`
  - Goose-web: `ui/desktop/src/theme/theme-tokens.ts`
- Editor web-body injection points already exist:
  - `EpdocEditorThemeStyle`
  - `MarkEditCoreEditorView` theme injection
  - `HTMLWorkspacePreviewView.themeGuardCSSOverride`
- `--epdoc-bg` is already transparent; keep web bodies transparent over native glass rather than faking glass in CSS.
- MarkEdit/CoreEditor currently tends toward github-light/github-dark style. Replace that with Epistemos tokens.
- Global web-native tells to fix across Goose and editor bodies:
  - remove/neutralize custom `::-webkit-scrollbar` styling so macOS overlay scrollbars show through;
  - use an accent-colored macOS-style focus ring from the unified accent token.
- Pixel-diff harness spec exists in `GOOSE_NATIVE_WEB_RESKIN_2026_06_29.md`: use WebKit snapshots/native render
  snapshots plus pixelmatch/odiff with a strict threshold to compare native vs web controls.

## Final Grep Checks Run

Targeted stale-pattern sweeps were run against prompts and active research docs for:

```text
CodeEditorView.swift:706
routes .md to Prose
MD path stays on MarkEdit
Settings is embedded-but-inert
Full Settings present-but-inert
delete the 3 OLD
delete old code editor
native SwiftUI minichat
native SwiftUI chat
Phase-0 gated
after Phase 0 sign-off
Goose §7 sign-off
Stop only when I say stop OR
```

Remaining matches are intentional guardrails/checklist entries such as "do not delete" or "this old phrase is stale",
not active build instructions.

## What Is Not Proven

This audit was documentation/prompt hardening only. It did not prove the runtime editor implementation. The interrupted
build from the prior implementation thread was stopped and should not be counted as green.

Agent 2 must still prove in app:

- `.md` default opens in Edit/Prose.
- Edit/Preview/Source segmented control is visible and works.
- Source returns to Edit/Prose without losing data.
- Source MD surface has real MarkEdit controls/settings reachable.
- Code file shows highlighted CodeMirror content, not a blank body.
- HTML Workspace source panes show visible MarkEdit/CoreEditor code, not blank AppKit line numbers.
- Code chrome keeps preview/LSP/Outline and real file-type logos.
- Theme switching updates Prose/Epdoc, MarkEdit/CoreEditor, and HTML Workspace without flicker or stale github-only
  colors.
- Epdoc round-trip guardrails fail loudly for lossy markdown edge cases.

## Agent 2 Starting Advice

Start with route and UI truth before expanding features:

1. Inspect the current `.md` route in `NoteDetailWorkspaceView`, `CodeEditorView`, and `MarkEditCoreEditorView`.
2. Make the user-facing control clearly three-way: Edit, Preview, Source.
3. Keep default `.md` open in Edit/Prose unless a persisted/explicit user lens says otherwise.
4. Make Source explicit and reversible.
5. Then harden MarkEdit full MD chrome/settings reachability.
6. Then harden code mode: v1 minimal chrome on MarkEdit engine, real logos, preview/LSP/Outline.
7. Then unify themes through `EpistemosTheme` injection and run visual checks.

Do not start by deleting, renaming, or broad-refactoring old editor files. Wire and prove first.
