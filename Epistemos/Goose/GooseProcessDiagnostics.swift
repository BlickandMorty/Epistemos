import Foundation

enum GooseProcessDiagnostics {
    nonisolated static let maxBufferedLineBytes = 16 * 1024
    nonisolated static let maxStoredDiagnosticCharacters = 4096
    private nonisolated static let truncationSuffix = " ... [truncated]"

    nonisolated static func consume(
        from handle: FileHandle,
        record: @escaping @Sendable (String) async -> Void
    ) async {
        var buffer: [UInt8] = []
        buffer.reserveCapacity(maxBufferedLineBytes)
        var truncated = false

        do {
            for try await byte in handle.bytes {
                if byte == 10 || byte == 13 {
                    await emit(buffer: buffer, truncated: truncated, record: record)
                    buffer.removeAll(keepingCapacity: true)
                    truncated = false
                } else if buffer.count < maxBufferedLineBytes {
                    buffer.append(byte)
                } else {
                    truncated = true
                }
            }
        } catch {
            await emit(buffer: buffer, truncated: truncated, record: record)
            await emit(
                buffer: Array(error.localizedDescription.utf8),
                truncated: false,
                record: record
            )
            return
        }

        await emit(buffer: buffer, truncated: truncated, record: record)
    }

    nonisolated static func boundedLine(buffer: [UInt8], truncated: Bool) -> String? {
        var text = String(decoding: buffer, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || truncated else { return nil }
        if truncated || text.count > maxStoredDiagnosticCharacters {
            let budget = max(0, maxStoredDiagnosticCharacters - truncationSuffix.count)
            text = String(text.prefix(budget)) + truncationSuffix
        } else {
            text = String(text.prefix(maxStoredDiagnosticCharacters))
        }
        return text.isEmpty ? nil : text
    }

    private nonisolated static func emit(
        buffer: [UInt8],
        truncated: Bool,
        record: @escaping @Sendable (String) async -> Void
    ) async {
        guard let line = boundedLine(buffer: buffer, truncated: truncated) else { return }
        await record(line)
    }
}
