import Testing
import Foundation
@testable import Epistemos

/// Owner 2026-06-18 (P6.4 REAL BUG: "custom-theme font won't set"). These exercise
/// the REAL persistence + custom-gating layer of the heading-font override
/// (`AppDisplayTypography.setHeadingFontOverride` / `storedHeadingFontOverride` /
/// `headingFontOverride`, all `defaults:`-injectable). If a pick silently fails to
/// store, or the override isn't honored under the Custom theme, it surfaces here —
/// and locks the layer so it can't regress. (The SwiftUI view-observation layer is a
/// separate concern; this proves the model layer is sound.)
@Suite("Heading font override — persistence + custom-theme gating")
struct HeadingFontOverrideTests {

    private func freshDefaults(_ suite: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private func makeCustom(_ defaults: UserDefaults) {
        defaults.set(ThemePair.custom.rawValue, forKey: UIState.themePairDefaultsKey)
    }

    @Test("a valid pick round-trips: set → stored → honored under Custom")
    func validPickRoundTrips() {
        let defaults = freshDefaults("epistemos.test.headingfont.roundtrip")
        makeCustom(defaults)
        let name = AppDisplayTypography.displayFontOptions.first!.postScriptName

        AppDisplayTypography.setHeadingFontOverride(name, level: 1, defaults: defaults)
        // Persisted...
        #expect(AppDisplayTypography.storedHeadingFontOverride(level: 1, defaults: defaults) == name)
        // ...and HONORED under the Custom theme (the "it set" path).
        #expect(AppDisplayTypography.headingFontOverride(level: 1, defaults: defaults) == name)
    }

    @Test("every Picker font option persists — a pick can never silently no-op")
    func everyPickerOptionPersists() {
        let defaults = freshDefaults("epistemos.test.headingfont.alloptions")
        makeCustom(defaults)
        // The Picker tags each row with `option.postScriptName` and the setter only
        // stores when `displayFontOption(postScriptName:) != nil`. Prove EVERY offered
        // option clears that validation, so the owner's "won't set" can't come from a
        // tag/validation mismatch silently dropping the selection.
        for option in AppDisplayTypography.displayFontOptions {
            AppDisplayTypography.setHeadingFontOverride(option.postScriptName, level: 2, defaults: defaults)
            #expect(
                AppDisplayTypography.storedHeadingFontOverride(level: 2, defaults: defaults) == option.postScriptName,
                "Picker option '\(option.displayName)' must persist, not silently drop"
            )
        }
    }

    @Test("override is gated to the Custom theme: persisted but not honored off-Custom")
    func gatedToCustomTheme() {
        let defaults = freshDefaults("epistemos.test.headingfont.gating")
        makeCustom(defaults)
        let name = AppDisplayTypography.displayFontOptions.first!.postScriptName
        AppDisplayTypography.setHeadingFontOverride(name, level: 3, defaults: defaults)
        #expect(AppDisplayTypography.headingFontOverride(level: 3, defaults: defaults) == name)

        // Switch OFF Custom — the override stays persisted but is no longer honored
        // (heading fonts only apply to the Custom theme by design).
        defaults.set(ThemePair.platinumViolet.rawValue, forKey: UIState.themePairDefaultsKey)
        #expect(AppDisplayTypography.headingFontOverride(level: 3, defaults: defaults) == nil)
        #expect(AppDisplayTypography.storedHeadingFontOverride(level: 3, defaults: defaults) == name)
    }

    @Test("clearing the override removes it (Theme-default tag)")
    func clearingRemoves() {
        let defaults = freshDefaults("epistemos.test.headingfont.clear")
        makeCustom(defaults)
        let name = AppDisplayTypography.displayFontOptions.first!.postScriptName
        AppDisplayTypography.setHeadingFontOverride(name, level: 1, defaults: defaults)
        #expect(AppDisplayTypography.storedHeadingFontOverride(level: 1, defaults: defaults) == name)

        // The "Theme default" Picker tag is "" → clears the override.
        AppDisplayTypography.setHeadingFontOverride("", level: 1, defaults: defaults)
        #expect(AppDisplayTypography.storedHeadingFontOverride(level: 1, defaults: defaults) == nil)
    }

    @Test("an unknown font name never stores (validation holds)")
    func unknownNameRejected() {
        let defaults = freshDefaults("epistemos.test.headingfont.unknown")
        makeCustom(defaults)
        AppDisplayTypography.setHeadingFontOverride("NotARealFont-XYZ", level: 1, defaults: defaults)
        #expect(AppDisplayTypography.storedHeadingFontOverride(level: 1, defaults: defaults) == nil)
    }
}
