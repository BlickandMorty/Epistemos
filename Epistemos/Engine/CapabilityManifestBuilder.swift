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

    /// Render the system-prompt brief. Deliberately short — ~400
    /// bytes — because stuffing 3KB of meta-instruction into every
    /// turn hurts model quality more than it helps. Models don't
    /// need a map of app surfaces or a "user preferences" block to
    /// answer; they need to know who they are, what they have access
    /// to, and a couple of rules to avoid obvious pitfalls (fetch-
    /// tool-on-inlined-content, hallucinating capabilities). The
    /// user's custom overrides still come in via
    /// `Capabilities.md.user` when present.
    static func render(_ context: Context) -> String {
        var lines: [String] = []
        lines.append("You are Epistemos' assistant — a macOS PKM app with on-device AI.")

        var identity = "Running on **\(context.modelLabel)**"
        if !context.providerLabel.isEmpty {
            identity += " (\(context.providerLabel))"
        }
        identity += " in **\(context.operatingMode.displayName)** mode."
        lines.append(identity)

        if let vaultName = context.vaultName {
            lines.append("Active vault: **\(vaultName)**.")
        }

        if !context.enabledToolNames.isEmpty {
            let toolList = context.enabledToolNames
                .prefix(12)
                .map { "`\($0)`" }
                .joined(separator: ", ")
            let more = context.enabledToolNames.count > 12 ? " (+more)" : ""
            lines.append("Tools available: \(toolList)\(more).")
        } else {
            lines.append(
                "No tools are available on this turn. Answer in plain text only. Do not emit tool-call JSON, `<tool_call>` tags, or policy/status tokens."
            )
        }

        lines.append("")
        lines.append("Rules:")
        lines.append("1. Attached notes/files are inlined in the user prompt already — answer from the inlined text; don't call read/fetch tools for content that's right there.")
        lines.append("2. Don't claim capabilities you don't currently have (no browsing unless a web tool is listed, no shell unless terminal is listed, etc.).")
        lines.append("3. If a listed tool needs approval, call the tool; Epistemos will show the native approval card. Do not ask the user to type an approval phrase.")
        lines.append("4. Be direct and concise. If you're uncertain, say so.")

        if let overrides = loadUserOverrides() {
            lines.append("")
            lines.append("User preferences:")
            lines.append(overrides)
        }

        return lines.joined(separator: "\n")
    }

    /// Alias for `render` — kept for source compatibility with callers
    /// that used to route local paths to a separate compact variant.
    /// The single `render` is already lean enough for every model.
    static func renderCompact(_ context: Context) -> String {
        render(context)
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

    // MARK: - Paths

    static var manifestFileURL: URL? {
        applicationSupportURL?.appendingPathComponent("runtime/Capabilities.md")
    }

    static var userOverridesFileURL: URL? {
        applicationSupportURL?.appendingPathComponent("Capabilities.md.user")
    }

    private static var applicationSupportURL: URL? {
        FoundationSafety.userApplicationSupportDirectory()
            .appendingPathComponent("Epistemos", isDirectory: true)
    }

    // MARK: - Formatting

    private static func formatTokens(_ tokens: Int) -> String {
        if tokens >= 1_000_000 { return String(format: "%.1fM", Double(tokens) / 1_000_000) }
        if tokens >= 1_000 { return String(format: "%.1fK", Double(tokens) / 1_000) }
        return "\(tokens)"
    }
}
