# Plan 3 — Landing-page feature buttons (shipped code, Pass 6)

> Companion to `PLAN_3_CAPABILITIES_2026_06_28.md §8`. Owner requirement: EVERY Plan-3 feature is a one-tap button on
> the landing page. The shipped surface is pure additive UI — no backend/Plan-1/Plan-2 clash.
> `[VERIFIED-CODE]`/`[INFERRED]` tagged.

## Verified landing surface
- Landing page = `LandingView` (`Epistemos/Views/Landing/LandingView.swift:37`); content in `greetingContent` (`:413`);
  the existing shortcut grid is `landingPixelCommands` (`:492-598`) — a `LazyVGrid(columns:[.adaptive(min:136,max:176,
  spacing:8)])` of ~11 `PixelLandingCommandTile` (each = title/shortcut/glyph/theme/accent/haptic + `action:` closure,
  e.g. "notes"→`UtilityWindowManager.shared.show(.notes)` `:540`, "graph"→toggle `:578`). Capped `maxWidth:900`.
- Tile component `PixelLandingCommandTile` (`PixelSurfaceComponents.swift:668`); glyphs `PixelGlyphKind` (`:80-108`);
  haptics `HomeCommandHapticStyle` (`TypewriterMarkdown.swift:58-68`).
- **Existing Plan 3 summon mechanisms to reuse (no new windowing):** `UtilityWindowManager.shared.show(_:)` (`:219`,
  panels `.settings/.browser/.meetingNote`), `UtilityWindowManager.shared.showSettings(section:)`,
  `ArxivSearchView()` via the landing sheet, and `LiteParsePDFImportController.importPage` through the landing PDF import flow. Settings deep-links:
  `SettingsSection.provenance` (`SettingsView.swift:101`→`ProvenanceConsoleView` `:331`), `.skills` Pro-gated (`:114`).
  Do not route landing feature buttons through Goose or Work window controllers; those are outside Plan 3 ownership.
- Honest gating is **compile-time**: `#if EPISTEMOS_APP_STORE || MAS_SANDBOX` (`DeploymentProfileHealthRow.swift:24`,
  `SettingsView.swift:114`). A Pro-only landing button must show a lock/"PRO" pill in MAS + explain on tap, never
  summon an absent surface.

## `Epistemos/Views/Landing/LandingFeatureButtons.swift` [DELIVERED]
- **`enum LandingFeatureButton: CaseIterable`** — one case per feature (`pdfImport`/`arxiv`/`provenance`/`extensions`/
  `vaultMCP`/`browser`/`browserUsePro`/`meetingNote`/`voice`). Each derives
  `title`/`glyph`(reuse `PixelGlyphKind`)/theme-token `accent(in:)`/`haptic`/`isProOnly`/`isAvailableInThisBuild`;
  meeting additionally uses `MeetingNoteLandingGateStatus` for macOS 26 SpeechAnalyzer plus microphone denial checks.
  Adding a feature = **1 enum case + 1 switch line**.
- **`LandingFeatureButtonTile`** — wraps the existing `PixelLandingCommandTile` (unchanged) + overlays a "PRO" pill when
  `isProOnly && !isAvailableInThisBuild`; `.help` text honest. Pro-only feature tiles do not also reuse the shortcut
  slot for "PRO", so MAS shows one lock/pro indicator instead of a duplicated badge. Feature unavailable/help text is
  bounded and control/whitespace-normalized, then shown in tooltips and alerts with ellipsis kept inside configured caps.
- **`landingFeatureShortcuts`** computed view in `LandingView` — same `LazyVGrid` column spec, `ForEach(LandingFeatureButton.allCases)`,
  placed in `greetingContent` above `landingPixelCommands` (`:425`).
- **`performFeatureButton(_:)`** single dispatch — honest gate first (`guard isAvailableInThisBuild else {
  presentLandingFeatureStatus(feature.unavailableMessage); return }`), then summon the VERIFIED Plan 3 entry point:
  `.browser`→`UtilityWindowManager.shared.show(.browser)`, `.meetingNote`→`UtilityWindowManager.shared.show(.meetingNote)`,
  `.provenance`→`UtilityWindowManager.shared.showSettings(section: .provenance)`,
  `.extensions/.vaultMCP`→`UtilityWindowManager.shared.showSettings(section: .skills)`,
  `.voice`→`UtilityWindowManager.shared.showSettings(section: .voice)`, `.arxiv`→`showingArxivSearch = true`,
  `.pdfImport`→`runLandingPDFImport()` (lift `LiteParsePDFImportButton.runImport()` body — env already present in `LandingView`).
  Landing feature alerts cap PDF import result row count, per-row text, and final alert text before display, so bulk imports cannot flood the home surface.
  Feature unavailable/help text is bounded and control/whitespace-normalized, then shown in tooltips and alerts with ellipsis kept inside configured caps.

## Notes
- **Deep-link refinement `[VERIFIED-CODE]`:** `SettingsView.init(initialSelection:)` +
  `UtilityWindowManager.shared.showSettings(section:)` now land `.provenance`, `.extensions/.vaultMCP`, and `.voice`
  directly on their panes.
- **MAS-safe + no clash:** pure UI; every action summons an already-shipping surface; `.vaultMCP` and `.browserUsePro`
  are Pro-gated (lock pill + bounded status alert in MAS). Reusing the pixel tile inherits theme-token accents + hover motion automatically.
- **Browser button → Browser:** points at the in-app WKWebView Browser utility panel. The browser-use Chromium robot
  remains Pro-only and separate from this human-driven WebKit tab.
