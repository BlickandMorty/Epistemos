import Foundation

// MARK: - V3.2 ANEBackend
//
// Swift protocol surface for the Apple Neural Engine direct path —
// keeping inference on the Neural Engine for the layers it's good at
// (quantized matmuls, residency-friendly cache layouts) without GPU
// bus crossings. Per the post-recovery V2 plan §V3.2 + the design doc
// `docs/V2_4_AND_V3_2_DESIGN_2026_05_05.md`.
//
// **Build status (this slice):**
// - Protocol declaration ✓ (this file)
// - MockANEBackend in-process implementation ✓ (sibling file)
// - KV implantation typed buffer format ✓ (this file)
// - Tests against the mock ✓ (test file)
// - PrivateFrameworkANEBackend (does the dlopen of private
//   MLNeuralEngineModel) — DEFERRED to V3.2 second slice. Will be
//   `#if PRO_BUILD`-gated so MAS builds never compile it.
//
// **Doctrine alignment (cognitive DAG doctrine §6):**
// Companions own their model lineage via `Deforms` edges. When a
// companion swaps in via `CompanionRegistry::register`, the resolved
// `(weight_root, lora_path, weight_alpha)` becomes the input to
// `ANEBackend.loadModel(handle:)`. This file declares the shape of
// the handle that crosses the boundary; the Phase 8.D companion
// lifecycle work + V3.2 second slice complete the wiring.

// MARK: - Typed handles

/// Opaque handle to a loaded ANE model. The backend owns the actual
/// weight residency; callers see only this id. Equatable so callers
/// can store in collections; Codable so handles can cross the FFI
/// boundary into Rust if a future slice wants to surface ANE-resident
/// models in the cognitive DAG.
nonisolated public struct ANEModelHandle: Sendable, Hashable, Codable, CustomStringConvertible {
    public let id: UInt64
    public let modelLabel: String

    public init(id: UInt64, modelLabel: String) {
        self.id = id
        self.modelLabel = modelLabel
    }

    public var description: String {
        "ANEModelHandle(id=\(id), label=\(modelLabel))"
    }
}

/// Errors specific to the ANE backend. Concrete + flat so callers
/// can pattern-match without dynamic casts.
nonisolated public enum ANEBackendError: Error, Sendable, Equatable, CustomStringConvertible {
    /// The backend could not find the weight file at the given URL.
    case modelFileNotFound(url: URL)
    /// The weight file exists but the format is not parseable by the
    /// backend (e.g. the mock backend only accepts `.safetensors`
    /// files, the production `PrivateFrameworkANEBackend` accepts
    /// CoreML `.mlmodelc` directories).
    case modelFormatUnsupported(detail: String)
    /// The handle does not refer to a currently-loaded model. Either
    /// it was already unloaded, or it came from a different backend
    /// instance.
    case handleNotLoaded(handle: ANEModelHandle)
    /// The ANE rejected the inference request — typically because
    /// the input tensor shape doesn't match the model's compiled
    /// signature.
    case inferenceShapeMismatch(detail: String)
    /// The private MLNeuralEngineModel framework symbol could not
    /// be loaded at runtime. PRO_BUILD only — mock + protocol surface
    /// never throw this.
    case privateFrameworkLoadFailed(detail: String)
    /// The backend is being torn down; in-flight inferences are
    /// cancelled.
    case shutdown

    public var description: String {
        switch self {
        case .modelFileNotFound(let url):
            return "ANE: model file not found at \(url.path)"
        case .modelFormatUnsupported(let detail):
            return "ANE: model format unsupported — \(detail)"
        case .handleNotLoaded(let handle):
            return "ANE: handle not loaded — \(handle)"
        case .inferenceShapeMismatch(let detail):
            return "ANE: inference shape mismatch — \(detail)"
        case .privateFrameworkLoadFailed(let detail):
            return "ANE: private framework load failed — \(detail)"
        case .shutdown:
            return "ANE: backend shutdown"
        }
    }
}

// MARK: - KV implantation typed buffer

