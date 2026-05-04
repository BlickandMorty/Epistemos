import Foundation
import Observation
import OSLog
import SwiftData

/// `@Observable` `@MainActor` service that owns Companion CRUD +
/// activation state for the Simulation Mode v1.6 surfaces (Landing
/// Farm, Notes Sidebar Skin, Graph Live Theater).
///
/// Doctrinal posture (per `simulation` worktree DOCTRINE.md +
/// MAS_FIRST_FOCUS_DOCTRINE_2026_05_03.md):
/// - Single source of truth for active companion + companion roster
/// - Reads + writes go through the canonical SwiftData ModelContext
/// - Soft-delete (archive) → restore window → hard delete via
///   Sovereign Gate per Invariant I-12
/// - Active-companion change emits an info-class transcript / event
///   that downstream surfaces (Notes Sidebar) reflect in real time
@MainActor
@Observable
final class CompanionState {
    private static let log = Logger(subsystem: "com.epistemos", category: "CompanionState")

    /// Currently-foregrounded companion id, if any. The Farm shows
    /// every active companion; this picks the one whose persona
    /// augments the system prompt for the next chat.
    var activeCompanionID: String? = nil

    /// Cached snapshot of active companions for the Farm view to read
    /// without round-tripping through ModelContext on every render.
    /// Refreshed via `reloadRoster()` whenever a CRUD op touches the
    /// store.
    private(set) var roster: [CompanionRosterEntry] = []

    /// Cached snapshot of archived (trashed) companions. Used by the
    /// restore sheet.
    private(set) var trashed: [CompanionRosterEntry] = []

    private weak var modelContext: ModelContext?

    init() {}

    /// Wire the ModelContext after AppBootstrap finishes constructing
    /// the SwiftData container.
    func attachModelContext(_ context: ModelContext) {
        self.modelContext = context
        reloadRoster()
    }

    // MARK: - CRUD

