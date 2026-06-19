# RESKIN PLAYBOOK — pixel-art revamp across SwiftUI + WebKit (S2, 2026-06-19)

Read-only research (subagent). Feeds the DEEP_PLAN_AUDIT_HUB. Answers: the best PROVEN
way to reskin every surface (native + WebKit-hosted clones like OpenClaw) to one coherent
pixel-art theme. **Key finding: the machinery already exists — this is a CONSOLIDATION,
not a new theme system.**

## Single source of theme truth
- **`EpistemosTheme` → `theme.resolved: ResolvedTheme`** (`Epistemos/Theme/EpistemosTheme.swift:100-209`) = the token struct (palette: background/foreground/accent/border/card/syntax…). Every color is a `ResolvedColorToken` emitting BOTH `.color` (SwiftUI) and `.nsColor` (AppKit/CSS). Cached (`resolvedCache:295`), honors `AppCustomTheme`.
- **Pixel fonts** registered at launch by `EpistemosFont.registerFonts()` (`EpistemosFont.swift:37`); ~30 faces in `Epistemos/Resources/Fonts/`. PS-name→CSS family via `cssFontFamilyName(forPostScriptName:)` (`EpistemosTheme.swift:1880`).
- **GAP — borders/corners/image-rendering are NOT tokens yet:** they're literals scattered in `PixelPanelModifier` (`Views/Landing/PixelSurfaceComponents.swift:203-359`) + a one-off `--epdoc-card-radius:18px` (`js-editor/src/editor.css:98`). **No `image-rendering: pixelated` anywhere** (grep empty).
- Today there are TWO derivations of one truth: SwiftUI reads `.color`; WebKit reads `.nsColor`→`cssColor()`→`--epdoc-*` custom property (`EpdocEditorChromeView.swift:553-587`). The bridge already works.

## The one missing piece: a `PixelSkin` token group
Add `theme.pixel: PixelSkinTokens` (border width, corner=0, hard-shadow offset, scanline/CRT opacity, `imageRenderingPixelated`, pixel-display + mono PS-names; emit `.color`/`.nsColor`). Then BOTH renderers read `theme.pixel.*` instead of literals. Everything else is existing plumbing.

## Native SwiftUI surfaces — proven approach
- Pattern exists: `.pixelPanel(theme:surface:)` (`PixelSurfaceComponents.swift:361`) + `PixelPanelModifier:203` + components `PixelGlyph:631`, `PixelLandingCommandTile:668`, `PixelPanelTitle:476`, frame-stepped `PixelStepMotion:371`. All token-driven.
- **Problem:** the pixel look is (a) only one of 3 branches keyed to `themePair==.platinumViolet` via `LandingCommandThemeTreatment.resolve:12` (other themes fall back to rounded "native"/"hybrid"), and (b) scoped to the Landing surface only.
- **Fix:** hoist `pixelPanel`/`PixelGlyph`/etc. out of `Views/Landing/` into `Theme/`; collapse the 3-way treatment to read `theme.pixel` (or a global pixel-on flag) so the look is theme-UNCONDITIONAL; then apply `.pixelPanel` to Chat / Settings / Notes chrome / Graph. Low risk — battle-tested modifier, just hoisted.

