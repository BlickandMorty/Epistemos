import SwiftUI

enum LandingFeatureButton: String, CaseIterable, Identifiable {
    case pdfImport
    case arxiv
    case provenance
    case extensions
    case vaultMCP
    case browser
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
        case .meetingNote: .capture
        case .voice: .chat
        }
    }

    var integrationBrand: IntegrationBrand {
        .landingFeature(rawValue: rawValue)
    }

    var accent: Color {
        switch self {
        case .pdfImport: Color(hex: 0x8ABF5D)
        case .arxiv: Color(hex: 0x4C8DFF)
        case .provenance: Color(hex: 0xD96B7E)
        case .extensions: Color(hex: 0xC985D8)
        case .vaultMCP: Color(hex: 0x4FB477)
        case .browser: Color(hex: 0xE0A53C)
        case .meetingNote: Color(hex: 0x5AA6A6)
        case .voice: Color(hex: 0xB26BD6)
        }
    }

    var haptic: HomeCommandHapticStyle {
        switch self {
        case .pdfImport, .arxiv: .document
        case .provenance: .graph
        case .extensions, .vaultMCP: .workspace
        case .browser: .agent
        case .meetingNote, .voice: .capture
        }
    }

    var shortcut: String? {
        switch self {
        case .pdfImport: nil
        case .arxiv: nil
        case .provenance: nil
        case .extensions: nil
        case .vaultMCP: "PRO"
        case .browser: nil
        case .meetingNote: nil
        case .voice: nil
        }
    }

    var isProOnly: Bool {
        switch self {
        case .vaultMCP:
            return true
        case .pdfImport, .arxiv, .provenance, .extensions, .browser, .meetingNote, .voice:
            return false
        }
    }

    var isAvailableInThisBuild: Bool {
        switch self {
        case .vaultMCP:
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
        case .browser, .meetingNote, .voice:
            return true
        }
    }

    var unavailableMessage: String {
        if isProOnly {
            return "\(title) is available in Epistemos Pro."
        }
        switch self {
        case .pdfImport:
            return LiteParseImportGateStatus.status().detail
        case .arxiv:
            return ArxivPullGateStatus.status().detail
        case .browser:
            return "Browser is unavailable in this build."
        case .meetingNote:
            return "Meeting notes are unavailable in this build."
        case .voice:
            return "Voice settings are unavailable in this build."
        case .provenance, .extensions, .vaultMCP:
            return "\(title) is unavailable in this build."
        }
    }

    var helpText: String {
        if isAvailableInThisBuild {
            return "Open \(title)."
        }
        return unavailableMessage
    }
}

struct LandingFeatureButtonTile: View {
    let feature: LandingFeatureButton
    let theme: EpistemosTheme
    let action: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            PixelLandingCommandTile(
                title: feature.title,
                shortcut: feature.shortcut,
                glyph: feature.glyph,
                theme: theme,
                accent: feature.accent,
                haptic: feature.haptic,
                brand: feature.integrationBrand,
                action: action
            )
            .opacity(feature.isAvailableInThisBuild ? 1 : 0.58)

            if feature.isProOnly && !feature.isAvailableInThisBuild {
                Text("PRO")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(feature.accent)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background {
                        Capsule(style: .continuous)
                            .fill(feature.accent.opacity(theme.isDark ? 0.20 : 0.12))
                    }
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(feature.accent.opacity(0.45), lineWidth: 0.75)
                    }
                    .padding(5)
            }
        }
        .help(feature.helpText)
    }
}
