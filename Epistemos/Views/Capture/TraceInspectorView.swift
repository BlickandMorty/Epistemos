import SwiftUI
import Foundation

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
        Task {
            let sortedTraces = await Task.detached {
                let appSupport = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
                guard let baseDir = appSupport?.appendingPathComponent("com.epistemos.app/traces/production") else { return [ParsedTraceEvent]() }
                
                var loadedTraces: [ParsedTraceEvent] = []
                
                let fileManager = FileManager.default
                guard let dateDirs = try? fileManager.contentsOfDirectory(at: baseDir, includingPropertiesForKeys: nil) else { return [ParsedTraceEvent]() }
                
                for dir in dateDirs {
                    var isDir: ObjCBool = false
                    guard fileManager.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else { continue }
                    
                    guard let files = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
                    for file in files where file.pathExtension == "jsonl" {
                        if let content = try? String(contentsOf: file, encoding: .utf8) {
                            let lines = content.components(separatedBy: .newlines)
                            for line in lines where !line.isEmpty {
                                if let data = line.data(using: .utf8),
                                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                    let eventType = json["type"] as? String ?? ""
                                    if eventType.hasPrefix("capture_") || eventType == "structure_generated" || eventType == "note_persisted" || eventType == "graph_write_attempted" || eventType == "evidence_linked" {
                                        let parsed = ParsedTraceEvent(
                                            type: eventType,
                                            sessionId: json["sessionId"] as? String ?? "",
                                            content: json["content"] as? String ?? "",
                                            timestamp: json["ts"] as? String ?? ""
                                        )
                                        loadedTraces.append(parsed)
                                    }
                                }
                            }
                        }
                    }
                }
                
                return loadedTraces.sorted { $0.timestamp > $1.timestamp }
            }.value
            
            self.traces = sortedTraces
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
