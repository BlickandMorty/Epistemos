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

---

## ROUND-2 DEEPENING (code-level, 2026-06-19)

**Correction to round 1:** pixel components are NOT Landing-scoped — `.pixelPanel` already has **8 call sites across 5 areas** (Settings `SettingsSurfaceComponents.swift:132`, Capture `QuickCaptureView:94`/`TraceInspectorView:145`, Landing ×5). So the hoist is LOWER risk; the real gap is the **theme-conditional 3-way branch** in `PixelPanelModifier.body` (`PixelSurfaceComponents.swift:208-216`) keyed off `LandingCommandThemeTreatment.resolve:12`, which silently downgrades all 8 surfaces to rounded "native/hybrid" on Classic/Ember/custom themes. Collapse THAT.

**(1) PixelSkinTokens** — new `struct PixelSkinTokens: Equatable, Sendable` (cornerRadius=0, borderWidthLight/Dark, hardShadowOffset/Opacity light/dark, accentBarHeight, scanlineOpacity, imageRenderingPixelated, borderTokenLight/Dark = textPrimary@0.34/0.24, pixelDisplayPSName, pixelMonoPSName). Hang as a **stored field on `ResolvedTheme`** (`EpistemosTheme.swift:100-138`, set in the nonisolated init) — it's the cached, custom-theme-honoring, Sendable single-truth both renderers read; convenience `EpistemosTheme.pixel { resolved.pixel }`. Give the init a `pixel: = .standard` DEFAULT so the ~30-param positional init doesn't force every `buildResolved()` site to change at once. Emit: SwiftUI reads geometry directly + `borderToken*.color`; WebKit extends `cssVariables(for:)` (`EpdocEditorChromeView.swift:553`) with string vars `--ep-pixel-radius/border-w/border/shadow-x/shadow-y/scanline-opacity/image-rendering/display-font/mono-font` via the existing `cssColor()` serializer. `editor.css:98 --epdoc-card-radius:18px` → `var(--ep-pixel-radius,18px)`.

**(2) Hoist + collapse** — move `PixelPanelModifier`+`pixelPanel` ext + `PixelGlyph/PixelPanelTitle/PixelPanelBackground/PixelStepMotion` into new `Theme/PixelSkinModifier.swift`; LEAVE landing-specific types (`LandingCommandThemeTreatment`, `PixelLandingCommandTile`, `LandingStageCommandPeak`). In `body` delete the `switch`, call the (renamed) pixel panel UNCONDITIONALLY with literals repointed to `theme.pixel`; delete `classicNativePanel`/`emberHybridPanel`+helpers+`pixelPanelStroke*`. Breaks to fix: keep `LandingCommandThemeTreatment.resolve` (still drives TILE hover/peak, not the panel); custom themes now get pixel (verify `textPrimary` border legibility); all 8 callers unchanged signature but now pixel on every theme (= the deliverable).

**(3) `EpistemosWebTheme.applyScript(for:namespace:)`** — new `@MainActor enum` lifting `EpdocEditorThemeStyle:531-600` verbatim non-private; `Namespace{varPrefix,datasetKey,skinValue}`; templates `--epdoc`→prefix so Epdoc stays byte-identical (zero regression) while OpenClaw emits `--ep-claw-*`; sets `data-epistemos-skin` when skinValue!=nil. Repoint Epdoc's 2 call sites (`:615`,`:758`) — no-op output. **WebKitCodeEditorView must NOT switch to applyScript** (it's message-driven `setState` with `--bg/--fg`; switching breaks its CSS) — instead ADD pixel vars + `data-epistemos-skin` to its setState payload (additive, gated `html[data-epistemos-skin="pixel"]`).

**(4) Failure modes (specific):** (a) **cache-bust** — if pixel is a GLOBAL toggle (not theme-derived) it's not in `resolvedCache:295`'s key → stale tokens; AND `Coordinator.applyTheme:754` diffs on `theme` only → skin-flag change skips re-injection. Fix: keep pixel theme-derived, diff on `(theme,skin)` tuple. (b) **font** — `cssFontFamilyName:1880` maps only 3 names; `ChonkyPixels` is safe (registered + @font-face + PS==family), but **`JetBrainsMono-Regular` has NO @font-face in editor.css and may not be in `displayFontOptions`** → WebView falls back to system mono + scheme handler 404s the font; must add @font-face + ensure it's a served display option. AVOID the DEMO faces. (c) **WKWebView leak** — a 2nd/3rd skinned web surface MUST replicate `dismantleNSView:675` + `Coordinator.shutdown:774` (removeAllUserScripts, invalidate CADisplayLink, removeScriptMessageHandler, notifyWebViewDismantled for the shared-pool refcount). (d) **theme-switch re-inject race** — keep `lastApplied` diff (extended to skin), idempotent var-set, don't route theme through the outbound coalescer.

**(5) Order:** tokens+modifier first (blocks all) → Settings → Capture → Landing overlays → Recall → Onboarding; WebKit: Epdoc (repoint=no-op, then author `html[data-epistemos-skin="pixel"]` rules; dormant until Epdoc's skinValue flips to "pixel") → WebKitCodeEditorView (additive) → OpenClaw (future).

**(6) Open questions:** is the skin theme-derived or a global toggle (the most consequential decision — affects cache-safety)? which production pixel display face (ChonkyPixels recommended)? collapse the landing-tile's own 3-way branch too or leave (will mismatch)? is JetBrainsMono in displayFontOptions+editor.css? wrap Recall/Onboarding raw backgrounds in .pixelPanel? build a native scanline overlay (no consumer yet) or keep scanline web-only?
