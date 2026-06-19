import Testing
import Foundation
@testable import Epistemos

/// DATA+FINETUNE part (5) SHARE — the marketplace "share" verb completes
/// browse/import/apply/SHARE. Locks the portable export → parse round-trip, the
/// ProvenanceGate re-validation on parse, non-share/malformed rejection, the
/// share→import flow, and the view wiring (export to clipboard + import accepts a paste).
@Suite("Fine-tune pack share (export/import via ProvenanceGate)")
struct FineTunePackShareTests {

    private func samplePack() -> FineTunePack {
        FineTunePack(
            id: "import.hf.owner-name",
            kind: .loraAdapter,
            displayName: "Cool LoRA",
            source: .huggingFace(repo: "owner/name"),
            license: "Apache-2.0",
            gate: .pro,
            provenance: "imported"
        )
    }

    @Test("export then parse round-trips the full descriptor")
    func roundTrip() throws {
        let pack = samplePack()
        let shared = FineTunePackShare.export(pack)
        #expect(shared.hasPrefix(FineTunePackShare.prefix))
        #expect(FineTunePackShare.isShare(shared))
        let parsed = try FineTunePackShare.parse(shared)
        #expect(parsed == pack)
    }

    @Test("parse rejects a non-share string + malformed JSON")
    func rejectsNonShareAndMalformed() {
        #expect(throws: FineTunePackShareError.notAShare) {
            try FineTunePackShare.parse("owner/name")
        }
        #expect(throws: FineTunePackShareError.malformed) {
            try FineTunePackShare.parse(FineTunePackShare.prefix + "not json")
        }
        #expect(!FineTunePackShare.isShare("owner/name"))
    }

    @Test("parse re-validates the ProvenanceGate: an unlicensed shared pack is rejected")
    func reValidatesLicense() {
        // A shared pack with an empty license — export() doesn't validate (it just
        // encodes), so parse() must catch it on the way back in.
        let unlicensed = FineTunePack(
            id: "x",
            kind: .dataset,
            displayName: "X",
            source: .gitHub(repo: "a/b"),
            license: "",
            gate: .free
        )
        let shared = FineTunePackShare.export(unlicensed)
        #expect(throws: FineTunePackShareError.unlicensed) {
            try FineTunePackShare.parse(shared)
        }
    }

    @Test("share → import round-trips into the registry")
    func shareImportRoundTrip() throws {
        var registry = FineTunePackRegistry()
        let shared = FineTunePackShare.export(samplePack())
        let parsed = try FineTunePackShare.parse(shared)
        try registry.add(parsed)
        #expect(registry.pack(id: "import.hf.owner-name") != nil)
    }

    @Test("the marketplace view wires share (export to clipboard + import accepts a paste)")
    func viewWiresShare() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Settings/FineTuneMarketplaceView.swift")
        #expect(src.contains("FineTunePackShare.export(pack)"))
        #expect(src.contains("FineTunePackShare.isShare(importSpec)"))
        #expect(src.contains("FineTunePackShare.parse(importSpec)"))
        #expect(src.contains("NSPasteboard.general"))
        #expect(src.contains("sharePack(pack)"))
    }
}
