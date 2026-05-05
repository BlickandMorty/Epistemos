import Foundation
import Metal
import Testing

/// Wave 4.1 source-guard for offline Metal shader compilation
/// (`docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md` Wave 4.1,
///  cross-ref dpp §4.1 Sprint 3 deep perf).
///
/// Three contracts covered:
///   1. The `.metal` file ships under Epistemos/Shaders/ where Xcode's
///      Metal build phase will pick it up automatically.
///   2. Both kernel symbols (cosineSimilarityBatch, batchNormalize)
///      live in the .metal source so they end up in default.metallib.
///   3. CodeEditorView no longer compiles a Metal source string at
///      runtime via `device.makeLibrary(source:options:)` — that was
///      the slow path Wave 4.1 removed.
@Suite("Metal shader offline compilation (Wave 4.1)")
nonisolated struct MetalShaderOfflineTests {

    private static func loadText(_ relative: String) throws -> String {
        try loadMirroredSourceTextFile(relative)
    }

    @Test("CodeEditorEmbedding.metal exists at the canonical path")
    func metalFileExists() throws {
        let url = try sourceMirrorURL(for: "Epistemos/Shaders/CodeEditorEmbedding.metal")
        #expect(FileManager.default.fileExists(atPath: url.path),
                "Epistemos/Shaders/CodeEditorEmbedding.metal must exist (Wave 4.1)")
    }

    @Test("CodeEditorEmbedding.metal declares both kernel functions")
    func metalKernelsDeclared() throws {
        let source = try Self.loadText("Epistemos/Shaders/CodeEditorEmbedding.metal")
        #expect(source.contains("kernel void cosineSimilarityBatch("),
                "CodeEditorEmbedding.metal must declare cosineSimilarityBatch — CodeEditorView.setupGPU loads it via makeDefaultLibrary().makeFunction(name:)")
        #expect(source.contains("kernel void batchNormalize("),
                "CodeEditorEmbedding.metal must declare batchNormalize — same load path as cosineSimilarityBatch")
    }

    @Test("CodeEditorView no longer compiles Metal source at runtime")
    func codeEditorUsesPrecompiledLibrary() throws {
        let source = try Self.loadText("Epistemos/Views/Notes/CodeEditorView.swift")
        #expect(!source.contains("device.makeLibrary(source:"),
                "CodeEditorView.swift must NOT call device.makeLibrary(source:options:) — Wave 4.1 moved the kernels to a .metal file")
        #expect(source.contains("device.makeDefaultLibrary()"),
                "CodeEditorView.swift must load via device.makeDefaultLibrary() (the Wave 4.1 fast path)")
    }

    /// Runtime sanity check: when a Metal device is available (real
    /// hardware in CI on macos-15 runners), the default library MUST
    /// expose both kernel functions. Skips gracefully when no device
    /// is available (e.g. a headless container).
    @Test("default.metallib exposes both kernels at runtime")
    func defaultMetallibContainsKernels() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            // No GPU on this runner — skip without failing.
            return
        }
        guard let library = device.makeDefaultLibrary() else {
            #expect(Bool(false),
                    "device.makeDefaultLibrary() returned nil — default.metallib was not bundled")
            return
        }
        #expect(library.makeFunction(name: "cosineSimilarityBatch") != nil,
                "default.metallib must expose cosineSimilarityBatch (Wave 4.1)")
        #expect(library.makeFunction(name: "batchNormalize") != nil,
                "default.metallib must expose batchNormalize (Wave 4.1)")
    }
}
