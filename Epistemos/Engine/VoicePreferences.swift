import Foundation
import OSLog
import SwiftUI

// MARK: - VoicePreferences (W11.4 + W15 — Auto/Manual TTS+STT contract)
//
// Single source-of-truth for the user's voice preferences across the
// app. Honours the W11.4 Auto/Manual Mode contract: every voice
// surface has BOTH an Auto mode (the app decides + acts) AND a
// Manual mode (the app proposes + waits for the user to invoke).
//
// Voice surfaces governed by this store:
//   1. Read-aloud agent responses (auto-speak when a streamed
//      response completes? or always require a tap?)
//   2. Read-aloud notes (long-form TTS for note bodies)
//   3. Auto-stop dictation on silence (auto-detect "I'm done
//      speaking" pause vs require explicit Stop tap)
//   4. Brain-dump dictation auto-launch on hotkey
//   5. Retired per-model voice routing preference kept for defaults
//      migration only; shipped TTS is Kokoro-only and honestly gated.
//
// Persistence: UserDefaults under the
// `com.epistemos.voice.*` namespace so other parts of the app can
// read directly via the centralised `VoicePreferenceKeys` constants.

private let voiceLog = Logger(
    subsystem: "com.epistemos",
    category: "VoicePreferences"
)

// MARK: - Decision modes

nonisolated public enum VoiceDecisionMode: String, Sendable, Codable, CaseIterable, Identifiable {
    /// App decides + acts (with a "Why?" rationale shown briefly).
    case auto
    /// App proposes; user has to invoke explicitly.
    case manual

    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .auto:   return "Auto"
        case .manual: return "Manual"
        }
    }
}

nonisolated public enum VoiceEffect: String, Sendable, Codable, CaseIterable, Identifiable {
    case clean
    case pixelArt
    case chiptune
    case robot

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .clean: return "Clean"
        case .pixelArt: return "Pixel Art"
        case .chiptune: return "Chiptune"
        case .robot: return "Robot"
        }
    }

    public var systemImage: String {
        switch self {
        case .clean: return "waveform"
        case .pixelArt: return "square.grid.3x3.square"
        case .chiptune: return "dot.radiowaves.left.and.right"
        case .robot: return "cpu"
        }
    }

    public var bitDepth: Int {
        switch self {
        case .clean: return 16
        case .pixelArt: return 8
        case .chiptune: return 6
        case .robot: return 4
        }
    }

    public var sampleRateHold: Int {
        switch self {
        case .clean: return 1
        case .pixelArt: return 2
        case .chiptune: return 4
        case .robot: return 6
        }
    }
}

// MARK: - UserDefaults bridge

public enum VoicePreferenceKeys {
    /// When `auto`, agent responses are spoken aloud automatically as
    /// the stream completes. When `manual`, user must tap the
    /// ReadAloud button.
    public static let agentResponseTTS =
        "com.epistemos.voice.agentResponseTTS"

    /// When `auto`, opening a long note auto-starts read-aloud
    /// playback. When `manual`, user must tap the ReadAloud button.
    public static let noteReadAloud =
        "com.epistemos.voice.noteReadAloud"

    /// When `auto`, dictation auto-stops after 2 s of silence.
    /// When `manual`, user must tap Stop explicitly.
    public static let dictationAutoStop =
        "com.epistemos.voice.dictationAutoStop"

    /// When `auto`, the global brain-dump hotkey auto-starts a
    /// dictation session. When `manual`, hotkey opens a sheet that
    /// requires an explicit "Start dictating" tap.
    public static let brainDumpHotkeyDictate =
        "com.epistemos.voice.brainDumpHotkeyDictate"

    /// Retired per-model voice persona preference. Shipped TTS is Kokoro-only.
    public static let perModelVoicePersona =
        "com.epistemos.voice.perModelVoicePersona"

    /// When `auto`, Quick Capture reads each completed sentence aloud as you
    /// pause typing. When `manual`, read-back only happens via the speaker button.
    public static let quickCaptureReadBack =
        "com.epistemos.voice.quickCaptureReadBack"

    /// Global read-aloud post-filter. Effects are applied only to Kokoro PCM
    /// after the checked local model renders; clean remains the default.
    public static let readAloudEffect =
        "com.epistemos.voice.readAloudEffect"
}

// MARK: - Preferences singleton

@MainActor
@Observable
public final class VoicePreferences {

    public static let shared = VoicePreferences()

    private init() {
        // Conservative defaults: STT/TTS surfaces default to MANUAL
        // mode so users opt INTO automation explicitly. Per-model
        // voice persona defaults to AUTO since the W9.1.b voice
        // picker already requires user setup.
        let d = UserDefaults.standard
        if d.object(forKey: VoicePreferenceKeys.agentResponseTTS) == nil {
            d.set(VoiceDecisionMode.manual.rawValue, forKey: VoicePreferenceKeys.agentResponseTTS)
        }
        if d.object(forKey: VoicePreferenceKeys.noteReadAloud) == nil {
            d.set(VoiceDecisionMode.manual.rawValue, forKey: VoicePreferenceKeys.noteReadAloud)
        }
        if d.object(forKey: VoicePreferenceKeys.dictationAutoStop) == nil {
            d.set(VoiceDecisionMode.auto.rawValue, forKey: VoicePreferenceKeys.dictationAutoStop)
        }
        if d.object(forKey: VoicePreferenceKeys.brainDumpHotkeyDictate) == nil {
            d.set(VoiceDecisionMode.manual.rawValue, forKey: VoicePreferenceKeys.brainDumpHotkeyDictate)
        }
        if d.object(forKey: VoicePreferenceKeys.perModelVoicePersona) == nil {
            d.set(VoiceDecisionMode.auto.rawValue, forKey: VoicePreferenceKeys.perModelVoicePersona)
        }
        if d.object(forKey: VoicePreferenceKeys.quickCaptureReadBack) == nil {
            d.set(VoiceDecisionMode.manual.rawValue, forKey: VoicePreferenceKeys.quickCaptureReadBack)
        }
        if d.object(forKey: VoicePreferenceKeys.readAloudEffect) == nil {
            d.set(VoiceEffect.clean.rawValue, forKey: VoicePreferenceKeys.readAloudEffect)
        }
    }

