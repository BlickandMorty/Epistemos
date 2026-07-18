import SwiftUI

/// Plan 3 whole-app logos: non-model brand marks for tools, integrations, MCP,
/// marketplace rows, and utility surfaces. This intentionally stays separate
/// from `ProviderBrand`, which remains the model-provider logo registry.
nonisolated enum IntegrationBrand: String, CaseIterable, Sendable, Equatable {
    static let maxClassifierInputCharacters = 512

    case vault
    case eidos
    case web
    case graph
    case builtinTool
    case remoteMCP
    case skillRepo
    case bundledSkills
    #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
    case codexSkills
    #endif
    case localSkill
    case rawSkill
    case context7
    #if EPISTEMOS_FREE_V1
    case paidSkills
    #else
    case anthropicSkills
    #endif
    case smithery
    case mcpSO
    case glama
    case github
    case slack
    case gmail
    case googleDrive
    case huggingFace
    case notion
    case pdfImport
    case arxiv
    case provenance
    case extensions
    case vaultMCP
    case meetingNote
    case voice
    case appleNative
    case generic

    var displayName: String {
        switch self {
        case .vault: "Vault"
        case .eidos: "Eidos"
        case .web: "Web"
        case .graph: "Graph"
        case .builtinTool: "Built-in Tool"
        case .remoteMCP: "Remote MCP"
        case .skillRepo: "Skill Repository"
        case .bundledSkills: "Bundled Skills"
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        case .codexSkills: "Codex Skills"
        #endif
        case .localSkill: "Local Skill"
        case .rawSkill: "Raw Skill"
        case .context7: "Context7"
        #if EPISTEMOS_FREE_V1
        case .paidSkills: "Paid Skills"
        #else
        case .anthropicSkills: "Anthropic Skills"
        #endif
        case .smithery: "Smithery"
        case .mcpSO: "mcp.so"
        case .glama: "Glama"
        case .github: "GitHub"
        case .slack: "Slack"
        case .gmail: "Gmail"
        case .googleDrive: "Google Drive"
        case .huggingFace: "Hugging Face"
        case .notion: "Notion"
        case .pdfImport: "PDF Import"
        case .arxiv: "arXiv"
        case .provenance: "Provenance"
        case .extensions: "Extensions"
        case .vaultMCP: "Vault MCP"
        case .meetingNote: "Meeting Note"
        case .voice: "Voice"
        case .appleNative: "Apple Native"
        case .generic: "Integration"
        }
    }

    /// Optional vetted asset name. Keep nil until a checked-in asset has a
    /// documented license and provenance; fallback marks are honest and local.
    var assetName: String? { nil }

    var systemSymbol: String {
        switch self {
        case .vault: "tray.full"
        case .eidos: "brain.head.profile"
        case .web: "network"
        case .graph: "point.3.connected.trianglepath.dotted"
        case .builtinTool: "wrench.and.screwdriver"
        case .remoteMCP, .vaultMCP: "server.rack"
        case .skillRepo: "wand.and.stars"
        case .bundledSkills: "shippingbox"
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        case .codexSkills: "terminal"
        #endif
        case .localSkill: "folder"
        case .rawSkill: "doc.plaintext"
        case .context7: "book.pages"
        #if EPISTEMOS_FREE_V1
        case .paidSkills: "sparkles"
        #else
        case .anthropicSkills: "sparkles"
        #endif
        case .smithery: "hammer"
        case .mcpSO: "m.circle"
        case .glama: "sparkle.magnifyingglass"
        case .github: "chevron.left.forwardslash.chevron.right"
        case .slack: "number"
        case .gmail: "envelope"
        case .googleDrive: "externaldrive"
        case .huggingFace: "face.smiling"
        case .notion: "doc.text"
        case .pdfImport: "doc.richtext"
        case .arxiv: "doc.text.magnifyingglass"
        case .provenance: "checkmark.seal"
        case .extensions: "puzzlepiece.extension"
        case .meetingNote: "waveform"
        case .voice: "waveform.and.mic"
        case .appleNative: "apple.logo"
        case .generic: "app.connected.to.app.below.fill"
        }
    }

    var monogram: String {
        switch self {
        case .context7: "C7"
        #if EPISTEMOS_FREE_V1
        case .paidSkills: "PS"
        #else
        case .anthropicSkills: "AS"
        #endif
        case .smithery: "SM"
        case .mcpSO: "SO"
        case .glama: "GL"
        case .github: "GH"
        case .bundledSkills: "BS"
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        case .codexSkills: "CX"
        #endif
        case .localSkill: "LS"
        case .rawSkill: "MD"
        case .slack: "SL"
        case .gmail: "GM"
        case .googleDrive: "GD"
        case .huggingFace: "HF"
        case .notion: "NT"
        default:
            String(displayName.prefix(2)).uppercased()
        }
    }

    var usesMonogramFallback: Bool {
        switch self {
        #if EPISTEMOS_FREE_V1
        case .context7, .paidSkills, .smithery, .mcpSO, .glama, .github,
             .bundledSkills, .localSkill, .rawSkill,
             .slack, .gmail, .googleDrive, .huggingFace, .notion:
            return true
        #else
        case .context7, .anthropicSkills, .smithery, .mcpSO, .glama, .github,
             .bundledSkills, .localSkill, .rawSkill,
             .slack, .gmail, .googleDrive, .huggingFace, .notion:
            return true
        #endif
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        case .codexSkills:
            return true
        #endif
        default:
            return false
        }
    }

    static func installedMCPServer(name: String, host: String) -> IntegrationBrand {
        let haystack = normalizedHaystack(name, host)
        if haystack.contains("context7") { return .context7 }
        if haystack.contains("slack") { return .slack }
        if haystack.contains("gmail") || haystack.contains("googlemail") { return .gmail }
        if haystack.contains("google-drive") || haystack.contains("gdrive") || haystack.contains("drive") {
            return .googleDrive
        }
        if isHuggingFace(haystack) { return .huggingFace }
        if haystack.contains("notion") { return .notion }
        if haystack.contains("github") { return .github }
        return .remoteMCP
    }

    static func mcpRegistry(source: String, installKind: String, name: String) -> IntegrationBrand {
        let named = installedMCPServer(name: name, host: "")
        if named != .remoteMCP {
            return named
        }

        switch normalized(source) {
        case "smithery":
            return .smithery
        case "mcpso", "mcp-so":
            return .mcpSO
        case "glama":
            return .glama
        case "github":
            return .github
        default:
            break
        }

        switch normalized(installKind) {
        case "remoteurl":
            return .remoteMCP
        case "skillrepo":
            return .skillRepo
        default:
            return .builtinTool
        }
    }

    static func bestOfPreset(kind: String, id: String, displayName: String) -> IntegrationBrand {
        let haystack = normalizedHaystack(id, displayName)
        if haystack.contains("context7") { return .context7 }
        #if EPISTEMOS_FREE_V1
        if haystack.contains("skill") { return .paidSkills }
        #else
        if haystack.contains("anthropic") && haystack.contains("skill") { return .anthropicSkills }
        #endif
        if isHuggingFace(haystack) { return .huggingFace }
        if haystack.contains("vault") { return .vault }
        if haystack.contains("eidos") { return .eidos }
        if haystack.contains("web") { return .web }
        if haystack.contains("graph") { return .graph }

        switch normalized(kind) {
        case "remotemcp":
            return .remoteMCP
        case "skillrepo":
            return .skillRepo
        default:
            return .builtinTool
        }
    }

    static func connector(id: String, displayName: String) -> IntegrationBrand {
        let haystack = normalizedHaystack(id, displayName)
        if haystack.contains("slack") { return .slack }
        if haystack.contains("gmail") || haystack.contains("googlemail") { return .gmail }
        if haystack.contains("drive") { return .googleDrive }
        if isHuggingFace(haystack) { return .huggingFace }
        if haystack.contains("notion") { return .notion }
        return .remoteMCP
    }

    static func skillDiscovery(source: String, identifier: String, category: String) -> IntegrationBrand {
        let haystack = normalizedHaystack(identifier, category)
        if isHuggingFace(normalizedHaystack(source, identifier, category)) { return .huggingFace }
        #if EPISTEMOS_FREE_V1
        if haystack.contains("skill") { return .paidSkills }
        #else
        if haystack.contains("anthropic") { return .anthropicSkills }
        #endif
        if haystack.contains("github") { return .github }

        switch normalized(source) {
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        case "codex":
            return .codexSkills
        #endif
        case "bundled":
            return .bundledSkills
        default:
            return .skillRepo
        }
    }

    static func skillInstallSource(rawValue: String) -> IntegrationBrand {
        switch normalized(rawValue) {
        case "github":
            return .github
        case "rawurl":
            return .rawSkill
        case "localpath":
            return .localSkill
        default:
            return .skillRepo
        }
    }

    static func skillInventory(identifier: String, description: String) -> IntegrationBrand {
        let haystack = normalizedHaystack(identifier, description)
        if isHuggingFace(haystack) { return .huggingFace }
        #if EPISTEMOS_FREE_V1
        if haystack.contains("skill") { return .paidSkills }
        #else
        if haystack.contains("anthropic") { return .anthropicSkills }
        #endif
        if haystack.contains("github") { return .github }
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        if haystack.contains("codex") { return .codexSkills }
        #endif
        return .skillRepo
    }

    static func landingFeature(rawValue: String) -> IntegrationBrand {
        switch rawValue {
        case "pdfImport": .pdfImport
        case "arxiv": .arxiv
        case "provenance": .provenance
        case "extensions": .extensions
        case "vaultMCP": .vaultMCP
        case "meetingNote": .meetingNote
        case "voice": .voice
        default: .generic
        }
    }

    private static func normalizedHaystack(_ values: String...) -> String {
        values.map(normalized).joined(separator: " ")
    }

    private static func isHuggingFace(_ haystack: String) -> Bool {
        haystack.contains("hugging-face")
            || haystack.contains("huggingface")
            || haystack.contains("hugging face")
            || haystack.contains("hf-hub")
    }

    private static func normalized(_ value: String) -> String {
        let bounded = boundedClassifierInput(value)
        let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.lowercased()
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "_", with: "-")
    }

    private static func boundedClassifierInput(_ value: String) -> String {
        var output = ""
        for scalar in value.unicodeScalars.prefix(maxClassifierInputCharacters) {
            guard !CharacterSet.controlCharacters.contains(scalar) else { continue }
            output.append(Character(scalar))
        }
        return output
    }
}

struct IntegrationBrandMarkView: View {
    @Environment(UIState.self) private var ui

    let brand: IntegrationBrand
    var size: CGFloat = 18

    private var theme: EpistemosTheme {
        ui.theme.surfaceVariant(.other)
    }

    private var monogramBackground: Color {
        theme.resolved.mutedForeground.color.opacity(theme.isDark ? 0.16 : 0.11)
    }

    var body: some View {
        Group {
            if let assetName = brand.assetName, NSImage(named: assetName) != nil {
                Image(assetName)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
            } else if brand.usesMonogramFallback {
                monogramMark
            } else {
                Image(systemName: brand.systemSymbol)
                    .font(.system(size: size * 0.72, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("\(brand.displayName) brand mark")
    }

    private var monogramMark: some View {
        Text(brand.monogram)
            .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.62)
            .frame(width: size, height: size)
            .background {
                RoundedRectangle(cornerRadius: min(size * 0.18, 4), style: .continuous)
                    .fill(monogramBackground)
            }
    }
}
