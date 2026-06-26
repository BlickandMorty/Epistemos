import Testing
import Foundation

@testable import Epistemos

@Suite("MLX adapter override resolution")
struct MLXAdapterOverrideResolutionTests {

    private func makeValidAdapterDir() throws -> URL {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("ssad-comp-\(UUID().uuidString)")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: NativeAdapterDirectory.configURL(in: dir))
        try Data("w".utf8).write(to: NativeAdapterDirectory.weightsURL(in: dir))
        return dir
    }

    @Test("a valid request adapter path wins over the registry adapter")
    func requestOverrideWinsWhenValid() throws {
        let requestAdapter = try makeValidAdapterDir()
        defer { try? FileManager.default.removeItem(at: requestAdapter) }
        let registry = URL(fileURLWithPath: "/tmp/registry-adapter")
        let resolved = MLXInferenceService.resolveActiveAdapterDirectory(
            requestAdapterPath: requestAdapter.path, registryActiveDirectory: registry
        )
        #expect(resolved == requestAdapter)
    }

    @Test("nil / blank / incomplete request adapter path falls back to the registry")
    func fallsBackToRegistry() throws {
        let registry = URL(fileURLWithPath: "/tmp/registry-adapter")
        #expect(
            MLXInferenceService.resolveActiveAdapterDirectory(
                requestAdapterPath: nil, registryActiveDirectory: registry) == registry
        )
        #expect(
            MLXInferenceService.resolveActiveAdapterDirectory(
                requestAdapterPath: "   ", registryActiveDirectory: registry) == registry
        )
        // A directory that isn't a complete native adapter → registry (no half adapter).
        let incomplete = FileManager.default.temporaryDirectory
            .appendingPathComponent("ssad-bad-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: incomplete, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: incomplete) }
        #expect(
            MLXInferenceService.resolveActiveAdapterDirectory(
                requestAdapterPath: incomplete.path, registryActiveDirectory: registry) == registry
        )
        // No request override and no registry adapter -> nil (no adapter at all).
        #expect(
            MLXInferenceService.resolveActiveAdapterDirectory(
                requestAdapterPath: nil, registryActiveDirectory: nil) == nil
        )
    }
}
