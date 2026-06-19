import Testing
import Foundation
@testable import Epistemos

/// DATA + FINETUNE part (5) — locks the marketplace registry contract: typed
/// {id, kind, source, license, gate} packs, a ProvenanceGate license check, dedup
/// by id, and honest build/cert gating (a Pro/Dev pack never surfaces where it
/// can't run). MAS-safe: packs are descriptors, never runtime code.
@Suite("Fine-tune pack registry")
struct FineTunePackRegistryTests {

    private func pack(
        _ id: String, kind: FineTunePackKind = .loraAdapter,
        license: String = "MIT", gate: FineTunePackGate = .free
    ) -> FineTunePack {
        FineTunePack(
            id: id, kind: kind, displayName: id,
            source: .huggingFace(repo: "acme/\(id)"),
            license: license, gate: gate
        )
    }

    @Test("a valid, licensed pack registers")
    func registersValidPack() throws {
        var reg = FineTunePackRegistry()
        try reg.add(pack("a"))
        #expect(reg.packs.count == 1)
        #expect(reg.pack(id: "a")?.kind == .loraAdapter)
    }

    @Test("ProvenanceGate rejects an unlicensed pack")
    func rejectsUnlicensed() {
        var reg = FineTunePackRegistry()
        #expect(throws: FineTunePackRegistryError.unlicensed(id: "x")) {
            try reg.add(pack("x", license: "  "))
        }
        #expect(reg.packs.isEmpty)
    }

    @Test("empty id is rejected")
    func rejectsEmptyID() {
        var reg = FineTunePackRegistry()
        #expect(throws: FineTunePackRegistryError.emptyID) { try reg.add(pack("   ")) }
    }

    @Test("dedup by id is case-insensitive")
    func dedupsByID() throws {
        var reg = FineTunePackRegistry()
        try reg.add(pack("Pack1"))
        #expect(throws: FineTunePackRegistryError.duplicateID("pack1")) {
            try reg.add(pack("pack1"))
        }
        #expect(reg.packs.count == 1)
        #expect(reg.pack(id: "PACK1") != nil)  // lookup is case-insensitive too
    }

    @Test("honest gating: free everywhere, pro on pro/dev, dev only on dev")
    func honestGating() throws {
        var reg = FineTunePackRegistry()
        try reg.add(pack("free", gate: .free))
        try reg.add(pack("pro", gate: .pro))
        try reg.add(pack("dev", gate: .dev))

        let mas = reg.available(isPro: false, isDev: false).map(\.id)
        #expect(mas == ["free"])                                  // MAS sees only free
        let pro = Set(reg.available(isPro: true, isDev: false).map(\.id))
        #expect(pro == ["free", "pro"])                           // Pro sees free + pro, NOT dev
        let dev = Set(reg.available(isPro: false, isDev: true).map(\.id))
        #expect(dev == ["free", "pro", "dev"])                    // dev sees all
    }

    @Test("packs filter by kind")
    func filtersByKind() throws {
        var reg = FineTunePackRegistry()
        try reg.add(pack("a", kind: .dataset))
        try reg.add(pack("b", kind: .loraAdapter))
        try reg.add(pack("c", kind: .dataset))
        #expect(Set(reg.packs(ofKind: .dataset).map(\.id)) == ["a", "c"])
        #expect(reg.packs(ofKind: .loraAdapter).map(\.id) == ["b"])
    }

    @Test("FineTunePack round-trips through Codable (shareable descriptor)")
    func codableRoundTrip() throws {
        let p = FineTunePack(
            id: "k1", kind: .knowledgePack, displayName: "K",
            source: .gitHub(repo: "acme/k"), license: "Apache-2.0", gate: .pro,
            sizeBytes: 1234, provenance: "direct_import"
        )
        let data = try JSONEncoder().encode(p)
        let back = try JSONDecoder().decode(FineTunePack.self, from: data)
        #expect(back == p)
        #expect(back.source == .gitHub(repo: "acme/k"))
    }
}
