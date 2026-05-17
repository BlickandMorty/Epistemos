import Foundation
import SwiftUI

// MARK: - Note Chat Sidebar
// Popover showing per-note chat history from NoteChatState.messages.

struct NoteChatSidebar: View {
    @Environment(NoteChatState.self) private var noteChat
    @Environment(UIState.self) private var ui
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var autoFollow = ScrollAutoFollowState(
        attachThreshold: 24,
        detachThreshold: 72
    )

    private var theme: EpistemosTheme { ui.theme.surfaceVariant(.other) }

    var body: some View {
        VStack(spacing: 0) {
            if noteChat.messages.isEmpty {
                emptyState
            } else {
                messageList
            }
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(noteChat.messages) { msg in
                        messageRow(msg)
                            .id(msg.id)
                    }

                    Color.clear
                        .frame(height: 1)
                }
                .padding(14)
            }
            .onScrollGeometryChange(
                for: CGFloat.self,
                of: { geometry in
                    ScrollStability.distanceToBottom(for: geometry)
                }
            ) { _, distanceToBottom in
                let next = ScrollStability.updatedAutoFollowState(
                    from: autoFollow,
                    distanceToBottom: distanceToBottom
                )
                guard next != autoFollow else { return }
                autoFollow = next
            }
            .onChange(of: noteChat.messages.count) { _, _ in
                guard autoFollow.isFollowingBottom else { return }
                if let last = noteChat.messages.last {
                    autoFollow.markProgrammaticScrollToBottom()
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                Task { @MainActor in
                    guard let last = noteChat.messages.last else { return }
                    autoFollow.markProgrammaticScrollToBottom()
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private func messageRow(_ msg: AssistantMessage) -> some View {
        let displayContent = msg.role == .assistant
            ? UserFacingModelOutput.finalVisibleText(from: msg.content)
            : msg.content
        let provenanceEntries = msg.role == .assistant
            ? NoteVaultProvenanceParser.entries(from: displayContent)
            : []
        return VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(msg.role == .user ? "You" : "Assistant")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                    Spacer()
                    Text(msg.createdAt.formatted(.relative(presentation: .named)))
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary.opacity(0.5))
                }
                Text(displayContent)
                    .font(msg.role == .assistant
                        ? Font(ClaudeAppTypography.noteAssistantUIFont(size: 12))
                        : .system(size: 12))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .lineSpacing(2)

                if msg.role == .assistant,
                   let thinkingTrace = msg.thinkingTrace?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !thinkingTrace.isEmpty {
                    ThinkingTrailView(
                        content: thinkingTrace,
                        durationSeconds: msg.thinkingDurationSeconds
                    )
                    .padding(.top, 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                msg.role == .user
                    ? theme.resolved.foreground.color.opacity(0.04)
                    : theme.resolved.accent.color.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )

            if !provenanceEntries.isEmpty {
                NoteVaultProvenanceCardsView(entries: provenanceEntries, theme: theme)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(theme.textTertiary.opacity(0.4))

            Text("No messages yet")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.textSecondary)

            Text("Use the Ask field to chat")
                .font(.system(size: 11))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

nonisolated struct NoteVaultProvenanceEntry: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let path: String?
    let reasons: [String]
}

nonisolated enum NoteVaultProvenanceParser {
    static func entries(from content: String) -> [NoteVaultProvenanceEntry] {
        var entries: [NoteVaultProvenanceEntry] = []
        var current: PendingEntry?

        func flush() {
            guard let entry = current else { return }
            entries.append(
                NoteVaultProvenanceEntry(
                    id: "\(entry.title)|\(entry.path ?? "")|\(entries.count)",
                    title: entry.title,
                    path: entry.path,
                    reasons: entry.reasons.isEmpty ? ["Indexed vault match"] : entry.reasons
                )
            )
            current = nil
        }

        for rawLine in content.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            if let parsed = parseBullet(line) {
                flush()
                current = PendingEntry(title: parsed.title, path: parsed.path, reasons: [])
                continue
            }
            if let reasons = parseReasons(line), current != nil {
                current?.reasons = uniqueReasons((current?.reasons ?? []) + reasons)
            }
        }
        flush()

        guard content.localizedCaseInsensitiveContains("indexed vault matches")
                || content.localizedCaseInsensitiveContains("vault provenance:") else {
            return []
        }
        return dedupedEntries(entries)
    }

    private static func parseBullet(_ line: String) -> (title: String, path: String?)? {
        guard line.hasPrefix("- **") else { return nil }
        let titleStart = line.index(line.startIndex, offsetBy: 4)
        guard let titleEnd = line[titleStart...].range(of: "**")?.lowerBound else {
            return nil
        }
        let title = String(line[titleStart..<titleEnd])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }

        var path: String?
        if let pathStartMarker = line[titleEnd...].range(of: "(`")?.upperBound,
           let pathEnd = line[pathStartMarker...].range(of: "`)")?.lowerBound {
            let parsedPath = String(line[pathStartMarker..<pathEnd])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !parsedPath.isEmpty {
                path = parsedPath
            }
        }
        return (title, path)
    }

    private static func parseReasons(_ line: String) -> [String]? {
        guard line.lowercased().hasPrefix("why:"),
              let colon = line.firstIndex(of: ":") else { return nil }
        let remainder = line[line.index(after: colon)...]
        let reasons = remainder
            .split(separator: ";")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return reasons.isEmpty ? nil : reasons
    }

    private static func dedupedEntries(
        _ entries: [NoteVaultProvenanceEntry]
    ) -> [NoteVaultProvenanceEntry] {
        var merged: [NoteVaultProvenanceEntry] = []
        var indexesByKey: [String: Int] = [:]

        for entry in entries {
            let key = "\(entry.title.lowercased())|\((entry.path ?? "").lowercased())"
            if let index = indexesByKey[key] {
                let existing = merged[index]
                merged[index] = NoteVaultProvenanceEntry(
                    id: existing.id,
                    title: existing.title,
                    path: existing.path,
                    reasons: uniqueReasons(existing.reasons + entry.reasons)
                )
            } else {
                indexesByKey[key] = merged.count
                merged.append(entry)
            }
        }
        return merged
    }

    private static func uniqueReasons(_ reasons: [String]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for reason in reasons {
            if seen.insert(reason).inserted {
                ordered.append(reason)
            }
        }
        return ordered
    }

    private struct PendingEntry {
        let title: String
        let path: String?
        var reasons: [String]
    }
}

private struct NoteVaultProvenanceCardsView: View {
    let entries: [NoteVaultProvenanceEntry]
    let theme: EpistemosTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 11, weight: .semibold))
                Text("Vault provenance")
                    .font(.system(size: 10, weight: .semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(theme.resolved.accent.color)

            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(2)
                    if let path = entry.path {
                        Text(path)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(theme.textTertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(entry.reasons.prefix(5)), id: \.self) { reason in
                            Text(reason)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(theme.textSecondary)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(.top, entry.id == entries.first?.id ? 0 : 6)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            theme.resolved.accent.color.opacity(0.05),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.resolved.accent.color.opacity(0.18), lineWidth: 1)
        )
    }
}
