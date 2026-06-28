# Plan 3 — Landing-page feature buttons (clone-ready code, Pass 5)

> Companion to `PLAN_3_CAPABILITIES_2026_06_28.md §8`. Owner requirement: EVERY Plan-3 feature is a one-tap button on
> the landing page. Pure additive UI — no backend/Plan-1/Plan-2 clash. `[VERIFIED-CODE]`/`[INFERRED]` tagged.

## Verified landing surface
- Landing page = `LandingView` (`Epistemos/Views/Landing/LandingView.swift:37`); content in `greetingContent` (`:413`);
  the existing shortcut grid is `landingPixelCommands` (`:492-598`) — a `LazyVGrid(columns:[.adaptive(min:136,max:176,
  spacing:8)])` of ~11 `PixelLandingCommandTile` (each = title/shortcut/glyph/theme/accent/haptic + `action:` closure,
  e.g. "notes"→`UtilityWindowManager.shared.show(.notes)` `:540`, "graph"→toggle `:578`). Capped `maxWidth:900`.
- Tile component `PixelLandingCommandTile` (`PixelSurfaceComponents.swift:668`); glyphs `PixelGlyphKind` (`:80-108`);
  haptics `HomeCommandHapticStyle` (`TypewriterMarkdown.swift:58-68`).
- **Existing summon mechanisms to reuse (no new windowing):** `UtilityWindowManager.shared.show(_:)` (`:219`, panels
  `.notes/.settings`); standalone window controllers `GooseSurfaceWindowController.open()` (`Goose/...:11`) +
  `WorkWebSurfaceWindowController.open()`; inline `LiteParsePDFImportButton.runImport()` (`:41`). Settings deep-links:
  `SettingsSection.provenance` (`SettingsView.swift:101`→`ProvenanceConsoleView` `:331`), `.skills` Pro-gated (`:114`).
- Honest gating is **compile-time**: `#if EPISTEMOS_APP_STORE || MAS_SANDBOX` (`DeploymentProfileHealthRow.swift:24`,
  `SettingsView.swift:114`). A Pro-only landing button must show a lock/"PRO" pill in MAS + explain on tap, never
  summon an absent surface.

## NEW `Epistemos/Views/Landing/LandingFeatureButtons.swift`
- **`enum LandingFeatureButton: CaseIterable`** — one case per feature (`browser`/`extensions`/`vaultMCP`/`pdfImport`/
  `provenance`, + future ones). Each derives `title`/`glyph`(reuse `PixelGlyphKind`)/`accent`/`haptic`/`isProOnly`/
  `isAvailableInThisBuild` (compile-time). Adding a feature = **1 enum case + 1 switch line**.
- **`LandingFeatureButtonTile`** — wraps the existing `PixelLandingCommandTile` (unchanged) + overlays a "PRO" pill when
  `isProOnly && !isAvailableInThisBuild`; `.help` text honest.
- **`landingFeatureShortcuts`** computed view in `LandingView` — same `LazyVGrid` column spec, `ForEach(LandingFeatureButton.allCases)`,
  placed in `greetingContent` above `landingPixelCommands` (`:425`).
- **`performFeatureButton(_:)`** single dispatch — honest gate first (`guard isAvailableInThisBuild else { showToast("…
  available in Epistemos Pro"); return }`), then summon the VERIFIED entry point: `.browser`→`GooseSurfaceWindowController.shared.open()`,
  `.extensions/.vaultMCP/.provenance`→`UtilityWindowManager.shared.show(.settings)`, `.pdfImport`→`runLandingPDFImport()`
  (lift `LiteParsePDFImportButton.runImport()` body — env already present in `LandingView`).

## Notes
- **Deep-link refinement `[INFERRED]`:** add `initialSection: SettingsSection?` to `SettingsView.init` + a
  `show(.settings, section:)` overload so `.provenance`/`.extensions` land directly on their pane (works without it,
  just one click away).
- **MAS-safe + no clash:** pure UI; every action summons an already-shipping surface; only `.extensions` is Pro-gated
  (lock pill + toast in MAS). Reusing the pixel tile inherits theme treatments + hover motion automatically.
- **Browser button → Obscura:** points at the in-app WKWebView browser (Obscura Tier 1 codepack). Once Obscura Tier 1
  lands as its own `UtilityPanel.browser`, repoint `.browser` to `UtilityWindowManager.shared.show(.browser)`.