    public var agentResponseTTS: VoiceDecisionMode {
        get { decode(forKey: VoicePreferenceKeys.agentResponseTTS, default: .manual) }
        set { encode(newValue, forKey: VoicePreferenceKeys.agentResponseTTS) }
    }

    public var noteReadAloud: VoiceDecisionMode {
        get { decode(forKey: VoicePreferenceKeys.noteReadAloud, default: .manual) }
        set { encode(newValue, forKey: VoicePreferenceKeys.noteReadAloud) }
    }

    public var dictationAutoStop: VoiceDecisionMode {
        get { decode(forKey: VoicePreferenceKeys.dictationAutoStop, default: .auto) }
        set { encode(newValue, forKey: VoicePreferenceKeys.dictationAutoStop) }
    }

    public var brainDumpHotkeyDictate: VoiceDecisionMode {
        get { decode(forKey: VoicePreferenceKeys.brainDumpHotkeyDictate, default: .manual) }
        set { encode(newValue, forKey: VoicePreferenceKeys.brainDumpHotkeyDictate) }
    }

    public var perModelVoicePersona: VoiceDecisionMode {
        get { decode(forKey: VoicePreferenceKeys.perModelVoicePersona, default: .auto) }
        set { encode(newValue, forKey: VoicePreferenceKeys.perModelVoicePersona) }
    }

    public var quickCaptureReadBack: VoiceDecisionMode {
        get { decode(forKey: VoicePreferenceKeys.quickCaptureReadBack, default: .manual) }
        set { encode(newValue, forKey: VoicePreferenceKeys.quickCaptureReadBack) }
    }

    public var readAloudEffect: VoiceEffect {
        get {
            guard let raw = UserDefaults.standard.string(forKey: VoicePreferenceKeys.readAloudEffect),
                  let effect = VoiceEffect(rawValue: raw) else {
                return .clean
            }
            return effect
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: VoicePreferenceKeys.readAloudEffect)
            voiceLog.debug("voice pref \(VoicePreferenceKeys.readAloudEffect, privacy: .public) → \(newValue.rawValue, privacy: .public)")
        }
    }

    // MARK: - Rationale strings (W11.4 Manual-mode "Why?" surface)

    public func rationale(for key: String) -> String {
        switch key {
        case VoicePreferenceKeys.agentResponseTTS:
            return """
            Auto mode speaks agent responses aloud as the stream completes — useful when you're hands-busy or want a 'briefing' read-aloud feel. Manual mode keeps responses silent unless you tap the speaker button. Manual is the conservative default.
            """
        case VoicePreferenceKeys.noteReadAloud:
            return """
            Auto mode starts read-aloud as soon as you open a long note (>500 chars). Manual mode keeps read-aloud opt-in via the speaker button on the note toolbar.
            """
        case VoicePreferenceKeys.dictationAutoStop:
            return """
            Auto mode stops dictation after 2 s of silence (matches Apple Notes). Manual mode keeps recording until you tap Stop — useful for long brain dumps where you pause to think.
            """
        case VoicePreferenceKeys.brainDumpHotkeyDictate:
            return """
            Auto mode auto-starts dictation when you press the global brain-dump hotkey. Manual mode opens an empty sheet that requires you to tap 'Start dictating' before recording begins.
            """
        case VoicePreferenceKeys.perModelVoicePersona:
            return """
            This legacy preference is kept for migration only. Shipped text-to-speech is Kokoro-only and remains unavailable until native Kokoro playback is wired.
            """
        case VoicePreferenceKeys.quickCaptureReadBack:
            return """
            Auto mode will read each completed sentence aloud as you pause typing in Quick Capture once native Kokoro playback is wired. Manual mode keeps read-back opt-in via the speaker button. Manual is the conservative default. Apple AVSpeech is not used as a fallback.
            """
        default:
            return ""
        }
    }

    // MARK: - Helpers

    private func decode(forKey key: String, default fallback: VoiceDecisionMode) -> VoiceDecisionMode {
        guard let raw = UserDefaults.standard.string(forKey: key),
              let mode = VoiceDecisionMode(rawValue: raw) else {
            return fallback
        }
        return mode
    }

    private func encode(_ mode: VoiceDecisionMode, forKey key: String) {
        UserDefaults.standard.set(mode.rawValue, forKey: key)
        voiceLog.debug("voice pref \(key, privacy: .public) → \(mode.rawValue, privacy: .public)")
    }
}
