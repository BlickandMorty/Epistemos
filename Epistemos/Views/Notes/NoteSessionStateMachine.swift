import Darwin
import Foundation
import GRDB
import Observation

enum NoteSessionLens: String, CaseIterable, Sendable {
    case edit
    case document
    case preview
    case source

    init(_ mode: NoteWorkspaceMode) {
        switch mode {
        case .edit:
            self = .edit
        case .document:
            self = .document
        case .preview:
            self = .preview
        case .source:
            self = .source
        }
    }
}

enum NoteSessionEditSource: String, Sendable {
    case user
    case agent
}

enum NoteSessionSaveReason: String, Sendable {
    case idleDebounce
    case maxCeiling
    case lensSwitch
    case blur
    case appBackground
    case explicitSave
    case disappear
    case leaseHandoff
}

enum NoteSessionUndoPolicy: String, Sendable {
    case preservedWithinLens
    case documentedV1UndoLossAcrossLensSwitch
}

struct NoteSessionLensSwitch: Equatable, Sendable {
    let from: NoteSessionLens
    let to: NoteSessionLens
}

enum NoteSessionState: Equatable, Sendable {
    case idle
    case loading(epoch: UInt64?)
    case clean
    case dirty(since: Date)
    case autosaving(reason: NoteSessionSaveReason)
    case externalChange(pendingReload: Bool)
    case conflict(diff3Base: String)

    var needsWriteLease: Bool {
        switch self {
        case .dirty, .autosaving, .conflict:
            return true
        case .idle, .loading, .clean, .externalChange:
            return false
        }
    }
}

enum NoteSessionEditDecision: Equatable, Sendable {
    case accepted
    case needsLeaseHandoff(currentOwnerID: String?)
}

enum NoteSessionExternalChangeDecision: Equatable, Sendable {
    case reloadWhenClean
    case conflict(diff3Base: String)
}

protocol NoteSessionLeaseStore: AnyObject {
    func ownerID(for noteID: String) throws -> String?
    func ownerNeedsWriteLease(for noteID: String) throws -> Bool?
    @discardableResult
    func acquire(
        noteID: String,
        sessionID: String,
        lens: NoteSessionLens,
        state: NoteSessionState,
        updatedAtMs: Int64
    ) throws -> Bool
    func recordState(
        noteID: String,
        sessionID: String,
        lens: NoteSessionLens,
        state: NoteSessionState,
        updatedAtMs: Int64
    ) throws
    func release(noteID: String, sessionID: String) throws
    @discardableResult
    func transfer(noteID: String, from ownerID: String, to nextOwnerID: String, updatedAtMs: Int64) throws -> Bool
    func resetAllForTests() throws
}

final class NoteSessionGRDBLeaseStore: NoteSessionLeaseStore {
    private let writer: any DatabaseWriter

    init(databaseWriter: any DatabaseWriter) {
        self.writer = databaseWriter
    }

    func ownerID(for noteID: String) throws -> String? {
        try ensureSchema()
        return try writer.read { db in
            return try String.fetchOne(
                db,
                sql: "SELECT owner_session_id FROM note_session WHERE note_id = ?",
                arguments: [noteID]
            )
        }
    }

    func ownerNeedsWriteLease(for noteID: String) throws -> Bool? {
        try ensureSchema()
        return try writer.read { db in
            guard let state = try String.fetchOne(
                db,
                sql: "SELECT state FROM note_session WHERE note_id = ?",
                arguments: [noteID]
            ) else {
                return nil
            }
            return Self.storageLabelNeedsWriteLease(state)
        }
    }

    @discardableResult
    func acquire(
        noteID: String,
        sessionID: String,
        lens: NoteSessionLens,
        state: NoteSessionState,
        updatedAtMs: Int64
    ) throws -> Bool {
        try writer.write { db in
            try Self.installSchemaIfNeeded(db)
            let owner = try String.fetchOne(
                db,
                sql: "SELECT owner_session_id FROM note_session WHERE note_id = ?",
                arguments: [noteID]
            )
            if let owner, owner != sessionID {
                return false
            }
            try db.execute(
                sql: """
                    INSERT INTO note_session(note_id, owner_session_id, lens, state, updated_at_ms)
                    VALUES (?, ?, ?, ?, ?)
                    ON CONFLICT(note_id) DO UPDATE SET
                        owner_session_id = excluded.owner_session_id,
                        lens = excluded.lens,
                        state = excluded.state,
                        updated_at_ms = excluded.updated_at_ms
                    """,
                arguments: [noteID, sessionID, lens.rawValue, state.storageLabel, updatedAtMs]
            )
            return true
        }
    }

