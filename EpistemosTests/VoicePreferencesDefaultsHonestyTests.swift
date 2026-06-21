import Testing
import Foundation

// SS-QC / P7.7 voice (owner 2026-06-20; RESEARCH_VOICE_2026_06_18 §3 "Settings auto-mode +
// granular toggles"): the voice auto-mode contract requires every ACTING surface — anything
// that speaks aloud or starts audio capture — to default to MANUAL: "each off by default;
// honest, never silent." A future edit that flipped one of these defaults to `.auto` would make
// the app speak or record without an explicit opt-in — a privacy/honesty regression with no
// current guard. Pin the conservative defaults so any flip fails HERE first and forces a
// deliberate review.
//
// Source-guard (not a runtime read): `VoicePreferences.shared` is a @MainActor @Observable
// singleton that seeds `UserDefaults.standard` in its private init, so a runtime read returns
// whatever the dev machine already persisted — not the default. The getter fallbacks
// (`decode(forKey:default:)`) ARE the runtime source of truth for every read, so pinning them +
// the init seed is the robust, checkout-independent guard.
@Suite("Voice preferences — conservative 'never silent' defaults")
struct VoicePreferencesDefaultsHonestyTests {

    /// Surfaces that SPEAK ALOUD or START CAPTURE. Each must default to Manual so the app never
    /// emits audio / records without the user opting in.
    private static let actingSurfaces = [
        "agentResponseTTS",      // speaks agent responses aloud
        "noteReadAloud",         // speaks note bodies aloud
        "brainDumpHotkeyDictate",// starts a dictation (mic) session
        "quickCaptureReadBack",  // speaks each completed sentence aloud
    ]

    @Test("every acting voice surface's getter defaults to Manual (never speaks/records without opt-in)")
    func actingSurfaceGettersDefaultManual() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Engine/VoicePreferences.swift")
        for key in Self.actingSurfaces {
            let pattern = "decode(forKey: VoicePreferenceKeys.\(key), default: .manual)"
            #expect(
                src.contains(pattern),
                "VoicePreferences.\(key) getter must fall back to .manual (never silent): missing \(pattern)")
        }
    }

    @Test("the init seeds those acting surfaces as Manual too (first run is silent)")
    func initSeedsActingSurfacesManual() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Engine/VoicePreferences.swift")
        for key in Self.actingSurfaces {
            let pattern = "d.set(VoiceDecisionMode.manual.rawValue, forKey: VoicePreferenceKeys.\(key))"
            #expect(
                src.contains(pattern),
                "VoicePreferences.init must seed \(key) as .manual so a fresh install never auto-speaks/records")
        }
    }

    @Test("the two non-acting defaults are documented-honest auto (safer/neutral, not silent capture)")
    func nonActingDefaultsAreHonestAuto() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Engine/VoicePreferences.swift")
        // dictationAutoStop=.auto STOPS recording on silence (a safety convenience, not capture);
        // perModelVoicePersona=.auto only chooses WHICH voice, never whether to speak. Honest auto.
        #expect(src.contains("decode(forKey: VoicePreferenceKeys.dictationAutoStop, default: .auto)"))
        #expect(src.contains("decode(forKey: VoicePreferenceKeys.perModelVoicePersona, default: .auto)"))
    }
}