## WebKit-hosted surfaces (Epdoc + future OpenClaw) — CSS injection
- **Proven precedent #1 (primary template):** `EpdocEditorThemeStyle.applyScript(for:)` (`EpdocEditorChromeView.swift:536`) — IIFE sets `documentElement.dataset.epdocTheme` (scoping hook) + `root.style.setProperty(--epdoc-*, …)` from `theme.resolved`; injected as `WKUserScript` `.atDocumentEnd` (`:613-619`); **survives re-renders/theme switches** via `Coordinator.applyTheme(_:to:)` (`:753`, diffs `lastAppliedTheme`, re-`evaluateJavaScript`). Static CSS that consumes the vars = `js-editor/src/editor.css` (`:root` defaults `:78`), bundled to `Resources/Editor/`, served by `EpdocEditorURLSchemeHandler` (`EpdocEditorBridge.swift:187`, Brotli decompress `:277`).
- **Proven precedent #2:** `WebKitCodeEditorView.swift:856` `epistemosCodeEditor.setState()` (message-driven var push).
- **OpenClaw approach (generalize the injector):** (1) extract `EpistemosWebTheme.applyScript(for:namespace:)` from `EpdocEditorThemeStyle`, emitting namespaced `--ep-pixel-*` vars + a single `data-epistemos-skin="pixel"` on `<html>`; keep the `cssColor()` serializer (`:589`). (2) Ship static `Resources/OpenClawUI/pixel-theme.css` (built by `build-openclaw-ui-bundle.sh`, sibling of `build-tiptap-bundle.sh`) scoped under `html[data-epistemos-skin="pixel"]`: `image-rendering:pixelated`, `border-radius:0`, 2px hard borders, pixel `@font-face`. (3) Inject **`.atDocumentStart`** for OpenClaw (before Lit's first render) — re-apply on theme change via the Epdoc `applyTheme` diff. OpenClaw renders markdown via `marked`+`dompurify` into a STABLE DOM → pure-CSS skin, no render-code fork. (4) Serve the pixel font for free via the copied scheme handler's `bundledFontAsset` (`EpdocEditorBridge.swift:133`). (5) Scope ALL selectors `html[data-epistemos-skin="pixel"] …` + namespaced vars so the skin toggles off and never bleeds into OpenClaw dialogs.

## Demo-ish inconsistencies to standardize
- Pixel look is theme-CONDITIONAL (only `.platinumViolet`), not a real skin.
- Pixel components are Landing-SCOPED (not applied to Chat/Settings/Notes/Graph).
- No `image-rendering: pixelated` anywhere.
- Borders/corners are divergent literals (SwiftUI `cornerRadius:28/18` vs CSS `18px`).
- Self-declared DEMO fonts (`MatrixDotsDemoRegular` stamps "DEMO FONT"; `Dotemp-8bit2` PSName `DotempDemo-8bit`) — avoid for production pixel face.
- TWO parallel WebKit injectors with differently-named vars (`--epdoc-*` vs `--bg/--fg`) — should share one serializer.
- Epdoc CSS keeps its own `:root` + `@media(prefers-color-scheme)` palette that can drift from `EpistemosTheme`.

## Ordered reskin plan
1. Add `PixelSkinTokens` to `EpistemosTheme` (single source — blocks everything).
2. Hoist + unconditionalize the native modifier (move to `Theme/`, drive border/corner/shadow from tokens).
3. Apply native skin surface-by-surface: Settings rows → Chat bubbles/composer → Notes chrome → Graph → overlays.
4. Generalize the WebKit injector into `EpistemosWebTheme.applyScript(for:namespace:)`; repoint Epdoc + code-editor at it (pure refactor, regression-safe).
5. Author `pixel-theme.css` for Epdoc first (stable DOM + bundling + font-serving already there), gated by `data-epistemos-skin="pixel"`.
6. OpenClaw when it lands: `build-openclaw-ui-bundle.sh` + `OpenClawUIURLSchemeHandler` (copy Epdoc handler) + inject at documentStart + scoped `pixel-theme.css`.

Key files: `Epistemos/Theme/EpistemosTheme.swift` · `EpistemosFont.swift` · `Views/Landing/PixelSurfaceComponents.swift` · `Views/Epdoc/EpdocEditorChromeView.swift` (template) · `Views/Notes/WebKitCodeEditorView.swift` · `Engine/EpdocEditorBridge.swift` · `js-editor/src/editor.css` · pairs with `docs/research/OPENCLAW_UI_EMBED_MAP_2026_06_19.md`.
