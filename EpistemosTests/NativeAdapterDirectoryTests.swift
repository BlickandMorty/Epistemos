import Testing
import Foundation
@testable import Epistemos

/// Data + finetune substrate (owner 2026-06-18) — locks the native adapter
/// directory contract between NativeLoRATrainer (writes adapter_config.json +
/// adapters.safetensors) and NativeAdapterApply (LoRAContainer.from(directory:)).
/// A directory is only loadable when BOTH files are present.
@Suite("Native adapter directory")
struct NativeAdapterDirectoryTests {

    private func tempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-adapter-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func write(_ name: String, in dir: URL) throws {
        try "x".write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    @Test("file names match what LoRAContainer.from(directory:) reads")
    func canonicalFileNames() {
        #expect(NativeAdapterDirectory.configFileName == "adapter_config.json")
        #expect(NativeAdapterDirectory.weightsFileName == "adapters.safetensors")
    }

    @Test("valid only when BOTH config + weights exist")
    func validRequiresBoth() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        #expect(!NativeAdapterDirectory.isValid(dir))            // empty
        try write("adapters.safetensors", in: dir)
        #expect(!NativeAdapterDirectory.isValid(dir))            // weights only (raw LoRATrain output)
        try write("adapter_config.json", in: dir)
        #expect(NativeAdapterDirectory.isValid(dir))             // both → loadable
    }

    @Test("invalidReason names the missing piece honestly")
    func invalidReasonIsHonest() throws {
        let missingDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-adapter-absent-\(UUID().uuidString)")
        #expect(NativeAdapterDirectory.invalidReason(missingDir)?.contains("does not exist") == true)

        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(NativeAdapterDirectory.invalidReason(dir)?.contains("Not a native adapter") == true)

        try write("adapter_config.json", in: dir)
        #expect(NativeAdapterDirectory.invalidReason(dir)?.contains("adapters.safetensors") == true)

        try write("adapters.safetensors", in: dir)
        #expect(NativeAdapterDirectory.invalidReason(dir) == nil)   // complete
    }

    @Test("config/weights URLs resolve under the directory")
    func urlsResolve() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(NativeAdapterDirectory.configURL(in: dir).lastPathComponent == "adapter_config.json")
        #expect(NativeAdapterDirectory.weightsURL(in: dir).lastPathComponent == "adapters.safetensors")
    }
}
