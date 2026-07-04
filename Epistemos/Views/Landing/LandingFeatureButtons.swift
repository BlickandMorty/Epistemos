import AVFoundation
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
        speechAnalyzerAvailable: Bool = isSpeechAnalyzerAvailable,
        audioAuthorizationStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    ) -> Status {
        guard speechAnalyzerAvailable else {
            return Status(
                isActive: false,
                headline: "Meeting notes: unavailable",
                detail: "Meeting notes require macOS 26 SpeechAnalyzer for on-device transcription."
            )
        }

        switch audioAuthorizationStatus {
        case .denied, .restricted:
            return Status(
                isActive: false,
                headline: "Meeting notes: microphone unavailable",
                detail: "Meeting notes require microphone access in System Settings before on-device transcription can start."
            )
        case .notDetermined, .authorized:
            return Status(
                isActive: true,
                headline: "Meeting notes: ready",
                detail: "Meeting notes use macOS 26 SpeechAnalyzer for on-device transcription. Microphone permission is requested when recording starts."
            )
        @unknown default:
            return Status(
                isActive: false,
                headline: "Meeting notes: microphone status unknown",
                detail: "Meeting notes are unavailable until microphone authorization can be checked."
            )
        }
    }
}

enum LandingFeatureButton: String, CaseIterable, Identifiable {
    case pdfImport
    case arxiv
    case browser
    case meetingNote
    case agent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pdfImport: "pdf import"
        case .arxiv: "arXiv"
        case .browser: "browser"
        case .meetingNote: "meeting"
        case .agent: "agent"
        }
    }

    var glyph: PixelGlyphKind {
        switch self {
        case .pdfImport: .document
        case .arxiv: .search
        case .browser: .html
        case .meetingNote: .capture
        case .agent: .agent
        }
    }

    var integrationBrand: IntegrationBrand {
        .landingFeature(rawValue: rawValue)
    }

    func accent(in theme: EpistemosTheme) -> Color {
        switch self {
        case .pdfImport:
            theme.resolved.accent.color
        case .arxiv, .browser, .agent:
            theme.resolved.headingAccent.color
        case .meetingNote:
            theme.resolved.foreground.color.opacity(theme.isDark ? 0.88 : 0.76)
        }
    }

    var haptic: HomeCommandHapticStyle {
        switch self {
        case .pdfImport, .arxiv: .document
        case .browser, .agent: .agent
        case .meetingNote: .capture
        }
    }

    var shortcut: String? {
        nil
    }

    var isProOnly: Bool {
        false
    }

    var isAvailableInThisBuild: Bool {
        switch self {
        case .pdfImport:
            return LiteParseImportGateStatus.status().isActive
        case .arxiv:
            return ArxivPullGateStatus.status().isActive
        case .meetingNote:
            return MeetingNoteLandingGateStatus.status().isActive
        case .browser:
            return true
        case .agent:
            // Available on BOTH targets: MAS mounts the vendored June agent
            // room (Plan 1-MAS, LandingView case .agent → JuneAgentSurfaceView);
            // Pro mounts its own agent workspace. The old MAS `false` predated
            // the June surface and left it unreachable at runtime.
            return true
        }
    }

    private var rawUnavailableMessage: String {
        switch self {
        case .pdfImport:
            return LiteParseImportGateStatus.status().detail
        case .arxiv:
            return ArxivPullGateStatus.status().detail
        case .browser:
            return "Browser is unavailable in this build."
        case .meetingNote:
            return MeetingNoteLandingGateStatus.status().detail
        case .agent:
            return "The agent workspace ships in the Pro build."
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
        case .arxiv:
            return "Search arXiv, browse featured AI & ML papers, and save any paper to notes."
        case .browser:
            return "A themed in-app browser — save any page to notes; links across the app open here."
        case .meetingNote:
            return "Record a meeting and capture a live, auto-saved transcript."
        case .agent:
            #if EPISTEMOS_APP_STORE
            return "The agent room — chat with June, streaming real answers from on-device models."
            #else
            return "The agent workspace — chat with coding agents over your projects, with files, git, diffs, and a terminal."
            #endif
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

        ZStack(alignment: .topTrailing) {
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

            if feature.isProOnly && !feature.isAvailableInThisBuild {
                Text("PRO")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background {
                        Capsule(style: .continuous)
                            .fill(accent.opacity(theme.isDark ? 0.20 : 0.12))
                    }
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(accent.opacity(0.45), lineWidth: 0.75)
                    }
                    .padding(5)
            }
        }
        .help(feature.helpText)
    }
}
