import Foundation

/// Durable incremental persistence for in-progress meeting transcripts.
///
/// A meeting transcript otherwise lives only in memory until the user taps Save
/// (`MeetingNoteCaptureService.finalize`), so any crash / force-quit / OOM kill /
/// power loss mid-meeting loses the entire recording — the single biggest gap for
/// "trust this app with my meetings" (audit 2026-07-03, HIGH).
///
/// This store writes the active transcript to a small draft file as segments
/// finalize, and deletes it once the meeting is saved. A draft that survives to
/// the next launch therefore belongs to a session that never saved (a crash), and
/// is offered back to the user for recovery.
///
/// Writes are atomic (temp + rename) so a crash mid-write can't corrupt the draft.
///
/// `nonisolated` (the module defaults types to `@MainActor`): this is pure file IO
/// with no shared state, and the debounced writes run off the main actor.
nonisolated enum MeetingDraftStore {
    private static let directoryName = "Epistemos/MeetingDrafts"
    private static let fileExtension = "txt"

    private static func directory(create: Bool) -> URL? {
        guard let base = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: create
        ) else { return nil }
        let dir = base.appendingPathComponent(directoryName, isDirectory: true)
        if create {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private static func url(for sessionId: String, create: Bool) -> URL? {
        guard !sessionId.isEmpty, let dir = directory(create: create) else { return nil }
        return dir.appendingPathComponent(sessionId).appendingPathExtension(fileExtension)
    }

    /// Persist (or overwrite) the draft for a session. No-op for an empty transcript.
    static func write(sessionId: String, transcript: String) {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = url(for: sessionId, create: true) else { return }
        try? Data(transcript.utf8).write(to: url, options: .atomic)
    }

    /// Remove a session's draft — called once the meeting is saved.
    static func delete(sessionId: String) {
        guard let url = url(for: sessionId, create: false) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    struct RecoverableDraft: Equatable, Sendable {
        let sessionId: String
        let transcript: String
        let modifiedAt: Date
    }

    /// The most recently modified orphaned draft, excluding the currently-active
    /// session. Returns nil when there is nothing to recover.
    static func latestRecoverable(excluding activeSessionId: String?) -> RecoverableDraft? {
        guard let dir = directory(create: false),
              let items = try? FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
              ) else { return nil }

        var best: RecoverableDraft?
        for item in items where item.pathExtension == fileExtension {
            let sessionId = item.deletingPathExtension().lastPathComponent
            if let activeSessionId, sessionId == activeSessionId { continue }
            guard let text = try? String(contentsOf: item, encoding: .utf8),
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            let modifiedAt = (try? item.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            if best == nil || modifiedAt > best!.modifiedAt {
                best = RecoverableDraft(sessionId: sessionId, transcript: text, modifiedAt: modifiedAt)
            }
        }
        return best
    }
}
