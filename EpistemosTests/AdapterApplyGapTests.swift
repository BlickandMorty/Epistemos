import Testing
import Foundation

@testable import Epistemos

// SS-LS apply-gap keystone (step 2): the inference load path must attach the user's
// ACTIVE LoRA adapter so a trained+activated adapter actually changes generated
// tokens — but ONLY when an active, complete adapter exists; with none, the load
// path stays byte-for-byte unchanged. The DECISION (is there an active, valid
// adapter, and which directory?) is witnessed here WITHOUT a live model via the
// stateless on-disk lookup. The live "tokens differ with vs without the adapter"
// behavior is PENDING OWNER VERIFICATION (needs an on-device run).
@Suite("SS-LS apply-gap decision (step 2)")
struct AdapterApplyGapTests {

    private func makeRecord(adapterPath: URL, isActive: Bool) -> AdapterRecord {
        AdapterRecord(
            id: UUID(),
            name: "test",
            type: .knowledge,
            adapterPath: adapterPath,
            metadataPath: adapterPath.appendingPathComponent("training_metadata.json"),
            sourceVault: "vault",
            createdAt: Date(timeIntervalSince1970: 1_000),
            qualityScore: nil,
            isActive: isActive,
            baseModel: "model",
            loraRank: 8,
            parameterCount: 1,
            trainingExamples: 1
        )
    }

    private func writeRegistry(_ records: [AdapterRecord], to path: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        try encoder.encode(records).write(to: path)
    }

    /// Build a complete, loadable native adapter directory (config + weights).
    private func makeValidAdapterDir() throws -> URL {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("applygap-\(UUID().uuidString)")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: NativeAdapterDirectory.configURL(in: dir))
        try Data("weights".utf8).write(to: NativeAdapterDirectory.weightsURL(in: dir))
        return dir
    }

    @Test("nil when there is no registry file (the normal first-run / no-adapters case)")
    func nilWhenNoFile() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("no-registry-\(UUID().uuidString).json")
        #expect(AdapterRegistry.activeAdapterDirectoryOnDisk(registryPath: missing) == nil)
    }

    @Test("nil when an adapter exists but none is active")
    func nilWhenNoneActive() throws {
        let dir = try makeValidAdapterDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let registry = FileManager.default.temporaryDirectory
            .appendingPathComponent("reg-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: registry) }
        try writeRegistry([makeRecord(adapterPath: dir, isActive: false)], to: registry)
        #expect(AdapterRegistry.activeAdapterDirectoryOnDisk(registryPath: registry) == nil)
    }

    @Test("returns the active adapter's directory when it is active and complete")
    func returnsActiveValidDir() throws {
        let inactive = try makeValidAdapterDir()
        let active = try makeValidAdapterDir()
        defer {
            try? FileManager.default.removeItem(at: inactive)
            try? FileManager.default.removeItem(at: active)
        }
        let registry = FileManager.default.temporaryDirectory
            .appendingPathComponent("reg-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: registry) }
        try writeRegistry(
            [makeRecord(adapterPath: inactive, isActive: false),
             makeRecord(adapterPath: active, isActive: true)],
            to: registry
        )
        #expect(AdapterRegistry.activeAdapterDirectoryOnDisk(registryPath: registry) == active)
    }

    @Test("nil when the active adapter's directory is incomplete (no adapters.safetensors)")
    func nilWhenActiveDirIncomplete() throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("applygap-bad-\(UUID().uuidString)")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        // config only — missing the weights file ⇒ not a loadable adapter.
        try Data("{}".utf8).write(to: NativeAdapterDirectory.configURL(in: dir))
        defer { try? fm.removeItem(at: dir) }
        let registry = fm.temporaryDirectory.appendingPathComponent("reg-\(UUID().uuidString).json")
        defer { try? fm.removeItem(at: registry) }
        try writeRegistry([makeRecord(adapterPath: dir, isActive: true)], to: registry)
        #expect(AdapterRegistry.activeAdapterDirectoryOnDisk(registryPath: registry) == nil)
    }

    @Test("the load path wires the apply behind the active-adapter + Pro guard")
    func loadPathWiringIsGuarded() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Engine/MLXInferenceService.swift")
        // Applied only on the Pro build...
        #expect(src.contains("#if !EPISTEMOS_APP_STORE"))
        #expect(src.contains("await applyActiveAdapterIfPresent(to: container)"))
        // ...and only when an active adapter resolves (else early-return = unchanged).
        #expect(src.contains("guard let adapterDir = AdapterRegistry.activeAdapterDirectoryOnDisk() else { return }"))
        #expect(src.contains("NativeAdapterApply.apply(adapterDirectory: adapterDir, into: context.model)"))
    }
}
