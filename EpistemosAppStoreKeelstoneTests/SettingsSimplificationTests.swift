import Foundation
import Testing
@testable import Epistemos

@Suite("Free V1 Settings Simplification", .serialized)
@MainActor
struct SettingsSimplificationTests {
    private let graphPreferenceKeys = [
        "epistemos.graph.performanceMode",
        "epistemos.graph.maxFPS",
        "epistemos.graph.forceMaximumFPS",
    ]
    private let retiredCustomThemePreferenceKeys = [
        "epistemos.theme.pair",
        "epistemos.theme.customExperimentalEnabled",
        "epistemos.customTheme.background",
        "epistemos.customTheme.light.accent",
        "epistemos.customTheme.dark.noteSurface",
        "epistemos.typography.heading.h1.fontName",
        "epistemos.typography.heading.h2.scale",
    ]

    @Test("Settings exposes only current Free V1 user choices")
    func settingsExposeOnlyCurrentFreeV1Choices() {
        let expected: Set<SettingsView.SettingsSection> = [
            .general,
            .ambientFrequencies,
            .voice,
            .landing,
            .appearance,
            .vault,
            .privacy,
        ]

        #expect(Set(SettingsView.SettingsSection.visibleSections) == expected)
        for retired in [
            SettingsView.SettingsSection.skills,
            .cloudModels,
            .provenance,
            .substrateHealth,
        ] {
            #expect(SettingsView.SettingsSection.safeDetailSelection(for: retired) == .general)
        }
    }

    @Test("the user power policy has no Eco tier")
    func powerPolicyHasNoEcoTier() {
        #expect(PowerMode.allCases == [.full, .lowPower])
        #expect(!PowerMode.full.disablesBackground)
        #expect(PowerMode.lowPower.disablesBackground)
        #expect(PowerMode.lowPower.throttlesRendering)
    }

    @Test("only the three preset theme pairs remain and a retired Custom selection migrates")
    func customThemeCapabilityMigratesToAPreset() {
        #expect(ThemePair.allCases == [.platinumViolet, .classic, .ember])

        let defaults = FoundationSafety.runtimeUserDefaults
        let previousValues = Dictionary(
            uniqueKeysWithValues: retiredCustomThemePreferenceKeys.map { ($0, defaults.object(forKey: $0)) }
        )
        defer {
            for key in retiredCustomThemePreferenceKeys {
                if let value = previousValues[key] {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }

        defaults.set("custom", forKey: UIState.themePairDefaultsKey)
        defaults.set(true, forKey: "epistemos.theme.customExperimentalEnabled")
        defaults.set(0x123456, forKey: "epistemos.customTheme.background")
        defaults.set(0x654321, forKey: "epistemos.customTheme.light.accent")
        defaults.set(0x224466, forKey: "epistemos.customTheme.dark.noteSurface")
        defaults.set("Charybdis", forKey: "epistemos.typography.heading.h1.fontName")
        defaults.set(1.2, forKey: "epistemos.typography.heading.h2.scale")

        let state = UIState()

        #expect(state.activePair == .platinumViolet)
        #expect(defaults.string(forKey: UIState.themePairDefaultsKey) == ThemePair.platinumViolet.rawValue)
        for key in retiredCustomThemePreferenceKeys.dropFirst() {
            #expect(defaults.object(forKey: key) == nil)
        }
    }

    @Test("retired graph throttling preferences cannot cap a new session")
    func retiredGraphThrottlingPreferencesCannotCapANewSession() {
        let defaults = FoundationSafety.runtimeUserDefaults
        let previousValues = Dictionary(
            uniqueKeysWithValues: graphPreferenceKeys.map { ($0, defaults.object(forKey: $0)) }
        )
        defer {
            for key in graphPreferenceKeys {
                if let value = previousValues[key] {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }

        defaults.set(false, forKey: "epistemos.graph.performanceMode")
        defaults.set(30, forKey: "epistemos.graph.maxFPS")
        defaults.set(false, forKey: "epistemos.graph.forceMaximumFPS")

        let state = GraphState()

        #expect(state.performanceModeEnabled)
        #expect(state.qualityLevel == 2)
        #expect(state.graphMaxFPS == 0)
        #expect(state.graphForceMaximumFPS)
    }
}
