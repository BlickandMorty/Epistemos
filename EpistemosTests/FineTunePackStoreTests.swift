import Testing
import Foundation
@testable import Epistemos

/// DATA+FINETUNE part (5) PERSISTENCE — imported packs survive a relaunch. Locks the
/// on-disk store round-trip + dedup + honest empty-on-missing/corrupt, the full
/// import→store→reload contract, and the view wiring (load on appear, save on import).
@Suite("Fine-tune pack store (cross-launch persistence)")
struct FineTunePackStoreTests {

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-ftp-test-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("packs.json")
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    private func samplePack(id: String = "import.hf.owner-name") -> FineTunePack {
        FineTunePack(
            id: id,
            kind: .loraAdapter,
            displayName: "Sample",
            source: .huggingFace(repo: "owner/name"),
            license: "MIT",
            gate: .free,
            provenance: "imported"
        )
    }

    @Test("save then load round-trips the descriptors")
    func saveLoadRoundTrip() throws {
        let url = tempURL(); defer { cleanup(url) }
        let store = FineTunePackStore(url: url)
        let pack = samplePack()
        try store.save([pack])
        let loaded = store.load()
        #expect(loaded.count == 1)
        #expect(loaded.first?.id == pack.id)
        #expect(loaded.first?.source == .huggingFace(repo: "owner/name"))
    }

    @Test("append persists + dedups by id")
    func appendDedups() throws {
        let url = tempURL(); defer { cleanup(url) }
        let store = FineTunePackStore(url: url)
        try store.append(samplePack())
        try store.append(samplePack()) // same id → deduped
        #expect(store.load().count == 1)
        try store.append(samplePack(id: "import.gh.acme-data"))
        #expect(store.load().count == 2)
    }

    @Test("a missing file loads as empty (honest, never a crash)")
    func missingFileIsEmpty() {
        let url = tempURL(); defer { cleanup(url) }
        #expect(FineTunePackStore(url: url).load().isEmpty)
    }

    @Test("a corrupt file loads as empty (honest)")
    func corruptFileIsEmpty() throws {
        let url = tempURL(); defer { cleanup(url) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: url)
        #expect(FineTunePackStore(url: url).load().isEmpty)
    }

    @Test("import → store → reload survives (the cross-launch contract)")
    func importStoreReload() throws {
        let url = tempURL(); defer { cleanup(url) }
        // import (validate through the ProvenanceGate) → persist
        let pack = try FineTunePackImporter.makePack(
            spec: "owner/cool-lora",
            kind: .loraAdapter,
            displayName: "Cool LoRA",
            license: "Apache-2.0",
            gate: .free
        )
        try FineTunePackStore(url: url).append(pack)
        // a "fresh launch" = a new store at the same url → the pack is still there
        let reloaded = FineTunePackStore(url: url).load()
        #expect(reloaded.contains { $0.id == pack.id })
        #expect(reloaded.first?.license == "Apache-2.0")
    }

    @Test("the marketplace view wires persistence (load on appear + save on import)")
    func viewWiresPersistence() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Settings/FineTuneMarketplaceView.swift")
        #expect(src.contains("FineTunePackStore"))
        #expect(src.contains("loadPersistedImports()"))
        #expect(src.contains(".onAppear { loadPersistedImports() }"))
        #expect(src.contains("store.append(pack)"))
        #expect(src.contains("store.load()"))
    }
}
