# Code Editor Feature Truth — 2026-05-04

Track: T9 `.epdoc` / editor.

This bridge promotes the `codex/runtime-input-audit` code-editor audit into
fusion so editor work starts from live truth instead of stale feature claims.

## Donor / Live Authority

Source:

- branch `codex/runtime-input-audit`
- root `CODE_EDITOR_FEATURE_AUDIT.md`
- `Epistemos/Views/Notes/CodeEditorView.swift`

Current main evidence:

- `CODE_EDITOR_FEATURE_AUDIT.md` exists at repo root and matches the branch
  audit shape.

## Live Truth

- Code-like notes route to `CodeEditorView`; non-code notes route to the prose
  editor path.
- The live editor surface is `SourceEditor` from CodeEditSourceEditor, not the
  older custom `NSTextView` + minimap stack.
- The earlier custom storage/delegate path was reverted because
  CodeEditSourceEditor owns internal delegate plumbing.
- Editor feature claims drift quickly and must be verified against live code
  before optimization or migration.

## Feature Status Summary

| Claim | Status |
|---|---|
| Custom NSTextView + line gutter + minimap is the live architecture | reverted |
| Indentation guides | verified |
| Minimap | reverted |
| Outline navigator replacing minimap | verified |
| Search/find bar | planned; UI exists, execution remains stubbed |
| Go to Line sheet | verified |
| Semantic sidebar | planned; code exists but release-gated off |
| Old status bar layout | reverted; current chrome is breadcrumb-based |
| Search button / View menu / Settings menu | verified |
| Word-wrap, font-size, tab-width preferences | verified |
| Show-invisibles and use-spaces preferences | verified; consumed by CodeEditSourceEditor invisible-character and indentation configuration |
| Line gutter / folding ribbon | verified; native SourceEditor gutter + indentation-derived folding ribbon wired, old right-edge Epistemos gutter kept dormant as fallback scaffold |
| VS Code-style indentation guides | verified; segmented guide overlay is live, toggleable, and aligned to actual font + tab-width metrics |

## Recovery Rule

Any editor work must:

1. read `CODE_EDITOR_FEATURE_AUDIT.md`;
2. verify the relevant `CodeEditorView.swift` call sites before claiming a
   feature is live;
3. update the audit if a planned/reverted feature becomes wired;
4. keep PLAN_V2 §23 benchmark gates in force;
5. avoid replacing the editor shell without measured evidence.

This bridge does not authorize a bulk editor migration.

## 2026-05-07 Native Editor Upgrade

The code editor remains native. The current upgrade deliberately avoids a
CodeMirror/WebKit migration because the app already ships
CodeEditSourceEditor + SwiftTreeSitter and the benchmark gate for replacing
the live editor has not been met.

Changes now treated as live truth:

- CodeEditSourceEditor's native left gutter is the visible line-number surface.
- CodeEditSourceEditor's native folding ribbon provides the scope-collapse
  arrows when the line gutter is enabled. The folding provider is
  indentation-derived, so nested collapsible affordances follow the same
  hierarchy as the code indentation instead of behaving like generic gutter
  decoration.
- `Show Invisibles` feeds native invisible-character rendering for spaces,
  tabs, and line endings.
- `Use Spaces` feeds native tab insertion behavior.
- `Indent Guides` exposes the existing segmented VS Code-style vertical guide
  overlay, now aligned from the live editor font, tab width, and text inset.
- The live semantic theme no longer collapses most token categories into body
  text; the no-highlight theme remains only as explicit fallback scaffold.
