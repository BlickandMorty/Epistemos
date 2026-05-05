import Foundation

// MARK: - V3.2 MockANEBackend
//
// In-process mock that satisfies `ANEBackend` without loading actual
// CoreML models or accessing the Neural Engine. Used by tests + by
// the V3.2 "buildable today" workflow — exercises the protocol shape,
// the typed buffer formats, and the lifecycle ordering without
// requiring the PrivateFrameworkANEBackend's `dlopen` path or any
// signing.
//
// **Determinism contract:** the mock's `generate` output is a function
// of `(promptTokens, maxNewTokens, seed)` so tests can assert exact
// token sequences without flake. Default seed is 0; callers can
// override per-mock-instance via `init(seed:)`.

/// In-process mock of `ANEBackend`. Records every call in `callLog`
/// for test assertions. Generates deterministic token sequences so
/// tests can assert exact outputs.
public actor MockANEBackend: ANEBackend {

    // MARK: - Recorded state

    public enum Call: Equatable, Sendable {
        case loadModel(url: URL, label: String)
        case implantKVCache(handle: ANEModelHandle, declaredBytes: UInt64)
        case generate(handle: ANEModelHandle, promptTokenCount: Int, maxNewTokens: Int)
        case unloadModel(handle: ANEModelHandle)
        case shutdown
    }

    private(set) var callLog: [Call] = []
    private var loadedHandles: Set<UInt64> = []
    private var nextHandleId: UInt64 = 1
    private var seed: UInt64
    private var isShutdown: Bool = false

    public init(seed: UInt64 = 0) {
        self.seed = seed
    }

    /// Snapshot the call log for test assertions. Actor-bound.
    public func snapshotCallLog() -> [Call] {
        callLog
    }

    /// True iff the handle is currently loaded. Actor-bound.
    public func isLoaded(_ handle: ANEModelHandle) -> Bool {
        loadedHandles.contains(handle.id)
    }

    // MARK: - ANEBackend conformance

    public func loadModel(at url: URL, label: String) async throws -> ANEModelHandle {
        try ensureNotShutdown()
        callLog.append(.loadModel(url: url, label: label))
        // Mock format check: only `.safetensors` files are accepted.
        // The PrivateFrameworkANEBackend in V3.2 second slice will
        // accept `.mlmodelc` directories (the CoreML compiled-model
        // format).
        guard url.pathExtension == "safetensors" else {
            throw ANEBackendError.modelFormatUnsupported(
                detail: "Mock requires .safetensors; got .\(url.pathExtension)"
            )
        }
        // We DON'T require the file to actually exist on disk because
        // tests construct synthetic URLs. Production would check
        // `FileManager.default.fileExists(atPath:)` here.
        let handle = ANEModelHandle(id: nextHandleId, modelLabel: label)
        nextHandleId += 1
        loadedHandles.insert(handle.id)
        return handle
    }

    public func implantKVCache(
        _ buffer: ANEKVCacheBuffer,
        into handle: ANEModelHandle
    ) async throws {
        try ensureNotShutdown()
        callLog.append(.implantKVCache(
            handle: handle,
            declaredBytes: buffer.declaredByteCount
        ))
        guard loadedHandles.contains(handle.id) else {
            throw ANEBackendError.handleNotLoaded(handle: handle)
        }
        guard buffer.isWellSized else {
            throw ANEBackendError.inferenceShapeMismatch(
                detail: "KV cache buffer payload \(buffer.bytes.count) bytes does not match declared \(buffer.declaredByteCount)"
            )
        }
        // Mock: cache is accepted; no actual residency change.
    }

    public func generate(
        handle: ANEModelHandle,
        promptTokens: [Int32],
        maxNewTokens: Int
    ) async throws -> AsyncStream<Int32> {
        try ensureNotShutdown()
        callLog.append(.generate(
            handle: handle,
            promptTokenCount: promptTokens.count,
            maxNewTokens: maxNewTokens
        ))
        guard loadedHandles.contains(handle.id) else {
            throw ANEBackendError.handleNotLoaded(handle: handle)
        }
        guard maxNewTokens > 0 else {
            throw ANEBackendError.inferenceShapeMismatch(
                detail: "maxNewTokens must be > 0; got \(maxNewTokens)"
            )
        }
        let tokens = Self.deterministicGeneration(
            promptTokens: promptTokens,
            maxNewTokens: maxNewTokens,
            seed: seed,
            handleId: handle.id
        )
        return AsyncStream(bufferingPolicy: .bufferingNewest(maxNewTokens)) { continuation in
            for token in tokens {
                continuation.yield(token)
            }
            continuation.finish()
        }
    }

    public func unloadModel(_ handle: ANEModelHandle) async throws {
        callLog.append(.unloadModel(handle: handle))
        // Idempotent: removing an absent id is a no-op (per protocol
        // contract).
        loadedHandles.remove(handle.id)
    }

    public func shutdown() async {
        callLog.append(.shutdown)
        isShutdown = true
        loadedHandles.removeAll()
    }

    // MARK: - Helpers

    private func ensureNotShutdown() throws {
        if isShutdown {
            throw ANEBackendError.shutdown
        }
    }

    /// Pure function — same inputs always produce the same outputs.
    /// The token sequence is a simple LCG over the seed + handle id +
    /// prompt fingerprint, capped at `maxNewTokens`. This is enough
    /// for tests to assert exact outputs without committing to a
    /// realistic distribution.
    nonisolated private static func deterministicGeneration(
        promptTokens: [Int32],
        maxNewTokens: Int,
        seed: UInt64,
        handleId: UInt64
    ) -> [Int32] {
        // Seed mixing: combine seed + handle + prompt sum so two
        // different handles or prompts produce different sequences,
        // but the same triple always produces the same output.
        var state: UInt64 = seed &+ handleId &* 0x9E3779B97F4A7C15
        for token in promptTokens {
            state = state &* 6364136223846793005 &+ UInt64(bitPattern: Int64(token))
        }
        var out: [Int32] = []
        out.reserveCapacity(maxNewTokens)
        for _ in 0..<maxNewTokens {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            // Mock vocab: 0..32000 (matches typical Llama-class tokenizer).
            let id = Int32(truncatingIfNeeded: (state >> 33) % 32_000)
            out.append(id)
        }
        return out
    }
}
