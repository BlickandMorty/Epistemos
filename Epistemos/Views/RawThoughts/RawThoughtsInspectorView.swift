import SwiftUI
import OSLog

// MARK: - RawThoughtsInspectorView
// Patch 5 — read-only inspector for one Raw Thoughts run folder.
// Renders manifest fields, the streaming `events.jsonl`, and the optional
// `summary.md`. All file I/O happens off the MainActor.

struct RawThoughtsInspectorView: View {
    let run: RawThoughtsState.RunSummary

    @Environment(\.dismiss) private var dismiss

    @State private var eventLines: [String] = []
    @State private var summaryMarkdown: String?
    @State private var loadError: String?
    @State private var isLoading = false

    nonisolated private static let log = Logger(subsystem: "com.epistemos", category: "RawThoughtsInspector")

    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .medium
        return f
    }()

    struct RunArtifacts: Sendable {
        let eventLines: [String]
        let summaryMarkdown: String?
        let loadError: String?
    }

    nonisolated static let maxVisibleEventLines = 500
    nonisolated static let maxEventTailBytes: UInt64 = 256 * 1024

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            manifestRow
            Divider()
            if isLoading {
                ProgressView("Loading run artifacts…")
                    .controlSize(.small)
                    .padding(.vertical, 4)
            }
            if let summaryMarkdown {
                summaryView(body: summaryMarkdown)
                Divider()
            }
            eventsView
            if let loadError {
                Text(loadError)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .padding(20)
        .frame(minWidth: 600, idealWidth: 760, minHeight: 460, idealHeight: 540)
        .task {
            await loadArtifacts()
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "brain")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(run.model.isEmpty ? run.provider : run.model)
                    .font(.headline)
                Text("Run \(run.id)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([run.folderURL])
            }
            Button("Close") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
    }

    private var manifestRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            field(label: "Provider", value: run.provider)
            field(label: "Model", value: run.model)
            field(label: "Status", value: run.status)
            field(label: "Started", value: Self.dateTimeFormatter.string(from: run.startedAt))
            if let endedAt = run.endedAt {
                field(label: "Ended", value: Self.dateTimeFormatter.string(from: endedAt))
            }
        }
    }

    private func field(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.caption.monospaced())
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func summaryView(body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Summary")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ScrollView {
                Text(body)
                    .font(.caption)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 120)
        }
    }

    private var eventsView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("Events")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("(\(eventLines.count))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(eventLines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: .infinity)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }

    // MARK: - Loading

    private func loadArtifacts() async {
        isLoading = true
        defer { isLoading = false }
        let folderURL = run.folderURL
        let result = await Task.detached(priority: .utility) {
            Self.loadRunArtifacts(folderURL: folderURL)
        }.value

        eventLines = result.eventLines
        summaryMarkdown = result.summaryMarkdown
        loadError = result.loadError
    }

    nonisolated static func loadRunArtifacts(folderURL: URL) -> RunArtifacts {
        let eventsURL = folderURL.appendingPathComponent("events.jsonl", isDirectory: false)
        let summaryURL = folderURL.appendingPathComponent("summary.md", isDirectory: false)

        var events: [String] = []
        var summary: String?
        var error: String?

        do {
            events = try loadEventTailLines(eventsURL: eventsURL)
        } catch {
            log.warning("RawThoughtsInspectorView: events read failed: \(String(describing: error), privacy: .public)")
        }

        if let summaryBody = try? String(contentsOf: summaryURL, encoding: .utf8) {
            summary = summaryBody
        }

        if events.isEmpty && summary == nil {
            error = "No artifacts found in \(folderURL.lastPathComponent)"
        }

        return RunArtifacts(
            eventLines: events,
            summaryMarkdown: summary,
            loadError: error
        )
    }

    nonisolated static func loadEventTailLines(
        eventsURL: URL,
        maxLines: Int = maxVisibleEventLines,
        maxBytes: UInt64 = maxEventTailBytes
    ) throws -> [String] {
        guard maxLines > 0, maxBytes > 0 else { return [] }

        let handle = try FileHandle(forReadingFrom: eventsURL)
        defer {
            try? handle.close()
        }

        let fileSize = try handle.seekToEnd()
        let offset = fileSize > maxBytes ? fileSize - maxBytes : 0
        try handle.seek(toOffset: offset)

        guard let data = try handle.readToEnd(), !data.isEmpty else {
            return []
        }

        let body = String(decoding: data, as: UTF8.self)
        var lines = body
            .split(whereSeparator: { $0.isNewline })
            .map(String.init)

        if offset > 0, !lines.isEmpty {
            lines.removeFirst()
        }

        if lines.count > maxLines {
            return Array(lines.suffix(maxLines))
        }
        return lines
    }
}
