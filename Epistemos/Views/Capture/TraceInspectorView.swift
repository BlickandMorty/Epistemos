import SwiftUI
import Foundation
import os

nonisolated enum TraceInspectorDiagnostics {
    static let maxLogMessageCharacters = 240
    static let maxItemNameCharacters = 96

    static func externalLogMessage(_ operation: String, error: Error) -> String {
        let fallback = boundedLogMessage(operation, fallback: "Trace load failed")
        let nsError = error as NSError
        return boundedLogMessage(
            "\(fallback) (domain=\(safeDomain(nsError.domain)) code=\(nsError.code))",
            fallback: fallback
        )
    }

    static func logName(for url: URL) -> String {
        let name = url.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        return boundedLogMessage(name, limit: maxItemNameCharacters, fallback: "trace item")
    }

    static func boundedLogMessage(
        _ message: String,
        limit: Int = maxLogMessageCharacters,
        fallback: String = "Trace load failed"
    ) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }
        guard trimmed.count > limit else { return trimmed }

        let suffix = "..."
        let end = trimmed.index(trimmed.startIndex, offsetBy: max(0, limit - suffix.count))
        return String(trimmed[..<end]) + suffix
    }

    private static func safeDomain(_ domain: String) -> String {
        let trimmed = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Error" }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        guard trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return "Error"
        }
        guard trimmed.count <= 80 else {
            let end = trimmed.index(trimmed.startIndex, offsetBy: 80)
            return String(trimmed[..<end])
        }
        return trimmed
    }
}

struct ParsedTraceEvent: Identifiable, Sendable {
    let id = UUID()
    let type: String
    let sessionId: String
    let content: String
    let timestamp: String
}

@MainActor
@Observable
class TraceInspectorViewModel {
    var traces: [ParsedTraceEvent] = []
    var graphProjectionReport: GraphEventAuditProjectionReport = .empty

    @ObservationIgnored private let graphProjectionReportProvider: @Sendable () -> GraphEventAuditProjectionReport
    @ObservationIgnored private var loadTask: Task<Void, Never>?

    init(
        graphProjectionReportProvider: @escaping @Sendable () -> GraphEventAuditProjectionReport = {
            GraphEventAuditProjectionService().auditReport(limit: 100)
        }
    ) {
        self.graphProjectionReportProvider = graphProjectionReportProvider
    }

    deinit {
        loadTask?.cancel()
    }
    
    func loadTraces() {
        loadTask?.cancel()

        let reportProvider = graphProjectionReportProvider
        loadTask = Task(priority: .utility) {
            let snapshot = await Task.detached(priority: .utility) {
                (
                    report: reportProvider(),
                    traces: Self.loadTraceFiles()
                )
            }.value

            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard !Task.isCancelled else { return }
                self.refreshGraphProjectionReport(snapshot.report)
                self.traces = snapshot.traces
            }
        }
    }

    private func refreshGraphProjectionReport(_ report: GraphEventAuditProjectionReport) {
        graphProjectionReport = report
    }

    private nonisolated static func loadTraceFiles() -> [ParsedTraceEvent] {
        let fileManager = FileManager.default
        let logger = Logger(
            subsystem: "com.epistemos.app",
            category: "TraceInspector"
        )

        do {
            let appSupport = FoundationSafety.userApplicationSupportDirectory(fileManager: fileManager)
            let baseDir = appSupport.appendingPathComponent("com.epistemos.app/traces/production")

            let dateDirs = try fileManager.contentsOfDirectory(at: baseDir, includingPropertiesForKeys: nil)
            var loadedTraces: [ParsedTraceEvent] = []

            for dir in dateDirs {
                var isDir: ObjCBool = false
                guard fileManager.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else {
                    continue
                }

                do {
                    let files = try fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
                    for file in files where file.pathExtension == "jsonl" {
                        do {
                            let content = try String(contentsOf: file, encoding: .utf8)
                            for line in content.components(separatedBy: .newlines) where !line.isEmpty {
                                guard let data = line.data(using: .utf8),
                                      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                                    continue
                                }

                                let eventType = json["type"] as? String ?? ""
                                if eventType.hasPrefix("capture_") || eventType == "structure_generated" || eventType == "note_persisted" || eventType == "graph_write_attempted" || eventType == "evidence_linked" {
                                    loadedTraces.append(
                                        ParsedTraceEvent(
                                            type: eventType,
                                            sessionId: json["sessionId"] as? String ?? "",
                                            content: json["content"] as? String ?? "",
                                            timestamp: json["ts"] as? String ?? ""
                                        )
                                    )
                                }
                            }
                        } catch {
                            let failure = TraceInspectorDiagnostics.externalLogMessage(
                                "Failed reading trace file",
                                error: error
                            )
                            let traceFile = TraceInspectorDiagnostics.logName(for: file)
                            logger.error("\(failure, privacy: .public) file=\(traceFile, privacy: .public)")
                        }
                    }
                } catch {
                    let failure = TraceInspectorDiagnostics.externalLogMessage(
                        "Failed reading trace directory",
                        error: error
                    )
                    let traceDirectory = TraceInspectorDiagnostics.logName(for: dir)
                    logger.error("\(failure, privacy: .public) directory=\(traceDirectory, privacy: .public)")
                }
            }

            return loadedTraces.sorted { $0.timestamp > $1.timestamp }
        } catch {
            let failure = TraceInspectorDiagnostics.externalLogMessage(
                "Failed loading capture traces",
                error: error
            )
            logger.error("\(failure, privacy: .public)")
            return []
        }
    }
}

