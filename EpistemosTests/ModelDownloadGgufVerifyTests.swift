import Testing
@testable import Epistemos

/// MODEL DOWNLOAD robustness (owner 2026-06-19, reqs 8/10): the artifact-validation
/// hardening assumed safetensors/MLX layout (require `.safetensors` weights + `config.json`
/// + a tokenizer), which falsely rejected a COMPLETE GGUF download as "corrupted / not
/// complete" — a GGUF model is one self-contained `.gguf` file that embeds its config +
/// tokenizer. These pure helpers drive the now runtime-aware `verifySnapshot`.
@Suite("Model download GGUF-aware verification")
struct ModelDownloadGgufVerifyTests {

    @Test("weight extension is per-runtime: .gguf for GGUF, .safetensors for MLX/remote")
    func weightExtensionPerRuntime() {
        #expect(ModelDownloadManager.weightFileExtension(for: .gguf) == "gguf")
        #expect(ModelDownloadManager.weightFileExtension(for: .mlx) == "safetensors")
        #expect(ModelDownloadManager.weightFileExtension(for: .remote) == "safetensors")
    }

    @Test("GGUF needs NO config/tokenizer sidecars; MLX still does")
    func sidecarRequirementPerRuntime() {
        // GGUF embeds config + tokenizer in the single weight file → no sidecars required.
        #expect(ModelDownloadManager.requiresSidecarConfigAndTokenizer(for: .gguf) == false)
        // MLX/Transformers ship them separately → still required (validation unchanged).
        #expect(ModelDownloadManager.requiresSidecarConfigAndTokenizer(for: .mlx) == true)
        #expect(ModelDownloadManager.requiresSidecarConfigAndTokenizer(for: .remote) == true)
    }
}
