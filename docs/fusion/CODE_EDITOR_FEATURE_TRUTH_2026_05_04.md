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
| Show-invisibles and use-spaces preferences | planned; stored/toggled but not consumed by the live editor path |
| Line gutter / folding ribbon | reverted in current SourceEditor configuration |

## Recovery Rule

Any editor work must:

1. read `CODE_EDITOR_FEATURE_AUDIT.md`;
2. verify the relevant `CodeEditorView.swift` call sites before claiming a
   feature is live;
3. update the audit if a planned/reverted feature becomes wired;
4. keep PLAN_V2 §23 benchmark gates in force;
5. avoid replacing the editor shell without measured evidence.

This bridge does not authorize a bulk editor migration.
