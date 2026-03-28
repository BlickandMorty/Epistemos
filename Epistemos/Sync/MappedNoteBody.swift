import Foundation

// MARK: - MappedNoteBody
// ~Copyable wrapper for memory-mapped note file data.
// Avoids String allocation during bulk vault operations (hashing, search).
// The consuming `toString()` method allocates a String only when actually needed.

struct MappedNoteBody: ~Copyable {
    private let data: Data

    /// Load a note body from a file URL using memory mapping when possible.
    /// Falls back to regular read if mapping fails.
    init(url: URL) throws {
        self.data = try Data(contentsOf: url, options: .mappedIfSafe)
    }

    /// Raw byte count (no String allocation).
    var byteCount: Int { data.count }

    /// Whether the body is empty.
    var isEmpty: Bool { data.isEmpty }

    /// Check if the raw bytes contain a needle without creating a String.
    /// Useful for fast vault-wide keyword search before expensive String conversion.
    func contains(_ needle: [UInt8]) -> Bool {
        guard !needle.isEmpty, needle.count <= data.count else { return false }
        return data.withUnsafeBytes { buffer in
            guard let base = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return false }
            let count = buffer.count
            let needleCount = needle.count
            outer: for i in 0...(count - needleCount) {
                for j in 0..<needleCount {
                    if base[i + j] != needle[j] { continue outer }
                }
                return true
            }
            return false
        }
    }

    /// Return the first N bytes as Data (zero-copy slice for hashing).
    func prefix(_ maxBytes: Int) -> Data {
        data.prefix(maxBytes)
    }

    /// Consume the mapped data and produce a String. Allocates once.
    consuming func toString() -> String {
        FoundationSafety.decodedText(from: data) ?? ""
    }
}
