import Foundation

extension Notification.Name {
    /// Posted when the set of ACTIVE LoRA adapters changes (activate/deactivate).
    /// The inference service observes this to reload the loaded container so the swap
    /// goes live mid-session (SS-LS reload-on-activate). Not posted when the active
    /// state is unchanged.
    nonisolated static let epistemosActiveAdaptersDidChange = Notification.Name("EpistemosActiveAdaptersDidChange")
}

// MARK: - Types

enum AdapterType: String, Codable, Sendable, CaseIterable {
    case knowledge
    case style
    case tool
    case kto
}

struct AdapterRecord: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    var name: String
    let type: AdapterType
    let adapterPath: URL
    let metadataPath: URL
    let sourceVault: String
    let createdAt: Date
    var qualityScore: Double?
    var isActive: Bool
    let baseModel: String
    let loraRank: Int
    let parameterCount: Int
    let trainingExamples: Int
    /// SS-AD: a human-readable explanation of what this adapter does — what it was
    /// trained on and its effect. Auto-seeded from training metadata at registration
    /// and editable. Optional + last field so legacy records (no key) decode to nil.
    var description: String? = nil

    static func == (lhs: AdapterRecord, rhs: AdapterRecord) -> Bool {
        lhs.id == rhs.id
    }
}

/// SS-AD: a human-readable explanation for an adapter — its stored `description` when
/// set, else a derived one-liner from the record so the user ALWAYS sees what an
/// adapter is and does (even before descriptions are seeded). Pure + testable.
nonisolated enum AdapterExplanation {
    static func text(for adapter: AdapterRecord) -> String {
        if let stored = adapter.description?.trimmingCharacters(in: .whitespacesAndNewlines),
           !stored.isEmpty {
            return stored
        }
        let kind: String
        switch adapter.type {
        case .knowledge: kind = "knowledge"
        case .style: kind = "style"
        case .tool: kind = "tool-use"
        case .kto: kind = "preference (KTO)"
        }
        let n = adapter.trainingExamples
        return "A \(kind) LoRA adapter for \(adapter.baseModel) (rank \(adapter.loraRank)), "
            + "trained on \(n) example\(n == 1 ? "" : "s") from \(adapter.sourceVault)."
    }
}

// MARK: - AdapterRegistry

/// Central source of truth for all installed adapters.
/// Persisted to ApplicationSupport/Epistemos/adapter_registry.json.
/// Atomic write using temporary file + rename for crash safety.
///
/// CRITICAL (ANCHOR 3, GAP 1): This registry manages adapters as SEPARATE
/// files. Adapters are NEVER fused into base model weights.
actor AdapterRegistry {

    private var records: [AdapterRecord] = []
    private let storagePath: URL

    init(storagePath: URL? = nil) {
        self.storagePath = storagePath ?? Self.defaultStoragePath()
    }

    /// The canonical on-disk registry path (ApplicationSupport/Epistemos/
    /// adapter_registry.json) — shared by the actor's default storage and the
    /// stateless `activeAdapterDirectoryOnDisk` lookup so the two can't drift.
    nonisolated static func defaultStoragePath() -> URL {
        FoundationSafety.userApplicationSupportDirectory()
            .appendingPathComponent("Epistemos")
            .appendingPathComponent("adapter_registry.json")
    }

    /// SS-LS apply-gap (step 2): a STATELESS read of the on-disk registry for the
    /// first active adapter's directory, or nil. The inference load path uses this to
    /// attach the active adapter without coupling to a live registry actor instance.
    /// Returns nil — so the load path stays byte-for-byte unchanged — when there is no
    /// registry file, no active adapter, or the active adapter's directory is not a
    /// complete loadable native adapter (validated via NativeAdapterDirectory: it must
    /// have adapter_config.json + adapters.safetensors).
    nonisolated static func activeAdapterDirectoryOnDisk(registryPath: URL? = nil) -> URL? {
        let path = registryPath ?? defaultStoragePath()
        guard let data = try? Data(contentsOf: path) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let records = try? decoder.decode([AdapterRecord].self, from: data) else {
            return nil
        }
        guard let active = records.first(where: \.isActive) else { return nil }
        guard NativeAdapterDirectory.isValid(active.adapterPath) else { return nil }
        return active.adapterPath
    }

    // MARK: - Persistence

    func load() throws {
        guard FileManager.default.fileExists(atPath: storagePath.path) else {
            records = []
            return
        }
        let data = try Data(contentsOf: storagePath)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        records = try decoder.decode([AdapterRecord].self, from: data)
    }

    func save() throws {
        let fm = FileManager.default
        try fm.createDirectory(
            at: storagePath.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode(records)

        // Atomic write: write to temp file, then rename
        let tempPath = storagePath.deletingLastPathComponent()
            .appendingPathComponent(".adapter_registry_\(UUID().uuidString).tmp")
        try data.write(to: tempPath, options: .atomic)

        if fm.fileExists(atPath: storagePath.path) {
            _ = try fm.replaceItemAt(storagePath, withItemAt: tempPath)
        } else {
            try fm.moveItem(at: tempPath, to: storagePath)
        }
    }

    // MARK: - CRUD

    func register(_ record: AdapterRecord) throws {
        // Prevent duplicate IDs
        records.removeAll { $0.id == record.id }
        records.append(record)
        try save()
    }

    func deregister(id: UUID) throws {
        records.removeAll { $0.id == id }
        try save()
    }

    func setActive(_ id: UUID, active: Bool) throws {
        guard let index = records.firstIndex(where: { $0.id == id }) else {
            throw AdapterRegistryError.adapterNotFound(id)
        }
        let changed = records[index].isActive != active
        records[index].isActive = active
        try save()
        if changed {
            // SS-LS reload-on-activate: the active set actually changed — signal the
            // inference service to drop+reload the container so the swap goes live.
            NotificationCenter.default.post(name: .epistemosActiveAdaptersDidChange, object: nil)
        }
    }

    func updateQualityScore(_ id: UUID, score: Double) throws {
        guard let index = records.firstIndex(where: { $0.id == id }) else {
            throw AdapterRegistryError.adapterNotFound(id)
        }
        records[index].qualityScore = score
        try save()
    }

    /// SS-AD: set/clear an adapter's human-readable explanation. Mirrors
    /// updateQualityScore (atomic JSON persist).
    func updateDescription(_ id: UUID, description: String?) throws {
        guard let index = records.firstIndex(where: { $0.id == id }) else {
            throw AdapterRegistryError.adapterNotFound(id)
        }
        records[index].description = description
        try save()
    }

    // MARK: - Queries

    func listAdapters(type: AdapterType? = nil) -> [AdapterRecord] {
        if let type {
            return records.filter { $0.type == type }
        }
        return records
    }

    func getActiveAdapters() -> [AdapterRecord] {
        records.filter(\.isActive)
    }

    func getAdapter(id: UUID) -> AdapterRecord? {
        records.first { $0.id == id }
    }

    var count: Int { records.count }

    /// Returns active adapters as MoLoRA config structs for the inference service.
    func getActiveAdapterConfigs() -> [MoLoRAAdapterConfig] {
        getActiveAdapters().map { record in
            MoLoRAAdapterConfig(
                path: record.adapterPath.path,
                type: record.type.rawValue,
                rank: record.loraRank,
                alpha: record.loraRank * 2  // Convention: alpha = 2 * rank
            )
        }
    }
}

// MARK: - Errors

enum AdapterRegistryError: Error, LocalizedError {
    case adapterNotFound(UUID)

    var errorDescription: String? {
        switch self {
        case .adapterNotFound(let id): return "Adapter not found: \(id)"
        }
    }
}
