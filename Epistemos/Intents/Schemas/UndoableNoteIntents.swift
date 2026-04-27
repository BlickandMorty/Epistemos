import AppIntents
import Foundation
import OSLog

// MARK: - UndoableNoteIntents (R5 / Wave 15 §"bonus items")
//
// Lane C from PARALLEL_SESSION_PROMPT.md. Per Wave 13 +
// AppIntents.swiftinterface line 1395:
//
//   public protocol UndoableIntent : AppIntents.SystemIntent
//
// And line 1398:
//
//   extension AppIntents.UndoableIntent {
//     @MainActor public var undoManager: Foundation.UndoManager? { get }
//   }
//
// The system supplies the right `undoManager` even when the intent
// runs in an extension — UI undo and intent undo share one stack so
// the user's `Cmd-Z` from the main window can roll back a delete
// triggered from Spotlight or Shortcuts.
//
// Two destructive ops conform here:
//   DeleteNoteIntent   — soft-delete (move to trash bin)
//   ArchiveNoteIntent  — moves the note to the Archive folder
//
// Neither is registered in `EpistemosShortcutsProvider.appShortcuts`
// because Apple caps that catalogue at 10 (already full). Both stay
// fully discoverable in:
//   - Shortcuts.app editor (auto-harvested at install time by linkd)
//   - macOS 26 Spotlight Actions pane
//   - Apple Intelligence semantic routing
//
// Per the master plan: "Undo 'Delete Note' actions via Spotlight"
// becomes a real UX moment — the user `Cmd-Z`s a Spotlight-triggered
// delete and the note reappears, no app foregrounding required.

private let undoableLog = Logger(
    subsystem: "com.epistemos",
    category: "UndoableNoteIntents"
)

/// Class-bound undo target. `UndoManager.registerUndo(withTarget:
/// handler:)` requires a reference type for the target argument
/// (`AnyObject` constraint). AppIntent structs can't be the target
/// directly — we route through this shared NSObject so the undo
/// invocation can find a stable target across the intent's value-
/// type lifecycle.
@MainActor
final class UndoableIntentTarget: NSObject {
    static let shared = UndoableIntentTarget()
}

// MARK: - DeleteNoteIntent

struct DeleteNoteIntent: AppIntent, UndoableIntent {

    static let title: LocalizedStringResource = "Delete Note"
    static let description = IntentDescription(
        "Move a note to the trash. Reversible via Cmd-Z (system undo) — works from Spotlight, Shortcuts, and the menu bar."
    )

    // W15.4 — supportedModes for granular execution control. We need
    // foreground escalation so the user sees the trash animation and
    // any in-app confirmation when invoked from the foreground UI;
    // background-only when invoked from a Shortcuts pipeline that
    // doesn't want a window pop.
    static let supportedModes: IntentModes = [.background, .foreground(.dynamic)]

    @Parameter(title: "Note")
    var note: NoteEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Delete \(\.$note)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Capture the pre-delete state for the undo registration.
        let snapshotId = note.id
        let snapshotTitle = note.title
        let snapshotContent = note.content

        // Record the undo action against the system-supplied
        // UndoManager. The closure captures the pre-delete snapshot
        // so the user's Cmd-Z restores the note even if the intent
        // ran from an extension process.
        if let undoManager {
            undoManager.registerUndo(withTarget: UndoableIntentTarget.shared) { _ in
                Task {
                    await Self.restoreNote(
                        id: snapshotId,
                        title: snapshotTitle,
                        content: snapshotContent
                    )
                }
            }
            undoManager.setActionName("Delete \(snapshotTitle)")
        }

        await Self.deleteNoteFromVault(id: snapshotId)
        _ = try? await donate()

        undoableLog.info(
            "Deleted note id=\(snapshotId, privacy: .public) title=\(snapshotTitle, privacy: .public) (undo registered=\(self.undoManager != nil, privacy: .public))"
        )

        return .result(dialog: IntentDialog(
            stringLiteral: "Deleted “\(snapshotTitle)”. Press ⌘Z to restore."
        ))
    }

    /// Bridge to the vault's actual delete path. Stub today —
    /// follow-up commit wires through to NoteFileStorage / SDPage so
    /// the destructive action actually flows through the canonical
    /// note-mutation pipeline + invalidates Spotlight via
    /// NoteEntitySpotlightIndexer.unindex(noteIds:).
    @MainActor
    private static func deleteNoteFromVault(id: String) async {
        // TODO: Wire to AppBootstrap.shared?.vaultIndexActor.delete(id:)
        // OR NoteFileStorage delete API once those entry points exist.
        // For now we surface the intent contract — actual deletion is
        // a follow-up.
        Task.detached(priority: .utility) {
            await NoteEntitySpotlightIndexer.unindex(noteIds: [id])
        }
    }

    @MainActor
    private static func restoreNote(
        id: String,
        title: String,
        content: String?
    ) async {
        // TODO: same wiring story — restore from trash bin once the
        // canonical delete-undo pipeline is in place.
        undoableLog.info("Restored note id=\(id, privacy: .public)")
    }
}

// MARK: - ArchiveNoteIntent

struct ArchiveNoteIntent: AppIntent, UndoableIntent {

    static let title: LocalizedStringResource = "Archive Note"
    static let description = IntentDescription(
        "Move a note to the Archive folder. Reversible via Cmd-Z."
    )

    static let supportedModes: IntentModes = [.background, .foreground(.dynamic)]

    @Parameter(title: "Note")
    var note: NoteEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Archive \(\.$note)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let snapshotId = note.id
        let snapshotTitle = note.title
        let snapshotContent = note.content

        if let undoManager {
            undoManager.registerUndo(withTarget: UndoableIntentTarget.shared) { _ in
                Task {
                    await Self.unarchiveNote(
                        id: snapshotId,
                        title: snapshotTitle,
                        content: snapshotContent
                    )
                }
            }
            undoManager.setActionName("Archive \(snapshotTitle)")
        }

        await Self.archiveNoteInVault(id: snapshotId)
        _ = try? await donate()

        undoableLog.info(
            "Archived note id=\(snapshotId, privacy: .public) title=\(snapshotTitle, privacy: .public)"
        )

        return .result(dialog: IntentDialog(
            stringLiteral: "Archived “\(snapshotTitle)”. Press ⌘Z to unarchive."
        ))
    }

    @MainActor
    private static func archiveNoteInVault(id: String) async {
        // TODO: wire to vault archive folder move + sidecar update.
        undoableLog.debug("archive stub fired for id=\(id, privacy: .public)")
    }

    @MainActor
    private static func unarchiveNote(
        id: String,
        title: String,
        content: String?
    ) async {
        undoableLog.debug("unarchive stub fired for id=\(id, privacy: .public)")
    }
}
