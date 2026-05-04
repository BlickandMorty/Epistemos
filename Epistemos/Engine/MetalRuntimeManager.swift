import Foundation
import Metal
import MetalPerformanceShaders
import os

/// MetalRuntimeManager manages custom Metal compute kernels for the Mamba-2 runtime.
///
/// Responsibilities:
/// - Load and cache compiled pipeline states for all Mamba-2 kernels
/// - Manage MTLHeap for arena allocation of inference buffers
/// - Provide ping-pong state buffers for SSM recurrence
/// - Encode SSD forward pass steps into command buffers
/// - Coordinate with MPS for dense matmul operations
///
/// Design constraints:
/// - Apple GPUs have 32KB threadgroup memory (M1 through M4)
/// - Chunk size Q=128 (16KB FP16 fits in threadgroup)
/// - NO Decoupled Lookback (crashes on Apple GPUs — no FPG)
/// - Uses 3-dispatch Reduce-then-Scan for inter-chunk state passing
/// - MPS for all dense matmuls (8.5x faster than custom)
@Observable
final class MetalRuntimeManager: @unchecked Sendable {
    private static let log = Logger(subsystem: "com.epistemos", category: "MetalRuntime")

    // MARK: - Device & Queue

    let device: MTLDevice
    let commandQueue: MTLCommandQueue

    // MARK: - Compiled Pipelines

    private var segsumPipeline: MTLComputePipelineState?
    private var segsumTiledPipeline: MTLComputePipelineState?
    private var interChunkReducePipeline: MTLComputePipelineState?
    private var interChunkScanTilesPipeline: MTLComputePipelineState?
    private var interChunkApplyPipeline: MTLComputePipelineState?
    private var intraChunkScanPipeline: MTLComputePipelineState?
    private var chunkStateDecayPipeline: MTLComputePipelineState?
    private var ssdOutputMergePipeline: MTLComputePipelineState?
    private var siluGatePipeline: MTLComputePipelineState?
    private var rmsNormPipeline: MTLComputePipelineState?
    private var stateBufferCopyPipeline: MTLComputePipelineState?
    private var convK4Pipeline: MTLComputePipelineState?
    private var convK4SiluPipeline: MTLComputePipelineState?
    private var convStepPipeline: MTLComputePipelineState?

    // MARK: - State Buffers (Ping-Pong)

    /// Ping-pong state buffers for SSM recurrence.
    /// MTLStorageModeShared: zero-copy CPU/GPU on Apple Silicon unified memory.
    private var stateBufferA: MTLBuffer?
    private var stateBufferB: MTLBuffer?
    private var currentStateIndex: Int = 0

    /// Inference heap for fast batch allocation (reduces individual makeBuffer overhead).
    private var inferenceHeap: MTLHeap?

    // MARK: - Configuration

    /// Whether all kernels compiled successfully.
    private(set) var isReady: Bool = false

    /// Kernel compilation errors, if any.
    private(set) var compilationErrors: [String] = []

    // MARK: - Wave 4.2 — MTLBinaryArchive caching

    /// Persistent compiled-pipeline cache. On first launch the archive is
    /// empty; pipelines compile normally and we serialise the archive at
    /// the end of `compileKernels()`. On subsequent launches Metal looks
    /// up each pipeline in the archive and skips compilation when found.
    ///
    /// The archive is best-effort: a missing / corrupt / version-mismatched
    /// file is logged and the runtime falls back to fresh compilation.
    private var binaryArchive: MTLBinaryArchive?

    /// Filesystem path for the persisted archive. Lives under the user's
    /// Caches directory so it survives normal uses but a "clean caches"
    /// rebuild forces fresh compilation. The filename includes a build
    /// version stamp so an app upgrade automatically invalidates the
    /// archive without us having to write migration logic.
    private static let archiveFileName = "Epistemos-mamba2-pipelines.metalarchive"

    private static func archiveURL() -> URL? {
        guard let caches = try? FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else {
            return nil
        }
        return caches.appendingPathComponent(archiveFileName, isDirectory: false)
    }

    /// Whether the binary archive was loaded from disk for this run
    /// (vs freshly created). Surfaced for tests + the post-compile log.
    private(set) var binaryArchiveLoadedFromDisk: Bool = false

    // MARK: - Initialization

