import Testing
import Foundation
@testable import Epistemos

/// V3.2 first-slice tests for the ANEBackend protocol +
/// MockANEBackend. Proves the protocol shape works end-to-end without
/// requiring private framework loading or any signing.
///
/// **Doctrine alignment:** the design doc
/// `docs/V2_4_AND_V3_2_DESIGN_2026_05_05.md` calls for "ANEBackend
/// Swift protocol declaration + MockANEBackend for tests + KV
/// implantation typed buffer format." This test suite exercises all
/// three.
@Suite("ANE Backend protocol (V3.2 first slice)")
struct ANEBackendTests {

    // MARK: - Lifecycle

    @Test("Mock backend loads model, generates, unloads — happy path")
    func mockHappyPath() async throws {
        let backend = MockANEBackend()
        let url = URL(fileURLWithPath: "/tmp/test.safetensors")
        let handle = try await backend.loadModel(at: url, label: "qwen3:Q4_K_M")
        #expect(handle.modelLabel == "qwen3:Q4_K_M")
        #expect(await backend.isLoaded(handle))

        let stream = try await backend.generate(
            handle: handle,
            promptTokens: [1, 2, 3, 4, 5],
            maxNewTokens: 10
        )
        var generated: [Int32] = []
        for await token in stream {
            generated.append(token)
        }
        #expect(generated.count == 10)

        try await backend.unloadModel(handle)
        #expect(await !backend.isLoaded(handle))
    }

    @Test("Mock backend rejects non-safetensors model files")
    func mockRejectsBadFormat() async {
        let backend = MockANEBackend()
        let url = URL(fileURLWithPath: "/tmp/test.gguf")
        do {
            _ = try await backend.loadModel(at: url, label: "bad")
            Issue.record("expected modelFormatUnsupported error")
        } catch let ANEBackendError.modelFormatUnsupported(detail) {
            #expect(detail.contains(".gguf"))
        } catch {
            Issue.record("unexpected error type: \(error)")
        }
    }

    @Test("Mock backend rejects generate against unloaded handle")
    func mockRejectsUnloadedHandle() async throws {
        let backend = MockANEBackend()
        let phantom = ANEModelHandle(id: 9999, modelLabel: "phantom")
        do {
            _ = try await backend.generate(
                handle: phantom,
                promptTokens: [1, 2, 3],
                maxNewTokens: 5
            )
            Issue.record("expected handleNotLoaded error")
        } catch let ANEBackendError.handleNotLoaded(handle) {
            #expect(handle == phantom)
        } catch {
            Issue.record("unexpected error type: \(error)")
        }
    }

    @Test("Mock backend rejects generate after shutdown")
    func mockRejectsAfterShutdown() async throws {
        let backend = MockANEBackend()
        let url = URL(fileURLWithPath: "/tmp/test.safetensors")
        let handle = try await backend.loadModel(at: url, label: "x")
        await backend.shutdown()
        do {
            _ = try await backend.generate(
                handle: handle,
                promptTokens: [1],
                maxNewTokens: 1
            )
            Issue.record("expected shutdown error")
        } catch ANEBackendError.shutdown {
            // Expected.
        } catch {
            Issue.record("unexpected error type: \(error)")
        }
    }

    @Test("Mock backend records every call in callLog")
    func mockRecordsCallLog() async throws {
        let backend = MockANEBackend()
        let url = URL(fileURLWithPath: "/tmp/m.safetensors")
        let handle = try await backend.loadModel(at: url, label: "m")
        _ = try await backend.generate(handle: handle, promptTokens: [1], maxNewTokens: 2)
        try await backend.unloadModel(handle)
        await backend.shutdown()

        let log = await backend.snapshotCallLog()
        #expect(log.count == 4)
        // Order check: load → generate → unload → shutdown
        if case .loadModel = log[0] {} else { Issue.record("log[0] not loadModel: \(log[0])") }
        if case .generate = log[1] {} else { Issue.record("log[1] not generate: \(log[1])") }
        if case .unloadModel = log[2] {} else { Issue.record("log[2] not unloadModel: \(log[2])") }
        if case .shutdown = log[3] {} else { Issue.record("log[3] not shutdown: \(log[3])") }
    }

    // MARK: - Determinism

    @Test("Mock backend generation is deterministic across runs (same seed + handle)")
    func mockGenerationIsDeterministic() async throws {
        let backend1 = MockANEBackend(seed: 42)
        let backend2 = MockANEBackend(seed: 42)
        // Same prompt + maxNewTokens against fresh backends with same
        // seed should produce IDENTICAL output (handle id starts at 1
        // each time so the LCG state is the same).
        let url = URL(fileURLWithPath: "/tmp/x.safetensors")
        let h1 = try await backend1.loadModel(at: url, label: "x")
        let h2 = try await backend2.loadModel(at: url, label: "x")
        #expect(h1 == h2)

        let s1 = try await backend1.generate(handle: h1, promptTokens: [1, 2, 3], maxNewTokens: 8)
        let s2 = try await backend2.generate(handle: h2, promptTokens: [1, 2, 3], maxNewTokens: 8)
        var t1: [Int32] = []
        var t2: [Int32] = []
        for await token in s1 { t1.append(token) }
        for await token in s2 { t2.append(token) }
        #expect(t1 == t2, "same seed + same prompt + same handle id must produce identical sequences")
    }

