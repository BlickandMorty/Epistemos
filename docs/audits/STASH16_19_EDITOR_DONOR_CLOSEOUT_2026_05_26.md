# Stash 16 / 19 Editor Donor Closeout - 2026-05-26

Status: closed for current product editor recovery.

Sources:

- `stash@{16}` (`session-stash-2026-04-27: W9.21 PR4 (X salvaged) + W9.8 wire-up partial`)
- `stash@{19}` (`Fix: Invisible text in code editor - isRichText must be true`)

Recovery rule: this slice was inspected with `git stash show`, `git show`, and
`git diff` only. No stash was popped, dropped, checked out, or bulk-applied.

## Decision

The useful editor work from these stashes is already represented on current
`main`, or has been superseded by newer editor architecture. The raw stash
trees must not be restored as live editor code.

## What Is Already On Main

Current `main` carries the durable editor/vendor pieces:

- `Epistemos/Resources/Editor/editor.html`
- `Epistemos/Resources/Editor/editor.css.br`
- `Epistemos/Resources/Editor/editor.js.br`
- compressed KaTeX CSS and `.woff2` fonts under
  `Epistemos/Resources/Editor/vendor/katex/`
- Xcode-style code color tokens via `EpistemosTheme.XcodeCodeColors`
- the live native editor path through `CodeEditSourceEditor`
- source guards that keep new visual/DOM work on HTML Workspace, not Mermaid

## What Was Not Restored

The untracked `stash@{16}` editor assets include uncompressed `editor.css`,
`editor.js`, broad KaTeX font variants, and `vendor/mermaid/mermaid.min.js`.
Current `main` intentionally uses the compressed bundle and `.woff2` KaTeX
fonts. The Mermaid runtime is intentionally absent: old Mermaid blocks remain
legacy source-compatible, while new visual creation routes to HTML Workspace.

The `stash@{19}` `CodeEditorView.swift` patch contains an old "MINIMAL TEST"
rewrite that removed the shell, gutter, and minimap around a plain
`NSTextView`. That file is not restored because current `main` has the newer
`CodeEditSourceEditor` path with native gutter, folding, invisibles, search,
debounced content writeback, and sidecar surfaces.

The old `isRichText = true` advice applied to the removed bespoke
`CodeTextView` syntax-highlighting path. Current `main` no longer uses that
path as the live code editor. The two remaining `isRichText = false` sites are
lightweight graph-inspector `NSTextView` preview/editor helpers; they are not
the production code editor canvas.

## Guardrail

`EpistemosTests/Stash16And19EditorCloseoutTests.swift` keeps this decision
executable:

1. The closeout must stay listed in the stash ledger and recovery status docs.
2. The compressed editor bundle and KaTeX `.woff2` resources must remain
   present.
3. `vendor/mermaid/mermaid.min.js` must stay absent from the live bundle.
4. `CodeEditorView.swift` must keep the `CodeEditSourceEditor` route.
5. The old "MINIMAL TEST" editor rewrite must stay absent.

## Remaining Risk

This closeout does not claim launched-app typing performance. It only prevents
old stashes from being forgotten or raw-restored over the current editor. Any
future editor performance claim still needs the dedicated launched-app editor
baseline from `docs/PERF_BASELINE.md` and the protected-editor constraints in
`docs/PHASE_S_AUDIT.md`.