    func recordState(
        noteID: String,
        sessionID: String,
        lens: NoteSessionLens,
        state: NoteSessionState,
        updatedAtMs: Int64
    ) throws {
        try writer.write { db in
            try Self.installSchemaIfNeeded(db)
            try db.execute(
                sql: """
                    UPDATE note_session
                    SET lens = ?, state = ?, updated_at_ms = ?
                    WHERE note_id = ? AND owner_session_id = ?
                    """,
                arguments: [lens.rawValue, state.storageLabel, updatedAtMs, noteID, sessionID]
            )
        }
    }

    func release(noteID: String, sessionID: String) throws {
        try writer.write { db in
            try Self.installSchemaIfNeeded(db)
            try db.execute(
                sql: "DELETE FROM note_session WHERE note_id = ? AND owner_session_id = ?",
                arguments: [noteID, sessionID]
            )
        }
    }

    @discardableResult
    func transfer(
        noteID: String,
        from ownerID: String,
        to nextOwnerID: String,
        updatedAtMs: Int64
    ) throws -> Bool {
        try writer.write { db in
            try Self.installSchemaIfNeeded(db)
            try db.execute(
                sql: """
                    UPDATE note_session
                    SET owner_session_id = ?, updated_at_ms = ?
                    WHERE note_id = ? AND owner_session_id = ?
                    """,
                arguments: [nextOwnerID, updatedAtMs, noteID, ownerID]
            )
            return db.changesCount > 0
        }
    }

    func resetAllForTests() throws {
        try writer.write { db in
            try Self.installSchemaIfNeeded(db)
            try db.execute(sql: "DELETE FROM note_session")
        }
    }

    private func ensureSchema() throws {
        try writer.write { db in
            try Self.installSchemaIfNeeded(db)
        }
    }

