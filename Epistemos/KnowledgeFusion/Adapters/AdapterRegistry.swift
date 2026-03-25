import Foundation

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

    static func == (lhs: AdapterRecord, rhs: AdapterRecord) -> Bool {
        lhs.id == rhs.id
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
        if let path = storagePath {
            self.storagePath = path
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.storagePath = appSupport
                .appendingPathComponent("Epistemos")
                .appendingPathComponent("adapter_registry.json")
        }
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
            try fm.removeItem(at: storagePath)
        }
        try fm.moveItem(at: tempPath, to: storagePath)
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
        records[index].isActive = active
        try save()
    }

    func updateQualityScore(_ id: UUID, score: Double) throws {
        guard let index = records.firstIndex(where: { $0.id == id }) else {
            throw AdapterRegistryError.adapterNotFound(id)
        }
        records[index].qualityScore = score
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
