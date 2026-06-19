import Testing
import Foundation
@testable import Epistemos

/// DATA+FINETUNE part (5) IMPORT — the marketplace "import" verb. Locks the honest
/// parse + ProvenanceGate validation of a public pack source into a registerable
/// descriptor (the byte download stays the on-device follow-on), the registry
/// round-trip, and the view wiring (rule #8 — the owner can see + use import).
@Suite("Fine-tune pack import (ProvenanceGate)")
struct FineTunePackImporterTests {

    @Test("parseSource recognizes HF / GitHub / URL / file, rejects junk")
    func parseSourceRecognizesHosts() {
        #expect(FineTunePackImporter.parseSource("meta-llama/Llama-3") == .huggingFace(repo: "meta-llama/Llama-3"))
        #expect(FineTunePackImporter.parseSource("https://huggingface.co/owner/model") == .huggingFace(repo: "owner/model"))
        #expect(FineTunePackImporter.parseSource("github.com/block/goose") == .gitHub(repo: "block/goose"))
        #expect(FineTunePackImporter.parseSource("https://example.com/pack.bin") == .remoteURL(URL(string: "https://example.com/pack.bin")!))
        #expect(FineTunePackImporter.parseSource("/Users/me/pack.safetensors") == .localFile(URL(fileURLWithPath: "/Users/me/pack.safetensors")))
        #expect(FineTunePackImporter.parseSource("just some text") == nil)
        #expect(FineTunePackImporter.parseSource("   ") == nil)
    }

    @Test("makePack builds a ProvenanceGate-clean descriptor from a valid request")
    func makePackValid() throws {
        let pack = try FineTunePackImporter.makePack(
            spec: "owner/cool-lora",
            kind: .loraAdapter,
            displayName: "Cool LoRA",
            license: "Apache-2.0",
            gate: .pro
        )
        #expect(pack.kind == .loraAdapter)
        #expect(pack.displayName == "Cool LoRA")
        #expect(pack.license == "Apache-2.0")
        #expect(pack.gate == .pro)
        #expect(pack.source == .huggingFace(repo: "owner/cool-lora"))
        #expect(pack.id == "import.hf.owner-cool-lora")
        #expect(pack.provenance.contains("ProvenanceGate"))
    }

    @Test("makePack rejects empty spec / unrecognized source / empty name / missing license")
    func makePackErrors() {
        #expect(throws: FineTunePackImportError.emptySpec) {
            try FineTunePackImporter.makePack(spec: "  ", kind: .dataset, displayName: "x", license: "MIT", gate: .free)
        }
        #expect(throws: FineTunePackImportError.unrecognizedSource("nonsense here")) {
            try FineTunePackImporter.makePack(spec: "nonsense here", kind: .dataset, displayName: "x", license: "MIT", gate: .free)
        }
        #expect(throws: FineTunePackImportError.emptyName) {
            try FineTunePackImporter.makePack(spec: "owner/name", kind: .dataset, displayName: "  ", license: "MIT", gate: .free)
        }
        // ProvenanceGate: no license → rejected.
        #expect(throws: FineTunePackImportError.missingLicense) {
            try FineTunePackImporter.makePack(spec: "owner/name", kind: .dataset, displayName: "x", license: "", gate: .free)
        }
    }

    @Test("import → register round-trips into the registry (available after add)")
    func importRegisterRoundTrip() throws {
        var registry = FineTunePackRegistry()
        let pack = try FineTunePackImporter.makePack(
            spec: "github.com/acme/dataset",
            kind: .dataset,
            displayName: "Acme Data",
            license: "MIT",
            gate: .free
        )
        try registry.add(pack)
        #expect(registry.pack(id: pack.id) != nil)
        #expect(registry.available(isPro: false, isDev: false).contains { $0.id == pack.id })

        // Re-importing the same source yields the same deterministic id → the registry
        // dedups it (no double entry).
        let dup = try FineTunePackImporter.makePack(
            spec: "github.com/acme/dataset", kind: .dataset, displayName: "Acme Data v2", license: "MIT", gate: .free
        )
        do {
            try registry.add(dup)
            Issue.record("expected duplicateID — re-import must dedup")
        } catch let error as FineTunePackRegistryError {
            #expect(error == .duplicateID(pack.id))
        } catch {
            Issue.record("wrong error type: \(error)")
        }
    }

    @Test("the marketplace view wires the import affordance (rule #8)")
    func viewWiresImport() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Settings/FineTuneMarketplaceView.swift")
        #expect(src.contains("importSection"))
        #expect(src.contains("FineTunePackImporter.makePack"))
        #expect(src.contains("Import a pack"))
        #expect(src.contains("registry.add(pack)"))
        #expect(src.contains("Add through ProvenanceGate"))
        // Browse still goes through the gated registry (apply/browse unbroken).
        #expect(src.contains("registry.available(isPro: isPro, isDev: isDev)"))
    }
}