    @Test("Mock backend generation differs for different prompts (sanity check)")
    func mockGenerationDiffersForDifferentPrompts() async throws {
        let backend = MockANEBackend(seed: 0)
        let url = URL(fileURLWithPath: "/tmp/x.safetensors")
        let h = try await backend.loadModel(at: url, label: "x")
        let s1 = try await backend.generate(handle: h, promptTokens: [1, 2, 3], maxNewTokens: 5)
        let s2 = try await backend.generate(handle: h, promptTokens: [4, 5, 6], maxNewTokens: 5)
        var t1: [Int32] = []
        var t2: [Int32] = []
        for await token in s1 { t1.append(token) }
        for await token in s2 { t2.append(token) }
        #expect(t1 != t2, "different prompts must produce different sequences (sanity check)")
    }

    // MARK: - KV implantation buffer format

    @Test("ANEKVCacheBuffer declared byte count matches packed size")
    func kvBufferDeclaredSizeMatchesPackedSize() {
        // 2 layers × 4 heads × 8 dim × 16 seq = 1024 elements per side
        // × 2 bits each = 256 bytes per side × 2 (K+V) = 512 bytes total.
        let buffer = ANEKVCacheBuffer(
            numLayers: 2,
            numHeads: 4,
            headDim: 8,
            seqLen: 16,
            quantBitsPerElement: 2,
            bytes: Data(count: 512)
        )
        #expect(buffer.declaredByteCount == 512)
        #expect(buffer.isWellSized)
    }

    @Test("ANEKVCacheBuffer flags shape mismatch when bytes don't match")
    func kvBufferFlagsShapeMismatch() {
        let buffer = ANEKVCacheBuffer(
            numLayers: 2,
            numHeads: 4,
            headDim: 8,
            seqLen: 16,
            quantBitsPerElement: 2,
            bytes: Data(count: 100) // wrong size
        )
        #expect(!buffer.isWellSized)
    }

    @Test("Mock backend implants KV cache + rejects shape mismatch")
    func mockImplantKVCacheRoundTrip() async throws {
        let backend = MockANEBackend()
        let url = URL(fileURLWithPath: "/tmp/m.safetensors")
        let handle = try await backend.loadModel(at: url, label: "m")

        // Well-sized buffer: implant succeeds.
        let goodBuffer = ANEKVCacheBuffer(
            numLayers: 1,
            numHeads: 2,
            headDim: 4,
            seqLen: 8,
            quantBitsPerElement: 2,
            bytes: Data(count: 16) // 1*2*4*8 elements * 2 bits = 16 bytes per side, * 2 (K+V) = 16... actually let me check
        )
        // 1 * 2 * 4 * 8 = 64 elements per side; 64 * 2 bits = 128 bits = 16 bytes per side; * 2 = 32 bytes.
        let buf = ANEKVCacheBuffer(
            numLayers: 1, numHeads: 2, headDim: 4, seqLen: 8,
            quantBitsPerElement: 2, bytes: Data(count: 32)
        )
        try await backend.implantKVCache(buf, into: handle)
        _ = goodBuffer // suppress unused; kept inline for the doc

        // Wrong-size buffer: implant rejects.
        let badBuffer = ANEKVCacheBuffer(
            numLayers: 1, numHeads: 2, headDim: 4, seqLen: 8,
            quantBitsPerElement: 2, bytes: Data(count: 99)
        )
        do {
            try await backend.implantKVCache(badBuffer, into: handle)
            Issue.record("expected inferenceShapeMismatch")
        } catch let ANEBackendError.inferenceShapeMismatch(detail) {
            #expect(detail.contains("99"))
        } catch {
            Issue.record("unexpected error type: \(error)")
        }
    }

    @Test("ANEKVCacheBuffer round-trips through Codable")
    func kvBufferRoundTripsThroughCodable() throws {
        let buffer = ANEKVCacheBuffer(
            numLayers: 4, numHeads: 8, headDim: 16, seqLen: 32,
            quantBitsPerElement: 4, bytes: Data([0xA5, 0xB7, 0xC9])
        )
        let json = try JSONEncoder().encode(buffer)
        let recovered = try JSONDecoder().decode(ANEKVCacheBuffer.self, from: json)
        #expect(recovered == buffer)
    }
}
