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

enum LandingFeatureButton: String, CaseIterable, Identifiable {
    case pdfImport
    case arxiv
    case provenance
    case extensions
    case vaultMCP
    case browser
    case browserUsePro
    case meetingNote
    case voice

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pdfImport: "pdf import"
        case .arxiv: "arXiv"
        case .provenance: "provenance"
        case .extensions: "extensions"
        case .vaultMCP: "vault MCP"
        case .browser: "browser"
        case .browserUsePro: "browser-use"
        case .meetingNote: "meeting"
        case .voice: "voice"
        }
    }

    var glyph: PixelGlyphKind {
        switch self {
        case .pdfImport: .document
        case .arxiv: .search
        case .provenance: .graph
        case .extensions: .workspace
        case .vaultMCP: .notes
        case .browser: .html
        case .browserUsePro: .agent
        case .meetingNote: .capture
        case .voice: .chat
        }
    }

    var integrationBrand: IntegrationBrand {
        .landingFeature(rawValue: rawValue)
    }

    func accent(in theme: EpistemosTheme) -> Color {
        switch self {
        case .pdfImport, .vaultMCP, .voice:
            theme.resolved.accent.color
        case .arxiv, .browser, .browserUsePro:
            theme.resolved.headingAccent.color
        case .provenance, .extensions, .meetingNote:
            theme.resolved.foreground.color.opacity(theme.isDark ? 0.88 : 0.76)
        }
    }

    var haptic: HomeCommandHapticStyle {
        switch self {
        case .pdfImport, .arxiv: .document
        case .provenance: .graph
        case .extensions, .vaultMCP: .workspace
        case .browser, .browserUsePro: .agent
        case .meetingNote, .voice: .capture
        }
    }

    var shortcut: String? {
        nil
    }

    var isProOnly: Bool {
        switch self {
        case .vaultMCP, .browserUsePro:
            return true
        case .pdfImport, .arxiv, .provenance, .extensions, .browser, .meetingNote, .voice:
            return false
        }
    }

    var isAvailableInThisBuild: Bool {
        switch self {
        case .vaultMCP, .browserUsePro:
            #if EPISTEMOS_APP_STORE || MAS_SANDBOX
            return false
            #else
            return true
            #endif
        case .pdfImport:
            return LiteParseImportGateStatus.status().isActive
        case .arxiv:
            return ArxivPullGateStatus.status().isActive
        case .provenance, .extensions:
            return true
        case .meetingNote:
            if #available(macOS 26.0, *) {
                return true
            }
            return false
        case .browser, .voice:
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
        case .browserUsePro:
            return "browser-use Pro is available in Developer ID builds only."
        case .vaultMCP:
            return "vault MCP is available in Epistemos Pro."
        case .meetingNote:
            return "Meeting notes require macOS 26 SpeechAnalyzer."
        case .voice:
            return "Voice settings are unavailable in this build."
        case .provenance, .extensions:
            return "\(title) is unavailable in this build."
        }
    }

    var unavailableMessage: String {
        LandingFeatureButtonTextPolicy.unavailableMessage(rawUnavailableMessage)
    }

    var helpText: String {
        if isAvailableInThisBuild {
            return "Open \(title)."
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
