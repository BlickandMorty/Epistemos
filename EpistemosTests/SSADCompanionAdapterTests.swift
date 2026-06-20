import Testing
import Foundation

@testable import Epistemos

// SS-AD step 3 (apply-side): the foregrounded Companion's loraAdapterPath overrides the
// global registry adapter at model load — guarded so a nil / blank / invalid companion
// path resolves to the registry (byte-for-byte the unchanged path). The request-builder
// setting LocalMLXRequest.loraAdapterPathOverride from the active Companion is the
// follow-on seam; the live token-effect is PENDING OWNER VERIFICATION.
@Suite("SS-AD companion adapter override (step 3 apply-side)")
struct SSADCompanionAdapterTests {

    private func makeValidAdapterDir() throws -> URL {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("ssad-comp-\(UUID().uuidString)")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: NativeAdapterDirectory.configURL(in: dir))
        try Data("w".utf8).write(to: NativeAdapterDirectory.weightsURL(in: dir))
        return dir
    }

    @Test("a valid companion adapter path wins over the registry adapter")
    func companionWinsWhenValid() throws {
        let companion = try makeValidAdapterDir()
        defer { try? FileManager.default.removeItem(at: companion) }
        let registry = URL(fileURLWithPath: "/tmp/registry-adapter")
        let resolved = MLXInferenceService.resolveActiveAdapterDirectory(
            companionLoraAdapterPath: companion.path, registryActiveDirectory: registry
        )
        #expect(resolved == companion)
    }

    @Test("nil / blank / incomplete companion path falls back to the registry (unchanged path)")
    func fallsBackToRegistry() throws {
        let registry = URL(fileURLWithPath: "/tmp/registry-adapter")
        #expect(
            MLXInferenceService.resolveActiveAdapterDirectory(
                companionLoraAdapterPath: nil, registryActiveDirectory: registry) == registry
        )
        #expect(
            MLXInferenceService.resolveActiveAdapterDirectory(
                companionLoraAdapterPath: "   ", registryActiveDirectory: registry) == registry
        )
        // A directory that isn't a complete native adapter → registry (no half adapter).
        let incomplete = FileManager.default.temporaryDirectory
            .appendingPathComponent("ssad-bad-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: incomplete, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: incomplete) }
        #expect(
            MLXInferenceService.resolveActiveAdapterDirectory(
                companionLoraAdapterPath: incomplete.path, registryActiveDirectory: registry) == registry
        )
        // No companion and no registry adapter → nil (no adapter at all).
        #expect(
            MLXInferenceService.resolveActiveAdapterDirectory(
                companionLoraAdapterPath: nil, registryActiveDirectory: nil) == nil
        )
    }
}
