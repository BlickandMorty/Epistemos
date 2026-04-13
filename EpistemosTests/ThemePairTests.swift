import AppKit
import Foundation
import SwiftUI
import Testing
@testable import Epistemos

@Suite("ThemePair Dock Icon")
struct ThemePairTests {
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

    @Test("Magnolia resolves to the new ash-rose light and nocturne dark themes")
    func magnoliaPairMapping() {
        #expect(ThemePair.magnolia.lightTheme == .magnolia)
        #expect(ThemePair.magnolia.darkTheme == .nocturne)
        #expect(ThemePair.magnolia.resolved(isDark: false) == .magnolia)
        #expect(ThemePair.magnolia.resolved(isDark: true) == .nocturne)
        #expect(EpistemosTheme.magnolia.usesNativeWindowBlur)
        #expect(EpistemosTheme.nocturne.usesNativeWindowBlur)
        #expect(!EpistemosTheme.light.usesNativeWindowBlur)
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

    @Test("Classic does not require a runtime dock icon override")
    func classicResourceMapping() {
        #expect(ThemePair.classic.dockIconResourceName(isDark: false) == nil)
        #expect(ThemePair.classic.dockIconResourceName(isDark: true) == nil)
    }

    @Test("Magnolia, Warmth, and Ember do not require runtime dock icon overrides")
    func alternatePairsUseAdaptiveResources() {
        #expect(ThemePair.magnolia.dockIconResourceName(isDark: false) == nil)
        #expect(ThemePair.magnolia.dockIconResourceName(isDark: true) == nil)
        #expect(ThemePair.warmth.dockIconResourceName(isDark: false) == nil)
        #expect(ThemePair.warmth.dockIconResourceName(isDark: true) == nil)
        #expect(ThemePair.ember.dockIconResourceName(isDark: false) == nil)
        #expect(ThemePair.ember.dockIconResourceName(isDark: true) == nil)
    }

    @MainActor
    @Test("UIState defaults to native system appearance when no theme settings are stored")
    func uiStateDefaultsToSystemDefaultAppearance() {
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

        #expect(uiState.themeMode == .systemDefault)
        #expect(uiState.customThemesEnabled == false)
        #expect(uiState.activePair == .classic)
        #expect(uiState.preferredColorScheme == nil)
        #expect(uiState.shouldUseThemeWorkarounds == false)
        #expect(uiState.usesNativeWindowBlur == false)
    }

    @MainActor
    @Test("Stored theme preferences no longer reactivate custom appearance")
    func storedThemePreferencesStayPinnedToSystemDefault() {
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

        #expect(uiState.activePair == .classic)
        #expect(uiState.customThemesEnabled == false)
        #expect(uiState.themeMode == .systemDefault)
        #expect(uiState.shouldUseThemeWorkarounds == false)
        #expect(uiState.preferredColorScheme == nil)
    }

    @MainActor
    @Test("UIState clears legacy theme defaults on init")
    func uiStateClearsLegacyThemeDefaultsOnInit() {
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

        _ = UIState()

        #expect(defaults.object(forKey: ThemeMode.defaultsKey) == nil)
        #expect(defaults.object(forKey: UIState.themePairDefaultsKey) == nil)
    }

    @MainActor
    @Test("Theme mutators stay inert under the system-only runtime")
    func themeMutatorsStayInert() {
        withPreservedThemeDefaults {
            let defaults = UserDefaults.standard
            defaults.removeObject(forKey: ThemeMode.defaultsKey)
            defaults.removeObject(forKey: UIState.themePairDefaultsKey)

            let uiState = UIState()

            uiState.setPair(.magnolia)
            uiState.setThemeMode(.custom)
            uiState.setCustomThemesEnabled(true)

            #expect(uiState.customThemesEnabled == false)
            #expect(uiState.activePair == .classic)
            #expect(uiState.themeMode == .systemDefault)
            #expect(uiState.preferredColorScheme == nil)
            #expect(uiState.shouldUseThemeWorkarounds == false)
            #expect(uiState.windowAppearance == nil)
        }
    }

    @MainActor
    @Test("System default keeps window appearance unforced even after legacy theme calls")
    func windowAppearanceStaysNative() {
        withPreservedThemeDefaults {
            let defaults = UserDefaults.standard
            defaults.removeObject(forKey: ThemeMode.defaultsKey)
            defaults.removeObject(forKey: UIState.themePairDefaultsKey)

            let uiState = UIState()
            uiState.isSystemDark = false

            #expect(uiState.themeMode == .systemDefault)
            #expect(uiState.windowAppearance == nil)
            #expect(uiState.theme == .systemLight)

            uiState.setPair(.platinum)
            uiState.setThemeMode(.custom)
            uiState.setCustomThemesEnabled(true)
            uiState.isSystemDark = true

            #expect(uiState.themeMode == .systemDefault)
            #expect(uiState.windowAppearance == nil)
            #expect(uiState.theme == .systemDark)
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

            #expect(uiState.themeMode == .systemDefault)
            uiState.isSystemDark = false
            #expect(uiState.graphOverlayTheme == .systemLight)
            #expect(GraphOverlayThemeStyle.windowAppearance(for: uiState.graphOverlayTheme)?.name == .aqua)
            #expect(GraphOverlayThemeStyle.lightModeEnabled(for: uiState.graphOverlayTheme))

            uiState.isSystemDark = true
            #expect(uiState.graphOverlayTheme == .systemDark)
            #expect(GraphOverlayThemeStyle.windowAppearance(for: uiState.graphOverlayTheme)?.name == .darkAqua)
            #expect(!GraphOverlayThemeStyle.lightModeEnabled(for: uiState.graphOverlayTheme))
        }
    }

    @MainActor
    @Test("Graph overlay fallback uses dedicated native tokens")
    func graphOverlayFallbackUsesNativeTokens() {
        #expect(GraphOverlayThemeStyle.resolvedTheme(uiState: nil, fallbackIsDark: false) == .systemLight)
        #expect(GraphOverlayThemeStyle.resolvedTheme(uiState: nil, fallbackIsDark: true) == .systemDark)
    }

    @MainActor
    @Test("Graph overlay uses floating glass blur in light and dark modes")
    func graphOverlayUsesFloatingGlassBlurMaterials() {
        #expect(GraphOverlayThemeStyle.blurMaterial(for: .systemLight) == .hudWindow)
        #expect(GraphOverlayThemeStyle.blurMaterial(for: .systemDark) == .hudWindow)
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

    @Test("Magnolia uses a rose display accent for app titles and headings")
    func magnoliaUsesRoseDisplayAccent() {
        #expect(EpistemosTheme.magnolia.headingAccentHex == 0xB86F8D)
    }

    @Test("Platinum pair resolves to distinct light and dark variants")
    func platinumPairMapping() {
        #expect(ThemePair.platinum.lightTheme == .platinum)
        #expect(ThemePair.platinum.darkTheme == .platinumDark)
        #expect(ThemePair.platinum.resolved(isDark: false) == .platinum)
        #expect(ThemePair.platinum.resolved(isDark: true) == .platinumDark)
        #expect(!EpistemosTheme.platinum.isDark)
        #expect(EpistemosTheme.platinumDark.isDark)
        #expect(EpistemosTheme.platinum.foregroundHex == 0x000000)
        #expect(EpistemosTheme.platinumDark.foregroundHex == 0xFFFFFF)
        #expect(EpistemosTheme.platinum.markdownHeadingAccentHex == 0x111111)
        #expect(EpistemosTheme.platinumDark.markdownHeadingAccentHex == 0xF2F2F2)
        #expect(EpistemosTheme.platinum.preferredMarkdownLinkHex == 0x111111)
        #expect(EpistemosTheme.platinumDark.preferredMarkdownLinkHex == nil)
        #expect(MarkdownHeadingDisplay.foregroundHex(for: .platinum, level: 1) == EpistemosTheme.platinum.headingAccentHex)
        #expect(MarkdownHeadingDisplay.foregroundHex(for: .platinumDark, level: 1) == EpistemosTheme.platinumDark.headingAccentHex)
        #expect(MarkdownHeadingDisplay.foregroundHex(for: .platinum, level: 2) == EpistemosTheme.platinum.markdownHeadingAccentHex)
        #expect(MarkdownHeadingDisplay.foregroundHex(for: .platinumDark, level: 2) == EpistemosTheme.platinumDark.markdownHeadingAccentHex)
        #expect(EpistemosTheme.platinum.assistantBubbleForegroundHex == EpistemosTheme.platinum.mutedForegroundHex)
        #expect(EpistemosTheme.platinumDark.assistantBubbleForegroundHex == EpistemosTheme.platinumDark.foregroundHex)
        #expect(EpistemosTheme.platinum.assistantBubbleBackgroundHex == nil)
        #expect(EpistemosTheme.platinumDark.assistantBubbleBackgroundHex == nil)
        #expect(EpistemosTheme.platinum.userBubbleBackgroundHex == 0x111111)
        #expect(EpistemosTheme.platinum.userBubbleText == Color(hex: 0xF2F2F2).opacity(0.94))
        #expect(EpistemosTheme.platinumDark.userBubbleBackgroundHex == 0x2A2A38)
        #expect(EpistemosTheme.platinumDark.userBubbleText == Color(hex: 0xF2F2F2).opacity(0.94))
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

    @Test("App heading roles use the shared display scale")
    func appHeadingRolesUseSharedDisplayScale() {
        #expect(AppDisplayTypography.displayFontName == "RetroGaming")
        #expect(AppHeadingRole.pageTitle.fontSize == 28)
        #expect(AppHeadingRole.pageTitle.animatesOnFirstAppearance)
        #expect(AppHeadingRole.h1.fontSize == 26)
        #expect(AppHeadingRole.h2.fontSize == 20)
        #expect(AppHeadingRole.h3.fontSize == 16)
        #expect(AppHeadingRole.section.fontSize == 12)
    }

    @Test("Markdown H1 sizing eases down for longer titles without collapsing into H2")
    func markdownH1AdaptiveSizing() {
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
        #expect(MarkdownHeadingDisplay.shadowOpacity(for: .platinum, level: 1) == 0)
        #expect(MarkdownHeadingDisplay.shadowOpacity(for: .platinum, level: 2) == 0)
        #expect(MarkdownHeadingDisplay.shadowOpacity(for: .platinum, level: 3) == 0)
        #expect(MarkdownHeadingDisplay.shadowOpacity(for: .platinumDark, level: 1) == 0.38)
        #expect(MarkdownHeadingDisplay.shadowOpacity(for: .platinumDark, level: 2) == 0.24)
        #expect(MarkdownHeadingDisplay.shadowOpacity(for: .platinumDark, level: 3) == 0.18)
        #expect(MarkdownHeadingDisplay.overlayOpacity(for: .platinum, level: 1) == 0)
        #expect(MarkdownHeadingDisplay.overlayOpacity(for: .platinum, level: 2) == 0)
        #expect(MarkdownHeadingDisplay.overlayOpacity(for: .platinum, level: 3) == 0)
        #expect(MarkdownHeadingDisplay.overlayOpacity(for: .platinumDark, level: 1) == 0.34)
        #expect(MarkdownHeadingDisplay.overlayOpacity(for: .platinumDark, level: 2) == 0.22)
        #expect(MarkdownHeadingDisplay.overlayOpacity(for: .platinumDark, level: 3) == 0.16)
        #expect(MarkdownHeadingDisplay.nsShadow(for: .platinum, level: 1) == nil)
        #expect(MarkdownHeadingDisplay.nsShadow(for: .platinum, level: 2) == nil)
        #expect(MarkdownHeadingDisplay.nsShadow(for: .platinum, level: 3) == nil)
        #expect(MarkdownHeadingDisplay.nsShadow(for: .platinum, level: 4) == nil)
        #expect(MarkdownHeadingDisplay.nsShadow(for: .platinumDark, level: 1) != nil)
        #expect(MarkdownHeadingDisplay.nsShadow(for: .platinumDark, level: 2) != nil)
        #expect(MarkdownHeadingDisplay.nsShadow(for: .platinumDark, level: 3) != nil)
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
        #expect(MarkdownHeadingDisplay.previewShadowOpacity(for: .platinum, level: 1) == 0)
        #expect(MarkdownHeadingDisplay.previewShadowOpacity(for: .platinum, level: 2) == 0)
        #expect(MarkdownHeadingDisplay.previewShadowOpacity(for: .platinum, level: 3) == 0)
        #expect(MarkdownHeadingDisplay.previewOverlayOpacity(for: .platinum, level: 1) == 0)
        #expect(MarkdownHeadingDisplay.previewOverlayOpacity(for: .platinum, level: 2) == 0)
        #expect(MarkdownHeadingDisplay.previewOverlayOpacity(for: .platinum, level: 3) == 0)
        #expect(MarkdownHeadingDisplay.previewOverlayOpacity(for: .platinumDark, level: 1) == 0.2)
        #expect(MarkdownHeadingDisplay.previewOverlayOpacity(for: .platinumDark, level: 2) == 0.12)
        #expect(MarkdownHeadingDisplay.previewOverlayOpacity(for: .platinumDark, level: 3) == 0.09)
    }

    @Test("Landing text glow is dark-mode only")
    func landingTextGlowIsDarkModeOnly() throws {
        let landingView = try loadTextFile("Epistemos/Views/Landing/LandingView.swift")
        let liquidGreeting = try loadTextFile("Epistemos/Views/Landing/LiquidGreeting.swift")

        #expect(landingView.contains(".shadow(color: theme.isDark ? theme.fontAccent.opacity(0.12) : .clear, radius: 8)"))
        #expect(liquidGreeting.contains(".shadow("))
        #expect(liquidGreeting.contains("color: compact ? .clear : (theme.isDark ? theme.fontAccent.opacity(0.12) : .clear)"))
        #expect(liquidGreeting.contains("radius: compact ? 0 : 8"))
    }

    @Test("Regular display mode keeps ripple-capable surfaces but drops retro display typography")
    func regularDisplayModePolicy() {
        #expect(AppDisplayMode.opulent.usesDisplayFont)
        #expect(!AppDisplayMode.opulent.reducesASCIIAnimations)
        #expect(!AppDisplayMode.regular.usesDisplayFont)
        #expect(AppDisplayMode.regular.reducesASCIIAnimations)
    }

    @Test("Regular display mode uses the macOS UI font family")
    func regularDisplayModeUsesMacOSUIFontFamily() {
        let font = AppDisplayTypography.regularUIFont(size: 13)

        #expect(AppDisplayTypography.isRegularUIFont(font))
        #expect(!AppDisplayTypography.isDisplayFont(font))
        #expect(AppDisplayTypography.displayFontName == "RetroGaming")
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

    @Test("Composer height scaling respects larger landing search typography")
    func composerHeightScalingRespectsLargerLandingSearchTypography() {
        let standardMin = ChatComposerInputMetrics.minHeight(for: ChatComposerInputMetrics.fontSize)
        let landingMin = ChatComposerInputMetrics.minHeight(for: LandingSearchLayout.inputFontSize)
        let landingMax = ChatComposerInputMetrics.maxHeight(for: LandingSearchLayout.inputFontSize)

        #expect(landingMin > standardMin)
        #expect(LandingSearchLayout.inputMinHeight == landingMin)
        #expect(
            ChatComposerInputMetrics.clampedHeight(for: 0, fontSize: LandingSearchLayout.inputFontSize)
                == landingMin
        )
        #expect(
            ChatComposerInputMetrics.clampedHeight(
                for: landingMax + 40,
                fontSize: LandingSearchLayout.inputFontSize
            ) == landingMax
        )
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

    @Test("Landing search composer stays glass-only without siri glow")
    func landingSearchComposerStaysGlassOnly() throws {
        let landingView = try loadTextFile("Epistemos/Views/Landing/LandingView.swift")

        #expect(landingView.contains("AssistantSendButton("))
        #expect(landingView.contains("NativeToolbarButtonStyle()"))
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

    @Test("Main chat transcript uses calmer bubble and markdown spacing")
    func mainChatTranscriptUsesCalmerBubbleAndMarkdownSpacing() throws {
        let chatView = try loadTextFile("Epistemos/Views/Chat/ChatView.swift")
        let messageBubble = try loadTextFile("Epistemos/Views/Chat/MessageBubble.swift")
        let markdownView = try loadTextFile("Epistemos/Views/Chat/TaggedMarkdownTextView.swift")

        #expect(chatView.contains("static let transcriptSpacing: CGFloat = 28"))
        #expect(messageBubble.contains(".padding(.horizontal, 18)"))
        #expect(messageBubble.contains(".padding(.vertical, 14)"))
        #expect(markdownView.contains("private static let bodyLineSpacing: CGFloat = 5"))
        #expect(markdownView.contains("private static let listMarkerWidth: CGFloat = 11"))
    }

    @Test("Chat streaming stays plain and no longer routes through a separate thinking accordion")
    func chatStreamingStaysPlainWithoutThinkingAccordion() throws {
        let chatView = try loadTextFile("Epistemos/Views/Chat/ChatView.swift")
        let messageBubble = try loadTextFile("Epistemos/Views/Chat/MessageBubble.swift")

        #expect(chatView.contains("TaggedMarkdownTextView("))
        #expect(chatView.contains("UserFacingModelOutput.streamingVisibleText"))
        #expect(!chatView.contains("ThinkingAccordion"))
        #expect(!chatView.contains("chat.isReasoning"))
        #expect(!messageBubble.contains("ThinkingAccordion"))
        #expect(!messageBubble.contains("reasoningText"))
    }

    @Test("Landing and active chat use the shared local model menu surface")
    func landingAndActiveChatUseSharedLocalModelMenu() throws {
        let landingView = try loadTextFile("Epistemos/Views/Landing/LandingView.swift")
        let rootView = try loadTextFile("Epistemos/App/RootView.swift")
        let miniChat = try loadTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")
        let noteWorkspace = try loadTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")

        #expect(landingView.contains("landingInferenceControl"))
        #expect(landingView.contains("LocalModelToolbarMenu("))
        #expect(rootView.contains("LocalModelToolbarMenu("))
        #expect(rootView.contains("variant: .toolbar"))
        #expect(miniChat.contains("LocalModelToolbarMenu("))
        #expect(miniChat.contains("variant: .toolbar"))
        #expect(noteWorkspace.contains("LocalModelToolbarMenu(variant: .toolbar)"))
        #expect(rootView.contains("struct LocalModelToolbarMenu: View"))
        #expect(rootView.contains("ASCIIRippleText("))
        #expect(rootView.contains("AnchoredPopoverButton("))
        #expect(rootView.contains("inference.setPreferredChatModelSelection(.localMLX(model.id))"))
        #expect(rootView.contains("Button(\"Open Inference Settings\")"))
        #expect(miniChat.contains("threadState.ensureMiniChatSession(id: chatID)"))
        #expect(miniChat.contains("threadState.upsertMiniChatSession("))
        #expect(!noteWorkspace.contains("Label(\"Local Only\""))
        #expect(!rootView.contains("Picker(\"Routing\", selection: routingBinding)"))
        #expect(!rootView.contains("InferenceControlPopoverButton"))
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

    @Test("Chat surfaces no longer expose a separate research entry point")
    func chatSurfacesDoNotExposeResearchEntryPoint() throws {
        let chatInputBar = try loadTextFile("Epistemos/Views/Chat/ChatInputBar.swift")
        let landingView = try loadTextFile("Epistemos/Views/Landing/LandingView.swift")
        let rootView = try loadTextFile("Epistemos/App/RootView.swift")
        let miniChatView = try loadTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")

        #expect(!chatInputBar.contains("ResearchComposerButton("))
        #expect(!landingView.contains("ResearchComposerButton("))
        #expect(!rootView.contains("title: \"Research\""))
        #expect(!rootView.contains("ResearchComplexityGate.toggledComposerDraft"))
        #expect(miniChatView.contains("operatingMode: operatingModeBinding"))
        #expect(!miniChatView.contains("composerText: $text"))
        #expect(!chatInputBar.contains("ResearchModeControl"))
        #expect(!landingView.contains("ResearchModeControl"))
        #expect(!miniChatView.contains("ResearchModeControl"))
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
        let coordinator = try loadTextFile("Epistemos/App/ChatCoordinator.swift")
        let chatState = try loadTextFile("Epistemos/State/ChatState.swift")
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

        #expect(!coordinator.contains("case .enriched"))
        #expect(!coordinator.contains("case .soarEvent"))
        #expect(!coordinator.contains("persistEnrichment("))
        #expect(!coordinator.contains("persistableDualMessage"))

        #expect(!chatState.contains("EnrichmentController.parseConceptsTag"))
        #expect(!chatState.contains("enrichMessage("))
        #expect(!chatState.contains("enrichLastMessage("))

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

    @Test("Chat chrome no longer carries enrichment-era cards or confidence overlays")
    func chatChromeDropsEnrichmentPanels() throws {
        let bubble = try loadTextFile("Epistemos/Views/Chat/MessageBubble.swift")
        let project = try loadTextFile("Epistemos.xcodeproj/project.pbxproj")

        #expect(!bubble.contains("laymanSummarySections"))
        #expect(!bubble.contains("EpistemicLensPanel"))
        #expect(!bubble.contains("ReflectionCard"))
        #expect(!bubble.contains("TruthAssessmentCard"))
        #expect(!bubble.contains("ConsensusReportCard"))
        #expect(!project.contains("ConfidenceOverlay.swift"))
        #expect(!project.contains("LearningIntents.swift"))
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

    @Test("Main chat sources use the popover panel presentation")
    func mainChatSourcesUsePopoverPanel() throws {
        let bubble = try loadTextFile("Epistemos/Views/Chat/MessageBubble.swift")
        let chrome = try loadTextFile("Epistemos/Theme/GlassModifiers.swift")

        #expect(bubble.contains("style: .popoverPanel"))
        #expect(chrome.contains("enum AssistantSourcesPresentationStyle"))
        #expect(chrome.contains("case popoverPanel"))
        #expect(chrome.contains("Text(\"Sources\")"))
        #expect(chrome.contains("AssistantSourcesListPanel"))
    }

    @Test("Mini chat uses the shared attachment resolver and carries explicit context attachments")
    func miniChatUsesSharedAttachmentResolverAndCarriesContextAttachments() throws {
        let miniChat = try loadTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")
        let threadState = try loadTextFile("Epistemos/State/ThreadState.swift")

        #expect(miniChat.contains("ChatCoordinator.resolveAttachedContext("))
        #expect(miniChat.contains("loadedNoteTitles: notesContext.loadedNoteTitles"))
        #expect(miniChat.contains("contextAttachments: attachments"))
        #expect(threadState.contains("func addMiniChatContextAttachment(_ attachment: ContextAttachment, chatID: String)"))
    }

    @Test("@ mentions search notes and chats through one shared picker")
    func mentionsSearchNotesAndChatsThroughSharedPicker() throws {
        let dropdown = try loadTextFile("Epistemos/Views/Chat/NotesMentionDropdown.swift")
        let mainChat = try loadTextFile("Epistemos/Views/Chat/ChatInputBar.swift")
        let miniChat = try loadTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")
        let coordinator = try loadTextFile("Epistemos/App/ChatCoordinator.swift")

        #expect(dropdown.contains("case allNotes"))
        #expect(dropdown.contains("case chat"))
        #expect(dropdown.contains("Text(\"All Notes\")"))
        #expect(dropdown.contains("sectionHeader(\"Chats\")"))
        #expect(mainChat.contains("ChatCoordinator.searchReferenceResults("))
        #expect(miniChat.contains("ChatCoordinator.searchReferenceResults("))
        #expect(coordinator.contains("static func searchReferenceResults("))
    }

    @Test("Note chat keeps the current note attachment implicit instead of rendering a redundant locked chip")
    func noteChatKeepsCurrentNoteAttachmentImplicit() throws {
        let noteWorkspace = try loadTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")

        #expect(noteWorkspace.contains("private var noteChatContextAttachment: ContextAttachment?"))
        #expect(noteWorkspace.contains("MiniChatWindowController.shared.openNewChat(attaching: noteChatContextAttachment)"))
        #expect(!noteWorkspace.contains("noteChatAttachmentChip("))
        #expect(!noteWorkspace.contains("if let attachment = noteChatContextAttachment"))
    }

    @MainActor
    @Test("UIState restores saved display mode from defaults")
    func uiStateRestoresDisplayMode() {
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: AppDisplayMode.defaultsKey)
        defer {
            if let previous {
                defaults.set(previous, forKey: AppDisplayMode.defaultsKey)
            } else {
                defaults.removeObject(forKey: AppDisplayMode.defaultsKey)
            }
        }

        defaults.set(AppDisplayMode.regular.rawValue, forKey: AppDisplayMode.defaultsKey)

        let uiState = UIState()
        #expect(uiState.displayMode == .regular)
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
            atPath: repoRootURL().appendingPathComponent("Epistemos/AppIcon.icon/Assets").path
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
        #expect(plist["CFBundleIdentifier"] as? String == "com.epistemos.app")
        #expect(plist["CFBundleIconName"] as? String == "AppIcon")
        #expect(plist["CFBundleIconFile"] == nil)
    }

    @Test("Project uses AppIcon.icon as the primary app icon source")
    func projectUsesIconComposerFile() throws {
        let pbxproj = try loadProjectFile()
        #expect(pbxproj.contains("AppIcon.icon */ = {isa = PBXFileReference; lastKnownFileType = wrapper.icon;"))
        #expect(pbxproj.contains("path = AppIcon.icon;"))
        #expect(pbxproj.contains("ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;"))
    }

    @Test("Assets catalog no longer keeps the stale AppIcon appiconset payload")
    func assetsCatalogDropsStaleAppIconSet() {
        let staleAppIconSet = repoRootURL().appendingPathComponent("Epistemos/Assets.xcassets/AppIcon.appiconset")
        #expect(!FileManager.default.fileExists(atPath: staleAppIconSet.path))
    }

    @Test("Project retains Rust bridge header wiring")
    func projectRetainsRustBridgeWiring() throws {
        let pbxproj = try loadProjectFile()
        #expect(pbxproj.contains("SWIFT_OBJC_BRIDGING_HEADER = \"Epistemos-Bridging-Header.h\";"))
        #expect(pbxproj.contains("SWIFT_INCLUDE_PATHS = \"$(PROJECT_DIR)/build-rust/swift-bindings/omega_mcpFFI"))
        #expect(pbxproj.contains("OTHER_LDFLAGS = \"-L$(PROJECT_DIR)/build-rust"))
        #expect(pbxproj.contains("\"@executable_path\","))
        #expect(pbxproj.contains("\"@loader_path/../Frameworks\","))
        #expect(!pbxproj.contains(#"""
LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
					"$(PROJECT_DIR)/build-rust",
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
        let miniChat = try loadTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")
        let landingView = try loadTextFile("Epistemos/Views/Landing/LandingView.swift")

        #expect(!rootView.contains("case .library"))
        #expect(!rootView.contains("case .settings"))
        #expect(!rootView.contains("Picker(\"\", selection: $uiBindable.homeTab)"))
        #expect(appCommands.contains("UtilityWindowManager.shared.show(.settings)"))
        #expect(!appCommands.contains(".keyboardShortcut(\",\", modifiers: .command)"))
        #expect(miniChat.contains("showRecentChats"))
        #expect(landingView.contains("label: \"Settings\""))
        #expect(landingView.contains("key: \"S\""))
    }

    @Test("landing notes hint reveals the new note shortcut on hover")
    func landingNotesHintRevealsNewNoteShortcut() throws {
        let landingView = try loadTextFile("Epistemos/Views/Landing/LandingView.swift")

        #expect(landingView.contains("HoverRevealCommandHint("))
        #expect(landingView.contains("primary: .init(modIcon: \"command\", key: \"2\", label: \"Notes\")"))
        #expect(landingView.contains("secondary: .init(modIcon: \"command\", key: \"N\", label: \"New Note\")"))
        #expect(!landingView.contains("CommandHint(modIcon: \"command\", key: \"N\", label: \"New Note\""))
    }

    @Test("liquid greeting task identity tracks playlist changes without restarting on typed character updates")
    func liquidGreetingTaskIdentityTracksPlaylistChanges() throws {
        let liquidGreeting = try loadTextFile("Epistemos/Views/Landing/LiquidGreeting.swift")

        #expect(liquidGreeting.contains("\"\\(shouldAnimate)_\\(retractNow)_\\(ui.landingGreetingPlaylistSignature)\""))
        #expect(!liquidGreeting.contains("\"\\(shouldAnimate)_\\(retractNow)_\\(displayText)\""))
    }

    @Test("landing greeting keeps static welcome back fallback and drops liquid controls")
    func liquidGreetingSupportsStaticWelcomeBackMode() throws {
        let liquidGreeting = try loadTextFile("Epistemos/Views/Landing/LiquidGreeting.swift")
        let settingsView = try loadTextFile("Epistemos/Views/Settings/SettingsView.swift")

        #expect(liquidGreeting.contains("text: shouldAnimate ? displayText : Self.restingGreeting"))
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
        #expect(!liquidGreeting.contains("cursorVisible"))
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
        #expect(liquidGreeting.contains("LiquidGreetingTiming.untypingDelay(forStep: index)"))
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

    @Test("settings view exposes a native sidebar toggle in the toolbar")
    func settingsViewExposesSidebarToggle() throws {
        let settingsView = try loadTextFile("Epistemos/Views/Settings/SettingsView.swift")

        #expect(settingsView.contains("ToolbarItem(placement: .navigation)"))
        #expect(settingsView.contains("Image(systemName: \"sidebar.left\")"))
        #expect(settingsView.contains("toggleSidebar()"))
    }

    @Test("landing view fetches chat history only on demand for daily brief generation")
    func landingViewLazilyFetchesDailyBriefChats() throws {
        let landingView = try loadTextFile("Epistemos/Views/Landing/LandingView.swift")

        #expect(landingView.contains("@Environment(\\.modelContext) private var modelContext"))
        #expect(!landingView.contains("@Query(sort: \\\\.updatedAt, order: .reverse)\n    private var allChats: [SDChat]"))
        #expect(landingView.contains("private func recentChats(limit: Int) -> [SDChat]"))
        #expect(landingView.contains("DailyBriefState.buildBriefPrompt(pages: Array(allPages), chats: recentChats(limit: 12))"))
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

    @Test("bootstrap owns a shared local MLX runtime and passes it into triage")
    func bootstrapWiresSharedLocalMLXRouting() throws {
        let bootstrap = try loadTextFile("Epistemos/App/AppBootstrap.swift")

        #expect(bootstrap.contains("let localInferenceService: MLXInferenceService"))
        #expect(bootstrap.contains("let localMLXClient: LocalMLXClient"))
        #expect(bootstrap.contains("let localLLMClient: any LocalConfigurableLLMClient"))
        #expect(bootstrap.contains("let localGGUFRuntime = LocalGGUFInProcessRuntime()"))
        #expect(bootstrap.contains("let localLLMClient = LocalBackendLLMClient("))
        #expect(bootstrap.contains("let localInferenceService = MLXInferenceService(snapshot: inference.hardwareCapabilitySnapshot)"))
        #expect(bootstrap.contains("localLLMService: localLLMClient"))
    }

    @Test("bootstrap and environment no longer inject the removed local voice stack")
    func bootstrapDropsLocalVoiceManager() throws {
        let bootstrap = try loadTextFile("Epistemos/App/AppBootstrap.swift")
        let environment = try loadTextFile("Epistemos/App/AppEnvironment.swift")

        #expect(!bootstrap.contains("let localVoiceManager: LocalVoiceManager"))
        #expect(!bootstrap.contains("self.localVoiceManager = LocalVoiceManager("))
        #expect(!environment.contains(".environment(bootstrap.localVoiceManager)"))
    }

    @Test("assistant chat surfaces no longer expose read aloud controls")
    func assistantSurfacesDropReadAloud() throws {
        let messageBubble = try loadTextFile("Epistemos/Views/Chat/MessageBubble.swift")
        let noteSidebar = try loadTextFile("Epistemos/Views/Notes/NoteChatSidebar.swift")

        #expect(!messageBubble.contains("@Environment(LocalVoiceManager.self) private var localVoice"))
        #expect(!messageBubble.contains("await localVoice.toggleSpeak("))
        #expect(!noteSidebar.contains("@Environment(LocalVoiceManager.self) private var localVoice"))
        #expect(!noteSidebar.contains("await localVoice.toggleSpeak("))
    }

    @Test("inference settings focus on qwen local routing without voice residue")
    func inferenceSettingsRefocusOnQwenRouting() throws {
        let settings = try loadTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let inferenceState = try loadTextFile("Epistemos/State/InferenceState.swift")
        let environment = try loadTextFile("Epistemos/App/AppEnvironment.swift")

        #expect(settings.contains("Routing Mode"))
        #expect(settings.contains("Active Local Model"))
        #expect(!settings.contains("Show Thinking Panel"))
        #expect(!settings.contains("Automatic Model Selection"))
        #expect(!settings.contains("Local Response Mode"))
        #expect(inferenceState.contains("Qwen 3.5"))
        #expect(inferenceState.contains("Local Only"))
        #expect(!environment.contains("localSidecarState"))
        #expect(!inferenceState.contains("Cloud Only"))
        #expect(!settings.contains("Preferred Local Voice"))
        #expect(!settings.contains("Voice Playback"))
        #expect(!settings.contains("Auto-download core local pack"))
        #expect(!settings.contains("Chatterbox"))
        #expect(!settings.contains("Gemma"))
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

    @Test("utility panels keep compact toolbar styles")
    func utilityPanelsKeepCompactToolbarStyles() throws {
        let utilityWindowManager = try loadTextFile("Epistemos/App/UtilityWindowManager.swift")
        let miniChatWindowController = try loadTextFile("Epistemos/Views/MiniChat/MiniChatWindowController.swift")

        #expect(utilityWindowManager.contains("panel.toolbarStyle = .unifiedCompact"))
        #expect(miniChatWindowController.contains("window.toolbarStyle = .unifiedCompact"))
        #expect(!miniChatWindowController.contains("window.toolbarStyle = .unified\n"))
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

        #expect(claude.contains("cloud API orchestration"))
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

    @Test("bundle plist drops unused speech and microphone permission prompts")
    func bundlePlistDropsUnusedSpeechAndMicrophonePrompts() throws {
        let plist = try loadBundlePlist()

        #expect(plist["NSSpeechRecognitionUsageDescription"] == nil)
        #expect(plist["NSMicrophoneUsageDescription"] == nil)
    }

    @Test("mini chat quick actions no longer use hidden system prompts")
    func miniChatQuickActionsUsePlainUserPrompts() throws {
        let source = try loadTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")

        #expect(source.contains("prompt: prompt, systemPrompt: nil"))
        #expect(!source.contains("let systemPrompt: String"))
        #expect(!source.contains("## Vault Index"))
    }

    @Test("note operation streaming pushes note instructions through the user prompt only")
    func noteOperationStreamingUsesUserPromptOnly() throws {
        let source = try loadTextFile("Epistemos/State/NoteChatState.swift")

        #expect(source.contains("Request: \\(trimmed)"))
        #expect(source.contains("systemPrompt: nil"))
        #expect(!source.contains("let fullSystemPrompt"))
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
        let dialogue = try loadTextFile("Epistemos/State/DialogueChatState.swift")
        let hologramInspector = try loadTextFile("Epistemos/Views/Graph/HologramNodeInspector.swift")
        let vaultOrganizer = try loadTextFile("Epistemos/Views/Notes/VaultOrganizerView.swift")
        let triage = try loadTextFile("Epistemos/Engine/TriageService.swift")

        #expect(!analysisIntents.contains("research assistant"))
        #expect(!noteActions.contains("research assistant"))
        #expect(!noteWorkspace.contains("systemPrompt: mapping.systemPrompt"))
        #expect(!noteWorkspace.contains("You are a writing assistant."))
        #expect(!nodeInspector.contains("You are a note analyst"))
        #expect(!dialogue.contains("You are \"\\(activeNodeLabel)\", a character in a knowledge graph."))
        #expect(!dialogue.contains("You speak in character."))
        #expect(!dialogue.contains("messages.append(Message(role: .assistant, text: profile.openingLine))"))
        #expect(!hologramInspector.contains("p.archetype.title"))
        #expect(!hologramInspector.contains("p.care.mood.displayName"))
        #expect(!hologramInspector.contains("p.portrait.symbol"))
        #expect(!hologramInspector.contains("statMeter(label: \"Focus\""))
        #expect(!vaultOrganizer.contains("You are a note organization assistant."))
        #expect(!triage.contains("let simpleSystem ="))
    }

    @Test("mini chat only resolves vault context for explicit note mentions")
    func miniChatUsesExplicitNoteMentionsOnly() throws {
        let source = try loadTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")

        #expect(source.contains("if ChatCoordinator.queryContainsExplicitNoteContext(trimmed)"))
        #expect(source.contains("context: nil"))
        #expect(source.contains("loadedNoteIds: []"))
        #expect(source.contains("loadedNoteTitles: []"))
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

    private func repoRootURL() -> URL {
        let testsFileURL = URL(fileURLWithPath: #filePath)
        return testsFileURL.deletingLastPathComponent().deletingLastPathComponent()
    }
}
