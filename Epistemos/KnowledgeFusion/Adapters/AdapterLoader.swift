import Foundation

// MARK: - Types

struct LoadedAdapter: Sendable {
    let record: AdapterRecord
    let loadedAt: Date
    let estimatedMemoryMB: Int
}

// MARK: - AdapterLoader

/// Loads and unloads adapters at inference time via hot-swap.
///
/// ⚠️ MANDATORY (ANCHOR 3, GAP 1): This component uses hot-swap ONLY.
/// It MUST NOT merge adapter weights into base weights.
/// Uses mlx-lm load_adapter() — NOT merge_adapter() or merge_weights=True.
/// Fusion causes 3x inference speed degradation (21→7 tok/s).
actor AdapterLoader {

    private var loadedAdapters: [UUID: LoadedAdapter] = [:]
    private let maxSimultaneousAdapters: Int

    /// - Parameter maxSimultaneous: Maximum adapters loaded at once.
    ///   Default 3 for 16GB systems, increase for 64GB+.
    init(maxSimultaneousAdapters: Int = 3) {
        self.maxSimultaneousAdapters = maxSimultaneousAdapters
    }

    // MARK: - Public API

    func load(_ record: AdapterRecord) throws {
        // Check capacity
        if loadedAdapters.count >= maxSimultaneousAdapters {
            throw AdapterLoaderError.capacityExceeded(max: maxSimultaneousAdapters)
        }

        // Verify adapter files exist
        let weightsPath = record.adapterPath.appendingPathComponent("adapter_weights.safetensors")
        guard FileManager.default.fileExists(atPath: weightsPath.path) else {
            throw AdapterLoaderError.weightsNotFound(weightsPath)
        }

        // Estimate memory: rough formula based on rank and parameter count
        // 4B model adapter at r=32 ≈ ~50-200MB
        let estimatedMB = estimateMemoryUsage(record: record)

        loadedAdapters[record.id] = LoadedAdapter(
            record: record,
            loadedAt: Date(),
            estimatedMemoryMB: estimatedMB
        )
    }

    func unload(_ id: UUID) {
        loadedAdapters.removeValue(forKey: id)
    }

    func unloadAll() {
        loadedAdapters.removeAll()
    }

    func currentlyLoaded() -> [AdapterRecord] {
        loadedAdapters.values.map(\.record)
    }

    func isLoaded(_ id: UUID) -> Bool {
        loadedAdapters[id] != nil
    }

    func totalMemoryUsageMB() -> Int {
        loadedAdapters.values.reduce(0) { $0 + $1.estimatedMemoryMB }
    }

    /// Returns the adapter path for the inference engine to use.
    /// The inference engine should call mlx_lm.load(model_path, adapter_path=...)
    /// with this path. NEVER merge_weights=True.
    func adapterPath(for id: UUID) -> URL? {
        loadedAdapters[id]?.record.adapterPath
    }

    // MARK: - Memory Estimation

    private func estimateMemoryUsage(record: AdapterRecord) -> Int {
        // Rough estimate: paramCount * 2 bytes (FP16) / 1024^2
        let bytesEstimate = record.parameterCount * 2
        return max(1, bytesEstimate / (1024 * 1024))
    }
}

// MARK: - Errors

enum AdapterLoaderError: Error, LocalizedError {
    case capacityExceeded(max: Int)
    case weightsNotFound(URL)

    var errorDescription: String? {
        switch self {
        case .capacityExceeded(let max):
            return "Cannot load more than \(max) adapters simultaneously"
        case .weightsNotFound(let url):
            return "Adapter weights not found at: \(url.path)"
        }
    }
}
