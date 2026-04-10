import Foundation
import MLX
import MLXLMCommon
import OSLog

/// SSMStateService manages Mamba/SSM hidden state persistence.
///
/// Responsibilities:
/// - Save SSM hidden state snapshots after generation turns
/// - Load state snapshots for session resume (without chat replay)
/// - Prune old snapshots via lifecycle management
/// - Coordinate with MLX's MambaCache for extraction/injection
///
/// State is stored as MLX prompt-cache `.safetensors` files scoped by vault and model.
/// Uses MLX-Swift's built-in `savePromptCache`/`loadPromptCache` for the primary
/// path, with Rust FFI as fallback for custom runtime.
@Observable
final class SSMStateService: @unchecked Sendable {
    private static let log = Logger(subsystem: "com.epistemos", category: "SSMState")

    /// Directory root for state storage (typically vault root).
    let stateRoot: URL

    /// Whether state persistence is active (mirrors feature flag).
    private(set) var isActive: Bool = false

    /// Currently loaded state session ID, if any.
    private(set) var currentSessionStateId: String?

    /// Last save duration in milliseconds (for perf tracking).
    private(set) var lastSaveDurationMS: Double = 0

    /// Last load duration in milliseconds.
    private(set) var lastLoadDurationMS: Double = 0

    init(stateRoot: URL) {
        self.stateRoot = stateRoot
    }

    // MARK: - Activation

    func activate(enabled: Bool) {
        isActive = enabled
        if enabled {
            Self.log.info("SSM state persistence activated at \(self.stateRoot.path, privacy: .public)")
        }
    }

    // MARK: - MLX Cache Save/Load (Primary Path)

    /// Save the current MLX prompt cache (including MambaCache state) to disk.
    /// Uses MLX-Swift's native `savePromptCache` which handles MambaCache properly.
    ///
    /// - Parameters:
    ///   - cache: The KVCache array from the model's generation context
    ///   - modelId: Model identifier for file scoping
    ///   - sessionId: Session identifier for this snapshot
    /// - Returns: URL of saved state file, or nil on failure
    func saveMLXCache(
        cache: [any KVCache],
        modelId: String,
        sessionId: String
    ) -> URL? {
        guard isActive else { return nil }
        if cache.contains(where: { $0 is CacheList }) {
            Self.log.info(
                "SSM state save skipped for \(modelId, privacy: .public) session=\(sessionId, privacy: .public) because composite prompt caches are not serializable yet"
            )
            return nil
        }

        let start = CFAbsoluteTimeGetCurrent()

        let sanitizedModel = modelId.replacingOccurrences(of: "/", with: "_")
        let stateDir = stateRoot
            .appendingPathComponent("ssm_cache", isDirectory: true)
            .appendingPathComponent(sanitizedModel, isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: stateDir, withIntermediateDirectories: true)
        } catch {
            Self.log.error("Failed to create state directory: \(error.localizedDescription, privacy: .public)")
            return nil
        }

        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "\(sessionId)_\(timestamp).safetensors"
        let fileURL = stateDir.appendingPathComponent(filename)

