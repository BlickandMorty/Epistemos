import Foundation
import Testing
@testable import Epistemos

@Suite("Theme Picker Restoration")
struct ThemePickerRestorationTests {
    @MainActor
    private func withPreservedThemeDefaults(_ body: () -> Void) {
        let defaults = UserDefaults.standard
        let keys = [ThemeMode.defaultsKey, UIState.themePairDefaultsKey]
        let previousValues = keys.map { ($0, defaults.object(forKey: $0)) }
        defer {
            for (key, value) in previousValues {
                if let value {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }
        body()
    }

    @MainActor
    @Test("custom theme pair resolves semantic tokens without custom window overlays")
    func customThemePairResolvesSemanticTokensWithoutWindowOverlays() {
        withPreservedThemeDefaults {
            let defaults = UserDefaults.standard
            defaults.removeObject(forKey: ThemeMode.defaultsKey)
            defaults.removeObject(forKey: UIState.themePairDefaultsKey)

            let uiState = UIState()
            uiState.isSystemDark = false
            uiState.setPair(.platinumViolet)
            uiState.setThemeMode(.custom)

            #expect(uiState.activePair == .platinumViolet)
            #expect(uiState.themeMode == .custom)
            #expect(uiState.customThemesEnabled)
            #expect(uiState.theme == .platinumViolet)
            #expect(uiState.preferredColorScheme == nil)
            #expect(uiState.shouldUseThemeWorkarounds == false)
            #expect(uiState.windowAppearance == nil)

            uiState.isSystemDark = true
            #expect(uiState.theme == .platinumVioletDark)
        }
    }

    @MainActor
    @Test("saved theme pair preferences restore on launch")
    func savedThemePairPreferencesRestoreOnLaunch() {
        withPreservedThemeDefaults {
            let defaults = UserDefaults.standard
            defaults.set(ThemePair.ember.rawValue, forKey: UIState.themePairDefaultsKey)
            defaults.set(ThemeMode.custom.rawValue, forKey: ThemeMode.defaultsKey)

            let uiState = UIState()
            uiState.isSystemDark = false

            #expect(uiState.activePair == .ember)
            #expect(uiState.themeMode == .custom)
            #expect(uiState.theme == .tan)

            uiState.isSystemDark = true
            #expect(uiState.theme == .ember)
        }
    }

    @Test("Settings Appearance exposes the theme pair picker")
    func settingsAppearanceExposesThemePairPicker() throws {
        let settings = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsView.swift")

        #expect(settings.contains("AppearanceThemePairSection("))
        #expect(settings.contains("ForEach(ThemePair.allCases, id: \\.self)"))
        #expect(settings.contains("ThemePairCard("))
        #expect(settings.contains("ThemePairCinematicPreview(pair: pair)"))
        #expect(settings.contains("ThemePairCinematicHalf(theme: pair.lightTheme"))
        #expect(settings.contains("ThemePairCinematicHalf(theme: pair.darkTheme"))
        #expect(settings.contains("ui.setPair(pair)"))
        #expect(!settings.contains("Toggle(\"Follow macOS\""))
        #expect(!settings.contains("Follows macOS"))
        #expect(!settings.contains("ui.setThemeMode(.systemDefault)"))
        #expect(settings.contains("ui.setThemeMode(.custom)"))
        #expect(settings.contains("Toggle(\"Readable fonts\""))
        #expect(settings.contains("ui.setReadableFontsEnabled($0)"))
        #expect(!settings.contains("Toggle(\"Regular Mode\""))
        #expect(!settings.contains("Restart to Apply Display Mode?"))
        #expect(!settings.contains("applyDisplayModeAndRelaunch"))

        let rootView = try loadMirroredSourceTextFile("Epistemos/App/RootView.swift")
        #expect(rootView.contains(".onChange(of: ui.readableFontsEnabled)"))
        #expect(!rootView.contains(".id(ui.readableFontsEnabled)"))
    }
}
