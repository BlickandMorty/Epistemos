import AppKit
import Foundation
import SwiftUI
import Testing
@testable import Epistemos

@Suite("ThemePair Dock Icon")
struct ThemePairTests {
    private var customThemeDefaultsKeys: [String] {
        AppCustomThemeColorSlot.allCases.flatMap { slot in
            [
                slot.defaultsKey,
                slot.defaultsKey(isDark: false),
                slot.defaultsKey(isDark: true),
            ]
        }
    }

    @MainActor
    private func withPreservedThemeDefaults(_ body: () -> Void) {
        let defaults = UserDefaults.standard
        let keys = [
            ThemeMode.defaultsKey,
            UIState.themePairDefaultsKey,
            // updated 2026-07-03: preserve the experimental custom-theme flag so
            // tests that enable it (custom fonts/colors now gate on it) restore cleanly.
            AppCustomTheme.experimentalDefaultsKey,
            AppDisplayTypography.headingLevel1FontDefaultsKey,
            AppDisplayTypography.headingLevel2FontDefaultsKey,
            AppDisplayTypography.headingLevel3FontDefaultsKey,
            AppDisplayTypography.headingLevel1ScaleDefaultsKey,
            AppDisplayTypography.headingLevel2ScaleDefaultsKey,
            AppDisplayTypography.headingLevel3ScaleDefaultsKey,
        ] + customThemeDefaultsKeys
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
        AppDisplayTypography.resetHeadingTypography(defaults: defaults)
        // updated 2026-07-03: custom theme is experimental + OFF by default now; start
        // each preserved-defaults test from a known-off baseline so preset assertions
        // never see a leaked custom engagement from a prior test.
        AppCustomTheme.setExperimentalEnabled(false, defaults: defaults)
        body()
    }