        do {
            let metadata = [
                "model_id": modelId,
                "session_id": sessionId,
                "timestamp": String(timestamp),
                "format": "mlx_prompt_cache",
            ]
            try savePromptCache(url: fileURL, cache: cache, metadata: metadata)

            let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
            lastSaveDurationMS = elapsed
            currentSessionStateId = sessionId

            let fileSize = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int) ?? 0
            Self.log.info(
                "SSM state saved: \(fileURL.lastPathComponent, privacy: .public) (\(fileSize) bytes, \(String(format: "%.1f", elapsed))ms)"
            )
            return fileURL
        } catch {
            Self.log.error("Failed to save SSM state: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Load an MLX prompt cache from disk and return the cache array.
    /// The returned cache can be injected into a ModelContainer for stateful generation.
    ///
    /// - Parameter url: Path to the saved state file
    /// - Returns: Tuple of (cache array, metadata dict), or nil on failure
    func loadMLXCache(from url: URL) -> (cache: [any KVCache], metadata: [String: String])? {
        guard isActive else { return nil }

        let start = CFAbsoluteTimeGetCurrent()

        do {
            let (cache, metadata) = try loadPromptCache(url: url)
            let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
            lastLoadDurationMS = elapsed

            currentSessionStateId = metadata["session_id"]

            Self.log.info(
                "SSM state loaded: \(url.lastPathComponent, privacy: .public) (\(String(format: "%.1f", elapsed))ms)"
            )
            return (cache, metadata)
        } catch {
            Self.log.error("Failed to load SSM state: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - State Discovery

    /// Find the most recent state file for a given model and session.
    func findLatestState(modelId: String, sessionId: String? = nil) -> URL? {
        let sanitizedModel = modelId.replacingOccurrences(of: "/", with: "_")
        let stateDir = stateRoot
            .appendingPathComponent("ssm_cache", isDirectory: true)
            .appendingPathComponent(sanitizedModel, isDirectory: true)

        guard FileManager.default.fileExists(atPath: stateDir.path) else { return nil }

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: stateDir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: .skipsHiddenFiles
            )

            let cacheFiles = files
                .filter { $0.pathExtension == "safetensors" }
                .filter { url in
                    if let sid = sessionId {
                        return url.lastPathComponent.hasPrefix(sid)
                    }
                    return true
                }
                .sorted { a, b in
                    let dateA = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    let dateB = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    return dateA > dateB
                }

            return cacheFiles.first
        } catch {
            Self.log.error("Failed to scan state directory: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// List all saved states for a model, newest first.
    func listStates(modelId: String) -> [(url: URL, sessionId: String, timestamp: Date)] {
        let sanitizedModel = modelId.replacingOccurrences(of: "/", with: "_")
        let stateDir = stateRoot
            .appendingPathComponent("ssm_cache", isDirectory: true)
            .appendingPathComponent(sanitizedModel, isDirectory: true)

        guard FileManager.default.fileExists(atPath: stateDir.path) else { return [] }

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: stateDir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: .skipsHiddenFiles
            )

            return files
                .filter { $0.pathExtension == "safetensors" }
                .compactMap { url -> (URL, String, Date)? in
                    let name = url.deletingPathExtension().lastPathComponent
                    let parts = name.split(separator: "_", maxSplits: 1)
                    let sessionId = parts.first.map(String.init) ?? "unknown"
                    let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    return (url, sessionId, date)
                }
                .sorted { $0.2 > $1.2 }
        } catch {
            return []
        }
    }

    // MARK: - Staleness Detection

    /// Check if a saved state is stale relative to the vault content.
    /// A state is stale when vault notes have been modified after the snapshot was taken.
    ///
    /// - Parameters:
    ///   - stateURL: Path to the saved state file
    ///   - vaultRoot: Root directory of the vault (where notes are stored)
    /// - Returns: true if the state is stale and should not be used
    func isStateStale(stateURL: URL, vaultRoot: URL) -> Bool {
        guard let stateDate = modificationDate(of: stateURL) else { return true }
        return vaultModifiedAfter(stateDate, in: vaultRoot)
    }

    /// Compare state timestamp to vault's latest modification.
    /// Walks the vault root looking for any file modified after the given date.
    private func vaultModifiedAfter(_ date: Date, in vaultRoot: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: vaultRoot.path) else { return false }

        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: vaultRoot,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return false }

        for case let fileURL as URL in enumerator {
            // Only check note-like files (markdown, text, json)
            let ext = fileURL.pathExtension.lowercased()
            guard ["md", "txt", "json", "markdown"].contains(ext) else { continue }

            if let modDate = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
               modDate > date {
                Self.log.info("Vault note modified after state snapshot: \(fileURL.lastPathComponent, privacy: .public)")
                return true
            }
        }
        return false
    }

    private func modificationDate(of url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    // MARK: - Lifecycle / Pruning

    /// Remove old state files for a model, keeping only the most recent `keepCount`.
    func pruneStates(modelId: String, keepCount: Int) -> Int {
        let states = listStates(modelId: modelId)
        var removed = 0

        for state in states.dropFirst(keepCount) {
            do {
                try FileManager.default.removeItem(at: state.url)
                removed += 1
            } catch {
                Self.log.warning("Failed to prune state: \(state.url.lastPathComponent, privacy: .public)")
            }
        }

        if removed > 0 {
            Self.log.info("Pruned \(removed) old SSM states for \(modelId, privacy: .public)")
        }
        return removed
    }

    /// Total disk usage of all state files, in bytes.
    func totalDiskUsage() -> Int {
        let cacheDir = stateRoot.appendingPathComponent("ssm_cache", isDirectory: true)
        guard FileManager.default.fileExists(atPath: cacheDir.path) else { return 0 }

        var total = 0
        if let enumerator = FileManager.default.enumerator(
            at: cacheDir,
            includingPropertiesForKeys: [.fileSizeKey],
            options: .skipsHiddenFiles
        ) {
            for case let url as URL in enumerator {
                if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    total += size
                }
            }
        }
        return total
    }
}
