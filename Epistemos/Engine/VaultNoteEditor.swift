import Foundation

/// Honest failures applying an agent edit to a note file.
enum VaultNoteEditError: Error, Equatable {
    /// The atomic edit batch couldn't apply (a missing anchor) — nothing was written.
    case editDidNotApply
    /// The edit WAS written, but its provenance `MutationEnvelope` could not be persisted (e.g. the
    /// EventStore was unavailable). Surfaced — never silently dropped — so a provenance-requiring caller
    /// knows the audit record is missing even though the note body is already updated on disk.
    case provenanceNotRecorded
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
    let read: @Sendable (URL) async throws -> String
    let write: @Sendable (URL, String) async throws -> Void

    /// Coordinated vault-file editor (UTF-8). The production path.
    static func fileSystem() -> VaultNoteEditor {
        VaultNoteEditor(
            read: { url in
                try await Task.detached(priority: .utility) {
                    try Self.coordinatedRead(url)
                }.value
            },
            write: { url, content in
                try await AtomicVaultWriter.shared.write(content, to: url)
            }
        )
    }

    /// Apply `edits` atomically to the note at `url`, returning the new content. Throws if read/write fails
    /// OR if the batch can't apply (missing anchor) — in which case NOTHING is written.
    @discardableResult
    func applyEdits(_ edits: [AgentNoteEdit], to url: URL) async throws -> String {
        let content = try await read(url)
        guard let updated = AgentNoteEdit.apply(edits, to: content) else {
            throw VaultNoteEditError.editDidNotApply
        }
        try await write(url, updated)
        return updated
    }

    /// VAULT-DEEP-INTEGRATION §720 (#4): apply `edits` atomically AND record the change as an agent
    /// `MutationEnvelope` (`SourceOp.artifactUpdate`) for provenance — the in-app agent-edit path now has an
    /// auditable trail, reusing the EventStore spine (`ModelAuthoredNoteMutation`'s model, not a parallel one).
    ///
    /// ORDER + HONESTY: read → apply atomically → write the body → THEN record provenance. A missing anchor
    /// throws `editDidNotApply` and writes/records NOTHING. If the body wrote but the envelope couldn't be
    /// saved, throws `provenanceNotRecorded` (the body IS on disk — reported, never a silent gap). `now` +
    /// `recordEnvelope` are injectable so the path is deterministic + unit-testable without a clock or DB.
    @discardableResult
    func applyEdits(
        _ edits: [AgentNoteEdit],
        to url: URL,
        provenance context: AgentEditProvenanceContext,
        now: () -> Int64 = { Int64(Date().timeIntervalSince1970 * 1_000) },
        recordEnvelope: (MutationEnvelope, String?) -> Bool = { envelope, traceID in
            EventStore.shared?.saveMutationEnvelope(envelope, traceId: traceID) ?? false
        }
    ) async throws -> String {
        let before = try await read(url)
        guard let updated = AgentNoteEdit.apply(edits, to: before) else {
            throw VaultNoteEditError.editDidNotApply
        }
        try await write(url, updated)

        let envelope = AgentNoteEditProvenance.envelope(
            context: context,
            beforeBody: before,
            afterBody: updated,
            createdAtMs: now()
        )
        guard recordEnvelope(envelope, AgentNoteEditProvenance.traceID(for: envelope)) else {
            throw VaultNoteEditError.provenanceNotRecorded
        }
        return updated
    }

    private nonisolated static func coordinatedRead(_ url: URL) throws -> String {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinatorError: NSError?
        var readResult: Result<String, Error>?
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinatorError) { coordinatedURL in
            readResult = Result {
                let data = try Data(contentsOf: coordinatedURL)
                guard let text = String(data: data, encoding: .utf8) else {
                    throw CocoaError(.fileReadInapplicableStringEncoding)
                }
                return text
            }
        }
        if let coordinatorError {
            throw coordinatorError
        }
        guard let readResult else {
            throw CocoaError(.fileReadUnknown)
        }
        return try readResult.get()
    }
}
