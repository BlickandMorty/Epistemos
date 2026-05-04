import Foundation
import SwiftUI
import Combine
import SwiftData

// ---------------------------------------------------------------------------
// MARK: - CompanionState
// ---------------------------------------------------------------------------

/// The single `@Observable` source of truth for companion simulation state.
///
/// `CompanionState` owns the array of companions, the active selection, and
/// the live event reaction stream. It is created once in `AppEnvironment` and
/// injected into the view hierarchy.
///
/// All mutations are `@MainActor` bound and async where they touch storage.
@MainActor
@Observable
public final class CompanionState {

    // MARK: - Public State

    /// All non-archived companions.
    public var companions: [CompanionModel] = []

    /// The currently active (selected) companion.
    public var activeCompanion: CompanionModel?

    /// Events that have triggered a companion reaction.
    public var companionEvents: [AgentProvenanceEvent] = []

    /// The current reaction being displayed (nil when idle).
    public var currentReaction: CompanionReaction?

    /// Timestamp of last reaction (for debounce / cancel logic).
    public var lastReactionAt: Date?

    // MARK: - Private State

    /// In-memory store for the Core tier (no SwiftData container needed).
    private var modelContext: ModelContext?

    /// File URL for JSON persistence in the App Group container.
    private var persistenceURL: URL?

    /// Ongoing reaction task (cancelled when a new event arrives).
    private var reactionTask: Task<Void, Never>?

    /// Observer handle for the event store.
    private var eventObserver: ((AgentProvenanceEvent) -> Void)?

    // MARK: - Constants

    private let companionsDirectoryName = "companions"
    private let companionsFileName = "companions.json"
    private let archivePurgeInterval: TimeInterval = 30 * 24 * 60 * 60 // 30 days

    // MARK: - Init

    public init() {}

    deinit {
        reactionTask?.cancel()
    }

    // MARK: - Persistence Setup

    /// Resolve the App Group container and build the persistence URL.
    private func resolvePersistenceURL() -> URL? {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.epistenos.shared")
        else {
            print("[CompanionState] App Group container unavailable.")
            return nil
        }
        let dir = container.appendingPathComponent(companionsDirectoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(companionsFileName)
    }

    // MARK: - Lifecycle

    /// Load companions from App Group JSON storage.
    public func loadCompanions() async throws {
        guard let url = resolvePersistenceURL() else {
            throw CompanionStateError.persistenceUnavailable
        }
        self.persistenceURL = url

        guard FileManager.default.fileExists(atPath: url.path) else {
            companions = []
            return
        }

        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode([CompanionRecord].self, from: data)
        companions = decoded.map { $0.toModel() }

        // Restore active companion if still present
        if let active = activeCompanion,
           !companions.contains(where: { $0.id == active.id }) {
            activeCompanion = nil
        }

        // Auto-purge stale archived companions
        purgeStaleArchives()
    }

    /// Wire this state to the global `EventStore` so companions react to agent events.
    public func startListeningToEvents() {
        EventStore.shared.onEvent { [weak self] event in
            guard let self else { return }
            Task { @MainActor in
                self.reactToEvent(event)
            }
        }
    }

    // MARK: - CRUD

    /// Create a new companion and persist.
    public func createCompanion(
        name: String,
        baseProfile: String,
        cosmetics: CosmeticConfig
    ) async throws {
        guard !name.isEmpty, name.count <= 32 else {
            throw CompanionStateError.invalidName
        }

        let companion = CompanionModel(
            name: name,
            baseProfile: baseProfile,
            cosmeticConfig: cosmetics
        )

        companions.append(companion)
        activeCompanion = companion
        try await persist()

        let event = AgentProvenanceEvent(
            kind: .vault_created,
            payload: "Created companion \\(name)"
        )
        EventStore.shared.append(event)
    }

    /// Delete a companion permanently (destructive — requires biometric gate).
    public func deleteCompanion(_ companion: CompanionModel) async throws {
        guard companions.contains(where: { $0.id == companion.id }) else {
            throw CompanionStateError.notFound
        }

        try await SovereignGate.shared.gate(
            requirement: .deviceOwnerAuthentication,
            reason: "Delete companion \\(companion.name)? This cannot be undone."
        ) { [weak self] in
            guard let self else { return }
            companions.removeAll { $0.id == companion.id }
            if activeCompanion?.id == companion.id {
                activeCompanion = nil
            }
            try await persist()

            let event = AgentProvenanceEvent(
                kind: .vault_archived,
                payload: "Deleted companion \\(companion.name)"
            )
            EventStore.shared.append(event)
        }
    }

    /// Archive a companion (soft-delete, recoverable).
    public func archiveCompanion(_ companion: CompanionModel) async throws {
        guard let idx = companions.firstIndex(where: { $0.id == companion.id }) else {
            throw CompanionStateError.notFound
        }

        companions[idx].isArchived = true
        if activeCompanion?.id == companion.id {
            activeCompanion = nil
        }
        try await persist()

        let event = AgentProvenanceEvent(
            kind: .vault_archived,
            payload: "Archived companion \\(companion.name)"
        )
        EventStore.shared.append(event)
    }

    /// Restore an archived companion by ID.
    public func restoreCompanion(id: UUID) async throws {
        guard let url = persistenceURL else {
            throw CompanionStateError.persistenceUnavailable
        }

        // Load all records including archived ones
        let data = try Data(contentsOf: url)
        let allRecords = try JSONDecoder().decode([CompanionRecord].self, from: data)
        guard let record = allRecords.first(where: { $0.id == id && $0.isArchived }) else {
            throw CompanionStateError.notFound
        }

        // Gate restoration behind biometric auth (sovereign gate)
        try await SovereignGate.shared.gate(
            requirement: .deviceOwnerAuthentication,
            reason: "Restore companion \\(record.name)?"
        ) { [weak self] in
            guard let self else { return }
            var restored = record
            restored.isArchived = false
            restored.lastActiveAt = Date()

            let model = restored.toModel()
            companions.append(model)
            try await persist()

            let event = AgentProvenanceEvent(
                kind: .vault_created,
                payload: "Restored companion \\(model.name)"
            )
            EventStore.shared.append(event)
        }
    }

    /// Rename a companion.
    public func renameCompanion(_ companion: CompanionModel, to newName: String) async throws {
        guard !newName.isEmpty, newName.count <= 32 else {
            throw CompanionStateError.invalidName
        }
        guard let idx = companions.firstIndex(where: { $0.id == companion.id }) else {
            throw CompanionStateError.notFound
        }
        companions[idx].name = newName
        companions[idx].lastActiveAt = Date()
        try await persist()
    }

    // MARK: - Event Reaction (Resonance Gate §4.1)

    /// React to a single `AgentProvenanceEvent` by updating `currentReaction`.
    public func reactToEvent(_ event: AgentProvenanceEvent) {
        companionEvents.append(event)
        if companionEvents.count > 64 {
            companionEvents.removeFirst(companionEvents.count - 64)
        }

        let reaction = CompanionReaction(from: event)
        guard reaction != .idle else { return }

        // Cancel any in-flight reaction
        reactionTask?.cancel()

        currentReaction = reaction
        lastReactionAt = Date()

        reactionTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            if !Task.isCancelled {
                currentReaction = nil
                lastReactionAt = nil
            }
        }
    }

