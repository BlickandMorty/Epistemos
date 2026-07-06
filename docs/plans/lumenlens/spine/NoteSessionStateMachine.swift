// ═══ AUDIT AMENDMENT (2026-07-06, repo-juxtaposed — BINDING; overrides body where they conflict) ═══
// KEELSTONE SEAM (ported from the superseded v1 LensSessionCoordinator): this state machine IS the
// implementation of KEELSTONE's ActiveEditorBridge protocol (activeRelativePath/baseHash/isDirty/
// reload/enterConflict — docs/plans/keelstone/spine/VaultReconciler.swift). Its Clean-reload and
// Dirty-conflict branches are that protocol verbatim; one object serves both plans. KEELSTONE
// Phases 0-4 land first; the follower/write-lease row (GRDB note_session) joins the EXISTING
// per-vault DB (never a second DB). Two live editors per note are real today (window registry is
// one-per-note, but GraphNotePage embeds NoteDetailWorkspaceView independently).
// ════════════════════════════════════════════════════════════════════════════════════════════════
//  NoteSessionStateMachine.swift
//  EPI-RP-02-LUMENLENS · Fork C (BINDING)
//
//  One write-lease per note session. Additional windows on the same note open as
//  FOLLOWERS (read-only mirrors, live-updated over the F6 bus). A follower requesting an
//  edit triggers a lease handoff. The single undo stack lives in the lease-owner's
//  ProseMirror history plugin; agent and user edits share it but are TAGGED so
//  "revert-all-by-companion" can filter by source.
//
//  Platform hygiene: @Observable (not ObservableObject); never block @MainActor.

import Foundation
import Observation

/// Every transaction is tagged so the ledger can attribute and selectively revert.
enum TransactionSource: String, Codable {
    case user
    case agent
}

/// The canonical session state machine. Side-states handle external file changes + conflict.
enum NoteSessionState: Equatable {
    case idle
    case loading
    case clean
    case dirty
    case autosaving
    // side-states:
    case externalChange(pendingReload: Bool)
    case conflict(diff3Base: String)   // Fork/scale verdict: diff3 merge v1, NOT a CRDT
}

@Observable
final class NoteSessionStateMachine {

    private(set) var state: NoteSessionState = .idle
    private(set) var isLeaseOwner: Bool = false

    /// Debounce config (Fork C): 800ms idle, 5s max-in-flight ceiling, force-flush on
    /// blur / lens-switch / app-background.
    let autosaveIdleMs: Int = 800
    let autosaveCeilingMs: Int = 5_000

    // MARK: Lease

    /// Acquire the write lease. Exactly one owner per note session id.
    func acquireLease() {
        // TODO: enforce single-owner via a GRDB `note_session` row keyed by note id.
        isLeaseOwner = true
    }

    /// Hand the lease to a follower window that wants to edit.
    func handoffLease(to _windowId: UUID) {
        // TODO: flush current owner to Clean, transfer PM-JSON + undo depth, flip ownership.
    }

    // MARK: Transitions

    func transition(to next: NoteSessionState) {
        // TODO: guard illegal transitions; publish the new state on the F6 state/event bus.
        state = next
    }

    func onUserEdit() { if isLeaseOwner { transition(to: .dirty) } }

    func onAutosaveTick() {
        guard case .dirty = state, isLeaseOwner else { return }
        transition(to: .autosaving)
        // TODO: minimal-diff writeback (Fork B) off the main actor; then -> .clean.
    }

    func onExternalChange() {
        switch state {
        case .clean: transition(to: .externalChange(pendingReload: true)) // reload
        default:     transition(to: .conflict(diff3Base: "")) // TODO capture disk base
        }
    }
}
