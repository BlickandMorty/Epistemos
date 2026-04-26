import Foundation
import Testing

/// Wave 4.3 regression guard: every Swift-side `MTLDevice.makeBuffer` /
/// `MTLHeap.makeBuffer` call MUST use `.storageModeShared` so we keep
/// the Apple Silicon UMA zero-copy CPU/GPU access pattern
/// (`docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md` Wave 4.3,
///  cross-ref dpp §4.3 Sprint 3 deep perf).
///
/// MTLStorageModeManaged forces CPU/GPU memory copies on macOS even on
/// Apple Silicon. MTLStorageModePrivate makes CPU writes impossible.
/// Both are wrong defaults for our workloads (graph state shuttle, MLX
/// embeddings, Mamba-2 inference) where the CPU writes input then the
/// GPU reads it then the CPU reads output — the textbook UMA case.
///
/// This test scans every Swift file under `Epistemos/` for buffer
/// allocations and fails if any of them use a non-shared storage mode.
/// New code that genuinely needs a different mode (e.g. a private
/// upload-only buffer) can opt out by adding `// W4.3-OPTOUT: <reason>`
/// to the line; the scanner skips lines carrying that marker.
///
/// Argument-buffer migration (the second half of the dpp Wave 4.3
/// goal) lives in graph-engine's Rust render path and is tracked as a
/// separate follow-up. The Swift side stays the canonical UMA path.
@Suite("Metal UMA storage mode regression guard (Wave 4.3)")
nonisolated struct MetalUMAStorageModeTests {

    private static func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // EpistemosTests/
            .deletingLastPathComponent() // repo root
    }

    private static func walkSwiftFiles(under root: URL) throws -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        var urls: [URL] = []
        while let item = enumerator.nextObject() as? URL {
            guard item.pathExtension == "swift" else { continue }
            urls.append(item)
        }
        return urls.sorted { $0.path < $1.path }
    }

    @Test("every Swift makeBuffer call uses .storageModeShared (UMA zero-copy)")
    func everyMakeBufferCallUsesShared() throws {
        let root = Self.repoRoot().appendingPathComponent("Epistemos", isDirectory: true)
        let files = try Self.walkSwiftFiles(under: root)
        #expect(!files.isEmpty, "scan must find Swift files under Epistemos/")

        // We treat the call as a multi-line block: from the line containing
        // `.makeBuffer(` to the next line that contains a closing `)` at
        // the call's indent. The block must contain `.storageModeShared`
        // OR `// W4.3-OPTOUT:`.
        var offenders: [String] = []
        for fileURL in files {
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            var idx = 0
            while idx < lines.count {
                let line = lines[idx]
                // Skip unrelated mentions (heap.makeBuffer in helper
                // signatures get caught too — that's fine, they pass the
                // policy check).
                if line.contains(".makeBuffer(") {
                    // Collect the call body up to the matching `)` at the
                    // same indent (or 5 lines, whichever first — Metal
                    // makeBuffer calls are short).
                    var body = line
                    var probe = idx + 1
                    while probe < lines.count && probe < idx + 6 {
                        body += "\n" + lines[probe]
                        if lines[probe].contains(")") { break }
                        probe += 1
                    }
                    if body.contains("// W4.3-OPTOUT:") {
                        // Explicitly opted-out.
                    } else if body.contains(".storageModeShared") {
                        // Compliant.
                    } else {
                        let rel = fileURL.path.replacingOccurrences(of: Self.repoRoot().path + "/", with: "")
                        offenders.append("\(rel):\(idx + 1) — makeBuffer without .storageModeShared")
                    }
                }
                idx += 1
            }
        }

        let detail = offenders.joined(separator: "\n  - ")
        #expect(offenders.isEmpty,
                "Wave 4.3 UMA policy violated by:\n  - \(detail)\nIf the call genuinely needs a different storage mode, add `// W4.3-OPTOUT: <reason>` to the call line.")
    }

    @Test("no Swift file declares .storageModeManaged (UMA antipattern)")
    func noManagedStorageModeAnywhere() throws {
        let root = Self.repoRoot().appendingPathComponent("Epistemos", isDirectory: true)
        let files = try Self.walkSwiftFiles(under: root)
        var offenders: [String] = []
        for fileURL in files {
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            for (idx, line) in source.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                if line.contains(".storageModeManaged") || line.contains("MTLStorageModeManaged") {
                    if line.contains("// W4.3-OPTOUT:") { continue }
                    let rel = fileURL.path.replacingOccurrences(of: Self.repoRoot().path + "/", with: "")
                    offenders.append("\(rel):\(idx + 1) — \(line.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
        let detail = offenders.joined(separator: "\n  - ")
        #expect(offenders.isEmpty,
                "Wave 4.3 forbids .storageModeManaged — forces CPU/GPU copies even on UMA Apple Silicon.\n  - \(detail)")
    }
}
