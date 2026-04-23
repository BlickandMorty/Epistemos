import Foundation
import SwiftData

/// Pass 9 — "thought never dies / never gets lost."
///
/// Every completed chat turn writes / overwrites a full markdown
/// transcript of the conversation into
/// `<vault>/Chat Transcripts/<safe-chat-title>.md`, so every chat is
/// always visible in the vault and shows up in the Notes sidebar
/// alongside regular notes. File name is derived from the chat title
/// and the chat id suffix so renames don't create orphan files.
///
/// Invariants:
/// - A missing or unwritable vault silently no-ops; persistence must
///   never block on vault availability.
/// - Writes are atomic (`.atomic`) so a mid-write crash never leaves
///   a half-rendered transcript.
/// - Deterministic filenames — re-running this helper with the same
///   SDChat overwrites the same file, giving a natural "live update"
///   behaviour without us tracking versions ourselves.
/// - Authorship (Pass 8) is carried into the markdown via a per-turn
///   `_(authored by: <model-id>)_` footer so the "involvement" view
///   can later read it straight out of the vault file if desired.
///
/// This is separate from `ConversationPersistence.generateCompanionMarkdown`,
/// which writes to an app-support scratch directory and is primarily
/// for session replay. The vault copy is the user-facing surface.
enum ChatTranscriptVaultWriter {
    /// Root directory inside the vault where transcripts go. Creating
    /// the folder is idempotent; all transcripts land here.
    static let vaultSubdirectory = "Chat Transcripts"

    /// Max characters from the title retained in the filename. Keeps
    /// filenames reasonable on filesystems with path length limits.
    static let maxTitleSlugLength = 80

    /// Entry point. Writes or overwrites the transcript for `chat`
    /// under `vaultURL`. Failures are logged and swallowed — see the
    /// invariant above.
    @MainActor
    static func writeTranscript(for chat: SDChat, vaultURL: URL?) {
        guard let vaultURL else { return }

        let messages = chat.sortedMessages
        guard !messages.isEmpty else { return }

        let directory = vaultURL.appendingPathComponent(vaultSubdirectory, isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        } catch {
            Log.persistence.error(
                "ChatTranscriptVaultWriter: could not create \(vaultSubdirectory, privacy: .public) directory: \(error.localizedDescription, privacy: .public)"
            )
            return
        }

        let fileURL = transcriptFileURL(for: chat, in: directory)
        let body = renderMarkdown(for: chat, messages: messages)
        do {
            try body.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            Log.persistence.error(
                "ChatTranscriptVaultWriter: failed to write \(fileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    /// Derive a stable, filesystem-safe filename from a chat. The id
    /// suffix disambiguates chats whose titles collide after slugging.
    static func transcriptFileName(for chat: SDChat) -> String {
        let slug = titleSlug(chat.title)
        let idSuffix = String(chat.id.prefix(8))
        return "\(slug)--\(idSuffix).md"
    }

    static func transcriptFileURL(for chat: SDChat, in directory: URL) -> URL {
        if let existing = existingTranscriptFileURL(for: chat, in: directory) {
            return existing
        }
        return directory.appendingPathComponent(
            transcriptFileName(for: chat),
            isDirectory: false
        )
    }

    static func titleSlug(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "Untitled Chat" : trimmed
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: " -_")
        let scrubbed = base.unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "-" }
        let collapsed = String(scrubbed)
            .components(separatedBy: CharacterSet(charactersIn: "-"))
            .filter { !$0.isEmpty }
            .joined(separator: "-")
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        if collapsed.count <= maxTitleSlugLength {
            return collapsed
        }
        return String(collapsed.prefix(maxTitleSlugLength))
    }

    private static func existingTranscriptFileURL(for chat: SDChat, in directory: URL) -> URL? {
        let idSuffix = "--\(String(chat.id.prefix(8))).md"
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }
        return files.first { $0.lastPathComponent.hasSuffix(idSuffix) }
    }

    // MARK: - Rendering

    private static let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func renderMarkdown(for chat: SDChat, messages: [SDMessage]) -> String {
        var lines: [String] = []
        lines.append("# \(chat.title)")
        lines.append("")
        lines.append("- **Chat id:** `\(chat.id)`")
        lines.append("- **Created:** \(dateFormatter.string(from: chat.createdAt))")
        lines.append("- **Updated:** \(dateFormatter.string(from: chat.updatedAt))")
        lines.append("- **Type:** \(chat.chatType)")
        if chat.isWorkerSession {
            lines.append("- **Worker session:** yes")
        }
        lines.append("- **Turns:** \(messages.count)")
        lines.append("")
        lines.append("---")
        lines.append("")

        for (index, message) in messages.enumerated() {
            lines.append(renderedTurn(index: index, message: message))
            lines.append("")
        }

        lines.append("---")
        lines.append("_Auto-generated by Epistemos. Updated live as the chat progresses._")
        return lines.joined(separator: "\n")
    }

    private static func renderedTurn(index: Int, message: SDMessage) -> String {
        var parts: [String] = []
        let roleLabel: String
        switch message.role {
        case "user": roleLabel = "User"
        case "assistant": roleLabel = "Assistant"
        case "system": roleLabel = "System"
        default: roleLabel = message.role.capitalized
        }

        parts.append("## \(index + 1). \(roleLabel) · \(dateFormatter.string(from: message.createdAt))")
        parts.append("")

        let content = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !content.isEmpty {
            parts.append(content)
            parts.append("")
        }

        if let trace = message.thinkingTrace?.trimmingCharacters(in: .whitespacesAndNewlines),
           !trace.isEmpty {
            parts.append("<details><summary>Thinking trace</summary>\n")
            parts.append(trace)
            parts.append("\n</details>")
            parts.append("")
        }

        if message.role == "assistant" {
            let provider = message.authoredByProviderID?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let model = message.authoredByModelID?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let attributionPieces: [String] = [provider, model].compactMap {
                ($0?.isEmpty == false) ? $0 : nil
            }
            if !attributionPieces.isEmpty {
                parts.append("_(authored by: \(attributionPieces.joined(separator: " · ")))_")
                parts.append("")
            }
        }

        return parts.joined(separator: "\n")
    }
}