    private static func installSchemaIfNeeded(_ db: Database) throws {
        try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS note_session (
                note_id TEXT PRIMARY KEY,
                owner_session_id TEXT NOT NULL,
                lens TEXT NOT NULL,
                state TEXT NOT NULL,
                updated_at_ms INTEGER NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_note_session_owner
                ON note_session(owner_session_id);
            """)
    }

    private static func storageLabelNeedsWriteLease(_ state: String) -> Bool {
        switch state {
        case "dirty", "autosaving", "conflict":
            true
        default:
            false
        }
    }
}

@MainActor
final class NoteSessionLeaseRegistry {
    static let shared = NoteSessionLeaseRegistry()

    private var ownersByNoteID: [String: String] = [:]
    private var storesByNoteID: [String: any NoteSessionLeaseStore] = [:]
    private var activeSessionIDs: Set<String> = []
    private var activeSessionsByID: [String: WeakNoteSessionStateMachine] = [:]

    private init() {}

    nonisolated static func makeSessionID() -> String {
        "epistemos:\(ProcessInfo.processInfo.processIdentifier):\(UUID().uuidString)"
    }

    func registerSession(_ sessionID: String) {
        activeSessionIDs.insert(sessionID)
    }

    func registerSession(_ session: NoteSessionStateMachine) {
        activeSessionIDs.insert(session.sessionID)
        activeSessionsByID[session.sessionID] = WeakNoteSessionStateMachine(session)
    }

    func unregisterSession(_ sessionID: String) {
        activeSessionIDs.remove(sessionID)
        activeSessionsByID.removeValue(forKey: sessionID)
    }

    func attachStore(_ store: any NoteSessionLeaseStore, noteID: String) {
        storesByNoteID[noteID] = store
        if let owner = try? store.ownerID(for: noteID) {
            ownersByNoteID[noteID] = owner
        } else {
            ownersByNoteID.removeValue(forKey: noteID)
        }
    }

    func ownerID(for noteID: String) -> String? {
        if let store = storesByNoteID[noteID] {
            if let owner = try? store.ownerID(for: noteID) {
                ownersByNoteID[noteID] = owner
                return owner
            }
            ownersByNoteID.removeValue(forKey: noteID)
            return nil
        }
        return ownersByNoteID[noteID]
    }

    @discardableResult
    func acquire(
        noteID: String,
        sessionID: String,
        lens: NoteSessionLens,
        state: NoteSessionState
    ) -> Bool {
        if let store = storesByNoteID[noteID] {
            clearInactiveStoredOwnerIfNeeded(noteID: noteID, sessionID: sessionID, store: store)
            guard let acquired = try? store.acquire(
                noteID: noteID,
                sessionID: sessionID,
                lens: lens,
                state: state,
                updatedAtMs: Self.nowMilliseconds()
            ) else {
                ownersByNoteID.removeValue(forKey: noteID)
                return false
            }
            ownersByNoteID[noteID] = try? store.ownerID(for: noteID)
            return acquired
        }

        if let owner = ownersByNoteID[noteID], owner != sessionID {
            guard ownerSessionIsActive(owner) else {
                ownersByNoteID.removeValue(forKey: noteID)
                ownersByNoteID[noteID] = sessionID
                return true
            }
            return false
        }
        ownersByNoteID[noteID] = sessionID
        return true
    }

    @discardableResult
    func acquireOrHandoffCleanOwner(
        noteID: String,
        sessionID: String,
        lens: NoteSessionLens,
        state: NoteSessionState
    ) -> Bool {
        if acquire(noteID: noteID, sessionID: sessionID, lens: lens, state: state) {
            return true
        }
        guard let owner = ownerID(for: noteID),
              owner != sessionID,
              ownerCanHandoffCleanly(noteID: noteID, ownerID: owner) else {
            return false
        }
        let transferred = transfer(noteID: noteID, from: owner, to: sessionID)
        guard transferred else { return false }
        recordState(noteID: noteID, sessionID: sessionID, lens: lens, state: state)
        refreshRegisteredSessions(for: noteID)
        return true
    }

    func recordState(noteID: String, sessionID: String, lens: NoteSessionLens, state: NoteSessionState) {
        guard let store = storesByNoteID[noteID] else { return }
        try? store.recordState(
            noteID: noteID,
            sessionID: sessionID,
            lens: lens,
            state: state,
            updatedAtMs: Self.nowMilliseconds()
        )
    }

    func release(noteID: String, sessionID: String) {
        if let store = storesByNoteID[noteID] {
            try? store.release(noteID: noteID, sessionID: sessionID)
            ownersByNoteID[noteID] = try? store.ownerID(for: noteID)
            return
        }
        guard ownersByNoteID[noteID] == sessionID else { return }
        ownersByNoteID.removeValue(forKey: noteID)
    }

    @discardableResult
    func transfer(noteID: String, from ownerID: String, to nextOwnerID: String) -> Bool {
        if let store = storesByNoteID[noteID] {
            guard let transferred = try? store.transfer(
                noteID: noteID,
                from: ownerID,
                to: nextOwnerID,
                updatedAtMs: Self.nowMilliseconds()
            ) else {
                return false
            }
            ownersByNoteID[noteID] = try? store.ownerID(for: noteID)
            refreshRegisteredSessions(for: noteID)
            return transferred
        }
        guard ownersByNoteID[noteID] == ownerID else { return false }
        ownersByNoteID[noteID] = nextOwnerID
        refreshRegisteredSessions(for: noteID)
        return true
    }

    func resetForTests() {
        for store in storesByNoteID.values {
            try? store.resetAllForTests()
        }
        resetInMemoryForTests()
    }

    func resetInMemoryForTests() {
        ownersByNoteID.removeAll()
        storesByNoteID.removeAll()
        activeSessionIDs.removeAll()
        activeSessionsByID.removeAll()
    }

    private static func nowMilliseconds() -> Int64 {
        Int64((Date().timeIntervalSince1970 * 1_000).rounded())
    }

    private func clearInactiveStoredOwnerIfNeeded(
        noteID: String,
        sessionID: String,
        store: any NoteSessionLeaseStore
    ) {
        guard let owner = try? store.ownerID(for: noteID),
              owner != sessionID,
              !ownerSessionIsActive(owner) else {
            return
        }
        try? store.release(noteID: noteID, sessionID: owner)
        ownersByNoteID.removeValue(forKey: noteID)
    }

    private func ownerSessionIsActive(_ ownerID: String) -> Bool {
        if let weakSession = activeSessionsByID[ownerID] {
            guard weakSession.value != nil else {
                activeSessionsByID.removeValue(forKey: ownerID)
                activeSessionIDs.remove(ownerID)
                return false
            }
            return true
        }
        if activeSessionIDs.contains(ownerID) {
            return true
        }

        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        // MAS relaunches must not trust a persisted owner solely because a PID
        // exists. PIDs can be reused after quit/reopen, leaving Source/Code
        // editors read-only until the stale row is cleared.
        return false
        #else
        guard let ownerPID = Self.processIdentifier(from: ownerID) else {
            return false
        }
        return Self.processIsRunning(ownerPID)
        #endif
    }

    private nonisolated static func processIdentifier(from sessionID: String) -> Int32? {
        let parts = sessionID.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0] == "epistemos",
              let pid = Int32(parts[1]) else {
            return nil
        }
        return pid
    }

    private nonisolated static func processIsRunning(_ pid: Int32) -> Bool {
        guard pid > 0 else { return false }
        if pid == ProcessInfo.processInfo.processIdentifier {
            return true
        }
        let result = Darwin.kill(pid, 0)
        return result == 0 || errno == EPERM
    }

    private func ownerCanHandoffCleanly(noteID: String, ownerID: String) -> Bool {
        if let activeOwner = activeSessionsByID[ownerID]?.value {
            return activeOwner.noteID == noteID && !activeOwner.state.needsWriteLease
        }
        activeSessionsByID.removeValue(forKey: ownerID)

        if let store = storesByNoteID[noteID],
           let needsWriteLease = try? store.ownerNeedsWriteLease(for: noteID) {
            return needsWriteLease == false
        }
        return false
    }

    private func refreshRegisteredSessions(for noteID: String) {
        activeSessionsByID = activeSessionsByID.filter { _, weakSession in
            weakSession.value != nil
        }
        for weakSession in activeSessionsByID.values {
            guard let session = weakSession.value,
                  session.noteID == noteID else { continue }
            session.refreshLeaseOwner()
        }
    }
}

@MainActor
private final class WeakNoteSessionStateMachine {
    weak var value: NoteSessionStateMachine?

    init(_ value: NoteSessionStateMachine) {
        self.value = value
    }
}

@MainActor
@Observable
final class NoteSessionStateMachine {
    static let autosaveDebounceMilliseconds = 800
    static let autosaveCeilingMilliseconds = 5_000

    let noteID: String
    let sessionID: String
    private(set) var lens: NoteSessionLens
    private(set) var state: NoteSessionState = .idle
    private(set) var leaseOwnerID: String?
    private(set) var undoPolicy: NoteSessionUndoPolicy = .preservedWithinLens
    private(set) var lastLensSwitch: NoteSessionLensSwitch?
    private(set) var lastForceFlushReason: NoteSessionSaveReason?
    private(set) var handoffRequestedFromOwnerID: String?
    private(set) var externalReloadPending = false
    private(set) var conflictBaseMarkdown: String?

    init(
        noteID: String,
        sessionID: String = NoteSessionLeaseRegistry.makeSessionID(),
        initialLens: NoteSessionLens = .document
    ) {
        self.noteID = noteID
        self.sessionID = sessionID
        self.lens = initialLens
    }

    var currentOwnerID: String? {
        leaseOwnerID
    }

    var isLeaseOwner: Bool {
        currentOwnerID == sessionID
    }

    var isFollower: Bool {
        guard let owner = currentOwnerID else { return false }
        return owner != sessionID
    }

    var canWrite: Bool {
        isLeaseOwner
    }

    var preservesUndoAcrossLensSwitch: Bool {
        undoPolicy != .documentedV1UndoLossAcrossLensSwitch
    }

    static func resetLeaseRegistryForTests() {
        NoteSessionLeaseRegistry.shared.resetForTests()
    }

    static func resetInMemoryLeaseRegistryForTests() {
        NoteSessionLeaseRegistry.shared.resetInMemoryForTests()
    }

    func configureLeaseStore(_ store: any NoteSessionLeaseStore) {
        NoteSessionLeaseRegistry.shared.attachStore(store, noteID: noteID)
        refreshLeaseOwner()
        persistSessionState()
    }

    @discardableResult
    func open() -> Bool {
        NoteSessionLeaseRegistry.shared.registerSession(self)
        state = .loading(epoch: nil)
        let acquired = acquireLeaseIfAvailable()
        state = .clean
        persistSessionState()
        return acquired
    }

    func close() {
        NoteSessionLeaseRegistry.shared.release(noteID: noteID, sessionID: sessionID)
        NoteSessionLeaseRegistry.shared.unregisterSession(sessionID)
        leaseOwnerID = NoteSessionLeaseRegistry.shared.ownerID(for: noteID)
        state = .idle
        externalReloadPending = false
        conflictBaseMarkdown = nil
        handoffRequestedFromOwnerID = nil
    }

    func beginLoad(epoch: UInt64? = nil) {
        state = .loading(epoch: epoch)
        persistSessionState()
    }

    func finishLoad() {
        state = .clean
        externalReloadPending = false
        persistSessionState()
    }

    @discardableResult
    func acquireLeaseIfAvailable() -> Bool {
        let acquired = NoteSessionLeaseRegistry.shared.acquire(
            noteID: noteID,
            sessionID: sessionID,
            lens: lens,
            state: state
        )
        leaseOwnerID = NoteSessionLeaseRegistry.shared.ownerID(for: noteID)
        return acquired
    }

    func refreshLeaseOwner() {
        leaseOwnerID = NoteSessionLeaseRegistry.shared.ownerID(for: noteID)
    }

    @discardableResult
    func acquireCleanLeaseHandoffIfAvailable() -> Bool {
        let acquired = NoteSessionLeaseRegistry.shared.acquireOrHandoffCleanOwner(
            noteID: noteID,
            sessionID: sessionID,
            lens: lens,
            state: state
        )
        leaseOwnerID = NoteSessionLeaseRegistry.shared.ownerID(for: noteID)
        if acquired {
            handoffRequestedFromOwnerID = nil
            persistSessionState()
        }
        return acquired
    }

    @discardableResult
    func requestLeaseHandoff() -> NoteSessionEditDecision {
        let owner = currentOwnerID
        handoffRequestedFromOwnerID = owner
        return .needsLeaseHandoff(currentOwnerID: owner)
    }

    @discardableResult
    func handoffLease(to nextOwnerID: String) -> Bool {
        guard isLeaseOwner else { return false }
        guard !state.needsWriteLease else {
            lastForceFlushReason = .leaseHandoff
            return false
        }
        let transferred = NoteSessionLeaseRegistry.shared.transfer(
            noteID: noteID,
            from: sessionID,
            to: nextOwnerID
        )
        refreshLeaseOwner()
        persistSessionState()
        return transferred
    }

    @discardableResult
    func recordUserEdit(source: NoteSessionEditSource = .user) -> NoteSessionEditDecision {
        _ = source
        if !isLeaseOwner {
            if acquireLeaseIfAvailable() {
                state = .dirty(since: .now)
                persistSessionState()
                return .accepted
            }
            return requestLeaseHandoff()
        }
        state = .dirty(since: .now)
        persistSessionState()
        return .accepted
    }

    @discardableResult
    func beginAutosave(reason: NoteSessionSaveReason) -> Bool {
        guard isLeaseOwner else {
            _ = requestLeaseHandoff()
            return false
        }
        lastForceFlushReason = reason
        state = .autosaving(reason: reason)
        persistSessionState()
        return true
    }

    func finishAutosave(succeeded: Bool) {
        state = succeeded ? .clean : .dirty(since: .now)
        persistSessionState()
    }

    func acceptLocalSave() {
        externalReloadPending = false
        conflictBaseMarkdown = nil
        state = .clean
        persistSessionState()
    }

    @discardableResult
    func forceFlush(reason: NoteSessionSaveReason) -> Bool {
        lastForceFlushReason = reason
        guard state.needsWriteLease else { return true }
        return beginAutosave(reason: reason)
    }

    @discardableResult
    func switchLens(to nextLens: NoteSessionLens) -> Bool {
        guard lens != nextLens else { return false }
        lastLensSwitch = NoteSessionLensSwitch(from: lens, to: nextLens)
        lens = nextLens
        undoPolicy = .documentedV1UndoLossAcrossLensSwitch
        if state.needsWriteLease {
            _ = forceFlush(reason: .lensSwitch)
            return true
        }
        lastForceFlushReason = .lensSwitch
        persistSessionState()
        return false
    }

    @discardableResult
    func externalBodyChanged(diff3Base: String? = nil) -> NoteSessionExternalChangeDecision {
        if state.needsWriteLease {
            let base = diff3Base ?? ""
            conflictBaseMarkdown = base
            state = .conflict(diff3Base: base)
            persistSessionState()
            return .conflict(diff3Base: base)
        }

        externalReloadPending = true
        state = .externalChange(pendingReload: true)
        persistSessionState()
        return .reloadWhenClean
    }

    func acceptExternalReload() {
        externalReloadPending = false
        conflictBaseMarkdown = nil
        state = .clean
        persistSessionState()
    }

    private func persistSessionState() {
        guard isLeaseOwner else { return }
        NoteSessionLeaseRegistry.shared.recordState(
            noteID: noteID,
            sessionID: sessionID,
            lens: lens,
            state: state
        )
    }
}

private extension NoteSessionState {
    var storageLabel: String {
        switch self {
        case .idle:
            "idle"
        case .loading:
            "loading"
        case .clean:
            "clean"
        case .dirty:
            "dirty"
        case .autosaving:
            "autosaving"
        case .externalChange:
            "external_change"
        case .conflict:
            "conflict"
        }
    }
}