/// Typed buffer format for moving a KV cache state between models.
/// "KV implantation" is the V3.2 technique that lets a quantized
/// 1.25-bit Sherry-style ANE model accept a KV cache produced by a
/// different model layout — the bridge between the V3.1 ternary
/// substrate and the V3.2 ANE direct path.
///
/// Encoding contract:
/// - `numLayers`, `numHeads`, `headDim`, `seqLen` are all u32; the
///   total cache size = `numLayers * numHeads * headDim * seqLen *
///   sizeof(quantElement) * 2` (the `* 2` is K + V).
/// - `quantBitsPerElement` is one of {1, 2, 4, 8, 16, 32} — the
///   ternary substrate uses 2 (since 1.25 bits can't be expressed
///   per-element; the 2-bit packing carries the ternary alphabet).
/// - `bytes` holds the K and V buffers concatenated, K first, in
///   row-major layer × head × position × dim order. The reader
///   reconstructs the per-layer slices via offset math.
nonisolated public struct ANEKVCacheBuffer: Sendable, Codable, Hashable {
    public let numLayers: UInt32
    public let numHeads: UInt32
    public let headDim: UInt32
    public let seqLen: UInt32
    public let quantBitsPerElement: UInt8
    public let bytes: Data

    public init(
        numLayers: UInt32,
        numHeads: UInt32,
        headDim: UInt32,
        seqLen: UInt32,
        quantBitsPerElement: UInt8,
        bytes: Data
    ) {
        self.numLayers = numLayers
        self.numHeads = numHeads
        self.headDim = headDim
        self.seqLen = seqLen
        self.quantBitsPerElement = quantBitsPerElement
        self.bytes = bytes
    }

    /// Total declared cache size in bytes. Useful for sanity-checking
    /// `bytes.count` against the descriptor — a mismatch is an
    /// implant validation failure.
    public var declaredByteCount: UInt64 {
        let elementsPerSide =
            UInt64(numLayers) * UInt64(numHeads) * UInt64(headDim) * UInt64(seqLen)
        let bitsPerSide = elementsPerSide * UInt64(quantBitsPerElement)
        let bytesPerSide = (bitsPerSide + 7) / 8
        return bytesPerSide * 2 // K + V
    }

    /// Whether the descriptor's declared size matches the bytes
    /// payload. Backends should call this before attempting an
    /// implant; mismatch returns `ANEBackendError.inferenceShapeMismatch`.
    public var isWellSized: Bool {
        UInt64(bytes.count) == declaredByteCount
    }
}

// MARK: - Backend protocol

/// Backend that owns ANE-resident models + serves inference. The
/// protocol is `nonisolated` because backend implementations choose
/// their own isolation (the mock is an actor; the
/// PrivateFrameworkANEBackend is a class with internal locking).
///
/// Lifecycle:
///   loadModel → (optional) implantKVCache → generate → unloadModel
///
/// Backends are expected to clean up automatically on `unloadModel`
/// + on shutdown. Failure to unload before backend deinit is a
/// resource leak — the mock asserts on it in tests.
nonisolated public protocol ANEBackend: Sendable {
    /// Load a model from the given URL. Returns a typed handle the
    /// caller passes to subsequent ops. Same URL loaded twice gives
    /// two different handles (no implicit dedup; backends own their
    /// residency strategy).
    func loadModel(at url: URL, label: String) async throws -> ANEModelHandle

    /// Implant a previously-extracted KV cache into the loaded model.
    /// Used by the V3.2 model-handoff pattern: model A produces a
    /// cache, model B (an ANE-resident quantized peer) accepts it as
    /// its starting state. Throws `inferenceShapeMismatch` if the
    /// buffer's declared shape doesn't fit the model.
    func implantKVCache(
        _ buffer: ANEKVCacheBuffer,
        into handle: ANEModelHandle
    ) async throws

    /// Generate from the model. Returns an AsyncStream of token ids
    /// (Int32). Stream finishes naturally when the model emits its
    /// EOS token or `maxNewTokens` is reached. Throws on shutdown
    /// or shape mismatch.
    func generate(
        handle: ANEModelHandle,
        promptTokens: [Int32],
        maxNewTokens: Int
    ) async throws -> AsyncStream<Int32>

    /// Unload the model. Releases ANE residency + cancels any
    /// in-flight generations against this handle. Idempotent —
    /// repeated unloads of the same handle are no-ops.
    func unloadModel(_ handle: ANEModelHandle) async throws

    /// Cooperative shutdown. After this, all subsequent calls throw
    /// `.shutdown`. Idempotent.
    func shutdown() async
}
