import Foundation
import Testing

/// Wave 4.2 source-guard for the MTLBinaryArchive caching layer in
/// `Epistemos/Engine/MetalRuntimeManager.swift`
/// (`docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md` Wave 4.2,
///  cross-ref dpp §4.2 Sprint 3 deep perf).
///
/// We can't fully exercise the archive at unit-test scope (it requires
/// the full Mamba-2 default.metallib + a real Metal device + filesystem
/// state across launches). What we CAN guard is that the canonical
/// helper symbols + persistence path stay wired so a refactor doesn't
/// silently regress to per-launch pipeline compilation.
@Suite("Metal binary archive (Wave 4.2)")
nonisolated struct MetalBinaryArchiveTests {

    private static func loadText(_ relative: String) throws -> String {
        try loadMirroredSourceTextFile(relative)
    }

    @Test("MetalRuntimeManager owns a binaryArchive property")
    func managerOwnsBinaryArchive() throws {
        let source = try Self.loadText("Epistemos/Engine/MetalRuntimeManager.swift")
        #expect(source.contains("var binaryArchive: MTLBinaryArchive?"),
                "MetalRuntimeManager must declare an MTLBinaryArchive? cache (Wave 4.2)")
        #expect(source.contains("Epistemos-mamba2-pipelines.metalarchive"),
                "MetalRuntimeManager must persist the archive at the canonical filename")
    }

    @Test("compilePipeline path uses MTLComputePipelineDescriptor + binaryArchives")
    func compilePipelineUsesArchiveDescriptor() throws {
        let source = try Self.loadText("Epistemos/Engine/MetalRuntimeManager.swift")
        #expect(source.contains("MTLComputePipelineDescriptor()"),
                "MetalRuntimeManager.compilePipeline must build a descriptor (the archive-aware code path)")
        #expect(source.contains("descriptor.binaryArchives = [archive]"),
                "MetalRuntimeManager.compilePipeline must attach the archive via descriptor.binaryArchives")
        #expect(source.contains("addComputePipelineFunctions"),
                "MetalRuntimeManager.compilePipeline must populate the archive via addComputePipelineFunctions so future launches hit the cache")
    }

    @Test("compileKernels persists the archive after compilation")
    func compileKernelsPersistsArchive() throws {
        let source = try Self.loadText("Epistemos/Engine/MetalRuntimeManager.swift")
        #expect(source.contains("loadOrCreateBinaryArchive"),
                "MetalRuntimeManager.compileKernels must call loadOrCreateBinaryArchive at the start (Wave 4.2)")
        #expect(source.contains("persistBinaryArchive"),
                "MetalRuntimeManager.compileKernels must call persistBinaryArchive after a successful run")
        #expect(source.contains("archive.serialize(to: url)"),
                "MetalRuntimeManager.persistBinaryArchive must call archive.serialize(to: url) — the documented MTLBinaryArchive write API")
    }

    @Test("Archive load is best-effort — falls back to fresh compilation")
    func archiveLoadFallsBackOnError() throws {
        let source = try Self.loadText("Epistemos/Engine/MetalRuntimeManager.swift")
        // The archive load + serialise paths must NOT use try! anywhere.
        // A force-try would crash the runtime on a stale / corrupt
        // archive instead of falling back to fresh compilation.
        #expect(!source.contains("try! device.makeBinaryArchive"),
                "loadOrCreateBinaryArchive must NOT force-try makeBinaryArchive — corrupt archives must degrade to fresh compilation")
        #expect(!source.contains("try! archive.serialize"),
                "persistBinaryArchive must NOT force-try archive.serialize — write failures must not crash")
    }
}
