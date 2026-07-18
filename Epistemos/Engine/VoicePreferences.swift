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
//   1. Read-aloud notes (long-form TTS for note bodies)
//   2. Auto-stop dictation on silence (auto-detect "I'm done
//      speaking" pause vs require explicit Stop tap)
//   3. Brain-dump dictation auto-launch on hotkey
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

    public nonisolated static var allowsReadAloudEffects: Bool {
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        false
        #else
        true
        #endif
    }

    public nonisolated static func shippedReadAloudEffect(_ requested: VoiceEffect) -> VoiceEffect {
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        .clean
        #else
        requested
        #endif
    }

    private init() {
        // Conservative defaults: STT/TTS surfaces default to MANUAL
        // mode so users opt into automation explicitly.
        let d = FoundationSafety.runtimeUserDefaults
        if d.object(forKey: VoicePreferenceKeys.noteReadAloud) == nil {
            d.set(VoiceDecisionMode.manual.rawValue, forKey: VoicePreferenceKeys.noteReadAloud)
        }
        if d.object(forKey: VoicePreferenceKeys.dictationAutoStop) == nil {
            d.set(VoiceDecisionMode.auto.rawValue, forKey: VoicePreferenceKeys.dictationAutoStop)
        }
        if d.object(forKey: VoicePreferenceKeys.brainDumpHotkeyDictate) == nil {
            d.set(VoiceDecisionMode.manual.rawValue, forKey: VoicePreferenceKeys.brainDumpHotkeyDictate)
        }
        if d.object(forKey: VoicePreferenceKeys.quickCaptureReadBack) == nil {
            d.set(VoiceDecisionMode.manual.rawValue, forKey: VoicePreferenceKeys.quickCaptureReadBack)
        }
        if d.object(forKey: VoicePreferenceKeys.readAloudEffect) == nil {
            d.set(VoiceEffect.clean.rawValue, forKey: VoicePreferenceKeys.readAloudEffect)
        }
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

    public var quickCaptureReadBack: VoiceDecisionMode {
        get { decode(forKey: VoicePreferenceKeys.quickCaptureReadBack, default: .manual) }
        set { encode(newValue, forKey: VoicePreferenceKeys.quickCaptureReadBack) }
    }

    public var readAloudEffect: VoiceEffect {
        get {
            guard let raw = FoundationSafety.runtimeUserDefaults.string(forKey: VoicePreferenceKeys.readAloudEffect),
                  let effect = VoiceEffect(rawValue: raw) else {
                return .clean
            }
            return Self.shippedReadAloudEffect(effect)
        }
        set {
            let shippedEffect = Self.shippedReadAloudEffect(newValue)
            FoundationSafety.runtimeUserDefaults.set(shippedEffect.rawValue, forKey: VoicePreferenceKeys.readAloudEffect)
            voiceLog.debug("voice pref \(VoicePreferenceKeys.readAloudEffect, privacy: .public) → \(shippedEffect.rawValue, privacy: .public)")
        }
    }

    // MARK: - Rationale strings (W11.4 Manual-mode "Why?" surface)

    public func rationale(for key: String) -> String {
        switch key {
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
        case VoicePreferenceKeys.quickCaptureReadBack:
            return """
            Auto mode reads each completed sentence aloud as you pause typing in Quick Capture when Kokoro is installed and ready. Manual mode keeps read-back opt-in via the speaker button. Manual is the conservative default. Apple AVSpeech is not used as a fallback.
            """
        default:
            return ""
        }
    }

    // MARK: - Helpers

    private func decode(forKey key: String, default fallback: VoiceDecisionMode) -> VoiceDecisionMode {
        guard let raw = FoundationSafety.runtimeUserDefaults.string(forKey: key),
              let mode = VoiceDecisionMode(rawValue: raw) else {
            return fallback
        }
        return mode
    }

    private func encode(_ mode: VoiceDecisionMode, forKey key: String) {
        FoundationSafety.runtimeUserDefaults.set(mode.rawValue, forKey: key)
        voiceLog.debug("voice pref \(key, privacy: .public) → \(mode.rawValue, privacy: .public)")
    }
}
