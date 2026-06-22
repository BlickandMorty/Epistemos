import Foundation

/// Honest failures applying an agent edit to a note file.
enum VaultNoteEditError: Error, Equatable {
    /// The atomic edit batch couldn't apply (a missing anchor) — nothing was written.
    case editDidNotApply
}

/// VAULT-DEEP-INTEGRATION §720 (#4): applies agent note edits to a note FILE — the in-app agent path that
/// reuses the `AgentNoteEdit` honest/atomic core. The LIVE-EDITOR binding (applying the SAME ops to an open
/// `NSTextView` / Tiptap buffer) is the UI follow-on; this file-level path works whether or not the note is
/// open, and shares the operation model so the two surfaces never diverge.
///
/// HONEST + ATOMIC: it reads → applies the batch all-or-nothing → writes ONLY on full success. A missing
/// anchor throws `editDidNotApply` and writes NOTHING — the agent never persists a partial/corrupted note.
/// `read`/`write` are injectable so the core is unit-testable without touching the filesystem.
struct VaultNoteEditor: Sendable {
    let read: @Sendable (URL) throws -> String
    let write: @Sendable (URL, String) throws -> Void

    /// FileManager-backed editor (UTF-8). The production path.
    static func fileSystem() -> VaultNoteEditor {
        VaultNoteEditor(
            read: { url in try String(contentsOf: url, encoding: .utf8) },
            write: { url, content in try content.write(to: url, atomically: true, encoding: .utf8) }
        )
    }

    /// Apply `edits` atomically to the note at `url`, returning the new content. Throws if read/write fails
    /// OR if the batch can't apply (missing anchor) — in which case NOTHING is written.
    @discardableResult
    func applyEdits(_ edits: [AgentNoteEdit], to url: URL) throws -> String {
        let content = try read(url)
        guard let updated = AgentNoteEdit.apply(edits, to: content) else {
            throw VaultNoteEditError.editDidNotApply
        }
        try write(url, updated)
        return updated
    }
}