    /// Create a new companion. Caller is responsible for any
    /// approval / Sovereign Gate confirmation upstream of this call.
    @discardableResult
    func createCompanion(
        name: String,
        tagline: String = "",
        bodyKind: CompanionBodyKind = .orb,
        accentHex: String = "#7BA8E0",
        loraAdapterPath: String? = nil,
        personaPrompt: String? = nil
    ) -> CompanionRosterEntry? {
        guard let context = modelContext else {
            Self.log.error("createCompanion: ModelContext not attached")
            return nil
        }
        let model = CompanionModel(
            name: name,
            tagline: tagline,
            bodyKind: bodyKind,
            accentHex: accentHex,
            loraAdapterPath: loraAdapterPath,
            personaPrompt: personaPrompt
        )
        context.insert(model)
        do {
            try context.save()
        } catch {
            Self.log.error("createCompanion: save failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
        reloadRoster()
        return CompanionRosterEntry(from: model)
    }

    /// Soft-delete: set `archivedAt` so the companion moves to trash
    /// but stays restorable. Hard delete happens via `purge(_:)`.
    /// Caller MUST have already confirmed via the canonical
    /// SovereignGate for the destructive action class.
    func archive(_ companionID: String) {
        guard let context = modelContext else { return }
        guard let model = fetch(by: companionID) else { return }
        model.archivedAt = .now
        if activeCompanionID == companionID { activeCompanionID = nil }
        do {
            try context.save()
        } catch {
            Self.log.error("archive: save failed: \(error.localizedDescription, privacy: .public)")
        }
        reloadRoster()
    }

    /// Restore an archived companion. Sets `archivedAt = nil` and
    /// bumps `lastInteractedAt` so it sorts to the top.
    func restore(_ companionID: String) {
        guard let context = modelContext else { return }
        guard let model = fetch(by: companionID) else { return }
        model.archivedAt = nil
        model.lastInteractedAt = .now
        do {
            try context.save()
        } catch {
            Self.log.error("restore: save failed: \(error.localizedDescription, privacy: .public)")
        }
        reloadRoster()
    }

    /// Hard-delete: remove from the store entirely. Caller MUST have
    /// confirmed via Sovereign Gate (deviceOwnerAuthentication every
    /// time per the Destructive action class).
    func purge(_ companionID: String) {
        guard let context = modelContext else { return }
        guard let model = fetch(by: companionID) else { return }
        context.delete(model)
        if activeCompanionID == companionID { activeCompanionID = nil }
        do {
            try context.save()
        } catch {
            Self.log.error("purge: save failed: \(error.localizedDescription, privacy: .public)")
        }
        reloadRoster()
    }

    /// Mark a companion as the active foreground companion. Updates
    /// lastInteractedAt so recency sorting reflects the change.
    func activate(_ companionID: String) {
        activeCompanionID = companionID
        guard let context = modelContext else { return }
        guard let model = fetch(by: companionID) else { return }
        model.lastInteractedAt = .now
        try? context.save()
        reloadRoster()
    }

    /// Clear the active companion (no companion active = base persona).
    func deactivate() {
        activeCompanionID = nil
    }

    // MARK: - Lookups

    func fetch(by id: String) -> CompanionModel? {
        guard let context = modelContext else { return nil }
        let descriptor = FetchDescriptor<CompanionModel>(
            predicate: #Predicate { $0.id == id }
        )
        return (try? context.fetch(descriptor))?.first
    }

    /// Refresh the in-memory snapshots from the SwiftData store.
    /// Cheap; called on every CRUD op. Sorted by `lastInteractedAt`
    /// descending so the most-recent companions appear first in the
    /// Farm.
    func reloadRoster() {
        guard let context = modelContext else {
            roster = []
            trashed = []
            return
        }
        let activeDescriptor = FetchDescriptor<CompanionModel>(
            predicate: #Predicate { $0.archivedAt == nil },
            sortBy: [SortDescriptor(\.lastInteractedAt, order: .reverse)]
        )
        let trashedDescriptor = FetchDescriptor<CompanionModel>(
            predicate: #Predicate { $0.archivedAt != nil },
            sortBy: [SortDescriptor(\.archivedAt, order: .reverse)]
        )
        let activeRows = (try? context.fetch(activeDescriptor)) ?? []
        let trashedRows = (try? context.fetch(trashedDescriptor)) ?? []
        roster = activeRows.map(CompanionRosterEntry.init(from:))
        trashed = trashedRows.map(CompanionRosterEntry.init(from:))
    }

    /// Synthesize the canonical 4-companion preset farm if the roster
    /// is completely empty — gives the Landing Farm visible "tomagotchi
    /// farm" reads on first launch with one of each canonical body
    /// family (Block Compact, Block Wide, Orb, Sage) per Simulation
    /// v1.6 §5.1. The user can rename, delete, or add to this set via
    /// the standard wizard / context menu.
    ///
    /// Invariant I-1 (single base substrate): all 4 ride the same
    /// rendering substrate; the wizard is the only path to non-canonical
    /// custom bodies.
    @discardableResult
    func seedDefaultIfEmpty() -> CompanionRosterEntry? {
        reloadRoster()
        guard roster.isEmpty && trashed.isEmpty else { return nil }

        let presets: [(name: String, tagline: String, bodyKind: CompanionBodyKind, accentHex: String, personaPrompt: String)] = [
            (
                name: "Sage",
                tagline: "Reflective companion · click to focus",
                bodyKind: .sage,
                accentHex: "#9C8FE5",
                personaPrompt: "Reflective tone. Cite reasoning. Respect the user's time."
            ),
            (
                name: "Orbit",
                tagline: "Drifting planner · slow & deliberate",
                bodyKind: .orb,
                accentHex: "#7B95A8",
                personaPrompt: "Calm planner. Consider trade-offs before acting."
            ),
            (
                name: "Brick",
                tagline: "Steady worker · purposeful",
                bodyKind: .blockCompact,
                accentHex: "#5B8DEF",
                personaPrompt: "Direct and concrete. Ship the work."
            ),
            (
                name: "Scribe",
                tagline: "Editorial reader · careful",
                bodyKind: .blockWide,
                accentHex: "#D97757",
                personaPrompt: "Careful editor. Consider style and clarity."
            ),
        ]

        var first: CompanionRosterEntry?
        for preset in presets {
            let entry = createCompanion(
                name: preset.name,
                tagline: preset.tagline,
                bodyKind: preset.bodyKind,
                accentHex: preset.accentHex,
                personaPrompt: preset.personaPrompt
            )
            if first == nil { first = entry }
        }
        return first
    }
}

/// Lightweight value-type snapshot of a CompanionModel. The Farm view
/// reads from `[CompanionRosterEntry]` so SwiftUI diffing is cheap and
/// stable, and so view code never holds a SwiftData model directly
/// (per CLAUDE.md: views project, never invent).
struct CompanionRosterEntry: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let tagline: String
    let bodyKind: CompanionBodyKind
    let accentHex: String
    let identityHash: String
    let loraAdapterPath: String?
    let personaPrompt: String?
    let createdAt: Date
    let lastInteractedAt: Date
    let archivedAt: Date?

    init(from model: CompanionModel) {
        self.id = model.id
        self.name = model.name
        self.tagline = model.tagline
        self.bodyKind = model.bodyKind
        self.accentHex = model.accentHex
        self.identityHash = model.identityHash
        self.loraAdapterPath = model.loraAdapterPath
        self.personaPrompt = model.personaPrompt
        self.createdAt = model.createdAt
        self.lastInteractedAt = model.lastInteractedAt
        self.archivedAt = model.archivedAt
    }

    var isArchived: Bool { archivedAt != nil }
}
