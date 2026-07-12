import Foundation
import GRDB
import Testing
@testable import Epistemos

@Suite("Note session state machine")
@MainActor
struct NoteSessionStateMachineTests {
    @Test("first session owns the note while second session follows")
    func firstSessionOwnsTheNoteWhileSecondSessionFollows() {
        NoteSessionStateMachine.resetLeaseRegistryForTests()

        let owner = NoteSessionStateMachine(noteID: "note-a", sessionID: "owner")
        let follower = NoteSessionStateMachine(noteID: "note-a", sessionID: "follower")

        #expect(owner.open())
        #expect(!follower.open())
        #expect(owner.isLeaseOwner)
        #expect(follower.isFollower)

        #expect(follower.recordUserEdit(source: .user) == .needsLeaseHandoff(currentOwnerID: "owner"))
        #expect(follower.state == .clean)

        #expect(owner.recordUserEdit(source: .user) == .accepted)
        guard case .dirty = owner.state else {
            Issue.record("Owner edits should move the session to dirty")
            return
        }
    }

    @Test("lease handoff waits until owner is clean")
    func leaseHandoffWaitsUntilOwnerIsClean() {
        NoteSessionStateMachine.resetLeaseRegistryForTests()

        let owner = NoteSessionStateMachine(noteID: "note-b", sessionID: "owner")
        let follower = NoteSessionStateMachine(noteID: "note-b", sessionID: "follower")
        _ = owner.open()
        _ = follower.open()

        _ = owner.recordUserEdit(source: .user)
        #expect(!owner.handoffLease(to: follower.sessionID))
        #expect(owner.lastForceFlushReason == .leaseHandoff)

        #expect(owner.beginAutosave(reason: .idleDebounce))
        owner.finishAutosave(succeeded: true)
        #expect(owner.handoffLease(to: follower.sessionID))
        owner.refreshLeaseOwner()
        follower.refreshLeaseOwner()

        #expect(owner.isFollower)
        #expect(follower.isLeaseOwner)
    }

    @Test("clean active owner can hand off to graph session without leaving stale writer")
    func cleanActiveOwnerCanHandoffToGraphSessionWithoutLeavingStaleWriter() {
        NoteSessionStateMachine.resetLeaseRegistryForTests()

        let owner = NoteSessionStateMachine(noteID: "note-clean-handoff", sessionID: "owner")
        let graph = NoteSessionStateMachine(noteID: "note-clean-handoff", sessionID: "graph")

        #expect(owner.open())
        #expect(!graph.open())

        #expect(graph.acquireCleanLeaseHandoffIfAvailable())
        #expect(graph.isLeaseOwner)
        #expect(owner.isFollower)
        #expect(!owner.canWrite)
        #expect(graph.canWrite)
    }

    @Test("deallocated clean owner does not keep graph Source editors read-only")
    func deallocatedCleanOwnerDoesNotKeepGraphSourceEditorsReadOnly() {
        NoteSessionStateMachine.resetLeaseRegistryForTests()

        var owner: NoteSessionStateMachine? = NoteSessionStateMachine(
            noteID: "note-deallocated-clean-owner",
            sessionID: "owner"
        )
        #expect(owner?.open() == true)
        owner = nil

        let graph = NoteSessionStateMachine(
            noteID: "note-deallocated-clean-owner",
            sessionID: "graph"
        )
        #expect(graph.open())
        #expect(graph.canWrite)
    }

    @Test("dirty active owner blocks graph clean handoff")
    func dirtyActiveOwnerBlocksGraphCleanHandoff() {
        NoteSessionStateMachine.resetLeaseRegistryForTests()

        let owner = NoteSessionStateMachine(noteID: "note-dirty-handoff", sessionID: "owner")
        let graph = NoteSessionStateMachine(noteID: "note-dirty-handoff", sessionID: "graph")

        #expect(owner.open())
        _ = owner.recordUserEdit(source: .user)
        #expect(!graph.open())

        #expect(!graph.acquireCleanLeaseHandoffIfAvailable())
        #expect(owner.isLeaseOwner)
        #expect(graph.isFollower)
        #expect(owner.canWrite)
        #expect(!graph.canWrite)
    }

