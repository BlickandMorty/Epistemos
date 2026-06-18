import Testing
import Foundation
@testable import Epistemos

/// P6.4 — locks the custom-theme heading-font override end to end after the
/// "picking a font does nothing" bug. The WRITE side (Settings picker →
/// `setHeadingFontOverride`) persisted correctly and the gated READ
/// (`headingFontOverride`, custom-theme-only) was correct too — the break was the
/// LIVE RE-RENDER: `UIState.theme` never observed `typographySettingsRevision`,
/// so an override persisted but no themed view re-derived. These guard both the
/// store round-trip/gate AND the re-render dependency.
@Suite("Custom theme font override")
struct CustomThemeFontOverrideTests {

    private func isolatedDefaults() -> UserDefaults {
        let name = "test.fontoverride.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    @Test("a picked heading font persists and reads back when the custom theme is active")
    func overridePersistsAndReadsBack() throws {
        let defaults = isolatedDefaults()
        // A real bundled display-font PostScript name — the exact tag the Settings
        // picker writes, and what `displayFontOption(postScriptName:)` validates.
        let option = try #require(AppDisplayTypography.displayFontOptions.first)
        let psName = option.postScriptName

        defaults.set(ThemePair.custom.rawValue, forKey: UIState.themePairDefaultsKey)
        AppDisplayTypography.setHeadingFontOverride(psName, level: 1, defaults: defaults)

        #expect(AppDisplayTypography.storedHeadingFontOverride(level: 1, defaults: defaults) == psName)
        // The gated read returns it because the custom theme is active.
        #expect(AppDisplayTypography.headingFontOverride(level: 1, defaults: defaults) == psName)
    }

    @Test("the override is gated to the custom theme (ignored on other pairs)")
    func overrideGatedToCustomTheme() throws {
        let defaults = isolatedDefaults()
        let psName = try #require(AppDisplayTypography.displayFontOptions.first).postScriptName

        defaults.set(ThemePair.custom.rawValue, forKey: UIState.themePairDefaultsKey)
        AppDisplayTypography.setHeadingFontOverride(psName, level: 2, defaults: defaults)
        #expect(AppDisplayTypography.headingFontOverride(level: 2, defaults: defaults) == psName)

        // Switch to a non-custom pair → the gated read ignores the override.
        defaults.set(ThemePair.platinumViolet.rawValue, forKey: UIState.themePairDefaultsKey)
        #expect(AppDisplayTypography.headingFontOverride(level: 2, defaults: defaults) == nil)
    }

    @Test("clearing the override (Theme default) removes it")
    func overrideClears() throws {
        let defaults = isolatedDefaults()
        let psName = try #require(AppDisplayTypography.displayFontOptions.first).postScriptName

        defaults.set(ThemePair.custom.rawValue, forKey: UIState.themePairDefaultsKey)
        AppDisplayTypography.setHeadingFontOverride(psName, level: 3, defaults: defaults)
        #expect(AppDisplayTypography.storedHeadingFontOverride(level: 3, defaults: defaults) == psName)

        AppDisplayTypography.setHeadingFontOverride(nil, level: 3, defaults: defaults)
        #expect(AppDisplayTypography.storedHeadingFontOverride(level: 3, defaults: defaults) == nil)
    }

    @Test("UIState.theme observes the typography revision so font changes re-render live")
    func themeObservesTypographyRevision() throws {
        // Source-guard for the actual bug fix: the `theme` getter must read
        // `typographySettingsRevision`, else overrides persist but never re-render.
        let source = try loadMirroredSourceTextFile("Epistemos/State/UIState.swift")
        #expect(source.contains("_ = typographySettingsRevision"))
    }
}
