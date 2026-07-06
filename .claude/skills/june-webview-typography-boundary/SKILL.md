---
name: june-webview-typography-boundary
description: Use when changing MAS June webview typography, native host CSS overlays, vendored June font tokens, landing/page-header display fonts, or any style rule that could make sidebar, body, composer, settings, or note text inherit a pixel/display face.
---

# June Webview Typography Boundary

## Purpose

Use this skill to keep June readable while preserving the Epistemos display voice. The rule is: body/chrome/editor text uses the regular June/system UI stack; Matrix Dots or other display faces are reserved for explicit large headers such as the landing greeting and page titles.

Do not use this skill to rewrite June's whole CSS theme, bundle unlicensed font files, or apply a display font through a broad selector like `html, body, *`, `.sidebar`, `.agent-composer *`, or `[contenteditable]`.

## Required Reads

1. `docs/prompts/PROMPT_PLAN_1_MAS_JUNE.md`
2. `docs/research/JUNE_MAS_CONNECTION_AUDIT.md`
3. `Epistemos/JuneAgent/JuneAgentSurfaceView.swift`
4. `/Users/jojo/dev/june-epistemos/src/styles/fonts.css`
5. `/Users/jojo/dev/june-epistemos/src/styles/tokens.css`
6. `/Users/jojo/dev/june-epistemos/src/styles/app.css`
7. The React component that owns the target header or surface
8. `EpistemosTests/AppStoreJuneHardeningTests.swift`

## Method

1. Start from the host overlay.
   - Inspect `workspaceOverlayScript()` before editing vendored CSS.
   - If the host overlay already overrides tokens with `!important`, fix the overlay first; vendored CSS cannot reliably win against it.
   - Keep R6 font substitution intact: June's commercial web fonts resolve to MAS-legal local/system substitutes.

2. Reset broad typography to the UI stack.
   - Point `--font-sans` and `--font-serif` at a readable UI family such as `"ABC Diatype", -apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif`.
   - Keep `--font-mono` on a real monospace stack.
   - Broad selectors may normalize readability and letter spacing, but must use the UI token:
     `html, body, button, input, textarea, select, [contenteditable], .sidebar, .agent-composer, .agent-composer *`.

3. Create a narrow display allowlist.
   - Define one display token such as `--epistemos-display-font`.
   - Load the approved bundled display face through an explicit `@font-face`; for the current June MAS surface this is `MatrixDotsDemoRegular.ttf` as `"Epistemos Matrix Dots"`.
   - Apply the display token only to large title selectors, for example:
     `.agent-hero-title`, `.folders-heading h1`, `.note-title`, `.folder-detail-title`, `.folder-detail-title-input`, `.welcome-title`.
   - Do not apply display fonts to sidebar nav labels, composer/editor text, settings rows, note bodies, buttons, chips, badges, code, or small section labels.

4. Preserve UX and layout fixes.
   - Keep existing bubble color, composer wrapping, caret, sidebar alignment, origin pinning, and rebrand fixes when changing font rules.
   - Avoid adding a second overlay or a second token system; the host overlay should remain the single native authority for MAS-only typography overrides.

5. Source-guard the boundary.
   - Guard that broad selectors use `var(--epistemos-ui-font)`.
   - Guard that display selectors use `var(--epistemos-display-font)`.
   - Guard that the old all-over display family is absent from the overlay.
   - Guard that the display `@font-face` loads the approved bundled resource.

## Verification

- Run `git diff --check` over touched CSS/Swift/test/audit files.
- Run parser-only Swift for `JuneAgentSurfaceView.swift` and `AppStoreJuneHardeningTests.swift` before any heavier build.
- Source-scan for the exact split: regular UI font on body/sidebar/composer, display token only on the header allowlist.
- On 16 GB machines, defer web bundle/native App Store build until no unrelated `xcodebuild`, `swift-frontend`, `rustc`, or large node build is active.
- Runtime proof later: MAS app screenshot or computed-style inspection showing body/sidebar/composer use regular UI fonts while landing/page headers use Matrix Dots.