    init?() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            Self.log.error("Metal device unavailable")
            return nil
        }
        guard let queue = device.makeCommandQueue() else {
            Self.log.error("Failed to create command queue")
            return nil
        }
        self.device = device
        self.commandQueue = queue

        Self.log.info("MetalRuntimeManager initialized on \(device.name, privacy: .public)")
    }

    // MARK: - Pipeline Compilation

    /// Compile all Mamba-2 Metal kernels from the app's metallib.
    /// Call this once at startup (or lazily on first inference).
    func compileKernels() {
        guard let library = device.makeDefaultLibrary() else {
            compilationErrors.append("No default Metal library found")
            Self.log.error("No default Metal library — check that .metal files are included in build target")
            return
        }

        // Wave 4.2: open or create the binary archive BEFORE compiling
        // pipelines so each pipeline can attach the archive via its
        // descriptor. Missing / corrupt archives degrade silently into
        // fresh compilation; we log but do not fail.
        loadOrCreateBinaryArchive()

        var errors: [String] = []

        // Segsum kernels
        segsumPipeline = compilePipeline(library: library, name: "segsum_stable", errors: &errors)
        segsumTiledPipeline = compilePipeline(library: library, name: "segsum_stable_tiled", errors: &errors)

        // Inter-chunk scan (3-dispatch safe approach)
        interChunkReducePipeline = compilePipeline(library: library, name: "inter_chunk_reduce", errors: &errors)
        interChunkScanTilesPipeline = compilePipeline(library: library, name: "inter_chunk_scan_tiles", errors: &errors)
        interChunkApplyPipeline = compilePipeline(library: library, name: "inter_chunk_apply", errors: &errors)
        intraChunkScanPipeline = compilePipeline(library: library, name: "intra_chunk_scan", errors: &errors)

        // Elementwise helpers
        chunkStateDecayPipeline = compilePipeline(library: library, name: "chunk_state_decay", errors: &errors)
        ssdOutputMergePipeline = compilePipeline(library: library, name: "ssd_output_merge", errors: &errors)
        siluGatePipeline = compilePipeline(library: library, name: "silu_gate", errors: &errors)
        rmsNormPipeline = compilePipeline(library: library, name: "rms_norm", errors: &errors)
        stateBufferCopyPipeline = compilePipeline(library: library, name: "state_buffer_copy", errors: &errors)

        // Direct convolution
        convK4Pipeline = compilePipeline(library: library, name: "depthwise_conv1d_k4", errors: &errors)
        convK4SiluPipeline = compilePipeline(library: library, name: "depthwise_conv1d_k4_silu", errors: &errors)
        convStepPipeline = compilePipeline(library: library, name: "conv1d_step", errors: &errors)

        compilationErrors = errors
        isReady = errors.isEmpty

        if isReady {
            Self.log.info("All 14 Mamba-2 kernels compiled successfully (archive loaded from disk: \(self.binaryArchiveLoadedFromDisk, privacy: .public))")
            // Wave 4.2: persist the populated archive so the next launch
            // can skip pipeline compilation. Best-effort — a write
            // failure does not affect this run.
            persistBinaryArchive()
        } else {
            Self.log.warning("Kernel compilation had \(errors.count) error(s): \(errors.joined(separator: "; "), privacy: .public)")
        }
    }

    private func compilePipeline(
        library: MTLLibrary,
        name: String,
        errors: inout [String]
    ) -> MTLComputePipelineState? {
        guard let function = library.makeFunction(name: name) else {
            // Function constants may cause this for function_constant-gated kernels
            Self.log.debug("Kernel '\(name, privacy: .public)' not found in library (may use function constants)")
            return nil
        }
        do {
            let pipeline: MTLComputePipelineState
            if let archive = binaryArchive {
                // Wave 4.2: descriptor path lets Metal look up the
                // function in the archive and skip compilation when
                // the cached binary matches.
                let descriptor = MTLComputePipelineDescriptor()
                descriptor.computeFunction = function
                descriptor.binaryArchives = [archive]
                pipeline = try device.makeComputePipelineState(
                    descriptor: descriptor,
                    options: [],
                    reflection: nil
                )
                // Add this descriptor to the archive so future runs hit
                // the cache. addComputePipelineFunctions is a no-op
                // when the entry already exists.
                do {
                    try archive.addComputePipelineFunctions(descriptor: descriptor)
                } catch {
                    Self.log.debug("archive.add for '\(name, privacy: .public)' failed: \(error.localizedDescription, privacy: .public)")
                }
            } else {
                pipeline = try device.makeComputePipelineState(function: function)
            }
            Self.log.debug("Compiled kernel '\(name, privacy: .public)' — maxThreads=\(pipeline.maxTotalThreadsPerThreadgroup)")
            return pipeline
        } catch {
            let msg = "\(name): \(error.localizedDescription)"
            errors.append(msg)
            Self.log.error("Failed to compile kernel '\(name, privacy: .public)': \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Wave 4.2 — binary archive helpers

    private func loadOrCreateBinaryArchive() {
        guard let url = Self.archiveURL() else {
            Self.log.warning("Cannot resolve caches directory for binary archive — pipelines will compile fresh every launch")
            return
        }

        let descriptor = MTLBinaryArchiveDescriptor()
        if FileManager.default.fileExists(atPath: url.path) {
            descriptor.url = url
            do {
                binaryArchive = try device.makeBinaryArchive(descriptor: descriptor)
                binaryArchiveLoadedFromDisk = true
                Self.log.info("Loaded Metal binary archive from \(url.path, privacy: .public)")
                return
            } catch {
                // Stale / corrupt / version-mismatched archive — fall
                // through to fresh creation. Don't delete the bad file
                // here; the next persistBinaryArchive() will overwrite.
                Self.log.warning("Could not load binary archive from \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public). Creating fresh.")
            }
        }

        descriptor.url = nil
        do {
            binaryArchive = try device.makeBinaryArchive(descriptor: descriptor)
            binaryArchiveLoadedFromDisk = false
            Self.log.info("Created fresh Metal binary archive (will persist after compileKernels)")
        } catch {
            Self.log.warning("Could not create binary archive: \(error.localizedDescription, privacy: .public). Pipelines will compile every launch.")
            binaryArchive = nil
        }
    }

    private func persistBinaryArchive() {
        guard let archive = binaryArchive, let url = Self.archiveURL() else {
            return
        }
        do {
            try archive.serialize(to: url)
            Self.log.info("Serialized Metal binary archive to \(url.path, privacy: .public)")
        } catch {
            Self.log.warning("Failed to serialize binary archive: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - State Buffer Management

    /// Allocate ping-pong state buffers for a given model configuration.
    /// Uses MTLStorageModeShared for zero-copy CPU/GPU access on Apple Silicon.
    ///
    /// - Parameters:
    ///   - layers: number of model layers
    ///   - stateDim: SSM state dimension (N, typically 64)
    ///   - headDim: per-head dimension (D_head, typically 64)
    ///   - heads: number of heads (H, typically 32)
    func allocateStateBuffers(layers: Int, stateDim: Int, headDim: Int, heads: Int) {
        let bytesPerLayer = heads * stateDim * headDim * 2  // FP16 = 2 bytes
        let totalBytes = layers * bytesPerLayer

        stateBufferA = device.makeBuffer(length: totalBytes, options: .storageModeShared)
        stateBufferB = device.makeBuffer(length: totalBytes, options: .storageModeShared)
        currentStateIndex = 0

        let sizeMB = Double(totalBytes) / (1024 * 1024)
        Self.log.info("Allocated state buffers: 2 × \(String(format: "%.1f", sizeMB))MB (\(layers) layers, H=\(heads), N=\(stateDim), D=\(headDim))")
    }

    /// Get the current read state buffer and the write buffer.
    var currentStateBuffer: MTLBuffer? {
        currentStateIndex == 0 ? stateBufferA : stateBufferB
    }

    var nextStateBuffer: MTLBuffer? {
        currentStateIndex == 0 ? stateBufferB : stateBufferA
    }

    /// Swap read/write state buffers after a generation step.
    func swapStateBuffers() {
        currentStateIndex ^= 1
    }

    // MARK: - Snapshot Save/Load

    /// Copy current state buffer to a Data object for disk persistence.
    /// This is a memcpy from the shared GPU/CPU buffer — ~2ms for 16MB on NVMe.
    func snapshotState() -> Data? {
        guard let buffer = currentStateBuffer else { return nil }
        return Data(bytes: buffer.contents(), count: buffer.length)
    }

    /// Load state data into the current state buffer.
    func loadState(_ data: Data) -> Bool {
        guard let buffer = currentStateBuffer, data.count <= buffer.length else { return false }
        guard !data.isEmpty else { return true }
        data.withUnsafeBytes { ptr in
            guard let baseAddress = ptr.baseAddress else { return }
            buffer.contents().copyMemory(from: baseAddress, byteCount: data.count)
        }
        return true
    }

    // MARK: - MPS Matmul

    /// Create an MPS matrix multiplication for the dense projection layers.
    /// MPS achieves 2.9 TFLOPS on M4 — 8.5x faster than custom Metal.
    func createMatmul(
        rows: Int,
        columns: Int,
        inner: Int,
        transposeLeft: Bool = false,
        transposeRight: Bool = false
    ) -> MPSMatrixMultiplication {
        MPSMatrixMultiplication(
            device: device,
            transposeLeft: transposeLeft,
            transposeRight: transposeRight,
            resultRows: rows,
            resultColumns: columns,
            interiorColumns: inner,
            alpha: 1.0, beta: 0.0
        )
    }

    // MARK: - Heap Management

    /// Pre-allocate an inference heap for fast buffer sub-allocation.
    /// Eliminates per-buffer makeBuffer overhead during inference.
    func allocateInferenceHeap(sizeBytes: Int) {
        let descriptor = MTLHeapDescriptor()
        descriptor.storageMode = .shared
        descriptor.size = sizeBytes
        descriptor.hazardTrackingMode = .tracked

        inferenceHeap = device.makeHeap(descriptor: descriptor)

        let sizeMB = Double(sizeBytes) / (1024 * 1024)
        Self.log.info("Allocated inference heap: \(String(format: "%.0f", sizeMB))MB")
    }

    /// Allocate a buffer from the inference heap (faster than device.makeBuffer).
    /// Default `options: .storageModeShared` keeps the UMA zero-copy
    /// invariant; caller may override (W4.3-aware).
    func heapBuffer(length: Int, options: MTLResourceOptions = .storageModeShared) -> MTLBuffer? {
        inferenceHeap?.makeBuffer(length: length, options: options) // W4.3-OPTOUT: pass-through of caller-supplied options; default at signature is .storageModeShared
    }

    /// Release large runtime allocations so idle unload can return unified
    /// memory to the system instead of keeping SSM buffers warm indefinitely.
    func releaseWorkingSet() {
        stateBufferA = nil
        stateBufferB = nil
        currentStateIndex = 0
        inferenceHeap = nil
        Self.log.info("Released Metal runtime working set")
    }

    /// Aggressively drop the *compiled* pipeline cache + binary archive on
    /// top of `releaseWorkingSet`. Each `MTLComputePipelineState` retains
    /// device-side state (~500 KB each × 14 kernels ≈ 6–8 MB) and the
    /// MTLBinaryArchive holds the in-memory image of the on-disk
    /// `\(archiveFileName)` (~3–5 MB). This is the right call from the
    /// memory-pressure `.critical` path: we trade a one-off ~200–500 ms
    /// recompile on the next inference for ~10–15 MB unified memory
    /// returned now. The on-disk archive survives, so the recompile
    /// hits the warm path once it lands.
    ///
    /// Idempotent — safe to call multiple times. Do NOT call from the
    /// inference hot path; this is a steady-state-pressure response.
    func deepUnload() {
        releaseWorkingSet()
        segsumPipeline = nil
        segsumTiledPipeline = nil
        interChunkReducePipeline = nil
        interChunkScanTilesPipeline = nil
        interChunkApplyPipeline = nil
        intraChunkScanPipeline = nil
        chunkStateDecayPipeline = nil
        ssdOutputMergePipeline = nil
        siluGatePipeline = nil
        rmsNormPipeline = nil
        stateBufferCopyPipeline = nil
        convK4Pipeline = nil
        convK4SiluPipeline = nil
        convStepPipeline = nil
        binaryArchive = nil
        binaryArchiveLoadedFromDisk = false
        Self.log.info("Released Metal pipelines + binary archive (deepUnload)")
    }

    // MARK: - Command Buffer Creation

    /// Create a new command buffer for encoding a forward pass.
    /// Each command buffer should complete in < 2 seconds to avoid GPU watchdog.
    func makeCommandBuffer(label: String? = nil) -> MTLCommandBuffer? {
        let buffer = commandQueue.makeCommandBuffer()
        buffer?.label = label
        return buffer
    }

    enum RuntimeError: LocalizedError, Sendable {
        case kernelsUnavailable([String])
        case missingPipeline(String)
        case commandBufferCreationFailed
        case commandEncodingFailed(String)
        case bufferAllocationFailed(String)
        case commandBufferFailed(String)

        var errorDescription: String? {
            switch self {
            case .kernelsUnavailable(let errors):
                return errors.isEmpty
                    ? "Metal kernels are unavailable."
                    : "Metal kernels are unavailable: \(errors.joined(separator: "; "))"
            case .missingPipeline(let name):
                return "Missing Metal pipeline: \(name)"
            case .commandBufferCreationFailed:
                return "Failed to create Metal command buffer."
            case .commandEncodingFailed(let name):
                return "Failed to encode Metal kernel: \(name)"
            case .bufferAllocationFailed(let name):
                return "Failed to allocate Metal buffer: \(name)"
            case .commandBufferFailed(let reason):
                return "Metal command buffer failed: \(reason)"
            }
        }
    }

    func ensureKernelsReady() throws {
        if !isReady {
            compileKernels()
        }
        guard isReady else {
            throw RuntimeError.kernelsUnavailable(compilationErrors)
        }
    }

    func makeSharedBuffer(length: Int, label: String? = nil) throws -> MTLBuffer {
        guard let buffer = device.makeBuffer(length: length, options: .storageModeShared) else {
            throw RuntimeError.bufferAllocationFailed(label ?? "shared")
        }
        buffer.label = label
        return buffer
    }

    func makeSharedBuffer<Element>(
        from values: [Element],
        label: String? = nil
    ) throws -> MTLBuffer {
        let length = values.count * MemoryLayout<Element>.stride
        let buffer = try makeSharedBuffer(length: length, label: label)
        values.withUnsafeBytes { source in
            guard let baseAddress = source.baseAddress else { return }
            buffer.contents().copyMemory(from: baseAddress, byteCount: length)
        }
        return buffer
    }

    func readSharedBuffer<Element>(
        _ buffer: MTLBuffer,
        as type: Element.Type,
        count: Int
    ) -> [Element] {
        let pointer = buffer.contents().bindMemory(to: Element.self, capacity: count)
        return Array(UnsafeBufferPointer(start: pointer, count: count))
    }

    func encodeMatmul(
        commandBuffer: MTLCommandBuffer,
        leftBuffer: MTLBuffer,
        rightBuffer: MTLBuffer,
        resultBuffer: MTLBuffer,
        rows: Int,
        columns: Int,
        inner: Int,
        label: String? = nil
    ) {
        let matMul = createMatmul(rows: rows, columns: columns, inner: inner)

        let descA = MPSMatrixDescriptor(rows: rows, columns: inner, rowBytes: inner * 2, dataType: .float16)
        let descB = MPSMatrixDescriptor(rows: inner, columns: columns, rowBytes: columns * 2, dataType: .float16)
        let descC = MPSMatrixDescriptor(rows: rows, columns: columns, rowBytes: columns * 2, dataType: .float16)

        let matA = MPSMatrix(buffer: leftBuffer, descriptor: descA)
        let matB = MPSMatrix(buffer: rightBuffer, descriptor: descB)
        let matC = MPSMatrix(buffer: resultBuffer, descriptor: descC)

        commandBuffer.pushDebugGroup(label ?? "mps_matmul")
        matMul.encode(commandBuffer: commandBuffer, leftMatrix: matA, rightMatrix: matB, resultMatrix: matC)
        commandBuffer.popDebugGroup()
    }

    func encodeIntraChunkScan(
        commandBuffer: MTLCommandBuffer,
        aLog: MTLBuffer,
        cumulativeDecay: MTLBuffer,
        batchSize: Int,
        sequenceLength: Int,
        headCount: Int,
        chunkLength: Int
    ) throws {
        try encodeCompute(
            commandBuffer: commandBuffer,
            pipeline: intraChunkScanPipeline,
            name: "intra_chunk_scan"
        ) { encoder in
            var batchSize = UInt32(batchSize)
            var sequenceLength = UInt32(sequenceLength)
            var headCount = UInt32(headCount)
            var chunkLength = UInt32(chunkLength)
            let chunkCount = max(1, (sequenceLength + chunkLength - 1) / chunkLength)
            let chunkLengthInt = Int(chunkLength)

            encoder.setBuffer(aLog, offset: 0, index: 0)
            encoder.setBuffer(cumulativeDecay, offset: 0, index: 1)
            encoder.setBytes(&batchSize, length: MemoryLayout<UInt32>.size, index: 2)
            encoder.setBytes(&sequenceLength, length: MemoryLayout<UInt32>.size, index: 3)
            encoder.setBytes(&headCount, length: MemoryLayout<UInt32>.size, index: 4)
            encoder.setBytes(&chunkLength, length: MemoryLayout<UInt32>.size, index: 5)

            let threadgroups = MTLSize(width: Int(chunkCount) * Int(headCount), height: Int(batchSize), depth: 1)
            let threadsPerThreadgroup = MTLSize(width: min(chunkLengthInt, 256), height: 1, depth: 1)
            encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
        }
    }

    func encodeChunkStateDecay(
        commandBuffer: MTLCommandBuffer,
        cumulativeDecay: MTLBuffer,
        decay: MTLBuffer,
        elementCount: Int
    ) throws {
        try encodeCompute(
            commandBuffer: commandBuffer,
            pipeline: chunkStateDecayPipeline,
            name: "chunk_state_decay"
        ) { encoder in
            var elementCount = UInt32(elementCount)
            encoder.setBuffer(cumulativeDecay, offset: 0, index: 0)
            encoder.setBuffer(decay, offset: 0, index: 1)
            encoder.setBytes(&elementCount, length: MemoryLayout<UInt32>.size, index: 2)
            let gridSize = MTLSize(width: Int(elementCount), height: 1, depth: 1)
            let threadgroupSize = MTLSize(width: 256, height: 1, depth: 1)
            encoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadgroupSize)
        }
    }

    func encodeSegsumTiled(
        commandBuffer: MTLCommandBuffer,
        aLog: MTLBuffer,
        lMatrix: MTLBuffer,
        batchSize: Int,
        sequenceLength: Int,
        headCount: Int,
        chunkLength: Int
    ) throws {
        try encodeCompute(
            commandBuffer: commandBuffer,
            pipeline: segsumTiledPipeline ?? segsumPipeline,
            name: segsumTiledPipeline == nil ? "segsum_stable" : "segsum_stable_tiled"
        ) { encoder in
            var batchSize = UInt32(batchSize)
            var sequenceLength = UInt32(sequenceLength)
            var headCount = UInt32(headCount)
            var chunkLength = UInt32(chunkLength)
            let chunkCount = max(1, (sequenceLength + chunkLength - 1) / chunkLength)
            let chunkLengthInt = Int(chunkLength)

            encoder.setBuffer(aLog, offset: 0, index: 0)
            encoder.setBuffer(lMatrix, offset: 0, index: 1)
            encoder.setBytes(&batchSize, length: MemoryLayout<UInt32>.size, index: 2)
            encoder.setBytes(&sequenceLength, length: MemoryLayout<UInt32>.size, index: 3)
            encoder.setBytes(&headCount, length: MemoryLayout<UInt32>.size, index: 4)
            encoder.setBytes(&chunkLength, length: MemoryLayout<UInt32>.size, index: 5)

            if segsumTiledPipeline != nil {
                let threadgroups = MTLSize(width: Int(chunkCount) * Int(headCount), height: Int(batchSize), depth: 1)
                let threadsPerThreadgroup = MTLSize(width: min(chunkLengthInt, 256), height: 1, depth: 1)
                encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
            } else {
                let gridSize = MTLSize(
                    width: chunkLengthInt,
                    height: chunkLengthInt,
                    depth: Int(chunkCount) * Int(headCount) * Int(batchSize)
                )
                let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
                encoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadgroupSize)
            }
        }
    }

    func encodeInterChunkStatePassing(
        commandBuffer: MTLCommandBuffer,
        chunkStates: MTLBuffer,
        chunkDecays: MTLBuffer,
        tileStates: MTLBuffer,
        tileDecays: MTLBuffer,
        chunkCount: Int,
        headCount: Int,
        stateDim: Int,
        tileSize: Int
    ) throws {
        let tileCount = max(1, (chunkCount + tileSize - 1) / tileSize)

        try encodeCompute(
            commandBuffer: commandBuffer,
            pipeline: interChunkReducePipeline,
            name: "inter_chunk_reduce"
        ) { encoder in
            var chunkCount = UInt32(chunkCount)
            var headCount = UInt32(headCount)
            var stateDim = UInt32(stateDim)
            var tileSize = UInt32(tileSize)

            encoder.setBuffer(chunkStates, offset: 0, index: 0)
            encoder.setBuffer(chunkDecays, offset: 0, index: 1)
            encoder.setBuffer(tileStates, offset: 0, index: 2)
            encoder.setBuffer(tileDecays, offset: 0, index: 3)
            encoder.setBytes(&chunkCount, length: MemoryLayout<UInt32>.size, index: 4)
            encoder.setBytes(&headCount, length: MemoryLayout<UInt32>.size, index: 5)
            encoder.setBytes(&stateDim, length: MemoryLayout<UInt32>.size, index: 6)
            encoder.setBytes(&tileSize, length: MemoryLayout<UInt32>.size, index: 7)

            let threadgroups = MTLSize(width: tileCount, height: Int(headCount), depth: 1)
            let threadsPerThreadgroup = MTLSize(width: min(Int(stateDim), 256), height: 1, depth: 1)
            encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
        }

        try encodeCompute(
            commandBuffer: commandBuffer,
            pipeline: interChunkScanTilesPipeline,
            name: "inter_chunk_scan_tiles"
        ) { encoder in
            var tileCount = UInt32(tileCount)
            var headCount = UInt32(headCount)
            var stateDim = UInt32(stateDim)

            encoder.setBuffer(tileStates, offset: 0, index: 0)
            encoder.setBuffer(tileDecays, offset: 0, index: 1)
            encoder.setBytes(&tileCount, length: MemoryLayout<UInt32>.size, index: 2)
            encoder.setBytes(&headCount, length: MemoryLayout<UInt32>.size, index: 3)
            encoder.setBytes(&stateDim, length: MemoryLayout<UInt32>.size, index: 4)

            let threadgroups = MTLSize(width: 1, height: Int(headCount), depth: 1)
            let threadsPerThreadgroup = MTLSize(width: min(Int(stateDim), 256), height: 1, depth: 1)
            encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
        }

        try encodeCompute(
            commandBuffer: commandBuffer,
            pipeline: interChunkApplyPipeline,
            name: "inter_chunk_apply"
        ) { encoder in
            var chunkCount = UInt32(chunkCount)
            var headCount = UInt32(headCount)
            var stateDim = UInt32(stateDim)
            var tileSize = UInt32(tileSize)

            encoder.setBuffer(chunkStates, offset: 0, index: 0)
            encoder.setBuffer(chunkDecays, offset: 0, index: 1)
            encoder.setBuffer(tileStates, offset: 0, index: 2)
            encoder.setBuffer(tileDecays, offset: 0, index: 3)
            encoder.setBytes(&chunkCount, length: MemoryLayout<UInt32>.size, index: 4)
            encoder.setBytes(&headCount, length: MemoryLayout<UInt32>.size, index: 5)
            encoder.setBytes(&stateDim, length: MemoryLayout<UInt32>.size, index: 6)
            encoder.setBytes(&tileSize, length: MemoryLayout<UInt32>.size, index: 7)

            let threadgroups = MTLSize(width: Int(chunkCount), height: Int(headCount), depth: 1)
            let threadsPerThreadgroup = MTLSize(width: 1, height: min(Int(stateDim), 256), depth: 1)
            encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
        }
    }

    func encodeOutputMerge(
        commandBuffer: MTLCommandBuffer,
        diagonalOutput: MTLBuffer,
        stateOutput: MTLBuffer,
        mergedOutput: MTLBuffer,
        elementCount: Int
    ) throws {
        try encodeCompute(
            commandBuffer: commandBuffer,
            pipeline: ssdOutputMergePipeline,
            name: "ssd_output_merge"
        ) { encoder in
            var elementCount = UInt32(elementCount)
            encoder.setBuffer(diagonalOutput, offset: 0, index: 0)
            encoder.setBuffer(stateOutput, offset: 0, index: 1)
            encoder.setBuffer(mergedOutput, offset: 0, index: 2)
            encoder.setBytes(&elementCount, length: MemoryLayout<UInt32>.size, index: 3)
            let gridSize = MTLSize(width: Int(elementCount), height: 1, depth: 1)
            let threadgroupSize = MTLSize(width: 256, height: 1, depth: 1)
            encoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadgroupSize)
        }
    }

    func encodeSiluGate(
        commandBuffer: MTLCommandBuffer,
        input: MTLBuffer,
        gate: MTLBuffer,
        output: MTLBuffer,
        elementCount: Int
    ) throws {
        try encodeCompute(
            commandBuffer: commandBuffer,
            pipeline: siluGatePipeline,
            name: "silu_gate"
        ) { encoder in
            var elementCount = UInt32(elementCount)
            encoder.setBuffer(input, offset: 0, index: 0)
            encoder.setBuffer(gate, offset: 0, index: 1)
            encoder.setBuffer(output, offset: 0, index: 2)
            encoder.setBytes(&elementCount, length: MemoryLayout<UInt32>.size, index: 3)
            let gridSize = MTLSize(width: Int(elementCount), height: 1, depth: 1)
            let threadgroupSize = MTLSize(width: 256, height: 1, depth: 1)
            encoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadgroupSize)
        }
    }

    private func encodeCompute(
        commandBuffer: MTLCommandBuffer,
        pipeline: MTLComputePipelineState?,
        name: String,
        body: (MTLComputeCommandEncoder) throws -> Void
    ) throws {
        guard let pipeline else {
            throw RuntimeError.missingPipeline(name)
        }
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw RuntimeError.commandEncodingFailed(name)
        }
        encoder.label = name
        encoder.setComputePipelineState(pipeline)
        try body(encoder)
        encoder.endEncoding()
    }

    // MARK: - Diagnostics

    /// GPU information for performance baseline reporting.
    var deviceInfo: String {
        "\(device.name) — \(device.maxThreadsPerThreadgroup.width)×\(device.maxThreadsPerThreadgroup.height) max threads, \(device.recommendedMaxWorkingSetSize / (1024*1024))MB working set"
    }

    // MARK: - Benchmark Harness

    /// Benchmark result for a single kernel dispatch.
    struct KernelBenchmark: Sendable {
        let kernelName: String
        let dispatchTimeMS: Double
        let elementCount: Int
        let passed: Bool
    }

    /// Run a synthetic benchmark of kernel compilation and basic dispatch.
    /// Returns timing data for PERF_BASELINE.md reporting.
    func runBenchmark() -> [KernelBenchmark] {
        if !isReady {
            compileKernels()
            guard isReady else {
                Self.log.error("Benchmark aborted — kernel compilation failed")
                return []
            }
        }

        var results: [KernelBenchmark] = []
        let elementCount = 128 * 64  // chunk_size × state_dim

        // Benchmark: segsum_stable dispatch
        if let pipeline = segsumPipeline {
            let result = benchmarkKernel(
                name: "segsum_stable",
                pipeline: pipeline,
                elementCount: elementCount,
                threadgroupSize: MTLSize(width: 16, height: 16, depth: 1),
                gridSize: MTLSize(width: 128, height: 128, depth: 1)
            )
            results.append(result)
        }

        // Benchmark: silu_gate dispatch (simple elementwise)
        if let pipeline = siluGatePipeline {
            let result = benchmarkKernel(
                name: "silu_gate",
                pipeline: pipeline,
                elementCount: elementCount,
                threadgroupSize: MTLSize(width: 256, height: 1, depth: 1),
                gridSize: MTLSize(width: elementCount, height: 1, depth: 1)
            )
            results.append(result)
        }

        // Benchmark: state_buffer_copy dispatch (memcpy throughput)
        if let pipeline = stateBufferCopyPipeline {
            let result = benchmarkKernel(
                name: "state_buffer_copy",
                pipeline: pipeline,
                elementCount: elementCount,
                threadgroupSize: MTLSize(width: 256, height: 1, depth: 1),
                gridSize: MTLSize(width: elementCount, height: 1, depth: 1)
            )
            results.append(result)
        }

        // Benchmark: MPS matmul (dense projection baseline)
        let mpsResult = benchmarkMPSMatmul(rows: 128, cols: 64, inner: 64)
        results.append(mpsResult)

        // State buffer alloc/snapshot round-trip
        let stateResult = benchmarkStateRoundTrip(layers: 48, stateDim: 64, headDim: 64, heads: 32)
        results.append(stateResult)

        for r in results {
            Self.log.info("Benchmark \(r.kernelName, privacy: .public): \(String(format: "%.2f", r.dispatchTimeMS))ms elements=\(r.elementCount) pass=\(r.passed)")
        }

        return results
    }

    private func benchmarkKernel(
        name: String,
        pipeline: MTLComputePipelineState,
        elementCount: Int,
        threadgroupSize: MTLSize,
        gridSize: MTLSize
    ) -> KernelBenchmark {
        let bufferSize = elementCount * 2  // FP16
        guard let inputBuffer = device.makeBuffer(length: bufferSize, options: .storageModeShared),
              let outputBuffer = device.makeBuffer(length: bufferSize, options: .storageModeShared),
              let cmdBuf = commandQueue.makeCommandBuffer(),
              let encoder = cmdBuf.makeComputeCommandEncoder() else {
            return KernelBenchmark(kernelName: name, dispatchTimeMS: -1, elementCount: elementCount, passed: false)
        }

        // Fill input with zeros (safe for all kernels)
        memset(inputBuffer.contents(), 0, bufferSize)

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(inputBuffer, offset: 0, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)
        encoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadgroupSize)
        encoder.endEncoding()

        let start = CFAbsoluteTimeGetCurrent()
        cmdBuf.commit()
        cmdBuf.waitUntilCompleted()
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000

        let passed = cmdBuf.status == .completed
        return KernelBenchmark(kernelName: name, dispatchTimeMS: elapsed, elementCount: elementCount, passed: passed)
    }

    private func benchmarkMPSMatmul(rows: Int, cols: Int, inner: Int) -> KernelBenchmark {
        let bufSize = rows * inner * 2  // FP16

        guard let bufA = device.makeBuffer(length: bufSize, options: .storageModeShared),
              let bufB = device.makeBuffer(length: inner * cols * 2, options: .storageModeShared),
              let bufC = device.makeBuffer(length: rows * cols * 2, options: .storageModeShared),
              let cmdBuf = commandQueue.makeCommandBuffer() else {
            return KernelBenchmark(kernelName: "mps_matmul", dispatchTimeMS: -1, elementCount: rows * cols, passed: false)
        }

        let start = CFAbsoluteTimeGetCurrent()
        encodeMatmul(
            commandBuffer: cmdBuf,
            leftBuffer: bufA,
            rightBuffer: bufB,
            resultBuffer: bufC,
            rows: rows,
            columns: cols,
            inner: inner,
            label: "mps_matmul"
        )
        cmdBuf.commit()
        cmdBuf.waitUntilCompleted()
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000

        return KernelBenchmark(kernelName: "mps_matmul", dispatchTimeMS: elapsed, elementCount: rows * cols, passed: cmdBuf.status == .completed)
    }

    private func benchmarkStateRoundTrip(layers: Int, stateDim: Int, headDim: Int, heads: Int) -> KernelBenchmark {
        allocateStateBuffers(layers: layers, stateDim: stateDim, headDim: headDim, heads: heads)

        let start = CFAbsoluteTimeGetCurrent()
        guard let snapshot = snapshotState() else {
            return KernelBenchmark(kernelName: "state_roundtrip", dispatchTimeMS: -1, elementCount: 0, passed: false)
        }
        let loaded = loadState(snapshot)
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000

        let totalBytes = layers * heads * stateDim * headDim * 2
        return KernelBenchmark(
            kernelName: "state_roundtrip",
            dispatchTimeMS: elapsed,
            elementCount: totalBytes,
            passed: loaded
        )
    }
}
