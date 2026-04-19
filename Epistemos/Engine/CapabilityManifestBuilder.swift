import Foundation
import os

/// Builds `Capabilities.md` — a narrative manifest of what Epistemos
/// is, what the active model can do, which tools are currently enabled,
/// and how the user prefers the model to behave. Regenerated per turn
/// so the model always reads from fresh state before acting.
///
/// Markdown (not JSON) because models read prose far better than schema
/// for descriptive context. The per-tool JSON schemas still ship via
/// the native tools array; this file is the *why*, not the *how*.
///
/// The auto-generated sections (identity / vault / tools) sit at the
/// top; the "How to act" section is user-editable via a sibling file
/// (`Capabilities.md.user`) so the user owns their behavioral prefs
/// without touching app source.
///
/// Reference: docs/architecture/MASTER_PLAN_2026-04-19.md §13A.
@MainActor
enum CapabilityManifestBuilder {
    private static let log = Logger(subsystem: "com.epistemos", category: "CapabilityManifest")

    // MARK: - Input

    struct Context {
        let providerLabel: String
        let modelLabel: String
        let operatingMode: EpistemosOperatingMode
        let reasoningTier: ChatReasoningTier
        let enabledToolNames: [String]
        let disabledToolNames: [String]
        let vaultName: String?
        let vaultNoteCount: Int?
        let skillNames: [String]
        let maxContextTokens: Int
    }

    // MARK: - Public API

    /// Render the markdown manifest for the given context. Pure — no
    /// side effects. Call `persist(_:)` to write to disk for inspection.
    static func render(_ context: Context) -> String {
        var sections: [String] = []
        sections.append(identitySection(context))
        sections.append(vaultSection(context))
        sections.append(enabledToolsSection(context))
        if !context.disabledToolNames.isEmpty {
            sections.append(disabledToolsSection(context))
        }
        if !context.skillNames.isEmpty {
            sections.append(skillsSection(context))
        }
        sections.append(preferencesSection(context))
        sections.append(howToActSection())
        return sections.joined(separator: "\n\n")
    }

    /// Persist the manifest at `~/Library/Application Support/Epistemos/runtime/Capabilities.md`
    /// so it's visible to the user and can be read by external tooling.
    /// Creates the directory lazily; failures log and return false so
    /// the UI layer can decide whether to surface the error.
    @discardableResult
    static func persist(_ manifest: String) -> Bool {
        guard let url = manifestFileURL else { return false }
        do {
            let directory = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            try manifest.write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            log.error(
                "failed to persist Capabilities.md: \(error.localizedDescription, privacy: .public)"
            )
            return false
        }
    }

    /// The user's editable "How to act" overrides, if present. Read
    /// from `Capabilities.md.user` alongside the auto-generated file
    /// so the user can override prose without app-source edits.
    /// Returns nil when the override file is missing or empty.
    static func loadUserOverrides() -> String? {
        guard let url = userOverridesFileURL,
              FileManager.default.fileExists(atPath: url.path),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - Sections

    private static func identitySection(_ ctx: Context) -> String {
        """
        # Capabilities

        You are Epistemos — a macOS-native personal knowledge
        management app with an on-device AI layer. You're currently
        running through \(ctx.providerLabel) on model
        **\(ctx.modelLabel)** in **\(ctx.operatingMode.displayName)**
        mode. Reasoning tier: **\(ctx.reasoningTier.displayName)**.
        Max context: \(formatTokens(ctx.maxContextTokens)).
        """
    }

    private static func vaultSection(_ ctx: Context) -> String {
        var lines = ["## Vault"]
        if let vaultName = ctx.vaultName {
            lines.append("- Active vault: **\(vaultName)**")
        } else {
            lines.append("- No vault is currently open.")
        }
        if let noteCount = ctx.vaultNoteCount {
            lines.append("- Notes indexed: \(noteCount)")
        }
        return lines.joined(separator: "\n")
    }

    private static func enabledToolsSection(_ ctx: Context) -> String {
        var lines = ["## Enabled tools"]
        if ctx.enabledToolNames.isEmpty {
            lines.append("_No tools are enabled for the current tier._")
        } else {
            for tool in ctx.enabledToolNames {
                lines.append("- `\(tool)`")
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func disabledToolsSection(_ ctx: Context) -> String {
        var lines = ["## Unavailable tools (not enabled for this tier)"]
        for tool in ctx.disabledToolNames {
            lines.append("- `\(tool)`")
        }
        lines.append(
            "\n_Do not claim to be able to use these tools right now. If the user asks for an action that requires one, say plainly that it's not available in the current mode and suggest switching tiers._"
        )
        return lines.joined(separator: "\n")
    }

    private static func skillsSection(_ ctx: Context) -> String {
        var lines = ["## Skills available"]
        for skill in ctx.skillNames {
            lines.append("- \(skill)")
        }
        return lines.joined(separator: "\n")
    }

    private static func preferencesSection(_ ctx: Context) -> String {
        """
        ## User preferences
        - Operating mode: **\(ctx.operatingMode.displayName)** — \
        \(ctx.operatingMode.helpText)
        - Reasoning: **\(ctx.reasoningTier.displayName)** — \
        \(ctx.reasoningTier.summary)
        """
    }

    private static func howToActSection() -> String {
        let defaultGuidance = """
        ## How to act
        - Answer directly and concisely. Avoid padding.
        - Never claim capabilities you don't have in the current tier.
        - When asked about your identity, say you are Epistemos running
          on the user's machine.
        - If a tool fails or times out, surface the failure — don't
          fabricate a success.
        - Quote user text verbatim when echoing it; don't paraphrase
          into your own voice.
        """
        if let user = loadUserOverrides() {
            return defaultGuidance + "\n\n### User overrides\n\n" + user
        }
        return defaultGuidance
    }

    // MARK: - Paths

    static var manifestFileURL: URL? {
        applicationSupportURL?.appendingPathComponent("runtime/Capabilities.md")
    }

    static var userOverridesFileURL: URL? {
        applicationSupportURL?.appendingPathComponent("Capabilities.md.user")
    }

    private static var applicationSupportURL: URL? {
        let base = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        return base?.appendingPathComponent("Epistemos")
    }

    // MARK: - Formatting

    private static func formatTokens(_ tokens: Int) -> String {
        if tokens >= 1_000_000 { return String(format: "%.1fM", Double(tokens) / 1_000_000) }
        if tokens >= 1_000 { return String(format: "%.1fK", Double(tokens) / 1_000) }
        return "\(tokens)"
    }
}