    @Test("Font registration ignores already-registered CoreText messages")
    func fontRegistrationAlreadyRegisteredMessagesAreBenign() {
        #expect(EpistemosFont.isBenignRegistrationErrorDescription("already registered"))
        #expect(
            EpistemosFont.isBenignRegistrationErrorDescription(
                "The file has already been registered in the specified scope."
            )
        )
        #expect(!EpistemosFont.isBenignRegistrationErrorDescription("missing font resource"))
    }

    @Test("Display font catalog includes the validated user font library")
    func displayFontCatalogIncludesValidatedUserFonts() {
        let postScriptNames = Set(AppDisplayTypography.displayFontOptions.map(\.postScriptName))
        let filenames = Set(AppDisplayTypography.displayFontOptions.map(\.resourceFilename))

        #expect(postScriptNames.contains("ReturnOfGanonReg"))
        #expect(postScriptNames.contains("Charybdis"))
        #expect(postScriptNames.contains("VTFMisterPixel"))
        #expect(postScriptNames.contains("AtlantisHeadline-Bold"))
        #expect(postScriptNames.contains("LunchtimeDoublySoReg"))
        #expect(postScriptNames.contains("DisposableDroidBB-BoldItalic"))
        #expect(postScriptNames.contains("EXEPixelPerfect"))
        #expect(postScriptNames.contains("Delicatus"))
        #expect(postScriptNames.contains("LEDDisplay7"))
        #expect(postScriptNames.contains("GNF"))
        #expect(postScriptNames.contains("Coder's-Crux"))
        #expect(filenames.contains("CodersCrux.ttf"))
        #expect(filenames.contains("VTFMisterPixel-Tools.otf"))
    }

    @Test("Heading typography overrides route through the shared theme resolver")
    func headingTypographyOverridesRouteThroughThemeResolver() {
        let defaults = UserDefaults.standard
        let keys = [
            UIState.themePairDefaultsKey,
            // updated 2026-07-03: heading overrides only engage when the custom pair is
            // actually active, which now requires the experimental flag — preserve it.
            AppCustomTheme.experimentalDefaultsKey,
            AppDisplayTypography.headingLevel1FontDefaultsKey,
            AppDisplayTypography.headingLevel2FontDefaultsKey,
            AppDisplayTypography.headingLevel3FontDefaultsKey,
            AppDisplayTypography.headingLevel1ScaleDefaultsKey,
            AppDisplayTypography.headingLevel2ScaleDefaultsKey,
            AppDisplayTypography.headingLevel3ScaleDefaultsKey,
        ]
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

        AppDisplayTypography.resetHeadingTypography(defaults: defaults)
        // updated 2026-07-03: custom theme is experimental + off by default; enable it so
        // the .custom branch below actually routes the stored H2 override/scale (the whole
        // point of this test). Preset (.classic) still ignores overrides regardless.
        AppCustomTheme.setExperimentalEnabled(true, defaults: defaults)
        AppDisplayTypography.setHeadingFontOverride("Coder's-Crux", level: 2, defaults: defaults)
        AppDisplayTypography.setHeadingSizeScale(1.2, level: 2, defaults: defaults)

        defaults.set(ThemePair.classic.rawValue, forKey: UIState.themePairDefaultsKey)
        // updated 2026-07-03: classic now shares Ember's heading face (ChonkyPixels); the
        // stored override does NOT leak into the preset classic pair.
        #expect(EpistemosTheme.oledSoft.headingFontName(level: 2) == AppDisplayTypography.chonkyDisplayFontName)
        #expect(abs(EpistemosTheme.oledSoft.headingSizeMultiplier(level: 2) - 1.0) < 0.001)

        defaults.set(ThemePair.custom.rawValue, forKey: UIState.themePairDefaultsKey)
        #expect(EpistemosTheme.platinumVioletDark.headingFontName(level: 2) == "Coder's-Crux")
        #expect(abs(EpistemosTheme.platinumVioletDark.headingSizeMultiplier(level: 2) - 1.2) < 0.001)

        AppDisplayTypography.resetHeadingTypography(defaults: defaults)
        #expect(EpistemosTheme.platinumVioletDark.headingFontName(level: 2) == AppDisplayTypography.matrixBoldDisplayFontName)
        #expect(abs(EpistemosTheme.platinumVioletDark.headingSizeMultiplier(level: 2) - 1.0) < 0.001)
    }

    @Test("Custom appearance colors are isolated from preset theme cards")
    func customAppearanceColorsAreIsolatedFromPresetThemes() {
        let defaults = UserDefaults.standard
        // updated 2026-07-03: custom theme now gates on the experimental flag — preserve it.
        let keys = [UIState.themePairDefaultsKey, AppCustomTheme.experimentalDefaultsKey] + customThemeDefaultsKeys
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

        AppCustomTheme.reset(defaults: defaults)
        // updated 2026-07-03: custom theme is experimental + off by default; enable it so a
        // .custom selection actually engages the stored palette (preset pairs stay isolated).
        AppCustomTheme.setExperimentalEnabled(true, defaults: defaults)
        AppCustomTheme.setHex(0x123456, for: .background, isDark: true, defaults: defaults)
        AppCustomTheme.setHex(0xABCDEF, for: .accent, isDark: true, defaults: defaults)

        defaults.set(ThemePair.classic.rawValue, forKey: UIState.themePairDefaultsKey)
        #expect(!AppCustomTheme.isActive(defaults: defaults))
        #expect(rgbHex(EpistemosTheme.oledSoft.resolved.background.nsColor) != 0x123456)

        defaults.set(ThemePair.custom.rawValue, forKey: UIState.themePairDefaultsKey)
        #expect(AppCustomTheme.isActive(defaults: defaults))
        #expect(rgbHex(EpistemosTheme.platinumVioletDark.resolved.background.nsColor) == 0x123456)
        #expect(rgbHex(EpistemosTheme.platinumVioletDark.presetResolved.background.nsColor) != 0x123456)
        #expect(rgbHex(EpistemosTheme.platinumVioletDark.resolved.accent.nsColor) == 0xABCDEF)
        #expect(rgbHex(EpistemosTheme.platinumViolet.resolved.background.nsColor) != 0x123456)
    }

    @MainActor
    @Test("Custom note surface has an explicit editor canvas token")
    func customNoteSurfaceHasExplicitEditorCanvasToken() {
        withPreservedThemeDefaults {
            let defaults = UserDefaults.standard
            defaults.set(ThemePair.custom.rawValue, forKey: UIState.themePairDefaultsKey)
            AppCustomTheme.reset(defaults: defaults)
            // updated 2026-07-03: canvas/solid-flat note surface resolves the custom token only
            // when the custom theme is active, which now requires the experimental flag.
            AppCustomTheme.setExperimentalEnabled(true, defaults: defaults)

            AppCustomTheme.setHex(0xABCDEF, for: .card, isDark: false, defaults: defaults)
            #expect(AppCustomTheme.noteSurfaceHex(isDark: false, defaults: defaults) == 0xABCDEF)

            AppCustomTheme.setHex(0x224466, for: .noteSurface, isDark: false, defaults: defaults)
            #expect(AppCustomTheme.noteSurfaceHex(isDark: false, defaults: defaults) == 0x224466)
            #expect(
                rgbHex(
                    MarkdownPreviewSurfaceStyle.solidFlatBackgroundNSColor(for: EpistemosTheme.platinumViolet)
                ) == 0x224466
            )
            #expect(
                rgbHex(
                    MarkdownPreviewSurfaceStyle.canvasNSColor(for: EpistemosTheme.platinumViolet)
                ) == 0x224466
            )
        }
    }

    @Test("Stored custom values never mutate preset themes")
    func storedCustomValuesNeverMutatePresetThemes() {
        withPreservedThemeDefaults {
            let defaults = UserDefaults.standard
            AppCustomTheme.setHex(0x112233, for: .background, isDark: false, defaults: defaults)
            AppCustomTheme.setHex(0x445566, for: .text, isDark: false, defaults: defaults)
            AppCustomTheme.setHex(0x778899, for: .accent, isDark: true, defaults: defaults)
            AppCustomTheme.setHex(0xAABBCC, for: .heading, isDark: true, defaults: defaults)
            AppDisplayTypography.setHeadingFontOverride("Charybdis", level: 1, defaults: defaults)
            AppDisplayTypography.setHeadingFontOverride("Coder's-Crux", level: 2, defaults: defaults)
            AppDisplayTypography.setHeadingSizeScale(1.3, level: 3, defaults: defaults)

            let lockedPairs: [ThemePair] = [.platinumViolet, .classic, .ember]
            for pair in lockedPairs {
                defaults.set(pair.rawValue, forKey: UIState.themePairDefaultsKey)
                #expect(!AppCustomTheme.isActive(defaults: defaults))

                for theme in [pair.lightTheme, pair.darkTheme] {
                    #expect(rgbHex(theme.resolved.background.nsColor) == rgbHex(theme.presetResolved.background.nsColor))
                    #expect(theme.resolved.foregroundHex == theme.presetResolved.foregroundHex)
                    #expect(theme.resolved.headingAccentHex == theme.presetResolved.headingAccentHex)
                    #expect(theme.resolved.markdownHeadingAccentHex == theme.presetResolved.markdownHeadingAccentHex)
                    #expect(theme.resolved.userBubbleBackgroundHex == theme.presetResolved.userBubbleBackgroundHex)
                }
            }

            // updated 2026-07-03: all non-custom themes now share Ember's heading face
            // (ChonkyPixels); classic's landing hero shares Ember's display face
            // (theme.displayFontName == "ColorBasic-Regular"). Presets still ignore the
            // stored custom overrides set above — that isolation is the point of this test.
            defaults.set(ThemePair.platinumViolet.rawValue, forKey: UIState.themePairDefaultsKey)
            #expect(EpistemosTheme.platinumViolet.headingFontName(level: 1) == AppDisplayTypography.chonkyDisplayFontName)
            #expect(EpistemosTheme.platinumViolet.headingFontName(level: 2) == AppDisplayTypography.chonkyDisplayFontName)
            #expect(EpistemosTheme.platinumViolet.headingFontName(level: 3) == AppDisplayTypography.chonkyDisplayFontName)

            defaults.set(ThemePair.classic.rawValue, forKey: UIState.themePairDefaultsKey)
            #expect(EpistemosTheme.light.headingFontName(level: 1) == AppDisplayTypography.chonkyDisplayFontName)
            #expect(EpistemosTheme.light.headingFontName(level: 2) == AppDisplayTypography.chonkyDisplayFontName)
            #expect(EpistemosTheme.light.headingFontName(level: 3) == AppDisplayTypography.chonkyDisplayFontName)
            #expect(LandingCommandTypography.heroFontName(for: .light) == EpistemosTheme.light.displayFontName)

            defaults.set(ThemePair.ember.rawValue, forKey: UIState.themePairDefaultsKey)
            #expect(EpistemosTheme.tan.headingFontName(level: 1) == AppDisplayTypography.chonkyDisplayFontName)
            #expect(EpistemosTheme.tan.headingFontName(level: 2) == AppDisplayTypography.chonkyDisplayFontName)
            #expect(EpistemosTheme.tan.headingFontName(level: 3) == AppDisplayTypography.chonkyDisplayFontName)
        }
    }

    @Test("Custom theme exposes color controls and labeled font previews")
    func customThemeExposesColorControlsAndLabeledFontPreviews() throws {
        let settings = try loadTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let themeSource = try loadTextFile("Epistemos/Theme/EpistemosTheme.swift")

        #expect(settings.contains("AppearanceCustomThemeSection(ui: ui)"))
        #expect(settings.contains("if ui.themeMode == .custom && ui.activePair == .custom"))
        #expect(settings.contains("CustomThemeColorTile("))
        #expect(themeSource.contains("Note Surface"))
        #expect(settings.contains("Picker(\"Variant\", selection: $editingDarkVariant)"))
        #expect(settings.contains("CustomThemeLivePreview(isDark: editingDarkVariant)"))
        #expect(settings.contains("AppCustomTheme.noteSurfaceHex(isDark: isDark)"))
        #expect(settings.contains("case .noteSurface"))
        #expect(settings.contains("FontLibraryPreviewGrid()"))
        #expect(settings.contains("Every bundled display face is labeled with its own preview."))
        #expect(settings.contains("Preset themes stay locked."))
        #expect(settings.contains("Heading font and scale apply only to Custom."))
        #expect(settings.contains("if pair == .custom"))
        #expect(settings.contains("let resolved = theme.presetResolved"))
    }

    @Test("Custom landing typography uses the stored H1 override while presets stay locked")
    func customLandingTypographyUsesStoredH1OverrideWhilePresetsStayLocked() {
        withPreservedThemeDefaults {
            UserDefaults.standard.set(ThemePair.custom.rawValue, forKey: UIState.themePairDefaultsKey)
            // updated 2026-07-03: custom theme is experimental + off by default; enable it so the
            // stored H1 override drives the custom landing hero (the point of this test).
            AppCustomTheme.setExperimentalEnabled(true)
            AppDisplayTypography.setHeadingFontOverride("Charybdis", level: 1)
            #expect(LandingCommandTypography.heroFontName(for: .platinumVioletDark) == "Charybdis")

            UserDefaults.standard.set(ThemePair.classic.rawValue, forKey: UIState.themePairDefaultsKey)
            // updated 2026-07-03: classic landing hero now shares Ember's display face
            // (theme.displayFontName == "ColorBasic-Regular"); preset ignores the H1 override.
            #expect(LandingCommandTypography.heroFontName(for: .light) == EpistemosTheme.light.displayFontName)
        }
    }

    private func rgbHex(_ color: NSColor) -> UInt32? {
        guard let color = color.usingColorSpace(.sRGB) else { return nil }
        let red = UInt32((color.redComponent * 255).rounded())
        let green = UInt32((color.greenComponent * 255).rounded())
        let blue = UInt32((color.blueComponent * 255).rounded())
        return (red << 16) | (green << 8) | blue
    }

    @Test("Classic does not require a runtime dock icon override")
    func classicResourceMapping() {
        #expect(ThemePair.classic.dockIconResourceName(isDark: false) == nil)
        #expect(ThemePair.classic.dockIconResourceName(isDark: true) == nil)
    }

    @Test("Platinum Violet and Ember do not require runtime dock icon overrides")
    func alternatePairsUseAdaptiveResources() {
        #expect(ThemePair.platinumViolet.dockIconResourceName(isDark: false) == nil)
        #expect(ThemePair.platinumViolet.dockIconResourceName(isDark: true) == nil)
        #expect(ThemePair.ember.dockIconResourceName(isDark: false) == nil)
        #expect(ThemePair.ember.dockIconResourceName(isDark: true) == nil)
    }

    @MainActor
    @Test("UIState defaults to the Platinum Violet app theme when no theme settings are stored")
    func uiStateDefaultsToPlatinumVioletAppearance() {
        let defaults = UserDefaults.standard
        let keys = [
            ThemeMode.defaultsKey,
            UIState.themePairDefaultsKey,
        ]
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
        for key in keys {
            defaults.removeObject(forKey: key)
        }

        let uiState = UIState()

        #expect(uiState.themeMode == .custom)
        #expect(uiState.customThemesEnabled)
        #expect(uiState.activePair == .platinumViolet)
        uiState.isSystemDark = false
        #expect(uiState.theme == .platinumViolet)
        uiState.isSystemDark = true
        #expect(uiState.theme == .platinumVioletDark)
        #expect(uiState.preferredColorScheme == nil)
        #expect(uiState.shouldUseThemeWorkarounds == false)
        #expect(uiState.usesNativeWindowBlur == false)
    }

    @MainActor
    @Test("Stored theme preferences restore the selected semantic pair")
    func storedThemePreferencesRestoreSelectedSemanticPair() {
        let defaults = UserDefaults.standard
        let pairsKey = UIState.themePairDefaultsKey
        let modeKey = ThemeMode.defaultsKey
        let previousPair = defaults.object(forKey: pairsKey)
        let previousMode = defaults.object(forKey: modeKey)
        defer {
            if let previousPair {
                defaults.set(previousPair, forKey: pairsKey)
            } else {
                defaults.removeObject(forKey: pairsKey)
            }
            if let previousMode {
                defaults.set(previousMode, forKey: modeKey)
            } else {
                defaults.removeObject(forKey: modeKey)
            }
        }

        defaults.set(ThemePair.ember.rawValue, forKey: pairsKey)
        defaults.set(ThemeMode.custom.rawValue, forKey: modeKey)

        let uiState = UIState()

        #expect(uiState.activePair == .ember)
        #expect(uiState.customThemesEnabled)
        #expect(uiState.themeMode == .custom)
        #expect(uiState.shouldUseThemeWorkarounds == false)
        #expect(uiState.preferredColorScheme == nil)
    }

    @MainActor
    @Test("UIState migrates legacy system-default theme mode to the selected app theme")
    func uiStateMigratesLegacySystemDefaultThemeModeOnInit() {
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

        defaults.set(ThemeMode.systemDefault.rawValue, forKey: ThemeMode.defaultsKey)
        defaults.set(ThemePair.ember.rawValue, forKey: UIState.themePairDefaultsKey)

        let uiState = UIState()

        #expect(uiState.themeMode == .custom)
        #expect(uiState.activePair == .ember)
        #expect(defaults.string(forKey: ThemeMode.defaultsKey) == ThemeMode.custom.rawValue)
        #expect(defaults.string(forKey: UIState.themePairDefaultsKey) == ThemePair.ember.rawValue)
    }

    @MainActor
    @Test("Theme mutators restore semantic themes without custom chrome")
    func themeMutatorsRestoreSemanticThemesWithoutCustomChrome() {
        withPreservedThemeDefaults {
            let defaults = UserDefaults.standard
            defaults.removeObject(forKey: ThemeMode.defaultsKey)
            defaults.removeObject(forKey: UIState.themePairDefaultsKey)

            let uiState = UIState()

            uiState.setPair(.platinumViolet)
            uiState.setThemeMode(.custom)
            uiState.setCustomThemesEnabled(true)

            #expect(uiState.customThemesEnabled)
            #expect(uiState.activePair == .platinumViolet)
            #expect(uiState.themeMode == .custom)
            #expect(uiState.preferredColorScheme == nil)
            #expect(uiState.shouldUseThemeWorkarounds == false)
            #expect(uiState.windowAppearance == nil)
        }
    }

    @MainActor
    @Test("Custom semantic themes keep window appearance unforced")
    func customSemanticThemesKeepWindowAppearanceNative() {
        withPreservedThemeDefaults {
            let defaults = UserDefaults.standard
            defaults.removeObject(forKey: ThemeMode.defaultsKey)
            defaults.removeObject(forKey: UIState.themePairDefaultsKey)

            let uiState = UIState()
            uiState.isSystemDark = false

            #expect(uiState.themeMode == .custom)
            #expect(uiState.windowAppearance == nil)
            #expect(uiState.theme == .platinumViolet)

            uiState.setPair(.platinumViolet)
            uiState.setThemeMode(.custom)
            uiState.setCustomThemesEnabled(true)
            uiState.isSystemDark = true

            #expect(uiState.themeMode == .custom)
            #expect(uiState.windowAppearance == nil)
            #expect(uiState.theme == .platinumVioletDark)
        }
    }

    @MainActor
    @Test("System default resolves to dedicated native tokens instead of the classic white or OLED theme")
    func systemDefaultUsesDedicatedNativeTokens() {
        withPreservedThemeDefaults {
            let defaults = UserDefaults.standard
            defaults.removeObject(forKey: ThemeMode.defaultsKey)
            defaults.removeObject(forKey: UIState.themePairDefaultsKey)

            let uiState = UIState()
            uiState.setThemeMode(.systemDefault)

            uiState.isSystemDark = false
            #expect(uiState.theme == .systemLight)
            #expect(uiState.theme != .light)

            uiState.isSystemDark = true
            #expect(uiState.theme == .systemDark)
            #expect(uiState.theme != .oled)
        }
    }

    @MainActor
    @Test("System default graph overlay follows native light and dark appearance")
    func systemDefaultGraphOverlayFollowsSystemAppearance() {
        withPreservedThemeDefaults {
            let defaults = UserDefaults.standard
            defaults.removeObject(forKey: ThemeMode.defaultsKey)
            defaults.removeObject(forKey: UIState.themePairDefaultsKey)

            let uiState = UIState()
            uiState.setThemeMode(.systemDefault)

            #expect(uiState.themeMode == .systemDefault)
            uiState.isSystemDark = false
            #expect(uiState.graphOverlayTheme == .systemLight)
            #expect(
                GraphOverlayThemeStyle.windowAppearance(
                    uiState: uiState,
                    theme: uiState.graphOverlayTheme
                ) == nil
            )
            #expect(GraphOverlayThemeStyle.lightModeEnabled(for: uiState.graphOverlayTheme))

            uiState.isSystemDark = true
            #expect(uiState.graphOverlayTheme == .systemDark)
            #expect(
                GraphOverlayThemeStyle.windowAppearance(
                    uiState: uiState,
                    theme: uiState.graphOverlayTheme
                ) == nil
            )
            #expect(!GraphOverlayThemeStyle.lightModeEnabled(for: uiState.graphOverlayTheme))
        }
    }

    @MainActor
    @Test("Graph overlay fallback uses dedicated native tokens")
    func graphOverlayFallbackUsesNativeTokens() {
        #expect(GraphOverlayThemeStyle.resolvedTheme(uiState: nil, fallbackIsDark: false) == .systemLight)
        #expect(GraphOverlayThemeStyle.resolvedTheme(uiState: nil, fallbackIsDark: true) == .systemDark)
        #expect(GraphOverlayThemeStyle.windowAppearance(uiState: nil, theme: .systemLight)?.name == .aqua)
        #expect(GraphOverlayThemeStyle.windowAppearance(uiState: nil, theme: .systemDark)?.name == .darkAqua)
    }

    @MainActor
    @Test("Graph overlay uses floating glass blur in light and dark modes")
    func graphOverlayUsesFloatingGlassBlurMaterials() {
        #expect(GraphOverlayThemeStyle.blurMaterial(for: .systemLight) == .hudWindow)
        #expect(GraphOverlayThemeStyle.blurMaterial(for: .systemDark) == .hudWindow)
    }

    @MainActor
    @Test("Graph overlay tint samples the selected theme surface")
    func graphOverlayTintSamplesSelectedThemeSurface() throws {
        let tanTint = try #require(
            GraphOverlayThemeStyle.surfaceTintColor(for: .tan).usingColorSpace(.deviceRGB)
        )
        let platinumTint = try #require(
            GraphOverlayThemeStyle.surfaceTintColor(for: .platinumViolet).usingColorSpace(.deviceRGB)
        )

        #expect(abs(tanTint.redComponent - (0xF5 / 255.0)) < 0.02)
        #expect(abs(tanTint.greenComponent - (0xEF / 255.0)) < 0.02)
        #expect(abs(tanTint.blueComponent - (0xE6 / 255.0)) < 0.02)
        #expect(abs(tanTint.alphaComponent - 0.65) < 0.01)
        #expect(abs(tanTint.redComponent - platinumTint.redComponent) > 0.05)
    }

    @MainActor
    @Test("System default notes sidebar uses the text background instead of the under-page gray")
    func systemDefaultNotesSidebarUsesTextBackground() {
        withPreservedThemeDefaults {
            let defaults = UserDefaults.standard
            defaults.removeObject(forKey: ThemeMode.defaultsKey)
            defaults.removeObject(forKey: UIState.themePairDefaultsKey)

            let uiState = UIState()

            #expect(uiState.notesSidebarBackgroundColor == .clear)

            uiState.setThemeMode(.custom)
            uiState.setPair(.classic)
            uiState.isSystemDark = false

            #expect(uiState.notesSidebarBackgroundColor == .clear)
        }
    }

    @MainActor
    @Test("UIState keeps the live landing greeting controls and clears removed cursor wake defaults")
    func uiStateLandingAnimationDefaults() {
        let defaults = UserDefaults.standard
        let keys = [
            LandingGreetingAnimationPolicy.enabledDefaultsKey,
            LandingGreetingAnimationPolicy.typewriterEnabledDefaultsKey,
            "epistemos.landingCursorAnimationEnabled",
            "epistemos.landingCursorVisibilityMode",
            "epistemos.landingCursorResponse",
            "epistemos.landingCursorSpread",
            "epistemos.landingCursorTrail",
            "epistemos.landingCursorViscosity",
            "epistemos.landingCursorTurbulence",
            "epistemos.landingCursorBlastPower",
            "epistemos.landingCursorOpacity",
            "epistemos.landingCursorBlur",
        ]
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
        for key in keys {
            defaults.removeObject(forKey: key)
        }

        let uiState = UIState()

        #expect(uiState.landingGreetingTypewriterEnabled == LandingGreetingAnimationPolicy.defaultTypewriterEnabled)
        for key in keys where key.hasPrefix("epistemos.landingCursor") {
            #expect(defaults.object(forKey: key) == nil)
        }
    }

    @MainActor
    @Test("UIState clears obsolete landing greeting defaults on init")
    func uiStateClearsObsoleteLandingGreetingDefaults() {
        let defaults = UserDefaults.standard
        let obsoleteKeys = [
            "epistemos.landingGreetingASCIIEnabled",
            "epistemos.landingGreetingASCIIHoverEnabled",
            "epistemos.landingGreetingTypewriterVersion",
            "epistemos.landingGreetingIntensity",
            "epistemos.landingGreetingVariety",
            "epistemos.landingGreetingPace",
        ]
        let previousValues = obsoleteKeys.map { ($0, defaults.object(forKey: $0)) }
        defer {
            for (key, value) in previousValues {
                if let value {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }
        for key in obsoleteKeys {
            defaults.set("legacy", forKey: key)
        }

        _ = UIState()

        for key in obsoleteKeys {
            #expect(defaults.object(forKey: key) == nil)
        }
    }

    @Test("Platinum Violet pair preserves the accented blue-violet variant")
    func platinumVioletPairMapping() {
        #expect(ThemePair.platinumViolet.lightTheme == .platinumViolet)
        #expect(ThemePair.platinumViolet.darkTheme == .platinumVioletDark)
        #expect(ThemePair.platinumViolet.resolved(isDark: false) == .platinumViolet)
        #expect(ThemePair.platinumViolet.resolved(isDark: true) == .platinumVioletDark)
        #expect(EpistemosTheme.platinumViolet.markdownHeadingAccentHex == 0x00007B)
        #expect(EpistemosTheme.platinumVioletDark.markdownHeadingAccentHex == 0x7B68EE)
        #expect(EpistemosTheme.platinumViolet.preferredMarkdownLinkHex == 0x00007B)
        #expect(EpistemosTheme.platinumVioletDark.preferredMarkdownLinkHex == nil)
        #expect(EpistemosTheme.platinumViolet.resolved.accent.color == Color(hex: 0x000080))
        #expect(EpistemosTheme.platinumVioletDark.resolved.accent.color == Color(hex: 0x7B68EE))
    }

    @Test("System appearance state reads the global Apple interface style")
    func systemAppearanceStateUsesGlobalInterfaceStyle() {
        #expect(SystemAppearanceState.isDark(globalDomain: nil) == false)
        #expect(SystemAppearanceState.isDark(globalDomain: [:]) == false)
        #expect(SystemAppearanceState.isDark(globalDomain: ["AppleInterfaceStyle": "Dark"]))
        #expect(
            SystemAppearanceState.isDark(globalDomain: ["AppleInterfaceStyle": "Light"]) == false
        )
    }

    @MainActor
    @Test("Classic resolves to the stable custom light and softened OLED themes with Matrix Bold headings")
    func appHeadingRolesUseSharedDisplayScale() {
        #expect(ThemePair.classic.description == "White · OLED Soft")
        #expect(ThemePair.classic.lightTheme == .light)
        #expect(ThemePair.classic.darkTheme == .oledSoft)
        #expect(ThemePair.classic.resolved(isDark: false) == .light)
        #expect(ThemePair.classic.resolved(isDark: true) == .oledSoft)
        #expect(EpistemosTheme.oledSoft.themePair == .classic)

        withPreservedThemeDefaults {
            UserDefaults.standard.set(ThemePair.classic.rawValue, forKey: UIState.themePairDefaultsKey)

            #expect(AppDisplayTypography.coralDisplayFontName == "CoralPixels-Regular")
            #expect(AppDisplayTypography.matrixBoldDisplayFontName == "MatrixTypeDisplay-Bold")
            #expect(AppDisplayTypography.legacyDisplayFontName == "RetroGaming")
            // updated 2026-07-03: all non-custom themes share Ember's typography — classic's
            // display face is now "ColorBasic-Regular" and its H1-H3 heading face is ChonkyPixels.
            #expect(AppDisplayTypography.displayFontName(isDark: false) == "ColorBasic-Regular")
            #expect(AppDisplayTypography.displayFontName(isDark: true) == "ColorBasic-Regular")
            #expect(AppDisplayTypography.displayFontScale(isDark: false) == 1.0)
            #expect(AppDisplayTypography.displayFontScale(isDark: true) == 1.0)
            #expect(AppHeadingRole.h1.fontName == AppDisplayTypography.chonkyDisplayFontName)
            #expect(AppHeadingRole.h2.fontName == AppDisplayTypography.chonkyDisplayFontName)
            #expect(AppHeadingRole.h3.fontName == AppDisplayTypography.chonkyDisplayFontName)
        }
        // Per user 2026-05-12: graph node labels use the JetBrainsMono
        // monospace atlas (the v1 "before" identity) in both light and
        // dark mode. The per-theme `_coral` and `_retro` atlases stay
        // bundled for any future per-theme override.
        #expect(AppDisplayTypography.graphLabelAtlasResourceName(isDark: false) == "sdf_labels")
        #expect(AppDisplayTypography.graphLabelAtlasResourceName(isDark: true) == "sdf_labels")
        #expect(AppHeadingRole.pageTitle.fontSize == 34)
        #expect(AppHeadingRole.pageTitle.animatesOnFirstAppearance)
        #expect(AppHeadingRole.h1.fontSize == 32)
        #expect(AppHeadingRole.h2.fontSize == 26)
        #expect(AppHeadingRole.h3.fontSize == 18)
        #expect(AppHeadingRole.section.fontSize == 12)
    }

    // updated 2026-07-03: classic now SHARES Ember's heading face (ChonkyPixels) at every
    // level, so the former font distinctness (!=) becomes equality (==). The genuine
    // remaining distinction is SIZE: classic H1 still renders smaller (0.72) than Ember's
    // 1.0, while classic H2/H3 keep Ember Tan's heading scale + note point sizes (27 / 17).
    @Test("Classic shares Ember's heading face but keeps a smaller H1 and the Ember Tan note heading scale")
    func classicH2H3UseMatrixBoldWithEmberTanNoteHeadingScale() {
        let classic = EpistemosTheme.light
        let emberTan = EpistemosTheme.tan

        #expect(classic.headingFontName(level: 1) == emberTan.headingFontName(level: 1))
        #expect(classic.headingFontName(level: 2) == AppDisplayTypography.chonkyDisplayFontName)
        #expect(classic.headingFontName(level: 3) == AppDisplayTypography.chonkyDisplayFontName)
        #expect(classic.headingFontName(level: 2) == emberTan.headingFontName(level: 2))
        #expect(classic.headingFontName(level: 3) == emberTan.headingFontName(level: 3))
        #expect(classic.headingSizeMultiplier(level: 1) < emberTan.headingSizeMultiplier(level: 1))
        #expect(classic.headingSizeMultiplier(level: 2) == emberTan.headingSizeMultiplier(level: 2))
        #expect(classic.headingSizeMultiplier(level: 3) == emberTan.headingSizeMultiplier(level: 3))
        #expect(classic.notesMatchingHeadingSpec(level: 2)?.fontName == AppDisplayTypography.chonkyDisplayFontName)
        #expect(classic.notesMatchingHeadingSpec(level: 2)?.size == emberTan.notesMatchingHeadingSpec(level: 2)?.size)
        #expect(classic.notesMatchingHeadingSpec(level: 3)?.fontName == AppDisplayTypography.chonkyDisplayFontName)
        #expect(classic.notesMatchingHeadingSpec(level: 3)?.size == emberTan.notesMatchingHeadingSpec(level: 3)?.size)
        #expect(classic.notesMatchingHeadingSpec(level: 2)?.size == 27)
        #expect(classic.notesMatchingHeadingSpec(level: 3)?.size == 17)
    }

    @Test("Platinum retires the Matrix Dots demo face from active text")
    func platinumRetiresMatrixDotsDemoFaceFromActiveText() throws {
        let theme = try loadTextFile("Epistemos/Theme/EpistemosTheme.swift")
        let fontRegistration = try loadTextFile("Epistemos/Theme/EpistemosFont.swift")
        let liquidGreeting = try loadTextFile("Epistemos/Views/Landing/LiquidGreeting.swift")
        let pixelComponents = try loadTextFile("Epistemos/Views/Landing/PixelSurfaceComponents.swift")
        let markdownContentStorage = try loadTextFile("Epistemos/Views/Notes/MarkdownContentStorage.swift")
        let markdownTextView = try loadTextFile("Epistemos/Views/Shared/MarkdownTextView.swift")
        let hologramInspector = try loadTextFile("Epistemos/Views/Graph/HologramNodeInspector.swift")

        #expect(AppDisplayTypography.matrixDotsDisplayFontName == "MatrixDotsDemoRegular")
        #expect(!AppDisplayTypography.displayFontOptions.map(\.postScriptName).contains("MatrixDotsDemoRegular"))
        #expect(AppDisplayTypography.platinumGlyphFontName(for: "A") == "MatrixTypeDisplay-Regular")
        #expect(AppDisplayTypography.platinumGlyphFontName(for: ",") == "MatrixTypeDisplay-Regular")
        #expect(AppDisplayTypography.platinumGlyphFontName(for: "1") == "MatrixTypeDisplay-Regular")
        #expect(!AppDisplayTypography.usesPlatinumGlyphFallback(theme: .platinumViolet, level: 1))
        // updated 2026-07-03: platinum now shares Ember's typography — heading + node-title
        // faces are ChonkyPixels and the panel face is "ColorBasic-Regular" (still NOT the
        // retired Matrix Dots demo face, which is what this test guards).
        #expect(EpistemosTheme.platinumViolet.headingFontName(level: 1) == AppDisplayTypography.chonkyDisplayFontName)
        #expect(EpistemosTheme.platinumViolet.headingFontName(level: 2) == AppDisplayTypography.chonkyDisplayFontName)
        #expect(EpistemosTheme.platinumViolet.headingFontName(level: 3) == AppDisplayTypography.chonkyDisplayFontName)
        #expect(EpistemosTheme.platinumViolet.nodeTitleFontName == AppDisplayTypography.chonkyDisplayFontName)
        #expect(EpistemosTheme.platinumViolet.panelFontName == "ColorBasic-Regular")
        #expect(EpistemosTheme.platinumViolet.headingSizeMultiplier(level: 2) > 0.72)
        #expect(EpistemosTheme.platinumViolet.headingSizeMultiplier(level: 3) > 0.72)
        withPreservedThemeDefaults {
            UserDefaults.standard.set(ThemePair.platinumViolet.rawValue, forKey: UIState.themePairDefaultsKey)
            #expect(AppHeadingRole.h1.fontName == AppDisplayTypography.chonkyDisplayFontName)
            #expect(AppHeadingRole.h2.fontName == AppDisplayTypography.chonkyDisplayFontName)
            #expect(AppHeadingRole.h3.fontName == AppDisplayTypography.chonkyDisplayFontName)
        }
        #expect(theme.contains(#"matrixDotsDisplayFontName = "MatrixDotsDemoRegular""#))
        #expect(theme.contains("platinumGlyphFallbackAttributedString"))
        #expect(theme.contains("applyPlatinumGlyphFallbackFonts"))
        #expect(fontRegistration.contains(#"registerFont(named: "MatrixTypeDisplay-Bold", extension: "otf")"#))
        #expect(fontRegistration.contains(#"registerFont(named: "MatrixDotsDemoRegular", extension: "ttf")"#))
        #expect(!pixelComponents.contains("AppDisplayTypography.matrixDotsDisplayFontName"))
        #expect(liquidGreeting.contains("platinumGlyphFallbackAttributedString"))
        #expect(markdownContentStorage.contains("applyPlatinumGlyphFallbackFonts"))
        #expect(markdownTextView.contains("platinumGlyphFallbackAttributedString"))
        #expect(hologramInspector.contains(".font(AppDisplayTypography.panelFont(size: 14, theme: theme))"))
        #expect(hologramInspector.contains("platinumGlyphFallbackAttributedString"))
        #expect(liquidGreeting.contains("theme.themePair == .classic"))
        #expect(!liquidGreeting.contains("[.classic, .platinumViolet].contains(theme.themePair)"))
    }

    // updated 2026-07-03: classic's landing greeting + H1-H3 headings now share Ember's
    // typography — ChonkyPixels headings and the ColorBasic-Regular display face via
    // theme.displayFontName (owner request). The greeting still keys off themePair == .classic.
    @Test("Classic landing greeting shares Ember's ColorBasic display face")
    func classicLandingGreetingUsesLatestMatrixTypeBoldFace() throws {
        let liquidGreeting = try loadTextFile("Epistemos/Views/Landing/LiquidGreeting.swift")
        let pixelComponents = try loadTextFile("Epistemos/Views/Landing/PixelSurfaceComponents.swift")

        #expect(AppDisplayTypography.matrixBoldDisplayFontName == "MatrixTypeDisplay-Bold")
        #expect(EpistemosTheme.light.headingFontName(level: 1) == AppDisplayTypography.chonkyDisplayFontName)
        #expect(EpistemosTheme.light.headingFontName(level: 2) == AppDisplayTypography.chonkyDisplayFontName)
        #expect(EpistemosTheme.light.headingFontName(level: 3) == AppDisplayTypography.chonkyDisplayFontName)
        #expect(pixelComponents.contains("case .classic:"))
        #expect(pixelComponents.contains("return theme.displayFontName"))
        #expect(!pixelComponents.contains("return AppDisplayTypography.coralDisplayFontName"))
        #expect(liquidGreeting.contains("theme.themePair == .classic"))
    }

    @Test("Bundled font registrations preserve the Epistemos-Latest font inventory")
    func bundledFontRegistrationsPreserveLatestInventory() throws {
        let fontRegistration = try loadTextFile("Epistemos/Theme/EpistemosFont.swift")
        let expectedFonts = [
            ("Atlantis-RegularSmallCaps", "otf"),
            ("AtlantisHeadline-Bold", "otf"),
            ("AtlantisText-Bold", "otf"),
            ("AtlantisText-Regular", "ttf"),
            ("BitPap", "ttf"),
            ("Charybdis", "ttf"),
            ("ChonkyPixels", "ttf"),
            ("CodersCrux", "ttf"),
            ("ColorBasic-Regular", "otf"),
            ("CoralPixels-Regular", "ttf"),
            ("Delicatus", "ttf"),
            ("DisposableDroidBB", "ttf"),
            ("DisposableDroidBB-Bold", "ttf"),
            ("DisposableDroidBB-BoldItalic", "ttf"),
            ("DisposableDroidBB-Italic", "ttf"),
            ("Dotemp-8bit2", "ttf"),
            ("EXEPixelPerfect", "ttf"),
            ("GNF", "ttf"),
            ("Inter-Regular", "ttf"),
            ("JetBrainsMono-Regular", "ttf"),
            ("LEDDisplay7", "ttf"),
            ("LunchtimeDoublySoReg", "ttf"),
            ("MatrixDotsDemoRegular", "ttf"),
            ("MatrixTypeDisplay-Bold", "otf"),
            ("MatrixtypeDisplay-9MyE5", "ttf"),
            ("Pixelon", "otf"),
            ("RetroByte", "ttf"),
            ("RetroGaming", "ttf"),
            ("ReturnOfGanonReg", "ttf"),
            ("VTFMisterPixel", "otf"),
            ("VTFMisterPixel-Tools", "otf"),
        ]

        for (name, ext) in expectedFonts {
            #expect(fontRegistration.contains(#"registerFont(named: "\#(name)", extension: "\#(ext)")"#))
        }
    }

    @Test("Classic softened OLED follows the same assistant glass path as old Classic dark")
    func classicSoftOLEDFollowsClassicAssistantGlassPath() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Theme/GlassModifiers.swift")

        #expect(source.contains("theme == .oled || theme == .oledSoft"))
    }

    @Test("Markdown heading sizing eases down for longer titles without collapsing levels")
    func markdownHeadingAdaptiveSizing() {
        let shortSize = MarkdownHeadingDisplay.fontSize(
            for: 1,
            text: "All Things Must Go",
            baseSize: AppHeadingRole.h1.fontSize,
            nextLevelSize: AppHeadingRole.h2.fontSize
        )
        let mediumSize = MarkdownHeadingDisplay.fontSize(
            for: 1,
            text: "A Neuroscientific explanation of determinism in society",
            baseSize: AppHeadingRole.h1.fontSize,
            nextLevelSize: AppHeadingRole.h2.fontSize
        )
        let longSize = MarkdownHeadingDisplay.fontSize(
            for: 1,
            text: "A Neuroscientific explanation of determinism in society across institutions, incentives, and collective mythmaking",
            baseSize: AppHeadingRole.h1.fontSize,
            nextLevelSize: AppHeadingRole.h2.fontSize
        )

        #expect(shortSize == AppHeadingRole.h1.fontSize)
        #expect(shortSize > mediumSize)
        #expect(mediumSize > longSize)
        #expect(shortSize - mediumSize >= 2)
        #expect(shortSize - longSize >= 3)
        #expect(longSize > AppHeadingRole.h2.fontSize)

        let h2Short = MarkdownHeadingDisplay.fontSize(
            for: 2,
            text: "Decision discipline",
            baseSize: MarkdownHeadingDisplay.noteHeadingBaseSize(for: 2),
            nextLevelSize: MarkdownHeadingDisplay.noteHeadingBaseSize(for: 3)
        )
        let h2Long = MarkdownHeadingDisplay.fontSize(
            for: 2,
            text: "Decision discipline across source, prose, document, preview, and graph inspector surfaces",
            baseSize: MarkdownHeadingDisplay.noteHeadingBaseSize(for: 2),
            nextLevelSize: MarkdownHeadingDisplay.noteHeadingBaseSize(for: 3)
        )
        let h3Long = MarkdownHeadingDisplay.fontSize(
            for: 3,
            text: "Implementation notes for a long heading that should not shout over the body",
            baseSize: MarkdownHeadingDisplay.noteHeadingBaseSize(for: 3),
            nextLevelSize: MarkdownEditorStyle.noteBaseFontSize
        )

        #expect(h2Short == MarkdownHeadingDisplay.noteHeadingBaseSize(for: 2))
        #expect(h2Long < h2Short)
        #expect(h2Long > MarkdownHeadingDisplay.noteHeadingBaseSize(for: 3))
        #expect(h3Long < MarkdownHeadingDisplay.noteHeadingBaseSize(for: 3))
        #expect(h3Long >= MarkdownEditorStyle.noteBaseFontSize)
    }

    @Test("Markdown heading display uppercases H1 through H3 only")
    func markdownHeadingDisplayUppercasesFirstThreeLevels() {
        #expect(MarkdownHeadingDisplay.displayText("All Things Must Go", level: 1) == "All Things Must Go")
        #expect(MarkdownHeadingDisplay.displayText("Sub Heading", level: 2) == "Sub Heading")
        #expect(MarkdownHeadingDisplay.displayText("Third Level", level: 3) == "Third Level")
        #expect(MarkdownHeadingDisplay.displayText("Fourth Level", level: 4) == "Fourth Level")
    }

    @Test("Markdown heading glow tapers from H1 to H3")
    func markdownHeadingGlowTapersByLevel() {
        #expect(MarkdownHeadingDisplay.glowRadius(for: 1) == 14)
        #expect(MarkdownHeadingDisplay.glowRadius(for: 2) == 10)
        #expect(MarkdownHeadingDisplay.glowRadius(for: 3) == 7)
        #expect(MarkdownHeadingDisplay.glowRadius(for: 4) == 0)
        #expect(MarkdownHeadingDisplay.shadowOpacity(for: .platinumViolet, level: 1) == 0.38)
        #expect(MarkdownHeadingDisplay.shadowOpacity(for: .platinumViolet, level: 2) == 0.24)
        #expect(MarkdownHeadingDisplay.shadowOpacity(for: .platinumViolet, level: 3) == 0.18)
        #expect(MarkdownHeadingDisplay.shadowOpacity(for: .platinumVioletDark, level: 1) == 0.38)
        #expect(MarkdownHeadingDisplay.shadowOpacity(for: .platinumVioletDark, level: 2) == 0.24)
        #expect(MarkdownHeadingDisplay.shadowOpacity(for: .platinumVioletDark, level: 3) == 0.18)
        #expect(MarkdownHeadingDisplay.overlayOpacity(for: .platinumViolet, level: 1) == 0.34)
        #expect(MarkdownHeadingDisplay.overlayOpacity(for: .platinumViolet, level: 2) == 0.22)
        #expect(MarkdownHeadingDisplay.overlayOpacity(for: .platinumViolet, level: 3) == 0.16)
        #expect(MarkdownHeadingDisplay.overlayOpacity(for: .platinumVioletDark, level: 1) == 0.34)
        #expect(MarkdownHeadingDisplay.overlayOpacity(for: .platinumVioletDark, level: 2) == 0.22)
        #expect(MarkdownHeadingDisplay.overlayOpacity(for: .platinumVioletDark, level: 3) == 0.16)
        #expect(MarkdownHeadingDisplay.nsShadow(for: .platinumViolet, level: 1) == nil)
        #expect(MarkdownHeadingDisplay.nsShadow(for: .platinumViolet, level: 2) == nil)
        #expect(MarkdownHeadingDisplay.nsShadow(for: .platinumViolet, level: 3) == nil)
        #expect(MarkdownHeadingDisplay.nsShadow(for: .platinumViolet, level: 4) == nil)
        #expect(MarkdownHeadingDisplay.nsShadow(for: .platinumVioletDark, level: 1) != nil)
        #expect(MarkdownHeadingDisplay.nsShadow(for: .platinumVioletDark, level: 2) != nil)
        #expect(MarkdownHeadingDisplay.nsShadow(for: .platinumVioletDark, level: 3) != nil)
    }

    @Test("Markdown preview heading glow stays softer than the editor heading glow")
    func markdownPreviewHeadingGlowStaysSoft() {
        #expect(MarkdownHeadingDisplay.previewGlowRadius(for: 1) == 9)
        #expect(MarkdownHeadingDisplay.previewGlowRadius(for: 2) == 6)
        #expect(MarkdownHeadingDisplay.previewGlowRadius(for: 3) == 4)
        #expect(MarkdownHeadingDisplay.previewGlowRadius(for: 4) == 0)
        #expect(MarkdownHeadingDisplay.previewGlowRadius(for: 1) < MarkdownHeadingDisplay.glowRadius(for: 1))
        #expect(MarkdownHeadingDisplay.previewGlowRadius(for: 2) < MarkdownHeadingDisplay.glowRadius(for: 2))
        #expect(MarkdownHeadingDisplay.previewGlowRadius(for: 3) < MarkdownHeadingDisplay.glowRadius(for: 3))
        #expect(MarkdownHeadingDisplay.previewShadowOpacity(for: .platinumViolet, level: 1) == 0)
        #expect(MarkdownHeadingDisplay.previewShadowOpacity(for: .platinumViolet, level: 2) == 0)
        #expect(MarkdownHeadingDisplay.previewShadowOpacity(for: .platinumViolet, level: 3) == 0)
        #expect(MarkdownHeadingDisplay.previewOverlayOpacity(for: .platinumViolet, level: 1) == 0)
        #expect(MarkdownHeadingDisplay.previewOverlayOpacity(for: .platinumViolet, level: 2) == 0)
        #expect(MarkdownHeadingDisplay.previewOverlayOpacity(for: .platinumViolet, level: 3) == 0)
        #expect(MarkdownHeadingDisplay.previewOverlayOpacity(for: .platinumVioletDark, level: 1) == 0.2)
        #expect(MarkdownHeadingDisplay.previewOverlayOpacity(for: .platinumVioletDark, level: 2) == 0.12)
        #expect(MarkdownHeadingDisplay.previewOverlayOpacity(for: .platinumVioletDark, level: 3) == 0.09)
    }

    @Test("Landing text shadow differs between dark and light modes")
    func landingTextShadowDiffersBetweenModes() throws {
        let landingView = try loadTextFile("Epistemos/Views/Landing/LandingView.swift")
        let liquidGreeting = try loadTextFile("Epistemos/Views/Landing/LiquidGreeting.swift")

        #expect(landingView.contains(".shadow(color: theme.isDark ? theme.fontAccent.opacity(0.12) : .clear, radius: 8)"))
        #expect(liquidGreeting.contains(".shadow("))
        #expect(liquidGreeting.contains("theme.fontAccent.opacity(0.12)"))
        #expect(liquidGreeting.contains("Color.black.opacity(0.08)"))
        #expect(liquidGreeting.contains("radius: compact ? 0 : (theme.isDark ? 8 : 5)"))
    }

    @Test("Landing backdrop uses the native surface without a startup intro fade")
    func landingBackdropUsesNativeSurfaceWithoutStartupIntroFade() throws {
        let landingView = try loadTextFile("Epistemos/Views/Landing/LandingView.swift")
        let rootView = try loadTextFile("Epistemos/App/RootView.swift")

        #expect(landingView.contains("private var landingBackdrop: some View"))
        #expect(landingView.contains("AppWindowBackdropStyle.background(for: theme)"))
        #expect(rootView.contains("AppWindowBackdropStyle.background(for: ui.theme)"))
        #expect(!rootView.contains("ui.theme.isDark ? Color.black : ui.theme.resolved.background.color"))
        #expect(!landingView.contains("showIntroBackdrop"))
        #expect(!landingView.contains("playLandingIntroIfNeeded()"))
        #expect(!landingView.contains("darkModeLandingBackdrop"))
    }

    @Test("Landing and root backdrops sample the selected semantic main chat surface instead of OLED")
    func landingAndRootBackdropsSampleSelectedSemanticThemeInsteadOfOLED() {
        #expect(AppWindowBackdropStyle.backgroundToken(for: .ember) == EpistemosTheme.ember.resolved.background)
        #expect(AppWindowBackdropStyle.backgroundToken(for: .nocturne) == EpistemosTheme.nocturne.resolved.background)
        #expect(AppWindowBackdropStyle.backgroundToken(for: .platinumVioletDark) == EpistemosTheme.platinumVioletDark.surfaceVariant(.mainChat).resolved.background)
        #expect(AppWindowBackdropStyle.backgroundToken(for: .ember) != EpistemosTheme.oled.resolved.background)
        #expect(AppWindowBackdropStyle.backgroundToken(for: .nocturne) != EpistemosTheme.oled.resolved.background)
    }

    @Test("Readable font preference is independent from landing and animation policy")
    func readableFontPreferencePolicy() {
        let defaults = UserDefaults(suiteName: "ThemePairReadableFontPreference")!
        defaults.removePersistentDomain(forName: "ThemePairReadableFontPreference")
        defer { defaults.removePersistentDomain(forName: "ThemePairReadableFontPreference") }

        #expect(!AppDisplayTypography.readableFontsEnabled(defaults: defaults))
        defaults.set("regular", forKey: AppDisplayTypography.legacyDisplayModeDefaultsKey)
        #expect(AppDisplayTypography.readableFontsEnabled(defaults: defaults))
        AppDisplayTypography.setReadableFontsEnabled(false, defaults: defaults)
        #expect(!AppDisplayTypography.readableFontsEnabled(defaults: defaults))
        #expect(defaults.string(forKey: AppDisplayTypography.legacyDisplayModeDefaultsKey) == nil)
    }

    @Test("Readable font preference uses Avenir Next when available")
    func readableFontPreferenceUsesReadableUIFontFamily() {
        let font = AppDisplayTypography.regularUIFont(size: 13)

        #expect(AppDisplayTypography.isRegularUIFont(font))
        #expect(!AppDisplayTypography.isDisplayFont(font))
        #expect(
            font.fontName.hasPrefix("AvenirNext")
                || font.fontName.hasPrefix(".SFNS")
                || font.fontName.hasPrefix(".AppleSystemUIFont")
        )
        #expect(AppDisplayTypography.coralDisplayFontName == "CoralPixels-Regular")
    }

    @Test("Assistant chrome tokens keep the floating surface hierarchy intact")
    func assistantSurfaceMetricsStayCalm() {
        let popout = AssistantSurfaceMetrics.popout

        #expect(popout.showsOuterStroke)
        #expect(popout.outerRadius == 30)
        #expect(popout.innerRadius == 24)
        #expect(popout.controlRadius == 18)
        #expect(popout.borderWidth == 0.72)
        #expect(popout.outerRadius > popout.innerRadius)
        #expect(popout.innerRadius > popout.controlRadius)
        #expect(popout.contentVerticalPadding == 18)
        #expect(popout.shadowRadius == 28)
    }

    @Test("Floating assistant surfaces follow the light and dark shell contrast rules")
    func floatingAssistantSurfacesUseThemeRelativeTints() {
        #expect(EpistemosTheme.light.floatingSurfaceTint == Color(hex: 0xF2F2F2))
        #expect(EpistemosTheme.tan.floatingSurfaceTint == Color(hex: 0xFBF5EB))
        #expect(EpistemosTheme.sunset.floatingSurfaceTint == Color(hex: 0x161018))
        #expect(EpistemosTheme.ember.floatingSurfaceTint == Color(hex: 0x16100C))
        #expect(EpistemosTheme.nocturne.floatingSurfaceTint == Color(hex: 0x141019))
        #expect(EpistemosTheme.oled.floatingSurfaceTint == Color(hex: 0x2A2A2F))
        #expect(EpistemosTheme.ember.floatingSurfaceTint != EpistemosTheme.ember.resolved.background.color)
        #expect(EpistemosTheme.nocturne.floatingSurfaceTint != EpistemosTheme.nocturne.resolved.background.color)
        #expect(EpistemosTheme.tan.floatingSurfaceTint != EpistemosTheme.tan.glassBg)
    }

    @Test("Main chat layout keeps the composer proportional to the message column")
    func mainChatLayoutStaysProportional() {
        #expect(ChatLayout.mainComposerMaxWidth == 860)
        #expect(ChatLayout.mainComposerHorizontalPadding == 10)
        #expect(MainChatComposerLayout.horizontalPadding == 11)
        #expect(MainChatComposerLayout.topPadding == 9)
        #expect(MainChatComposerLayout.bottomPadding == 7)
    }

    @Test("Main chat return key submits only when the composer is ready")
    func mainChatReturnSubmitsOnlyWhenReady() {
        #expect(
            ChatComposerKeyHandling.returnBehavior(
                modifierFlags: [],
                trimmedText: "hello",
                isProcessing: false
            ) == .submit
        )
        #expect(
            ChatComposerKeyHandling.returnBehavior(
                modifierFlags: [],
                trimmedText: "   ",
                isProcessing: false
            ) == .ignore
        )
        #expect(
            ChatComposerKeyHandling.returnBehavior(
                modifierFlags: [],
                trimmedText: "hello",
                isProcessing: true
            ) == .ignore
        )
    }

    @Test("Main chat shift return keeps multiline editing and clamps growth")
    func mainChatShiftReturnKeepsMultilineEditing() {
        #expect(
            ChatComposerKeyHandling.returnBehavior(
                modifierFlags: [.shift],
                trimmedText: "hello",
                isProcessing: false
            ) == .insertNewline
        )
        #expect(
            ChatComposerKeyHandling.returnBehavior(
                modifierFlags: [.option],
                trimmedText: "hello",
                isProcessing: false
            ) == .systemDefault
        )
        #expect(ChatComposerInputMetrics.maxVisibleLines == 8)
        #expect(ChatComposerInputMetrics.clampedHeight(for: 0) == ChatComposerInputMetrics.minHeight)
        #expect(
            ChatComposerInputMetrics.clampedHeight(
                for: ChatComposerInputMetrics.maxHeight + 40
            ) == ChatComposerInputMetrics.maxHeight
        )
    }

    @Test("Composer overlays own arrow return and escape while visible")
    func composerOverlaysOwnArrowReturnAndEscapeWhileVisible() {
        #expect(
            ChatComposerKeyHandling.overlayCommand(
                for: #selector(NSResponder.moveDown(_:)),
                modifierFlags: []
            ) == .moveDown
        )
        #expect(
            ChatComposerKeyHandling.overlayCommand(
                for: #selector(NSResponder.moveUp(_:)),
                modifierFlags: []
            ) == .moveUp
        )
        #expect(
            ChatComposerKeyHandling.overlayCommand(
                for: #selector(NSResponder.insertNewline(_:)),
                modifierFlags: []
            ) == .confirm
        )
        #expect(
            ChatComposerKeyHandling.overlayCommand(
                for: #selector(NSResponder.cancelOperation(_:)),
                modifierFlags: []
            ) == .cancel
        )
        #expect(
            ChatComposerKeyHandling.overlayCommand(
                for: #selector(NSResponder.insertNewline(_:)),
                modifierFlags: [.numericPad]
            ) == .confirm
        )
        #expect(
            ChatComposerKeyHandling.overlayCommand(
                for: #selector(NSResponder.moveDown(_:)),
                modifierFlags: [.numericPad, .function]
            ) == .moveDown
        )
        #expect(
            ChatComposerKeyHandling.returnBehavior(
                modifierFlags: [.numericPad],
                trimmedText: "ready",
                isProcessing: false
            ) == .submit
        )
        #expect(
            ChatComposerKeyHandling.overlayCommand(
                for: #selector(NSResponder.insertNewline(_:)),
                modifierFlags: [.command]
            ) == nil
        )
    }

    @Test("Reference popover search field owns keyboard selection commands")
    func referencePopoverSearchFieldOwnsKeyboardSelectionCommands() throws {
        let source = try loadTextFile("Epistemos/Views/Chat/NotesMentionDropdown.swift")

        #expect(source.contains("private struct ComposerReferenceSearchField: NSViewRepresentable"))
        #expect(source.contains("controlTextDidChange"))
        #expect(source.contains("doCommandBy commandSelector"))
        #expect(source.contains("ChatComposerKeyHandling.overlayCommand("))
        #expect(source.contains("case .confirm:"))
        #expect(source.contains("onSelect(selectedChoice)"))
        #expect(source.contains("selectedChoiceID: selectedChoice?.id"))
    }

    @Test("Landing no longer carries inline mention attachments")
    func landingNoLongerCarriesInlineMentionAttachments() throws {
        let source = try loadTextFile("Epistemos/Views/Landing/LandingView.swift")

        #expect(!source.contains("private var landingInlineContextChips: some View"))
        #expect(!source.contains("landingContextAttachments"))
        #expect(!source.contains("removeLandingContextAttachment"))
    }

    @Test("Composer height scaling no longer depends on landing search typography")
    func composerHeightScalingNoLongerDependsOnLandingSearchTypography() throws {
        let source = try loadTextFile("Epistemos/Views/Landing/LandingView.swift")
        let standardMin = ChatComposerInputMetrics.minHeight(for: ChatComposerInputMetrics.fontSize)

        #expect(standardMin == ChatComposerInputMetrics.clampedHeight(for: 0))
        #expect(!source.contains("LandingSearchLayout"))
        #expect(!source.contains("ChatComposerInputMetrics.minHeight(for: inputFontSize)"))
    }

    @Test("Assistant input chrome stays glass-first with restored depth")
    func assistantInputChromePrefersNativeGlass() {
        let input = AssistantGlassInputMetrics.default

        #expect(input.prefersGlassEffect)
        #expect(input.tintOpacity == 0)
        #expect(input.shadowOpacity > 0)
        #expect(input.shadowRadius > 0)
        #expect(input.activeBorderOpacity > input.idleBorderOpacity)
    }

    @Test("Assistant composer metrics restore a subtle dreamy shell shadow")
    func assistantComposerMetricsRestoreShadowDepth() {
        #expect(AssistantComposerMetrics.mainChat.shadowRadius > 0)
        #expect(AssistantComposerMetrics.mainChat.shadowYOffset > 0)
        #expect(AssistantComposerMetrics.compactChat.shadowRadius > 0)
        #expect(AssistantComposerMetrics.compactChat.shadowYOffset > 0)
    }

    @Test("Landing greeting toolbar glyph stays stable after cursor fx removal")
    func landingGreetingToolbarGlyphStaysStable() {
        #expect(LandingToolbarGlyphs.greetingSymbol == "textformat")
    }

    @Test("Markdown preview block chrome uses a rounded native reading surface")
    func markdownPreviewBlockChromeUsesRoundedNativeSurface() {
        let metrics = MarkdownPreviewSurfaceMetrics.default

        #expect(metrics.cornerRadius == 14)
        #expect(metrics.borderWidth == 0.8)
        #expect(metrics.contentPadding == 12)
        #expect(metrics.verticalSpacing == 4)
        #expect(metrics.topEdgeWidth == 0)
        #expect(metrics.bottomEdgeWidth == 0)
        #expect(metrics.rightEdgeWidth == 0.8)
        #expect(MarkdownPreviewSurfaceStyle.borderOpacity(isDark: true) > MarkdownPreviewSurfaceStyle.borderOpacity(isDark: false))
    }

    @Test("Markdown preview canvas uses the native reading surface in system mode")
    func markdownPreviewCanvasUsesTextBackgroundForSystemThemes() {
        #expect(MarkdownPreviewSurfaceStyle.canvasNSColor(for: .systemLight) == .textBackgroundColor)
        #expect(MarkdownPreviewSurfaceStyle.canvasNSColor(for: .systemDark) == .textBackgroundColor)
        #expect(
            TestColorAssertions.colorsMatch(
                MarkdownPreviewSurfaceStyle.canvasNSColor(for: .oled),
                EpistemosTheme.oled.resolved.background.nsColor
            )
        )
    }

    @Test("Editor block chrome frame keeps the trailing edge flush without clipping content")
    func editorBlockChromeFrameUsesMinimalTrailingInset() {
        let origin = NSPoint(x: 8, y: 0)
        let frame = MarkdownTextStorage.blockChromeFrame(
            textContainerOrigin: origin,
            containerWidth: 600,
            boundsWidth: 700
        )

        let leadingInset = max(MarkdownTextStorage.bodyIndent - 8, 14)
        let availableWidth = min(600, max(0, 700 - (origin.x * 2)))
        let expectedWidth = availableWidth - leadingInset - MarkdownPreviewSurfaceMetrics.default.rightEdgeWidth

        #expect(frame.minX == origin.x + leadingInset)
        #expect(frame.width == expectedWidth)
    }

    @Test("Assistant composer metrics keep the main and compact chat bars aligned")
    func assistantComposerMetricsStayConsistent() {
        let main = AssistantComposerMetrics.mainChat
        let compact = AssistantComposerMetrics.compactChat

        #expect(main.cornerRadius == 16)
        #expect(main.sendButtonSize == 32)
        #expect(main.sendButtonSize < compact.sendButtonSize)
        #expect(main.shadowRadius > 0)
        #expect(main.shadowYOffset > 0)
        #expect(compact.shadowRadius > main.shadowRadius)
        #expect(compact.shadowYOffset >= main.shadowYOffset)
        #expect(main.borderWidth <= 0.8)
        #expect(compact.cornerRadius > main.cornerRadius)
        #expect(compact.horizontalPadding > main.horizontalPadding)
        #expect(ChatComposerInputMetrics.fontSize == 14)
        #expect(ChatComposerInputMetrics.verticalInset == 4)
    }

    @Test("Landing no longer mounts the search composer or siri glow")
    func landingNoLongerMountsSearchComposerOrSiriGlow() throws {
        let landingView = try loadTextFile("Epistemos/Views/Landing/LandingView.swift")

        #expect(!landingView.contains("AssistantSendButton("))
        #expect(!landingView.contains("ChatComposerTextEditor("))
        #expect(!landingView.contains("landingSearchInlineStage"))
        #expect(!landingView.contains("LandingStageToolShell("))
        #expect(!landingView.contains("LandingSearchLiquidBubble("))
        #expect(!landingView.contains("LandingSearchFloatingBubbleField("))
        #expect(!landingView.contains(".siriGlow("))
        #expect(!landingView.contains("LandingSearchChromePolicy"))
    }

    @Test("Chat streaming shows incremental response text in the live bubble")
    func chatStreamingShowsIncrementalResponseTextInTheLiveBubble() {
        #expect(ChatStreamingDisplayPolicy.showsLiveResponseText)
    }

    @Test("Chat transcript rows capture the previous user query without re-scanning chat state")
    func chatTranscriptRowsCapturePreviousUserQuery() {
        let messages = [
            ChatMessage(chatId: "chat", role: .user, content: "first question"),
            ChatMessage(chatId: "chat", role: .assistant, content: "first answer"),
            ChatMessage(chatId: "chat", role: .assistant, content: "follow-up enrichment"),
            ChatMessage(chatId: "chat", role: .user, content: "second question"),
            ChatMessage(chatId: "chat", role: .assistant, content: "second answer"),
        ]

        let rows = makeChatTranscriptRows(from: messages, chatTitle: nil)

        #expect(rows.count == 5)
        #expect(rows[0].originalQuery == nil)
        #expect(rows[1].originalQuery == "first question")
        #expect(rows[2].originalQuery == "first question")
        #expect(rows[3].originalQuery == nil)
        #expect(rows[4].originalQuery == "second question")
    }

    @Test("LocalModelToolbarMenu is owned by standalone surfaces, not main chat or landing")
    func localModelToolbarMenuOwnershipMatchesMigration() throws {
        let landingView = try loadTextFile("Epistemos/Views/Landing/LandingView.swift")
        let rootView = try loadTextFile("Epistemos/App/RootView.swift")
        let noteWorkspace = try loadTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")

        // LocalModelToolbarMenu struct + `.localMLX(model.id)` producer (and its ASCIIRippleText/
        // AnchoredPopoverButton/Open Settings body) removed with cloud-only/Omega removal
        // 2026-07-03; the absence guards below stay valid.
        #expect(!rootView.contains("Picker(\"Routing\", selection: routingBinding)"))
        #expect(!rootView.contains("InferenceControlPopoverButton"))

        // Main chat + landing must NOT render LocalModelToolbarMenu — those advanced
        // controls now live exclusively in the Agent Command Center (⌘J).
        #expect(!landingView.contains("LocalModelToolbarMenu("))
        #expect(!landingView.contains("landingInferenceControl"))

        // Note surfaces keep note-native context controls without remounting the
        // old local-model chat toolbar.
        #expect(!noteWorkspace.contains("LocalModelToolbarMenu("))
        #expect(noteWorkspace.contains("ContextualShadowsButton(scopeKind: .note, scopeID: pageId)"))
        #expect(!noteWorkspace.contains("Label(\"Local Only\""))
    }

    @Test("Bare until pressed chrome stays invisible until press or active selection")
    func bareUntilPressedChromePolicy() {
        #expect(
            NativeControlChromePolicy.bareUntilPressed.showsSurface(
                isHovered: false,
                isPressed: false,
                isActive: false
            ) == false
        )
        #expect(
            NativeControlChromePolicy.bareUntilPressed.showsSurface(
                isHovered: true,
                isPressed: false,
                isActive: false
            ) == false
        )
        #expect(
            NativeControlChromePolicy.bareUntilPressed.showsSurface(
                isHovered: false,
                isPressed: true,
                isActive: false
            )
        )
        #expect(
            NativeControlChromePolicy.bareUntilPressed.showsSurface(
                isHovered: false,
                isPressed: false,
                isActive: true
            )
        )
    }

    @Test("Settings and landing metadata drop SOAR and confidence-era chat chrome")
    func settingsAndLandingDropAnalyticalChatChrome() throws {
        let settings = try loadTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let landing = try loadTextFile("Epistemos/Views/Landing/LandingView.swift")

        #expect(!settings.contains("case soar"))
        #expect(!settings.contains("SOARDetailView"))
        #expect(!landing.contains("Confidence:"))
        #expect(!landing.contains("confidence scores"))
        #expect(!landing.contains("evidence grades"))
    }

    @Test("Live runtime no longer keeps enrichment or SOAR hooks in the chat path")
    func liveRuntimeDropsEnrichmentAndSOARHooks() throws {
        let pipeline = try loadTextFile("Epistemos/Engine/PipelineService.swift")
        let bootstrap = try loadTextFile("Epistemos/App/AppBootstrap.swift")
        let environment = try loadTextFile("Epistemos/App/AppEnvironment.swift")
        let appCoordinator = try loadTextFile("Epistemos/App/AppCoordinator.swift")
        let engineTypes = try loadTextFile("Epistemos/Models/EngineTypes.swift")
        let eventBus = try loadTextFile("Epistemos/State/EventBus.swift")

        #expect(!pipeline.contains("EnrichmentController"))
        #expect(!pipeline.contains("soarService"))
        #expect(!pipeline.contains("skipEnrichment"))
        #expect(!pipeline.contains("onEnriched"))
        #expect(!pipeline.contains("cancelAllEnrichment"))

        #expect(!bootstrap.contains("let soarState"))
        #expect(!bootstrap.contains("let soarService"))
        #expect(!bootstrap.contains("cancelAllEnrichment()"))
        #expect(!environment.contains(".environment(bootstrap.soarState)"))
        #expect(!appCoordinator.contains(".epistemicLens"))
        #expect(!appCoordinator.contains("cancelAllEnrichment()"))
        #expect(!engineTypes.contains("case enriched("))
        #expect(!engineTypes.contains("case soarEvent("))
        #expect(!eventBus.contains("case soarEvent("))
    }

    @Test("Toolbar control metrics stay compact and boxy inside the outer pill")
    func toolbarControlMetricsStayCompactAndBoxy() {
        let toolbar = NativeControlSystem.toolbar

        #expect(toolbar.height == 26)
        #expect(toolbar.cornerRadius == 8)
        #expect(toolbar.minHitWidth == 26)
        #expect(toolbar.cornerRadius < (toolbar.height / 2))
    }

    @Test("Graph force settings panel keeps the wider readable width")
    func graphForceSettingsPanelWidth() {
        #expect(GraphForceSettingsLayout.panelWidth == 320)
    }

    @Test("Assistant source extraction keeps notes and links in a stable unique order")
    func assistantSourceExtractionDeduplicatesNotesAndLinks() {
        let sources = AssistantSourceReference.extract(
            from: """
            See [Paper](https://example.com/paper) and https://example.com/paper plus
            https://notes.example.org/entry for more context.
            """,
            noteTitles: ["Brown Essays", "Brown Essays", "Field Notes"]
        )

        #expect(sources.count == 4)
        #expect(sources[0].kind == .note)
        #expect(sources[0].title == "Brown Essays")
        #expect(sources[1].title == "Field Notes")
        #expect(sources[2].url?.absoluteString == "https://example.com/paper")
        #expect(sources[2].subtitle == "example.com")
        #expect(sources[3].subtitle == "notes.example.org")
    }

    @Test("Inline markdown preserves markdown links and linkifies raw URLs for clickable sources")
    func inlineMarkdownMakesSourcesClickable() {
        let attributed = InlineMarkdownStyler.attributedString(
            """
            See https://example.com/raw and [Paper](https://example.com/paper) for details.
            """,
            strongFontSize: 15,
            strongForegroundColor: nil,
            linkForegroundColor: .blue
        )

        #expect(attributed != nil)
        let links = attributed?.runs.compactMap(\.link) ?? []
        #expect(links.contains(URL(string: "https://example.com/raw")!))
        #expect(links.contains(URL(string: "https://example.com/paper")!))
    }

    @Test("Inline markdown can pin strong emphasis to a supplied monospaced font")
    func inlineMarkdownStrongEmphasisCanUseSuppliedMonospacedFont() {
        let attributed = InlineMarkdownStyler.attributedString(
            "Normal **bold idea** text",
            strongFontSize: 15,
            strongForegroundColor: nil,
            linkForegroundColor: nil,
            strongFont: ClaudeAppTypography.monoFont(size: 15, weight: .semibold)
        )

        let hasPinnedStrongFont = attributed?.runs.contains { run in
            guard let intent = run.inlinePresentationIntent, intent.contains(.stronglyEmphasized) else {
                return false
            }
            return run.font != nil
        } ?? false

        #expect(hasPinnedStrongFont)
    }

    @MainActor
    @Test("UIState migrates legacy regular display mode into readable fonts")
    func uiStateMigratesLegacyRegularDisplayMode() {
        let defaults = UserDefaults.standard
        let legacyKey = AppDisplayTypography.legacyDisplayModeDefaultsKey
        let readableKey = AppDisplayTypography.readableFontsDefaultsKey
        let previousLegacy = defaults.object(forKey: legacyKey)
        let previousReadable = defaults.object(forKey: readableKey)
        defer {
            if let previousLegacy {
                defaults.set(previousLegacy, forKey: legacyKey)
            } else {
                defaults.removeObject(forKey: legacyKey)
            }
            if let previousReadable {
                defaults.set(previousReadable, forKey: readableKey)
            } else {
                defaults.removeObject(forKey: readableKey)
            }
        }

        defaults.removeObject(forKey: readableKey)
        defaults.set("regular", forKey: legacyKey)

        let uiState = UIState()
        #expect(uiState.readableFontsEnabled)
        #expect(defaults.string(forKey: legacyKey) == nil)
        #expect(defaults.bool(forKey: readableKey))
    }

    @MainActor
    @Test("UIState no longer restores removed landing cursor defaults")
    func uiStateNoLongerRestoresLandingCursorDefaults() {
        let defaults = UserDefaults.standard
        let keys = [
            "epistemos.landingCursorAnimationEnabled",
            "epistemos.landingCursorVisibilityMode",
            LandingGreetingAnimationPolicy.enabledDefaultsKey,
            LandingGreetingAnimationPolicy.typewriterEnabledDefaultsKey,
        ]
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

        for key in keys {
            defaults.set(true, forKey: key)
        }

        let uiState = UIState()
        #expect(uiState.landingGreetingTypewriterEnabled == LandingGreetingAnimationPolicy.defaultTypewriterEnabled)
        for key in keys where key.hasPrefix("epistemos.landingCursor") {
            #expect(defaults.object(forKey: key) == nil)
        }
    }

    @Test("Icon composer package keeps the current layered icon bundle")
    func iconComposerUsesCurrentLayeredBundle() throws {
        let json = try loadIconComposerJSON()
        #expect(json.contains("\"appearance\" : \"dark\""))
        #expect(json.contains("\"appearance\" : \"tinted\""))
        #expect(json.contains("Gemini Generated Image 5.png"))
        #expect(json.contains("Gemini Generated Image 5 (1) 2.png"))
        #expect(json.contains("Gemini Generated Image 5 (1) 3.png"))
        #expect(json.contains("Gemini Generated Image 5 (2).png"))
        #expect(!json.contains("Ep (mag)-iOS-Default-1024x1024@1x.png"))
    }

    @Test("Icon composer package keeps the current asset bundle")
    func iconComposerKeepsCurrentAssetBundle() throws {
        let assetNames = try FileManager.default.contentsOfDirectory(
            atPath: sourceMirrorURL(for: "Epistemos/AppIcon.icon/Assets").path
        )
        #expect(assetNames.count == 4)
        #expect(assetNames.contains("Gemini Generated Image 5.png"))
        #expect(assetNames.contains("Gemini Generated Image 5 (1) 2.png"))
        #expect(assetNames.contains("Gemini Generated Image 5 (1) 3.png"))
        #expect(assetNames.contains("Gemini Generated Image 5 (2).png"))
        #expect(!assetNames.contains("Ep (mag)-watchOS-Default-1088x1088@1x.png"))
    }

    @Test("Bundle plist points at the icon composer asset")
    func bundlePlistUsesIconComposerFile() throws {
        let plist = try loadBundlePlist()
        #expect(plist["CFBundleIdentifier"] as? String == "$(PRODUCT_BUNDLE_IDENTIFIER)")
        #expect(plist["CFBundleIconName"] as? String == "AppIcon")
        #expect(plist["CFBundleIconFile"] == nil)

        let project = try loadProjectFile()
        #expect(project.contains("PRODUCT_BUNDLE_IDENTIFIER = com.epistemos.app;"))
        #expect(project.contains("PRODUCT_BUNDLE_IDENTIFIER = com.epistemos.appstore;"))
    }

    @Test("Project uses AppIcon.icon as the primary app icon source")
    func projectUsesIconComposerFile() throws {
        let pbxproj = try loadProjectFile()
        let iconComposer = try sourceMirrorURL(for: "Epistemos/AppIcon.icon/icon.json")

        #expect(FileManager.default.fileExists(atPath: iconComposer.path))
        #expect(pbxproj.contains("PBXFileSystemSynchronizedRootGroup"))
        #expect(pbxproj.contains("ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;"))
    }

    @Test("Assets catalog no longer keeps the stale AppIcon appiconset payload")
    func assetsCatalogDropsStaleAppIconSet() throws {
        let staleAppIconSet = try sourceMirrorURL(for: "Epistemos/Assets.xcassets/AppIcon.appiconset")
        #expect(!FileManager.default.fileExists(atPath: staleAppIconSet.path))
    }

    @Test("Project retains Rust bridge header wiring")
    func projectRetainsRustBridgeWiring() throws {
        let pbxproj = try loadProjectFile()
        let requiredLinkerFlags = [
            "-L$(PROJECT_DIR)/build-rust",
            "-lgraph_engine",
            "-lsyntax_core",
            "-lomega_mcp",
            // "-lomega_ax" removed with cloud-only/Omega removal 2026-07-03
            "-lepistemos_core",
            "-lagent_core",
            "-lepistemos_shadow",
            "-lepistemos_code_index",
            "-lsubstrate_rt",
        ]

        #expect(pbxproj.contains("SWIFT_OBJC_BRIDGING_HEADER = \"Epistemos-Bridging-Header.h\";"))
        #expect(pbxproj.contains("SWIFT_INCLUDE_PATHS = \"$(PROJECT_DIR)/build-rust/swift-bindings/omega_mcpFFI"))
        for flag in requiredLinkerFlags {
            #expect(pbxproj.contains(flag))
        }
        #expect(pbxproj.contains("\"@executable_path\","))
        #expect(pbxproj.contains("\"@loader_path/../Frameworks\","))
        #expect(pbxproj.contains(#"""
LD_RUNPATH_SEARCH_PATHS = (
					"@executable_path",
					"@executable_path/../Frameworks",
					"@loader_path/../Frameworks",
				);
"""#))
    }

    @Test("main window navigation keeps only the home tab")
    func homeNavigationKeepsOnlyHome() {
        #expect(HomeTab.allCases == [.home])
        #expect(HomeTab.home.label == "Home")
    }

    @Test("command surfaces route settings through the detached utility window")
    func commandSurfacesRouteSettingsToUtilityWindow() throws {
        let rootView = try loadTextFile("Epistemos/App/RootView.swift")
        let appCommands = try loadTextFile("Epistemos/App/EpistemosApp.swift")
        let landingView = try loadTextFile("Epistemos/Views/Landing/LandingView.swift")

        #expect(!rootView.contains("case .library"))
        #expect(!rootView.contains("case .settings"))
        #expect(!rootView.contains("Picker(\"\", selection: $uiBindable.homeTab)"))
        #expect(appCommands.contains("UtilityWindowManager.shared.show(.settings)"))
        #expect(!appCommands.contains(".keyboardShortcut(\",\", modifiers: .command)"))
        #expect(!landingView.contains("label: \"Settings\""))
        #expect(!landingView.contains("key: \"S\", label: \"Settings\""))
    }

    @Test("landing command grid exposes notes and new note as peer pixel tiles")
    func landingCommandGridExposesNotesAndNewNoteAsPeerPixelTiles() throws {
        let landingView = try loadTextFile("Epistemos/Views/Landing/LandingView.swift")

        #expect(landingView.contains("landingPixelCommands"))
        #expect(landingView.contains("PixelLandingCommandTile(\n                title: \"notes\""))
        #expect(landingView.contains("PixelLandingCommandTile(\n                title: \"new note\""))
        #expect(!landingView.contains("HoverRevealCommandHint("))
        #expect(!landingView.contains("CommandHint(modIcon: \"command\", key: \"N\", label: \"New Note\""))
    }

    @Test("liquid greeting task identity tracks playlist changes without restarting on typed character updates")
    func liquidGreetingTaskIdentityTracksPlaylistChanges() throws {
        let liquidGreeting = try loadTextFile("Epistemos/Views/Landing/LiquidGreeting.swift")

        #expect(liquidGreeting.contains("\"\\(shouldAnimate)_\\(retractNow)_\\(searchMode)\""))
        #expect(!liquidGreeting.contains("\"\\(shouldAnimate)_\\(retractNow)_\\(displayText)\""))
    }

    @Test("landing greeting keeps static welcome back fallback and drops liquid controls")
    func liquidGreetingSupportsStaticWelcomeBackMode() throws {
        let liquidGreeting = try loadTextFile("Epistemos/Views/Landing/LiquidGreeting.swift")
        let settingsView = try loadTextFile("Epistemos/Views/Settings/SettingsView.swift")

        #expect(liquidGreeting.contains("line1 = Self.greetingLine1"))
        #expect(liquidGreeting.contains("line2 = Self.greetingLine2"))
        #expect(liquidGreeting.contains("guard shouldAnimate else"))
        #expect(settingsView.contains("Animate typewriter"))
        #expect(!settingsView.contains("Enable liquid distortion"))
    }

    @Test("landing view drops the live cursor wake overlay")
    func landingViewDropsTheLiveCursorWakeOverlay() throws {
        let landingView = try loadTextFile("Epistemos/Views/Landing/LandingView.swift")

        #expect(!landingView.contains("currentCursorSurface"))
        #expect(!landingView.contains("ui.landingCursorVisibilityMode.shows(on: surface)"))
        #expect(!landingView.contains("landingWakeVocabulary"))
        #expect(!landingView.contains("LandingASCIIWakeFieldConfiguration"))
        #expect(!landingView.contains("LandingPointerState"))
    }

    @Test("landing greeting drops the liquid canvas timeline entirely")
    func liquidGreetingDropsLiquidTimeline() throws {
        let liquidGreeting = try loadTextFile("Epistemos/Views/Landing/LiquidGreeting.swift")

        #expect(!liquidGreeting.contains("TimelineView("))
        #expect(!liquidGreeting.contains("Canvas("))
        #expect(!liquidGreeting.contains("liquidReleaseDate"))
        #expect(!liquidGreeting.contains("hoverLocation"))
        #expect(!liquidGreeting.contains("cursorBlinkLoop"))
    }

    @Test("landing greeting drops liquid deformation controls from the toolbar")
    func liquidGreetingDropsDeformationControls() throws {
        let liquidGreeting = try loadTextFile("Epistemos/Views/Landing/LiquidGreeting.swift")
        let rootView = try loadTextFile("Epistemos/App/RootView.swift")
        let pageShell = try loadTextFile("Epistemos/Views/Shell/PageShell.swift")

        #expect(!liquidGreeting.contains("landingGreetingPull"))
        #expect(!liquidGreeting.contains("landingGreetingBlur"))
        #expect(!rootView.contains("Enable liquid distortion"))
        #expect(!rootView.contains("Reset Greeting Physics"))
        #expect(!rootView.contains("cursorVisible"))
        #expect(!pageShell.contains("cursorVisible"))
    }

    @Test("liquid greeting uses deterministic timing helpers instead of random per-character sleeps")
    func liquidGreetingUsesDeterministicTimingHelpers() throws {
        let liquidGreeting = try loadTextFile("Epistemos/Views/Landing/LiquidGreeting.swift")

        #expect(liquidGreeting.contains("LiquidGreetingTiming.typingDelay(forStep: index)"))
        #expect(liquidGreeting.contains("LiquidGreetingTiming.untypingDelay(forStep: nextLen)"))
        #expect(liquidGreeting.contains("private func pause(_ duration: Duration) async -> Bool"))
        #expect(!liquidGreeting.contains("Int.random(in: 45...75)"))
        #expect(!liquidGreeting.contains("Int.random(in: 20...40)"))
        #expect(!liquidGreeting.contains("try? await Task.sleep"))
    }

    @Test("root toolbar drops cursor fx controls")
    func rootToolbarDropsCursorFXControls() throws {
        let rootView = try loadTextFile("Epistemos/App/RootView.swift")

        #expect(!rootView.contains("Cursor FX"))
        #expect(!rootView.contains("LandingCursorControlsView"))
        #expect(!rootView.contains("landingCursorToolbarButton"))
    }

    @Test("settings keeps landing greetings but drops cursor animation controls")
    func settingsKeepsLandingGreetingsButDropsCursorAnimationControls() throws {
        let settingsView = try loadTextFile("Epistemos/Views/Settings/SettingsView.swift")

        #expect(settingsView.contains("case landing = \"Landing\""))
        #expect(settingsView.contains("LandingDetailView()"))
        #expect(settingsView.contains("Greeting Library"))
        #expect(!settingsView.contains("Cursor Visibility"))
        #expect(!settingsView.contains("Cursor Animation"))
    }

    @Test("landing settings re-expose quick capture and Siri shortcut guidance")
    func landingSettingsReExposeQuickCaptureAndSiriGuidance() throws {
        let settingsView = try loadTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let landingView = try loadTextFile("Epistemos/Views/Landing/LandingView.swift")

        #expect(settingsView.contains("Quick Capture & Siri"))
        #expect(settingsView.contains("Open Quick Capture"))
        #expect(settingsView.contains("Refresh Siri Shortcuts"))
        #expect(settingsView.contains("Open Shortcuts"))
        #expect(settingsView.contains("Microphone access"))
        #expect(settingsView.contains("showQuickCapture"))
        #expect(landingView.contains("quick capture"))
        #expect(landingView.contains("showLandingInlineCommand(.quickCapture)"))
    }

    @Test("landing command surfaces use pixel command tiles")
    func landingCommandSurfacesUsePixelCommandTiles() throws {
        let landingView = try loadTextFile("Epistemos/Views/Landing/LandingView.swift")
        let pixelComponents = try loadTextFile("Epistemos/Views/Landing/PixelSurfaceComponents.swift")

        #expect(landingView.contains("PixelLandingCommandTile("))
        #expect(landingView.contains("landingPixelCommands"))
        #expect(!landingView.contains("Session Intelligence"))
        #expect(!landingView.contains("CommandHint(modIcon: \"command\", key: \"S\", label: \"Settings\""))
        #expect(pixelComponents.contains("struct PixelPanelBackground"))
        #expect(pixelComponents.contains("struct PixelLandingCommandTile"))
        #expect(!pixelComponents.contains("PixelGridOverlay"))
        #expect(pixelComponents.contains("var systemImageName: String"))
        #expect(pixelComponents.contains("static func actionSurface"))
        #expect(pixelComponents.contains("enum PixelStepMotion"))
        #expect(pixelComponents.contains("struct PixelPanelTitle"))
        #expect(pixelComponents.contains("private func pixelPanelStrokeWidth"))
        #expect(pixelComponents.contains("private func platinumPixelPanel"))
        #expect(pixelComponents.contains("private func classicNativePanel"))
        #expect(pixelComponents.contains("private func emberHybridPanel"))
        #expect(pixelComponents.contains("RoundedRectangle(cornerRadius: 28, style: .continuous)"))
        #expect(pixelComponents.contains("RoundedRectangle(cornerRadius: 18, style: .continuous)"))
        #expect(pixelComponents.contains("theme.isDark ? 1 : 1.5"))
        #expect(pixelComponents.contains("theme.isDark ? 0.24 : 0.34"))
        #expect(pixelComponents.contains("@State private var isHovered"))
        #expect(!pixelComponents.contains("@State private var hoverFrame"))
        #expect(!pixelComponents.contains("@State private var hoverRevealTask"))
        #expect(pixelComponents.contains("var isActive = false"))
        #expect(!pixelComponents.contains("var onHoverReveal: (() -> Void)? = nil"))
        #expect(pixelComponents.contains("private var dormantCommandTitle"))
        #expect(!pixelComponents.contains("private var commandHoverChrome"))
        #expect(!pixelComponents.contains("private var commandHoverStroke"))
        #expect(!pixelComponents.contains("private var commandPeak"))
        #expect(!pixelComponents.contains("platinumCommandChrome"))
        #expect(!pixelComponents.contains("classicCommandChrome"))
        #expect(!pixelComponents.contains("emberCommandChrome"))
        #expect(!pixelComponents.contains(".background { commandHoverChrome }"))
        #expect(!pixelComponents.contains(".overlay { commandHoverStroke }"))
        #expect(!pixelComponents.contains(".overlay(alignment: .topLeading) { commandPeak }"))
        #expect(pixelComponents.contains("PixelCommandTypewriterText("))
        #expect(pixelComponents.contains("text: lowercasedTitle"))
        #expect(pixelComponents.contains("enum LandingCommandThemeTreatment"))
        #expect(pixelComponents.contains("case platinumBlock"))
        #expect(pixelComponents.contains("case classicNative"))
        #expect(pixelComponents.contains("case emberHybrid"))
        #expect(pixelComponents.contains("case .platinumViolet:"))
        #expect(pixelComponents.contains("return .platinumBlock"))
        #expect(pixelComponents.contains("case .classic:"))
        #expect(pixelComponents.contains("return .classicNative"))
        #expect(pixelComponents.contains("case .ember:"))
        #expect(pixelComponents.contains("return .emberHybrid"))
        #expect(!pixelComponents.contains("case .platinumViolet, .classic, .ember:"))
        #expect(pixelComponents.contains("enum LandingCommandTypography"))
        #expect(pixelComponents.contains("static func heroFontName(for theme: EpistemosTheme) -> String"))
        #expect(pixelComponents.contains("static func h2h3FontName(for theme: EpistemosTheme) -> String"))
        #expect(pixelComponents.contains("LandingCommandTypography.commandFont"))
        #expect(pixelComponents.contains("LandingCommandTypography.panelTitleFont"))
        #expect(pixelComponents.contains("theme.resolved.accent.color"))
        #expect(!pixelComponents.contains("ForEach(0..<4"))
        #expect(!pixelComponents.contains("onHoverReveal?()"))
        #expect(!pixelComponents.contains("private var hoverCommandOverlay"))
        #expect(!pixelComponents.contains("PixelVectorHoverBlur("))
        #expect(!pixelComponents.contains("hoverShortcutText"))
        #expect(pixelComponents.contains("if isLit"))
        #expect(pixelComponents.contains("PixelGlyph(kind: glyph, accent: accent)"))
        #expect(pixelComponents.contains(".frame(height: 52"))
        #expect(landingView.contains("GridItem(.adaptive(minimum: 136, maximum: 176), spacing: 8)"))
        #expect(pixelComponents.contains(".zIndex(isActive || isHovered ? 10 : 0)"))
        #expect(!pixelComponents.contains("private var hoverExpansionProgress"))
        #expect(!pixelComponents.contains("PixelStepMotion.hoverExpansionProgress"))
        #expect(!pixelComponents.contains("hoverBloomProgress"))
        #expect(!pixelComponents.contains("commandShadowColor"))
        #expect(!pixelComponents.contains("commandScale(isLit:"))
        #expect(!pixelComponents.contains("commandYOffset(isLit:"))
        #expect(!pixelComponents.contains("Circle()\n                    .fill(accent.opacity(isLit"))
        #expect(!pixelComponents.contains("RoundedRectangle(cornerRadius: 5, style: .continuous)\n                        .fill(Color(hex: 0xC99A62).opacity(isLit"))
        #expect(!pixelComponents.contains("private var hoverLift"))
        #expect(!pixelComponents.contains("private var hoverCardScale"))
        #expect(!pixelComponents.contains("shortcutBadge"))
        #expect(!pixelComponents.contains("hoverSparkline"))
        #expect(!pixelComponents.contains("Text(\"KEY\")"))
        #expect(!pixelComponents.contains("PixelGlyph(kind: glyph, accent: accent, isActive: true)"))
        #expect(!pixelComponents.contains("transaction.animation = nil"))
        #expect(!pixelComponents.contains("theme.resolved.background.color.opacity(theme.isDark ? 0.98 : 0.96)"))
        #expect(landingView.contains("title: \"time machine\""))
        #expect(landingView.contains("isActive: activeLandingInlineCommand == .timeMachine"))
        #expect(!landingView.contains("onHoverReveal:"))
        #expect(landingView.contains("landingStageRevealContainer(accent: theme.resolved.accent.color)"))
        #expect(landingView.contains("LandingStageCommandPeak(accent: accent, theme: theme)"))
        #expect(landingView.contains(".preferredColorScheme(landingInlineCommandSurfaceTheme.colorScheme)"))
    }

    // updated 2026-07-03: the Classic→Matrix Bold source mapping was retired; all non-custom
    // themes now share Ember's typography (ColorBasic-Regular display face + ChonkyPixels
    // headings), and the classic landing hero shares Ember's displayFontName. These greps now
    // pin the new shared-Ember source structure instead of the old classic-specific cases.
    @Test("landing typography follows the shared-Ember font mapping")
    func landingTypographyFollowsGlobalClassicMapping() throws {
        let liquidGreeting = try loadTextFile("Epistemos/Views/Landing/LiquidGreeting.swift")
        let pixelComponents = try loadTextFile("Epistemos/Views/Landing/PixelSurfaceComponents.swift")
        let theme = try loadTextFile("Epistemos/Theme/EpistemosTheme.swift")

        #expect(theme.contains("case .classic, .platinumViolet, .ember: return \"ColorBasic-Regular\""))
        #expect(theme.contains("case .classic, .platinumViolet, .ember: return AppDisplayTypography.chonkyDisplayFontName"))
        #expect(theme.contains("return chonkyDisplayFontName"))
        #expect(liquidGreeting.contains("LandingCommandTypography.heroFontName(for: theme)"))
        #expect(liquidGreeting.contains(".weight(.heavy)"))
        #expect(pixelComponents.contains("case .classic, .ember:"))
        #expect(pixelComponents.contains("theme.displayFontName"))
        #expect(pixelComponents.contains("theme.headingFontName(level: 2)"))
        #expect(pixelComponents.contains("return .system(size: size, weight: .semibold, design: .rounded)"))
    }

    @Test("landing command stage has no native search composer")
    func landingCommandStageHasNoNativeSearchComposer() throws {
        let landingView = try loadTextFile("Epistemos/Views/Landing/LandingView.swift")

        #expect(!landingView.contains("import UniformTypeIdentifiers"))
        #expect(!landingView.contains("@State private var landingFileAttachments"))
        #expect(!landingView.contains("@State private var landingToolsExpanded"))
        #expect(!landingView.contains("private var landingSearchInlineStage: some View"))
        #expect(!landingView.contains("private var landingSearchStageTools: some View"))
        #expect(!landingView.contains("private var landingSearchBrainTool: some View"))
        #expect(!landingView.contains("private var landingSearchCommandTool: some View"))
        #expect(!landingView.contains("private var landingSearchMentionTool: some View"))
        #expect(!landingView.contains("private var landingSearchAttachTool: some View"))
        #expect(!landingView.contains("private var landingSearchToolsToggle: some View"))
        #expect(!landingView.contains("private var landingSearchSendTool: some View"))
        #expect(!landingView.contains("private var landingSearchExpandedToolRow: some View"))
        #expect(!landingView.contains("LandingStageToolTile("))
        #expect(!landingView.contains("PixelPanelTitle(text: \"Search\""))
        #expect(landingView.contains("LiquidGreeting("))
        #expect(landingView.contains("searchMode: showingLandingStageCommand"))
        #expect(!landingView.contains("ChatComposerTextEditor("))
        #expect(!landingView.contains("onCommand: { selector, modifierFlags in"))
        #expect(!landingView.contains("handleLandingComposerCommand(selector, modifierFlags: modifierFlags)"))
        #expect(!landingView.contains("TextField(\"\", text: $landingSearchText)"))
        #expect(!landingView.contains(".offset(x: 80, y: 54)"))
        #expect(!landingView.contains("private var landingSearchPopoverContent"))
        #expect(!landingView.contains("private var landingSearchControlsRow"))
        #expect(!landingView.contains("landingSearchFloatingBubbles"))
        #expect(!landingView.contains("LandingSearchFloatingBubbleField("))
        #expect(!landingView.contains("LandingSearchBubbleEdgeCanvas("))
        #expect(!landingView.contains("LandingWaveOverlay("))
        #expect(!landingView.contains("LandingShortcutDisplay"))
        #expect(!landingView.contains("LandingCommandItem"))
        #expect(!landingView.contains("LandingCommandRow"))
        #expect(!landingView.contains("CommandHintSpec"))
        #expect(!landingView.contains("CommandHintLabel"))
        #expect(!landingView.contains("openLandingFilePicker()"))
        #expect(!landingView.contains("FileAttachmentBuilder.buildAll(from: urls)"))
        #expect(!landingView.contains("landingFileAttachments.append(attachment)"))
        #expect(!landingView.contains("chat.addAttachment(attachment)"))
        #expect(!landingView.contains("landingContextAttachments.append(contextAttachment)"))
        #expect(!landingView.contains("openLandingSlashCommandMenu()"))
        #expect(!landingView.contains("insertLandingMentionToken()"))
        #expect(!landingView.contains("toggleLandingAllNotesContext()"))
        #expect(!landingView.contains("ChatCapabilityPill("))
        #expect(!landingView.contains("ContextualShadowsButton(scopeKind: .chat, scopeID: landingRecallScopeID)"))
    }

    @Test("landing search attachment preservation is deleted with the composer")
    func landingSearchAttachmentPreservationIsDeletedWithComposer() throws {
        let landingView = try loadTextFile("Epistemos/Views/Landing/LandingView.swift")

        #expect(!landingView.contains("private func preserveLandingSearchSurfaceAfterAttachment()"))
        #expect(!landingView.contains("landingSearchRevealFrame = max(landingSearchRevealFrame, 5)"))
        #expect(!landingView.contains("private func attachLandingMentionReference"))
        #expect(!landingView.contains("private func openLandingFilePicker()"))
    }

    @Test("landing command stage reveal keeps the active theme accent without liquid wave input effects")
    func landingCommandStageRevealUsesActiveThemeAccentWithoutLandingWaveInputEffects() throws {
        let repoRoot = try sourceMirrorRootURL()
        let landingView = try loadTextFile("Epistemos/Views/Landing/LandingView.swift")
        let pixelComponents = try loadTextFile("Epistemos/Views/Landing/PixelSurfaceComponents.swift")

        #expect(landingView.contains("@State private var landingStageRevealFrame"))
        #expect(landingView.contains("runLandingStageReveal()"))
        #expect(landingView.contains("landingSearchStepReveal(frame: landingStageRevealFrame"))
        #expect(!landingView.contains("landingSearchInlineStage"))
        #expect(!landingView.contains("LandingStageToolShell("))
        #expect(landingView.contains("if ui.homeContent == .greeting && !showingLandingStageCommand"))
        #expect(landingView.contains("landingPixelCommands\n                .padding(.horizontal, Spacing.xxl)"))
        #expect(!landingView.contains("landingSearchControlsRow\n                    }"))
        #expect(!landingView.contains("LandingSearchFieldFramePreferenceKey"))
        #expect(!landingView.contains("landingSearchStaticBubbleFrames"))
        #expect(!landingView.contains(".onContinuousHover"))
        #expect(!landingView.contains("Color(hue: 0.75"))
        #expect(!landingView.contains("LandingWaveHaptics.fireBeat"))
        #expect(!landingView.contains("LandingWaveOverlay("))
        #expect(pixelComponents.contains("LandingSearchStepRevealModifier"))
        #expect(!pixelComponents.contains("LandingSearchLiquidRevealModifier"))
        #expect(!pixelComponents.contains("rippleOpacity"))
        #expect(!FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent("Epistemos/Views/Landing/Wave/LandingWaveMetalView.swift").path))
        #expect(!FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent("Epistemos/Views/Landing/Wave/LandingWaveRenderer.swift").path))
        #expect(!FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent("Epistemos/Views/Landing/Wave/LandingWaveChoreography.swift").path))
        #expect(!FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent("Epistemos/Shaders/LandingWave.metal").path))
    }

    @Test("landing command stages replace only the greeting slot")
    func landingCommandStagesReplaceOnlyTheGreetingSlot() throws {
        let landingView = try loadTextFile("Epistemos/Views/Landing/LandingView.swift")

        #expect(landingView.contains("Spacer(minLength: showingLandingStageCommand ? 24 : 0)"))
        #expect(landingView.contains("Spacer(minLength: showingLandingStageCommand ? 42 : 0)"))
        #expect(landingView.contains("landingPixelCommands\n                .padding(.horizontal, Spacing.xxl)"))
        #expect(!landingView.contains("if !showingLandingStageCommand {\n                landingPixelCommands"))
        #expect(!landingView.contains("case .workspaces: 540"))
        #expect(!landingView.contains(".frame(width: 520, height: 540)"))
        #expect(landingView.contains(".frame(width: 520, height: 370)"))
    }

    @Test("landing stage dismiss replays the greeting reveal")
    func landingStageDismissReplaysTheGreetingReveal() throws {
        let landingView = try loadTextFile("Epistemos/Views/Landing/LandingView.swift")
        let pixelComponents = try loadTextFile("Epistemos/Views/Landing/PixelSurfaceComponents.swift")

        #expect(landingView.contains("@State private var landingGreetingReturnFrame = 4"))
        #expect(landingView.contains("@State private var landingGreetingReturnTask: Task<Void, Never>?"))
        #expect(landingView.contains(".landingGreetingReturnReveal(frame: landingGreetingReturnFrame"))
        #expect(landingView.contains("private func runLandingGreetingReturnReveal()"))
        #expect(!landingView.contains("dismissLandingSearch(animateGreetingReturn: false)"))
        #expect(landingView.contains("private func dismissLandingStageCommand()"))
        #expect(landingView.contains("dismissLandingInlineCommand()"))
        #expect(pixelComponents.contains("playLandingGreetingReturnReveal"))
        #expect(pixelComponents.contains("landingGreetingReturnReveal(frame: Int, theme: EpistemosTheme)"))
    }

    @Test("landing command surfaces reuse real panels inside the greeting stage")
    func landingCommandSurfacesReuseRealPanelsInsideGreetingStage() throws {
        let landingView = try loadTextFile("Epistemos/Views/Landing/LandingView.swift")
        let savePanel = try loadTextFile("Epistemos/Views/Landing/QuitSavePanelController.swift")
        let workspaces = try loadTextFile("Epistemos/Views/Landing/WorkspaceSwitcherOverlay.swift")

        #expect(landingView.contains("private enum LandingInlineCommand"))
        #expect(landingView.contains("@State private var activeLandingInlineCommand: LandingInlineCommand?"))
        #expect(landingView.contains("private var showingLandingStageCommand: Bool"))
        #expect(landingView.contains("landingInlineCommandStage(for: command)"))
        #expect(landingView.contains("QuickCaptureView(isPresented: landingInlineCommandBinding(for: .quickCapture))"))
        #expect(landingView.contains("WorkspaceSwitcherOverlay("))
        #expect(landingView.contains("isPresented: landingInlineCommandBinding(for: .workspaces)"))
        #expect(landingView.contains("presentation: .inline"))
        #expect(landingView.contains("SaveWorkspaceInlineView(isPresented: landingInlineCommandBinding(for: .saveWorkspace))"))
        #expect(landingView.contains("TimeMachineView(isPresented: landingInlineCommandBinding(for: .timeMachine))"))
        #expect(landingView.contains("showLandingInlineCommand(.quickCapture)"))
        #expect(landingView.contains("showLandingInlineCommand(.workspaces)"))
        #expect(landingView.contains("showLandingInlineCommand(.saveWorkspace)"))
        #expect(landingView.contains("showLandingInlineCommand(.timeMachine)"))
        let commandsStart = try #require(landingView.range(of: "private var landingPixelCommands"))
        let commandsEnd = try #require(
            landingView.range(
                of: "private var landingCompanionDock",
                range: commandsStart.lowerBound..<landingView.endIndex
            )
        )
        let commandTileBody = landingView[commandsStart.lowerBound..<commandsEnd.lowerBound]
        #expect(!commandTileBody.contains("NotificationCenter.default.post(name: .toggleWorkspaceSwitcher"))
        #expect(!commandTileBody.contains("NotificationCenter.default.post(name: .showSaveWorkspacePanel"))
        #expect(!commandTileBody.contains("NotificationCenter.default.post(name: .toggleTimeMachine"))
        #expect(workspaces.contains("enum WorkspaceSwitcherPresentation"))
        #expect(workspaces.contains("presentation: WorkspaceSwitcherPresentation = .overlay"))
        #expect(workspaces.contains("presentation == .overlay"))
        #expect(workspaces.contains("@State private var cachedDiff: WorkspaceDiffSummary?"))
        #expect(workspaces.contains("private var shouldShowDriftIndicator"))
        #expect(workspaces.contains("refreshDiffIfNeeded()"))
        #expect(savePanel.contains("struct SaveWorkspaceInlineView: View"))
        #expect(savePanel.contains("QuitSaveContent(isQuitFlow: false)"))
    }

    @Test("quick capture time machine and workspace panels avoid blur materials")
    func pixelAdminSurfacesAvoidBlurMaterials() throws {
        for relativePath in [
            "Epistemos/Views/Capture/QuickCaptureView.swift",
            "Epistemos/Views/Landing/TimeMachineView.swift",
            "Epistemos/Views/Landing/WorkspaceSwitcherOverlay.swift",
            "Epistemos/Views/Landing/QuitSavePanelController.swift",
        ] {
            let source = try loadTextFile(relativePath)
            #expect(source.contains("pixelPanel(theme:"))
            #expect(source.contains("PixelPanelTitle("))
            #expect(!source.contains(".ultraThinMaterial"))
            #expect(!source.contains("NSVisualEffectView"))
        }
    }

    @Test("landing command overlays keep the home surface undimmed and use stepped pixel motion")
    func landingCommandOverlaysKeepHomeSurfaceUndimmedAndUseSteppedPixelMotion() throws {
        let rootView = try loadTextFile("Epistemos/App/RootView.swift")

        for relativePath in [
            "Epistemos/Views/Capture/QuickCaptureView.swift",
            "Epistemos/Views/Landing/TimeMachineView.swift",
            "Epistemos/Views/Landing/WorkspaceSwitcherOverlay.swift",
            "Epistemos/Views/Landing/QuitSavePanelController.swift",
        ] {
            let source = try loadTextFile(relativePath)
            #expect(source.contains("Color.clear"))
            #expect(source.contains("PixelStepMotion.play"))
            #expect(source.contains("pixelStepAppear(frame:"))
            #expect(!source.contains("appeared"))
            #expect(!source.contains("scrimOpacity"))
            #expect(!source.contains("scrimColor.opacity"))
        }

        #expect(!rootView.contains(".animation(Motion.smooth, value: showWorkspaceSwitcher)"))
        #expect(!rootView.contains(".animation(Motion.smooth, value: showTimeMachine)"))
        #expect(!rootView.contains(".animation(Motion.smooth, value: showQuickCapture)"))
    }

    @Test("embedded home graph uses bottom close control instead of a top home button")
    func embeddedHomeGraphUsesBottomCloseControlInsteadOfTopHomeButton() throws {
        let embeddedGraph = try loadTextFile("Epistemos/Views/Home/HomeGraphEmbeddedView.swift")
        let controls = try loadTextFile("Epistemos/Views/Graph/GraphFloatingControls.swift")

        #expect(!embeddedGraph.contains("backButton"))
        #expect(!embeddedGraph.contains("Text(\"Home\")"))
        #expect(!embeddedGraph.contains("Back-to-greeting button"))
        #expect(controls.contains("graphSurfacePresentation.isEmbeddedHome ? \"Return to home\" : \"Close Graph (Esc)\""))
        #expect(controls.contains("ui.homeContent = .greeting"))
    }

    @Test("settings shared surfaces use native cards with pixel icons")
    func settingsSharedSurfacesUseNativeCardsWithPixelIcons() throws {
        let components = try loadTextFile("Epistemos/Views/Settings/SettingsSurfaceComponents.swift")
        let settingsView = try loadTextFile("Epistemos/Views/Settings/SettingsView.swift")

        #expect(components.contains("SettingsAppleCardChrome("))
        #expect(components.contains("SettingsFeaturedPixelPanel"))
        #expect(components.contains("SettingsPixelGlyphBadge"))
        #expect(components.contains("SettingsThemedBlurBackdrop"))
        #expect(components.contains("SettingsBlurGroupBoxStyle"))
        #expect(components.contains("settingsThemedBlurPage(theme:"))
        #expect(components.contains(".background(.regularMaterial)"))
        #expect(components.contains(".glassEffect(.regular.interactive(), in: RoundedRectangle"))
        #expect(components.contains("pixelPanel(theme: theme)"))
        #expect(components.contains("Image(systemName: systemImage)"))
        #expect(components.contains("RoundedRectangle(cornerRadius:"))
        #expect(!components.contains("SettingsModernPixelChrome"))
        #expect(!components.contains("settingsModernPixelChrome"))
        #expect(!components.contains("PixelPanelBackground.actionSurface"))
        #expect(!components.contains(".ultraThinMaterial"))
        #expect(settingsView.contains(".settingsThemedBlurPage(theme: ui.theme.surfaceVariant(.other))"))
        #expect(settingsView.contains("SettingsSidebarBackdrop(theme: ui.theme)"))
        #expect(settingsView.contains("SettingsDetailBackdrop(theme: ui.theme)"))
        #expect(settingsView.contains("SettingsThemedBlurBackdrop(theme: theme.surfaceVariant(.other), role: .sidebar)"))
        #expect(settingsView.contains("SettingsThemedBlurBackdrop(theme: theme.surfaceVariant(.other), role: .page)"))
        #expect(settingsView.contains("SettingsPixelGlyphBadge(systemImage: section.icon"))
        #expect(settingsView.contains("SettingsFeaturedPixelPanel(theme: settingsTheme)"))
        #expect(!settingsView.contains("pixelPanel(theme: settingsTheme)"))
        #expect(!settingsView.contains(".background(.ultraThinMaterial"))
        #expect(!settingsView.contains(".fill(.white.opacity(0.001))"))
    }

    @Test("settings view exposes a native sidebar toggle in the toolbar")
    func settingsViewExposesSidebarToggle() throws {
        let settingsView = try loadTextFile("Epistemos/Views/Settings/SettingsView.swift")

        #expect(settingsView.contains("ToolbarItem(placement: .navigation)"))
        #expect(settingsView.contains("Image(systemName: \"sidebar.left\")"))
        #expect(settingsView.contains("toggleSidebar()"))
    }

    @Test("landing view does not fetch old chat history for daily brief generation")
    func landingViewDoesNotFetchOldChatHistoryForDailyBriefGeneration() throws {
        let landingView = try loadTextFile("Epistemos/Views/Landing/LandingView.swift")

        #expect(landingView.contains("@Environment(\\.modelContext) private var modelContext"))
        #expect(!landingView.contains("@Query(sort: \\\\.updatedAt, order: .reverse)\n    private var allChats: [SDChat]"))
        #expect(!landingView.contains("private func recentChats(limit: Int) -> [SDChat]"))
        #expect(landingView.contains("DailyBriefState.buildBriefPrompt(pages: Array(allPages), chats: [])"))
    }

    @Test("bootstrap runs disk style cache eviction at utility priority")
    func bootstrapRunsDiskStyleEvictionOffLaunchPriority() throws {
        let bootstrap = try loadTextFile("Epistemos/App/AppBootstrap.swift")

        #expect(bootstrap.contains("Task(priority: .utility) { DiskStyleCache.shared.evictIfNeeded() }"))
    }

    @Test("bootstrap defers fallback search index creation until query use")
    func bootstrapDefersFallbackSearchIndexCreation() throws {
        let bootstrap = try loadTextFile("Epistemos/App/AppBootstrap.swift")

        #expect(!bootstrap.contains("let searchIdx = vaultSync.searchService ?? (try? SearchIndexService())"))
        #expect(bootstrap.contains("searchIndexProvider: {"))
    }

    @Test("bootstrap no longer wires the retired local MLX runtime")
    func bootstrapDoesNotWireRetiredLocalMLXRuntime() throws {
        let bootstrap = try loadTextFile("Epistemos/App/AppBootstrap.swift")

        #expect(!bootstrap.contains("MLXInferenceService"))
        #expect(!bootstrap.contains("LocalMLXClient"))
        #expect(!bootstrap.contains("let localInferenceService"))
    }

    @Test("bootstrap and environment no longer inject the removed local voice stack")
    func bootstrapDropsLocalVoiceManager() throws {
        let bootstrap = try loadTextFile("Epistemos/App/AppBootstrap.swift")
        let environment = try loadTextFile("Epistemos/App/AppEnvironment.swift")

        #expect(!bootstrap.contains("let localVoiceManager: LocalVoiceManager"))
        #expect(!bootstrap.contains("self.localVoiceManager = LocalVoiceManager("))
        #expect(!environment.contains(".environment(bootstrap.localVoiceManager)"))
    }

    @Test("inference settings focus on the curated local routing stack without voice residue")
    func inferenceSettingsRefocusOnQwenRouting() throws {
        let settings = try loadTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let inferenceState = try loadTextFile("Epistemos/State/InferenceState.swift")
        let environment = try loadTextFile("Epistemos/App/AppEnvironment.swift")

        // Local routing/model-name asserts (Routing Mode / Active Local Model / Qwen 3.5 / Qwen 3.6 /
        // Recommended Baseline / Gemma 4 E4B / DeepSeek R1 7B / Qwen 2.5 Coder 7B) removed with
        // cloud-only/Omega removal 2026-07-03 — the curated local routing stack was deleted; the
        // no-local/no-voice-residue absence guards below stay valid.
        #expect(!settings.contains("Show Thinking Panel"))
        #expect(!settings.contains("Automatic Model Selection"))
        #expect(!settings.contains("Local Response Mode"))
        #expect(inferenceState.contains("Local Only"))
        #expect(!environment.contains("localSidecarState"))
        #expect(!inferenceState.contains("Cloud Only"))
        #expect(!settings.contains("Preferred Local Voice"))
        #expect(!settings.contains("Voice Playback"))
        #expect(!settings.contains("Auto-download core local pack"))
        #expect(!settings.contains("Chatterbox"))
    }

    @Test("UIState source keeps the typewriter toggle and drops liquid greeting state")
    func uiStateKeepsSplitGreetingTogglesAndDropsObsoleteFlags() throws {
        let uiState = try loadTextFile("Epistemos/State/UIState.swift")

        #expect(!uiState.contains("var landingCursorAnimationEnabled"))
        #expect(!uiState.contains("var landingCursorVisibilityMode"))
        #expect(!uiState.contains("LandingWakeFieldPolicy"))
        #expect(!uiState.contains("var landingGreetingASCIIEnabled"))
        #expect(uiState.contains("var landingGreetingTypewriterEnabled"))
        #expect(uiState.contains("\"epistemos.landingCursorAnimationEnabled\""))
        #expect(uiState.contains("\"epistemos.landingCursorVisibilityMode\""))
        #expect(!uiState.contains("var landingGreetingLiquidEnabled"))
        #expect(!uiState.contains("var landingGreetingASCIIHoverEnabled"))
        #expect(!uiState.contains("var landingGreetingTypewriterVersion"))
        #expect(!uiState.contains("var landingGreetingIntensity"))
        #expect(!uiState.contains("var landingGreetingCharacterVariety"))
        #expect(!uiState.contains("var landingGreetingPace"))
        #expect(!uiState.contains("enum LandingGreetingTypewriterVersion"))
        #expect(!uiState.contains("var landingGreetingThreshold"))
        #expect(!uiState.contains("var landingGreetingBlur"))
    }

    @Test("project drops the unused legacy navigation pill file")
    func projectDropsUnusedLegacyNavigationPillFile() throws {
        let pbxproj = try loadProjectFile()
        #expect(!pbxproj.contains("PillNavBar.swift"))
    }

    @Test("project drops dead Gemini generated image references")
    func projectDropsDeadGeminiGeneratedImageReferences() throws {
        let pbxproj = try loadProjectFile()
        #expect(!pbxproj.contains("Gemini Generated Image"))
    }

    @Test("shell helpers keep only the heading and flow layout still in use")
    func shellHelpersKeepOnlyLiveTypes() throws {
        let shellSource = try loadTextFile("Epistemos/Views/Shell/PageShell.swift")

        #expect(shellSource.contains("struct TypewriterHeading: View"))
        #expect(shellSource.contains("struct FlowLayout: Layout"))
        #expect(!shellSource.contains("struct PageShell<"))
        #expect(!shellSource.contains("struct AccentTitleBar: View"))
        #expect(!shellSource.contains("struct GlassSection<"))
        #expect(!shellSource.contains("struct ResearchTabBar<"))
    }

    @Test("project drops the standalone research subsystem")
    func projectDropsStandaloneResearchSubsystem() throws {
        let pbxproj = try loadProjectFile()
        let bootstrap = try loadTextFile("Epistemos/App/AppBootstrap.swift")
        let shortcuts = try loadTextFile("Epistemos/Intents/EpistemosShortcutsProvider.swift")

        #expect(!pbxproj.contains("ResearchState.swift"))
        #expect(!pbxproj.contains("ResearchService.swift"))
        #expect(!pbxproj.contains("ResearchIntents.swift"))
        #expect(!pbxproj.contains("PaperEntity.swift"))
        #expect(!pbxproj.contains("ResearchTypes.swift"))
        #expect(!bootstrap.contains("researchState"))
        #expect(!bootstrap.contains("researchService"))
        #expect(!shortcuts.contains("ResearchTopicIntent"))
        #expect(!shortcuts.contains("FindGapsIntent"))
        #expect(!shortcuts.contains("FactCheckIntent"))
    }

    @Test("living repo guidance distinguishes live local routing from Hermes cloud plumbing")
    func livingRepoGuidanceReflectsCurrentRouting() throws {
        let agents = try loadRepoRootTextFile("AGENTS.md")
        let claude = try loadRepoRootTextFile("CLAUDE.md")
        let memory = try loadTextFile("docs/codex-memory.md")

        for source in [agents, memory] {
            #expect(source.contains("Apple Intelligence"))
            #expect(source.contains("Qwen 3.5"))
            #expect(source.contains("no cloud fallback in the live app"))
        }

        #expect(claude.contains("agent_core crate owns: agentic loop, HTTP streaming, tool execution"))
        #expect(claude.contains("legacy agent subprocess was removed 2026-05-05; orchestration now lives in `agent_core::agent_runtime`"))
        #expect(claude.contains("LocalAgentPromptBuilder.swift and LocalAgentGatewayPolicy.swift"))
        #expect(claude.contains("Cloud models get agent/liveAgent"))
        #expect(claude.contains("Anthropic"))
        #expect(claude.contains("OpenAI"))
    }

    @Test("chat thread drops legacy provider metadata fields")
    func chatThreadDropsLegacyProviderMetadataFields() throws {
        let chatTypes = try loadTextFile("Epistemos/Models/ChatTypes.swift")

        #expect(!chatTypes.contains("var provider: String?"))
        #expect(!chatTypes.contains("var model: String?"))
        #expect(!chatTypes.contains("var useLocal: Bool"))
    }

    @Test("bundle plist keeps speech recognition and microphone prompts for shipped voice input")
    func bundlePlistKeepsRequiredVoicePermissionPrompts() throws {
        let plist = try loadBundlePlist()

        #expect(plist["NSSpeechRecognitionUsageDescription"] != nil)
        #expect(plist["NSMicrophoneUsageDescription"] != nil)
    }

    @Test("iMessage driver settings include native permission doctor actions")
    func iMessageDriverSettingsExposePermissionDoctor() throws {
        let source = try loadTextFile("Epistemos/Views/Settings/IMessageDriverSettingsView.swift")

        #expect(source.contains("Permission Doctor"))
        #expect(source.contains("Open Full Disk Access"))
        #expect(source.contains("Open Automation Settings"))
        #expect(source.contains("Run Native Setup"))
        #expect(source.contains("Refresh setup status"))
        #expect(source.contains("Messages database accessible"))
        #expect(source.contains("Messages automation ready"))
        #expect(source.contains("Messages app available"))
    }

    @Test("iMessage native setup doctor uses a real sqlite probe and Messages automation target")
    func iMessageNativeSetupDoctorUsesExactNativeChecks() throws {
        let source = try loadTextFile("Epistemos/Omega/iMessageDriver/IMessageNativeSetupDoctor.swift")

        #expect(source.contains("import SQLite3"))
        #expect(source.contains("sqlite3_open_v2"))
        #expect(source.contains("sqlite3_prepare_v2"))
        #expect(source.contains("com.apple.MobileSMS"))
        #expect(source.contains("runGuidedSetup"))
    }

    @Test("iMessage setup surfaces the active app copy and relaunch guidance")
    func iMessageSetupSurfacesActiveAppCopyAndRelaunchGuidance() throws {
        let doctor = try loadTextFile("Epistemos/Omega/iMessageDriver/IMessageNativeSetupDoctor.swift")
        let settings = try loadTextFile("Epistemos/Views/Settings/IMessageDriverSettingsView.swift")
        let channels = try loadTextFile("Epistemos/Views/Settings/ChannelsSettingsView.swift")

        #expect(doctor.contains("currentAppPath"))
        #expect(doctor.contains("runningEpistemosAppPaths"))
        #expect(doctor.contains("relaunchCurrentApp"))
        #expect(settings.contains("Reveal This Epistemos"))
        #expect(settings.contains("Relaunch Epistemos"))
        #expect(settings.contains("Current Epistemos build"))
        #expect(settings.contains("Another Epistemos copy is also running"))
        #expect(channels.contains("Reveal This Epistemos"))
        #expect(channels.contains("Relaunch Epistemos"))
    }

    @Test("channels settings surface guided native setup for iMessage")
    func channelsSettingsSurfaceGuidedNativeSetup() throws {
        let source = try loadTextFile("Epistemos/Views/Settings/ChannelsSettingsView.swift")

        #expect(source.contains("Run Native Setup"))
        #expect(source.contains("Messages database accessible"))
        #expect(source.contains("Messages automation ready"))
        #expect(source.contains("openIMessageSettings()"))
    }

    @Test("daily brief stays single pass without deep analysis scaffolding")
    func dailyBriefDropsSecondPassScaffolding() throws {
        let state = try loadTextFile("Epistemos/State/DailyBriefState.swift")
        let landing = try loadTextFile("Epistemos/Views/Landing/LandingView.swift")
        let coordinator = try loadTextFile("Epistemos/App/AppCoordinator.swift")
        let intent = try loadTextFile("Epistemos/Intents/Custom/DailyBriefingIntent.swift")

        #expect(!state.contains("isDeepBrief"))
        #expect(!state.contains("onGoDeepGenerate"))
        #expect(!state.contains("requestGoDeep"))
        #expect(!state.contains("deep actionable intelligence report"))
        #expect(!state.contains("research analyst's morning brief"))
        #expect(!landing.contains("Go Deeper"))
        #expect(!landing.contains("buildGoDeepPrompt"))
        #expect(!landing.contains("deep multi-perspective analysis"))
        #expect(!coordinator.contains("onGoDeepGenerate"))
        #expect(!intent.contains("daily intelligence brief"))
    }

    @Test("user-facing AI surfaces avoid hidden research personas and system wrappers")
    func userFacingAISurfacesDropHiddenPersonas() throws {
        let analysisIntents = try loadTextFile("Epistemos/Intents/Custom/AnalysisIntents.swift")
        let noteActions = try loadTextFile("Epistemos/Intents/Custom/NoteActionIntents.swift")
        let noteWorkspace = try loadTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let nodeInspector = try loadTextFile("Epistemos/Views/Graph/NodeInspectorState.swift")
        let hologramInspector = try loadTextFile("Epistemos/Views/Graph/HologramNodeInspector.swift")
        let vaultOrganizer = try loadTextFile("Epistemos/Views/Notes/VaultOrganizerView.swift")
        let triage = try loadTextFile("Epistemos/Engine/TriageService.swift")

        #expect(!analysisIntents.contains("research assistant"))
        #expect(!noteActions.contains("research assistant"))
        #expect(!noteWorkspace.contains("systemPrompt: mapping.systemPrompt"))
        #expect(!noteWorkspace.contains("You are a writing assistant."))
        #expect(!nodeInspector.contains("You are a note analyst"))
        #expect(!hologramInspector.contains("p.archetype.title"))
        #expect(!hologramInspector.contains("p.care.mood.displayName"))
        #expect(!hologramInspector.contains("p.portrait.symbol"))
        #expect(!hologramInspector.contains("statMeter(label: \"Focus\""))
        #expect(!vaultOrganizer.contains("You are a note organization assistant."))
        #expect(!triage.contains("let simpleSystem ="))
    }

    private func loadIconComposerJSON() throws -> String {
        try loadTextFile("Epistemos/AppIcon.icon/icon.json")
    }

    private func loadBundlePlist() throws -> [String: Any] {
        let data = try loadMirroredSourceDataFile("Epistemos-Info.plist")
        return try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    }

    private func loadProjectFile() throws -> String {
        try loadTextFile("Epistemos.xcodeproj/project.pbxproj")
    }

    private func loadRepoRootTextFile(_ relativePath: String) throws -> String {
        try loadMirroredSourceTextFile(relativePath)
    }

    private func loadTextFile(_ relativePath: String) throws -> String {
        try loadMirroredSourceTextFile(relativePath)
    }
}
