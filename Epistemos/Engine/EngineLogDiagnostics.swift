import Foundation

nonisolated enum EngineLogDiagnostics {
    static func logMessage(for error: Error, fallback: String) -> String {
        let detail = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return detail.isEmpty ? fallback : "\(fallback): \(detail)"
    }
}