    // MARK: - Persistence

    private func persist() async throws {
        guard let url = persistenceURL else {
            throw CompanionStateError.persistenceUnavailable
        }
        let records = companions.map { CompanionRecord(from: $0) }
        let data = try JSONEncoder().encode(records)
        try data.write(to: url, options: .atomic)
    }

    // MARK: - Archive Maintenance

    private func purgeStaleArchives() {
        let cutoff = Date().addingTimeInterval(-archivePurgeInterval)
        // Note: companions array only holds non-archived; purge from disk separately
        guard let url = persistenceURL,
              FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            let data = try Data(contentsOf: url)
            var records = try JSONDecoder().decode([CompanionRecord].self, from: data)
            let beforeCount = records.count
            records.removeAll { $0.isArchived && $0.lastActiveAt < cutoff }
            if records.count < beforeCount {
                let out = try JSONEncoder().encode(records)
                try out.write(to: url, options: .atomic)
                print("[CompanionState] purged \(beforeCount - records.count) stale archived companion(s)")
            }
        } catch {
            print("[CompanionState] purge error: \(error.localizedDescription)")
        }
    }
}

// ---------------------------------------------------------------------------
// MARK: - CompanionReaction
// ---------------------------------------------------------------------------

/// A transient reaction state produced by an `AgentProvenanceEvent`.
///
/// Reactions are rendered by `CompanionView` and `NotesSidebarSkin` as
/// brief visual feedback. They auto-expire after ~0.5 s.
@MainActor
public enum CompanionReaction: Equatable {
    case idle
    case toolCompleted      // brief green glow + nod
    case toolFailed         // brief red pulse + shake
    case summaryStarted     // attentive lean forward
    case summaryCompleted   // satisfied settle
    case vaultCreated       // curious tilt
    case vaultArchived      // somber dim

    init(from event: AgentProvenanceEvent) {
        switch event.kind {
        case .tool_completed:     self = .toolCompleted
        case .tool_failed:        self = .toolFailed
        case .summary_started:    self = .summaryStarted
        case .summary_completed:  self = .summaryCompleted
        case .vault_created:      self = .vaultCreated
        case .vault_archived:     self = .vaultArchived
        default:                  self = .idle
        }
    }
}

// ---------------------------------------------------------------------------
// MARK: - CompanionRecord (Codable DTO)
// ---------------------------------------------------------------------------

/// A plain Codable DTO for JSON persistence of `CompanionModel`.
private struct CompanionRecord: Codable, Identifiable {
    let id: UUID
    var name: String
    var baseProfile: String
    var cosmeticConfig: CosmeticConfig
    var createdAt: Date
    var lastActiveAt: Date
    var isArchived: Bool
    var personalityVector: [Float]?

    init(from model: CompanionModel) {
        self.id = model.id
        self.name = model.name
        self.baseProfile = model.baseProfile
        self.cosmeticConfig = model.cosmeticConfig
        self.createdAt = model.createdAt
        self.lastActiveAt = model.lastActiveAt
        self.isArchived = model.isArchived
        self.personalityVector = model.personalityVector
    }

    func toModel() -> CompanionModel {
        CompanionModel(
            id: id,
            name: name,
            baseProfile: baseProfile,
            cosmeticConfig: cosmeticConfig,
            createdAt: createdAt,
            lastActiveAt: lastActiveAt,
            isArchived: isArchived,
            personalityVector: personalityVector
        )
    }
}

// ---------------------------------------------------------------------------
// MARK: - CompanionStateError
// ---------------------------------------------------------------------------

public enum CompanionStateError: Error, LocalizedError {
    case persistenceUnavailable
    case invalidName
    case notFound

    public var errorDescription: String? {
        switch self {
        case .persistenceUnavailable:
            return "App Group container is unavailable. Cannot persist companions."
        case .invalidName:
            return "Companion name must be between 1 and 32 characters."
        case .notFound:
            return "Companion not found in state."
        }
    }
}