    @Test("external changes reload clean sessions and conflict dirty sessions")
    func externalChangesReloadCleanSessionsAndConflictDirtySessions() {
        NoteSessionStateMachine.resetLeaseRegistryForTests()

        let clean = NoteSessionStateMachine(noteID: "note-c", sessionID: "clean")
        _ = clean.open()
        #expect(clean.externalBodyChanged(diff3Base: "disk") == .reloadWhenClean)
        #expect(clean.state == .externalChange(pendingReload: true))
        clean.acceptExternalReload()
        #expect(clean.state == .clean)

        let dirty = NoteSessionStateMachine(noteID: "note-d", sessionID: "dirty")
        _ = dirty.open()
        _ = dirty.recordUserEdit(source: .user)
        #expect(dirty.externalBodyChanged(diff3Base: "base") == .conflict(diff3Base: "base"))
        #expect(dirty.conflictBaseMarkdown == "base")
        #expect(dirty.state == .conflict(diff3Base: "base"))
    }

    @Test("lens switches force flush and document v1 undo loss")
    func lensSwitchesForceFlushAndDocumentV1UndoLoss() {
        NoteSessionStateMachine.resetLeaseRegistryForTests()

        let session = NoteSessionStateMachine(noteID: "note-e", sessionID: "owner", initialLens: .document)
        _ = session.open()
        _ = session.recordUserEdit(source: .user)

        #expect(session.switchLens(to: .source))
        #expect(session.lastLensSwitch == NoteSessionLensSwitch(from: .document, to: .source))
        #expect(session.lastForceFlushReason == .lensSwitch)
        #expect(session.undoPolicy == .documentedV1UndoLossAcrossLensSwitch)
        #expect(!session.preservesUndoAcrossLensSwitch)
        #expect(session.state == .autosaving(reason: .lensSwitch))
        #expect(NoteSessionStateMachine.autosaveDebounceMilliseconds == 800)
        #expect(NoteSessionStateMachine.autosaveCeilingMilliseconds == 5_000)
    }

    @Test("lease ownership persists in the GRDB note_session row")
    func leaseOwnershipPersistsInGRDBNoteSessionRow() throws {
        NoteSessionStateMachine.resetLeaseRegistryForTests()
        let queue = try DatabaseQueue()
        let store = NoteSessionGRDBLeaseStore(databaseWriter: queue)

        let owner = NoteSessionStateMachine(noteID: "note-db", sessionID: "owner")
        owner.configureLeaseStore(store)
        #expect(owner.open())
        #expect(try store.ownerID(for: "note-db") == "owner")

        let follower = NoteSessionStateMachine(noteID: "note-db", sessionID: "follower")
        follower.configureLeaseStore(store)
        #expect(!follower.open())
        #expect(follower.isFollower)
        #expect(follower.recordUserEdit(source: .user) == .needsLeaseHandoff(currentOwnerID: "owner"))

        owner.close()
        #expect(try store.ownerID(for: "note-db") == nil)
    }

    @Test("relaunch reclaims orphaned persisted lease so Source stays editable")
    func relaunchReclaimsOrphanedPersistedLeaseSoSourceStaysEditable() throws {
        NoteSessionStateMachine.resetLeaseRegistryForTests()
        let queue = try DatabaseQueue()
        let store = NoteSessionGRDBLeaseStore(databaseWriter: queue)

        let firstLaunch = NoteSessionStateMachine(noteID: "note-relaunch", sessionID: "legacy-orphan")
        firstLaunch.configureLeaseStore(store)
        #expect(firstLaunch.open())
        #expect(try store.ownerID(for: "note-relaunch") == "legacy-orphan")

        NoteSessionStateMachine.resetInMemoryLeaseRegistryForTests()

        let secondLaunch = NoteSessionStateMachine(noteID: "note-relaunch", sessionID: "second-launch")
        secondLaunch.configureLeaseStore(store)
        #expect(secondLaunch.open())
        #expect(secondLaunch.canWrite)
        #expect(try store.ownerID(for: "note-relaunch") == "second-launch")
    }
}
