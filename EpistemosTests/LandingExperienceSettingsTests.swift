import Foundation
import Testing
@testable import Epistemos

@Suite("Landing Experience Settings")
struct LandingExperienceSettingsTests {
    @Test("greeting resolver falls back to defaults when custom greetings are unavailable")
    func greetingResolverFallsBackToDefaults() {
        let defaultsOnly = LandingGreetingResolver.resolve(
            sourceMode: .customOnly,
            customGreetings: []
        )

        #expect(defaultsOnly == LandingGreetingResolver.defaultPlaylist)
    }

    @Test("greeting resolver respects source mode order enabled state and duration bounds")
    func greetingResolverRespectsSourceModeAndSanitizes() {
        let customGreetings = [
            LandingGreetingEntry(
                id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
                text: "First custom",
                durationSeconds: 0.1,
                isEnabled: true
            ),
            LandingGreetingEntry(
                id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
                text: "  ",
                durationSeconds: 4,
                isEnabled: true
            ),
            LandingGreetingEntry(
                id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
                text: "Muted custom",
                durationSeconds: 3,
                isEnabled: false
            ),
            LandingGreetingEntry(
                id: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!,
                text: "Second custom",
                durationSeconds: 99,
                isEnabled: true
            ),
        ]

        let customOnly = LandingGreetingResolver.resolve(
            sourceMode: .customOnly,
            customGreetings: customGreetings
        )
        let mixed = LandingGreetingResolver.resolve(
            sourceMode: .mixed,
            customGreetings: customGreetings
        )

        #expect(customOnly.map(\.text) == ["First custom", "Second custom"])
        #expect(customOnly[0].durationSeconds == LandingGreetingEntry.minimumDurationSeconds)
        #expect(customOnly[1].durationSeconds == LandingGreetingEntry.maximumDurationSeconds)
        #expect(
            Array(mixed.prefix(LandingGreetingResolver.defaultPlaylist.count))
                == LandingGreetingResolver.defaultPlaylist
        )
        #expect(Array(mixed.suffix(2)).map(\.text) == ["First custom", "Second custom"])
    }

    @MainActor
    @Test("UIState removes legacy landing cursor defaults on init")
    func uiStateRemovesLegacyLandingCursorDefaultsOnInit() {
        let defaults = UserDefaults.standard
        let keys = [
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
            defaults.set("legacy", forKey: key)
        }

        _ = UIState()

        for key in keys {
            #expect(defaults.object(forKey: key) == nil)
        }
    }

    @MainActor
    @Test("UIState persists landing greeting library source mode and typewriter toggle")
    func uiStatePersistsGreetingLibrarySourceModeAndTypewriterToggle() {
        let defaults = UserDefaults.standard
        let keys = [
            LandingGreetingLibraryPolicy.customGreetingsDefaultsKey,
            LandingGreetingLibraryPolicy.sourceModeDefaultsKey,
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
            defaults.removeObject(forKey: key)
        }

        let uiState = UIState()
        uiState.landingGreetingSourceMode = .mixed
        uiState.landingGreetingTypewriterEnabled = false
        uiState.landingCustomGreetings = [
            LandingGreetingEntry(
                id: UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!,
                text: "Archive complete",
                durationSeconds: 2.4,
                isEnabled: true
            )
        ]

        let reloadedState = UIState()
        #expect(reloadedState.landingGreetingSourceMode == .mixed)
        #expect(reloadedState.landingGreetingTypewriterEnabled == false)
        #expect(reloadedState.landingCustomGreetings.count == 1)
        #expect(reloadedState.landingCustomGreetings[0].text == "Archive complete")
        #expect(reloadedState.landingCustomGreetings[0].durationSeconds == 2.4)
    }

    @MainActor
    @Test("UIState migrates the legacy combined greeting toggle into the typewriter toggle")
    func uiStateMigratesLegacyCombinedGreetingToggle() {
        let defaults = UserDefaults.standard
        let keys = [
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

        defaults.set(false, forKey: LandingGreetingAnimationPolicy.enabledDefaultsKey)
        defaults.removeObject(forKey: LandingGreetingAnimationPolicy.typewriterEnabledDefaultsKey)

        let disabledState = UIState()
        #expect(disabledState.landingGreetingTypewriterEnabled == false)

        defaults.set(true, forKey: LandingGreetingAnimationPolicy.enabledDefaultsKey)
        defaults.removeObject(forKey: LandingGreetingAnimationPolicy.typewriterEnabledDefaultsKey)

        let enabledState = UIState()
        #expect(enabledState.landingGreetingTypewriterEnabled)
    }
}
