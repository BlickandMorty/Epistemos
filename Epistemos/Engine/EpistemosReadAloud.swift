import Foundation
import OSLog

@MainActor
enum EpistemosReadAloud {
    private static let log = Logger(subsystem: "com.epistemos", category: "Speech.ReadAloud")
    static let maxResponsiveReadVisibleCharacters = 220

    @discardableResult
    static func speak(
        _ text: String,
        synthesizer: EpistemosSpeechSynthesizer = .shared,
        surface: EpistemosVisibleReadAloudSurface? = nil
    ) -> String? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            EpistemosReadAloudDiagnostics.showNoVisibleTextToast(surface: surface)
            return nil
        }
        guard EpistemosSpeechSynthesizer.isTextToSpeechInputSupported(cleaned) else {
            EpistemosReadAloudDiagnostics.showUnavailableToast(
                EpistemosSpeechSynthesizer.textToSpeechStatusMessage(for: cleaned)
            )
            return nil
        }
        EpistemosSpeechSynthesizer.logTextToSpeechReadiness(
            context: surface?.rawValue ?? "read-aloud"
        )
        guard EpistemosSpeechSynthesizer.isTextToSpeechAvailable() else {
            EpistemosReadAloudDiagnostics.showUnavailableToast()
            return nil
        }
        EpistemosReadAloudDiagnostics.showQueuedToast(surface: surface)
        let utteranceID = synthesizer.speak(
            String(cleaned.prefix(EpistemosSpeechSynthesizer.maxTextToSpeechInputCharacters)),
            voiceIdentifier: EpistemosSpeechSynthesizer.globalDefaultVoiceIdentifier(),
            effect: VoicePreferences.shared.readAloudEffect
        )
        if utteranceID == nil {
            EpistemosReadAloudDiagnostics.showFailureToast("Kokoro read-aloud could not start. Check Settings > Voice.")
        }
        return utteranceID
    }

    @discardableResult
    static func readVisibleSurface(
        preferred surface: EpistemosVisibleReadAloudSurface? = nil,
        synthesizer: EpistemosSpeechSynthesizer = .shared
    ) -> String? {
        log.notice(
            "Read visible surface requested preferred=\((surface?.rawValue ?? "active"), privacy: .public)"
        )
        guard let readable = EpistemosVisibleReadAloudRegistry.shared.visibleText(preferred: surface) else {
            EpistemosReadAloudDiagnostics.showNoVisibleTextToast(surface: surface)
            return nil
        }
        let prepared = responsiveReadVisibleText(readable.text, surface: readable.surface)
        log.notice(
            "Read visible surface queued surface=\(readable.surface.rawValue, privacy: .public) sourceChars=\(readable.text.count, privacy: .public) spokenChars=\(prepared.text.count, privacy: .public) truncated=\(prepared.truncated, privacy: .public)"
        )
        if prepared.truncated {
            EpistemosReadAloudDiagnostics.showExcerptToast(surface: readable.surface)
        }
        return speak(prepared.text, synthesizer: synthesizer, surface: readable.surface)
    }

    static func responsiveReadVisibleText(
        _ text: String,
        surface: EpistemosVisibleReadAloudSurface? = nil
    ) -> (text: String, truncated: Bool) {
        let cleaned = text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count > maxResponsiveReadVisibleCharacters else {
            return (cleaned, false)
        }

        let limit = cleaned.index(
            cleaned.startIndex,
            offsetBy: maxResponsiveReadVisibleCharacters
        )
        var end = limit
        let sentenceDelimiters = CharacterSet(charactersIn: ".!?")
        if let sentenceEnd = cleaned[..<limit].rangeOfCharacter(
            from: sentenceDelimiters,
            options: .backwards
        )?.upperBound,
           cleaned.distance(from: cleaned.startIndex, to: sentenceEnd) >= 48 {
            end = sentenceEnd
        } else if let wordBreak = cleaned[..<limit].rangeOfCharacter(
            from: .whitespaces,
            options: .backwards
        )?.lowerBound,
                  cleaned.distance(from: cleaned.startIndex, to: wordBreak) >= 48 {
            end = wordBreak
        }

        let excerpt = cleaned[..<end].trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix = surface.map { " Select text on the \($0.label) for a narrower read." } ?? ""
        return ("\(excerpt). Reading the first visible passage only.\(suffix)", true)
    }
}