struct TraceInspectorView: View {
    let theme: EpistemosTheme
    var onDismiss: (() -> Void)?

    @State private var viewModel = TraceInspectorViewModel()

    init(theme: EpistemosTheme, onDismiss: (() -> Void)? = nil) {
        self.theme = theme
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            inspectorHeader

            Divider()
                .opacity(theme.isDark ? 0.18 : 0.24)

            graphProjectionRow

            traceScroll
        }
        .onAppear {
            viewModel.loadTraces()
        }
        .frame(minWidth: 430, minHeight: 310)
        .pixelPanel(theme: theme)
        .foregroundStyle(theme.resolved.foreground.color)
    }

    private var inspectorHeader: some View {
        HStack(spacing: 10) {
            PixelGlyph(kind: .clock, accent: theme.resolved.accent.color)
                .frame(width: 26, height: 26)

            PixelPanelTitle(text: "Capture Trace Inspector", theme: theme, size: 14)

            Spacer()

            iconButton(systemName: "arrow.clockwise") {
                viewModel.loadTraces()
            }

            if let onDismiss {
                iconButton(systemName: "xmark") {
                    onDismiss()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var graphProjectionRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.resolved.accent.color.opacity(0.82))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 3) {
                Text("Graph projection")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(theme.textPrimary)
                Text(graphProjectionDetail)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(PixelPanelBackground.actionSurface(for: theme))
    }

    private var traceScroll: some View {
        ScrollView {
            LazyVStack(spacing: 7) {
                if viewModel.traces.isEmpty {
                    emptyTraceState
                } else {
                    ForEach(viewModel.traces) { trace in
                        traceRow(trace)
                    }
                }
            }
            .padding(12)
        }
    }

    private var emptyTraceState: some View {
        VStack(spacing: 8) {
            PixelGlyph(kind: .capture, accent: theme.resolved.accent.color.opacity(0.72))
                .frame(width: 30, height: 30)

            Text("No capture traces found.")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
    }

    private func traceRow(_ trace: ParsedTraceEvent) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(trace.type.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Spacer(minLength: 8)

                Text(trace.timestamp)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(1)
            }

            if !trace.content.isEmpty {
                Text(trace.content)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(PixelPanelBackground.actionSurface(for: theme))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(theme.resolved.accent.color.opacity(theme.isDark ? 0.14 : 0.18), lineWidth: 0.6)
        }
    }

    private func iconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(theme.textPrimary)
                .frame(width: 28, height: 28)
                .background {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(PixelPanelBackground.actionSurface(for: theme))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(theme.textTertiary.opacity(theme.isDark ? 0.12 : 0.18), lineWidth: 0.6)
                }
        }
        .buttonStyle(.plain)
    }

    private var graphProjectionDetail: String {
        let report = viewModel.graphProjectionReport
        guard !report.isEmpty else {
            return "No durable GraphEvents projected"
        }

        let latest = report.latestEventID.map { String($0.prefix(12)) } ?? "none"
        return "\(report.eventCount) events | \(report.nodeCount) nodes | \(report.edgeCount) edges | latest \(latest)"
    }
}
