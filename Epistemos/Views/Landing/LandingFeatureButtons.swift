import SwiftUI

nonisolated enum LandingFeatureButtonTextPolicy {
    static let maxUnavailableMessageCharacters = 512
    static let maxHelpTextCharacters = 240

    static func unavailableMessage(_ message: String) -> String {
        bounded(message, limit: maxUnavailableMessageCharacters, fallback: "Feature status unavailable.")
    }

    static func helpText(_ message: String) -> String {
        bounded(message, limit: maxHelpTextCharacters, fallback: "Feature unavailable.")
    }

    private static func bounded(_ value: String, limit: Int, fallback: String) -> String {
        let bounded = String(value.prefix(limit + 1))
        let clipped: String
        if bounded.count > limit {
            clipped = limit > 3 ? String(bounded.prefix(limit - 3)) + "..." : String(bounded.prefix(limit))
        } else {
            clipped = bounded
        }
        let trimmed = normalizedDisplayText(clipped).trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    static func normalizedDisplayText(_ value: String) -> String {
        var normalized = ""
        normalized.reserveCapacity(value.count)
        var previousWasSeparator = false
        for scalar in value.unicodeScalars {
            let isSeparator = CharacterSet.whitespacesAndNewlines.contains(scalar)
                || CharacterSet.controlCharacters.contains(scalar)
            if isSeparator {
                if !previousWasSeparator {
                    normalized.append(" ")
                    previousWasSeparator = true
                }
            } else {
                normalized.unicodeScalars.append(scalar)
                previousWasSeparator = false
            }
        }
        return normalized
    }
}

nonisolated enum MeetingNoteLandingGateStatus {
    struct Status: Equatable, Sendable {
        let isActive: Bool
        let headline: String
        let detail: String
    }

    static var isSpeechAnalyzerAvailable: Bool {
        if #available(macOS 26.0, *) {
            return true
        }
        return false
    }

    static func status(
        speechAnalyzerAvailable: Bool = isSpeechAnalyzerAvailable
    ) -> Status {
        guard speechAnalyzerAvailable else {
            return Status(
                isActive: false,
                headline: "Meeting notes: unavailable",
                detail: "Meeting notes require macOS 26 SpeechAnalyzer for on-device transcription."
            )
        }

        return Status(
            isActive: true,
            headline: "Meeting notes: ready",
            detail: "Meeting notes use macOS 26 SpeechAnalyzer for on-device transcription. Microphone permission is requested when recording starts."
        )
    }
}

enum LandingFeatureButton: String, CaseIterable, Identifiable {
    case pdfImport
    case meetingNote

    var id: String { rawValue }

    static var visibleCases: [LandingFeatureButton] {
        allCases
    }

    var title: String {
        switch self {
        case .pdfImport: "pdf import"
        case .meetingNote: "meeting"
        }
    }

    var glyph: PixelGlyphKind {
        switch self {
        case .pdfImport: .document
        case .meetingNote: .capture
        }
    }

    var integrationBrand: IntegrationBrand {
        .landingFeature(rawValue: rawValue)
    }

    func accent(in theme: EpistemosTheme) -> Color {
        switch self {
        case .pdfImport:
            theme.resolved.accent.color
        case .meetingNote:
            theme.resolved.foreground.color.opacity(theme.isDark ? 0.88 : 0.76)
        }
    }

    var haptic: HomeCommandHapticStyle {
        switch self {
        case .pdfImport: .document
        case .meetingNote: .capture
        }
    }

    var shortcut: String? {
        nil
    }

    var isAvailableInThisBuild: Bool {
        switch self {
        case .pdfImport:
            return LiteParseImportGateStatus.status().isActive
        case .meetingNote:
            return MeetingNoteLandingGateStatus.status().isActive
        }
    }

    private var rawUnavailableMessage: String {
        switch self {
        case .pdfImport:
            return LiteParseImportGateStatus.status().detail
        case .meetingNote:
            return MeetingNoteLandingGateStatus.status().detail
        }
    }

    var unavailableMessage: String {
        LandingFeatureButtonTextPolicy.unavailableMessage(rawUnavailableMessage)
    }

    /// A short description of what this feature does — surfaced on hover so users
    /// actually discover the app's capabilities instead of guessing from a one-word
    /// label (owner discoverability request 2026-07-03).
    var featureDescription: String {
        switch self {
        case .pdfImport:
            return "Import a PDF and turn it into searchable, linked notes in your vault."
        case .meetingNote:
            return "Record a meeting and capture a live, auto-saved transcript."
        }
    }

    var helpText: String {
        if isAvailableInThisBuild {
            return featureDescription
        }
        return LandingFeatureButtonTextPolicy.helpText(unavailableMessage)
    }
}

struct LandingFeatureButtonTile: View {
    let feature: LandingFeatureButton
    let theme: EpistemosTheme
    let action: () -> Void

    var body: some View {
        let accent = feature.accent(in: theme)

        PixelLandingCommandTile(
            title: feature.title,
            shortcut: feature.shortcut,
            glyph: feature.glyph,
            theme: theme,
            accent: accent,
            haptic: feature.haptic,
            brand: feature.integrationBrand,
            action: action
        )
        .opacity(feature.isAvailableInThisBuild ? 1 : 0.58)
        .help(feature.helpText)
    }
}
