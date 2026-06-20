import Testing
import Foundation

@testable import Epistemos

// SS-LS slice 1a (repair-before-add): the natively-trained adapter weights file
// is `adapters.safetensors` — what `NativeLoRATrainer` writes and what
// `LoRAContainer.from(directory:)` requires. The loader / exporter / deploy-gate
// previously hardcoded `adapter_weights.safetensors`, so a natively-trained
// adapter was silently never found (load/export/deploy-gate all missed it). This
// standardizes every consumer on the canonical `NativeAdapterDirectory` name.
@Suite("SS-LS adapter filename repair (slice 1a)")
struct SSLSAdapterFilenameRepairTests {

    @Test("the canonical weights filename is adapters.safetensors")
    func canonicalNameIsAdaptersSafetensors() {
        #expect(NativeAdapterDirectory.weightsFileName == "adapters.safetensors")
    }

    @Test("isValid accepts the native layout (adapters.safetensors + adapter_config.json)")
    func isValidAcceptsNativeLayout() throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("ssls-1a-\(UUID().uuidString)")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        // A weights-only directory is NOT a complete adapter.
        try Data("weights".utf8).write(to: NativeAdapterDirectory.weightsURL(in: dir))
        #expect(!NativeAdapterDirectory.isValid(dir))

        // With the config alongside it, the native layout is loadable.
        try Data("{}".utf8).write(to: NativeAdapterDirectory.configURL(in: dir))
        #expect(NativeAdapterDirectory.isValid(dir))
        #expect(NativeAdapterDirectory.invalidReason(dir) == nil)
    }

    @Test("loader / exporter / deploy-gate resolve the weights via the canonical name")
    func consumersUseCanonicalName() throws {
        for path in [
            "Epistemos/KnowledgeFusion/Adapters/AdapterLoader.swift",
            "Epistemos/KnowledgeFusion/Adapters/AdapterExporter.swift",
            "Epistemos/KnowledgeFusion/Alignment/TrainingScheduler.swift",
        ] {
            let src = try loadMirroredSourceTextFile(path)
            #expect(!src.contains("adapter_weights.safetensors"),
                    "\(path) still references the wrong adapter_weights.safetensors name")
            #expect(src.contains("NativeAdapterDirectory.weights"),
                    "\(path) must resolve the weights name via NativeAdapterDirectory")
        }
        // The trainer writes exactly the canonical name the consumers now look for.
        let trainer = try loadMirroredSourceTextFile(
            "Epistemos/KnowledgeFusion/Training/NativeLoRATrainer.swift"
        )
        #expect(trainer.contains("\"adapters.safetensors\""))
    }
}
