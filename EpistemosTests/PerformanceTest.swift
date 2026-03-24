import Foundation
import Testing
@testable import Epistemos

// MARK: - Performance Test

/// Verifies adapter loading does not cause inference speed degradation.
/// Per ANCHOR 5: with adapter loaded, speed must be within 10% of base model.
/// Per ANCHOR 3 GAP 1: >10% degradation → fusion bug detected.
///
/// Since actual model inference requires a downloaded model, this suite tests:
/// 1. Adapter loading/unloading is fast (< 100ms overhead)
/// 2. No fusion code exists in the codebase
/// 3. Memory tracking is accurate
/// 4. Adapter hot-swap doesn't leak resources
@Suite("Performance and Speed")
struct PerformanceTest {

    @Test("Adapter load/unload cycle is fast")
    func loadUnloadSpeed() async throws {
        let loader = AdapterLoader(maxSimultaneousAdapters: 5)

        let adapterDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kf-perf-adapter-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: adapterDir, withIntermediateDirectories: true)
        try Data([0x00]).write(to: adapterDir.appendingPathComponent("adapter_weights.safetensors"))
        defer { try? FileManager.default.removeItem(at: adapterDir) }

        let record = AdapterRecord(
            id: UUID(), name: "PerfTest", type: .knowledge,
            adapterPath: adapterDir,
            metadataPath: adapterDir.appendingPathComponent("meta.json"),
            sourceVault: "test", createdAt: Date(), qualityScore: nil,
            isActive: false, baseModel: "test", loraRank: 32,
            parameterCount: 32 * 4096 * 7 * 2, trainingExamples: 100
        )

        let start = Date()

        // Load and unload 10 times
        for _ in 0..<10 {
            try await loader.load(record)
            await loader.unload(record.id)
        }

        let elapsed = Date().timeIntervalSince(start)
        // 10 cycles should complete in well under 1 second
        #expect(elapsed < 1.0, "10 load/unload cycles took \(elapsed)s — should be < 1s")
    }

    @Test("Memory tracking accumulates correctly")
    func memoryTracking() async throws {
        let loader = AdapterLoader(maxSimultaneousAdapters: 10)

        var dirs: [URL] = []
        var records: [AdapterRecord] = []

        for i in 0..<3 {
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("kf-perf-mem-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try Data([0x00]).write(to: dir.appendingPathComponent("adapter_weights.safetensors"))
            dirs.append(dir)

            records.append(AdapterRecord(
                id: UUID(), name: "Mem\(i)", type: .knowledge,
                adapterPath: dir,
                metadataPath: dir.appendingPathComponent("meta.json"),
                sourceVault: "test", createdAt: Date(), qualityScore: nil,
                isActive: false, baseModel: "test", loraRank: 32,
                parameterCount: 1024 * 1024,  // ~1MB
                trainingExamples: 100
            ))
        }
        defer { dirs.forEach { try? FileManager.default.removeItem(at: $0) } }

        // Load all
        for record in records {
            try await loader.load(record)
        }

        let totalMB = await loader.totalMemoryUsageMB()
        #expect(totalMB >= 3, "3 adapters at ~2MB each should total >= 3MB, got \(totalMB)")

        // Unload one
        await loader.unload(records[0].id)
        let afterUnload = await loader.totalMemoryUsageMB()
        #expect(afterUnload < totalMB, "Memory should decrease after unloading")

        // Unload all
        await loader.unloadAll()
        let afterAll = await loader.totalMemoryUsageMB()
        #expect(afterAll == 0, "Memory should be 0 after unloading all")
    }

    @Test("No fusion code in entire KnowledgeFusion codebase")
    func noFusionCodeAnywhere() throws {
        let basePath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Epistemos/KnowledgeFusion")

        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: basePath, includingPropertiesForKeys: nil) else { return }

        var checkedFiles = 0
        while let url = enumerator.nextObject() as? URL {
            let ext = url.pathExtension
            guard ext == "swift" || ext == "py" else { continue }
            checkedFiles += 1

            let content = try String(contentsOf: url, encoding: .utf8)

            // Strip comments for Swift, strip # comments for Python
            let codeOnly: String
            if ext == "swift" {
                codeOnly = content.components(separatedBy: .newlines)
                    .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                    .joined(separator: "\n")
            } else {
                codeOnly = content.components(separatedBy: .newlines)
                    .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("#") }
                    .joined(separator: "\n")
            }

            // Check for actual fusion function calls (not safety documentation)
            #expect(!codeOnly.contains("merge_weights=True"),
                   "FUSION BUG: merge_weights=True in \(url.lastPathComponent)")
            #expect(!codeOnly.contains("merge_adapter("),
                   "FUSION BUG: merge_adapter() call in \(url.lastPathComponent)")
            #expect(!codeOnly.contains(".fuseAdapter("),
                   "FUSION BUG: .fuseAdapter() call in \(url.lastPathComponent)")
        }

        #expect(checkedFiles > 10, "Should have checked multiple files, found \(checkedFiles)")
    }

    @Test("Adapter format is .safetensors (not GGUF)")
    func adapterFormat() throws {
        // Per ANCHOR 3, GAP 3: Default to MLX .safetensors format.
        // Do NOT attempt GGUF export from 4-bit base.
        let basePath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Epistemos/KnowledgeFusion")

        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: basePath, includingPropertiesForKeys: nil) else { return }

        while let url = enumerator.nextObject() as? URL {
            let ext = url.pathExtension
            guard ext == "swift" || ext == "py" else { continue }
            let content = try String(contentsOf: url, encoding: .utf8)

            // Should reference .safetensors, not .gguf
            if content.contains("adapter_weights") {
                #expect(content.contains("safetensors"),
                       "Adapter format should be .safetensors in \(url.lastPathComponent)")
            }

            // Should not have GGUF export code
            let codeOnly = content.components(separatedBy: .newlines)
                .filter {
                    let t = $0.trimmingCharacters(in: .whitespaces)
                    return !t.hasPrefix("//") && !t.hasPrefix("#") && !t.hasPrefix("*")
                }
                .joined(separator: "\n")
            #expect(!codeOnly.contains("export_gguf"),
                   "GGUF export found in \(url.lastPathComponent) — use .safetensors only")
        }
    }

    @Test("KTO, not DPO, used for preference alignment")
    func ktoNotDPO() throws {
        let basePath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Epistemos/KnowledgeFusion/Alignment")

        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: basePath, includingPropertiesForKeys: nil) else { return }

        var foundKTO = false
        while let url = enumerator.nextObject() as? URL {
            guard url.pathExtension == "swift" || url.pathExtension == "py" else { continue }
            let content = try String(contentsOf: url, encoding: .utf8)

            if content.contains("KTO") { foundKTO = true }

            let codeOnly = content.components(separatedBy: .newlines)
                .filter {
                    let t = $0.trimmingCharacters(in: .whitespaces)
                    return !t.hasPrefix("//") && !t.hasPrefix("#")
                }
                .joined(separator: "\n")

            #expect(!codeOnly.contains("dpo_loss"), "DPO found in \(url.lastPathComponent)")
            #expect(!codeOnly.contains("DirectPreferenceOptimization"), "DPO found in \(url.lastPathComponent)")
        }

        #expect(foundKTO, "KTO should be referenced in Alignment subsystem")
    }
}
