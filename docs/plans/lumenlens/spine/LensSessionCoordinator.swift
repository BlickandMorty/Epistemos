//
//  LensSessionCoordinator.swift
//  Epistemos — LUMENLENS spine (authored from Spine Fork C + amendments L5/L6)
//
//  The per-note session state machine + write-lease. One instance per open
//  note session. This type is ALSO the implementation of KEELSTONE's
//  `ActiveEditorBridge` protocol — Fork C's Clean-reload / Dirty-conflict
//  branches ARE that protocol, so one object serves both plans:
//
//    KEELSTONE VaultReconciler ──(ActiveEditorBridge)──▶ LensSessionCoordinator
//
//  State machine (Fork C):  Idle → Loading → Clean → Dirty → Autosaving → Clean
//  Side states: ExternalChange (clean → silent reload) / Conflict (dirty +
//  disk moved → merge engine, NEVER clobber).
//
//  Write-lease (Fork C): the first surface to open a note acquires the lease
//  (GRDB `note_session` row). Followers are read-only mirrors on the F6 bus.
//  Justified by repo reality: NoteWindowManager keeps one window per note,
//  but GraphNotePage embeds NoteDetailWorkspaceView independently — a graph
//  embed + a window CAN show the same note live (verified 2026-07-06).
//
//  ⚠️ AMENDED ASSUMPTION (L5): the research claimed "the WKWebView Tiptap
//  instance is not torn down [on lens switch]". FALSE today —
//  EpdocEditorChromeView.dismantleNSView + Coordinator.shutdown() release the
//  WebView, and NoteDetailWorkspaceView mounts surfaces per resolvedNoteMode.
//  Phase 2 opens with an explicit decision:
//    (a) retain the WebView per session across lens switches (offscreen; mind
//        the repo's deliberate 40–60 MB-per-closed-editor reclamation), or
//    (b) documented undo-loss on lens switch for v1 (safe default).
//  Do not silently assume (a).
//
//  Autosave (L5): 800 ms debounce / 5 s ceiling / force-flush on blur,
//  lens-switch, background — CONFIGURES the existing EpdocEditorSavePipeline;
//  never a second pipeline. The final disk write goes through KEELSTONE's
//  AtomicVaultWriter (whole-buffer atomic replace; minimal-diff decides the
//  buffer CONTENT, not the IO shape — see minimal-diff-writeback.ts).
//

import Foundation

public enum NoteSessionState: Sendable, Equatable {
    case idle
    case loading(epoch: UInt64)          // Fork D loadEpoch in flight
    case clean
    case dirty
    case autosaving
    case externalChange                  // clean + disk moved → reload
    case conflict(baseHash: String?)     // dirty + disk moved → merge engine
}

public enum LeaseRole: Sendable { case owner, follower }

public struct AutosavePolicy: Sendable {
    public var debounce: Duration = .milliseconds(800)
    public var maxInFlightCeiling: Duration = .seconds(5)
    /// Force-flush triggers: blur, lens switch, app background (Fork C).
    public init() {}
}

/// GRDB row: one per live note session (write-lease registry).
/// Table: note_session(note_rel_path TEXT PK, owner_surface TEXT,
///                     acquired_at REAL, heartbeat_at REAL)
/// Lease releases on close/blur-timeout; a stale heartbeat is reapable so a
/// crashed owner can't wedge the note (pick a timeout in Phase 2, ~10s).
public struct NoteSessionLease: Sendable {
    public let noteRelativePath: String
    public let ownerSurface: String       // "window" | "graphEmbed" | "minichat"
    public let acquiredAt: Date
    public var heartbeatAt: Date
}

/// The session coordinator. Actor: all lens surfaces talk to it; it talks to
/// the save pipeline + (as ActiveEditorBridge) to KEELSTONE's reconciler.
public actor LensSessionCoordinator {

    public let noteRelativePath: String
    public private(set) var state: NoteSessionState = .idle
    public private(set) var role: LeaseRole

    /// Fork D: monotonic load epoch, bumped on every programmatic load.
    private var loadEpoch: UInt64 = 0
    /// Content-hash snapshot captured at open — the conflict base (Fork C).
    private var baseHash: String?
    /// Whether the buffer diverges from what was loaded.
    private var dirty = false

    public init(noteRelativePath: String, role: LeaseRole) {
        self.noteRelativePath = noteRelativePath
        self.role = role
    }

    // MARK: - Lens switching (Fork C + L5 decision point)

    /// Called before a lens switch. Force-flushes autosave. PM-JSON authority
    /// travels with the lease. Undo behavior follows the Phase-2 decision
    /// (retain-WebView vs documented loss) — encode the chosen branch HERE.
    public func willSwitchLens() async {
        // force-flush via EpdocEditorSavePipeline (existing), then hand off
    }

    // MARK: - ActiveEditorBridge (KEELSTONE seam — the reconciler calls these)

    public func activeRelativePath() async -> String? {
        state == .idle ? nil : noteRelativePath
    }

    public func baseHash(for path: String) async -> String? {
        path == noteRelativePath ? baseHash : nil
    }

    public func isDirty(for path: String) async -> Bool {
        path == noteRelativePath && dirty
    }

    /// Clean editor + disk changed → silent reload (Fork C ExternalChange).
    public func reload(path: String, diskContent: String) async {
        guard path == noteRelativePath, !dirty else { return }
        state = .externalChange
        // push diskContent through the Fork-D epoch-load protocol (load-epoch.ts)
        state = .clean
    }

    /// Dirty editor + disk changed → conflict, NEVER clobber (Fork C Conflict).
    /// Hands to the merge engine (OQ-1: diff3 over base/local/remote).
    public func enterConflict(path: String, diskContent: String, baseHash: String?) async {
        guard path == noteRelativePath else { return }
        state = .conflict(baseHash: baseHash)
        // merge-engine handoff; on clean merge → review; else conflict-copy
    }

    // MARK: - Dirty/save transitions (wired to the existing save pipeline)

    public func markDirty() {
        dirty = true
        if state == .clean { state = .dirty }
    }

    public func autosaveDidCommit(newHash: String) {
        baseHash = newHash
        dirty = false
        state = .clean
    }

    public func nextLoadEpoch() -> UInt64 {
        loadEpoch += 1
        return loadEpoch
    }
}
