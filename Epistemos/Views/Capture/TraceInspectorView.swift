import SwiftUI
import Foundation
import os

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
                            logger.error("Failed reading trace file \(file.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                        }
                    }
                } catch {
                    logger.error("Failed reading trace directory \(dir.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }

            return loadedTraces.sorted { $0.timestamp > $1.timestamp }
        } catch {
            logger.error("Failed loading capture traces: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }
}

struct TraceInspectorView: View {
    @State private var viewModel = TraceInspectorViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(Color.accentColor)
                Text("Capture Trace Inspector")
                    .font(.headline)
                Spacer()
                Button {
                    viewModel.loadTraces()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.secondary.opacity(0.1))

            HStack(spacing: 10) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Graph projection")
                        .font(.caption.bold())
                    Text(graphProjectionDetail)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.06))
            
            List(viewModel.traces) { trace in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(trace.type.uppercased())
                            .font(.caption.bold())
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(trace.timestamp)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    if !trace.content.isEmpty {
                        Text(trace.content)
                            .font(.caption)
                    }
                }
                .padding(.vertical, 4)
            }
            
            if viewModel.traces.isEmpty {
                Spacer()
                Text("No capture traces found.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            }
        }
        .onAppear {
            viewModel.loadTraces()
        }
        .frame(minWidth: 400, minHeight: 300)
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
