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
    
    func loadTraces() {
        Task(priority: .utility) {
            let sortedTraces = await Task.detached(priority: .utility) { () -> [ParsedTraceEvent] in
                let fileManager = FileManager.default
                let logger = Logger(
                    subsystem: "com.epistemos.app",
                    category: "TraceInspector"
                )

                do {
                    let appSupport = try fileManager.url(
                        for: .applicationSupportDirectory,
                        in: .userDomainMask,
                        appropriateFor: nil,
                        create: false
                    )
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
            }.value

            await MainActor.run {
                self.traces = sortedTraces
            }
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
}
