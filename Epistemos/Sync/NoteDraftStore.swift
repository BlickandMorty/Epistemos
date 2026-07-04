import Foundation
import OSLog

/// NOTE-4 (audit 2026-07-03): crash-recovery drafts for note editing.
///
/// The durable managed body (`NoteFileStorage`) is written on a ~5s debounce, and on a
/// HARD crash / kill -9 / kernel panic no `willTerminate` fires — so edits since the last
/// durable write are lost with no recovery (meetings have `MeetingDraftStore`; notes did
/// not). This mirrors that pattern for notes: the editor writes the current body to a
/// lightweight `.draft` file on a short (~1.5s) debounce and deletes it once the body is
/// durably saved. At launch, `reconcileOrphanedDrafts()` recovers any draft that is NEWER
/// than its durable body (a crash orphan) and clears the rest.
///
/// Drafts are non-canonical: the `.md` remains the source of truth. Recovery routes back
/// through the normalizing atomic writer, and a timestamp guard prevents clobbering a body
/// that was updated externally after the crash.
nonisolated enum NoteDraftStore {
    private static let directoryName = "Epistemos/NoteDrafts"
    private static let fileExtension = "draft"
    private static let log = Logger(subsystem: "com.epistemos.app", category: "NoteDraftStore")

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

    private static func url(for pageId: String, create: Bool) -> URL? {
        guard NoteFileStorage.isValidPageId(pageId), let dir = directory(create: create) else {
            return nil
        }
        return dir.appendingPathComponent(pageId).appendingPathExtension(fileExtension)
    }

    /// Persist (or overwrite) the crash draft for a page. Atomic; no-op for an empty body.
    static func write(pageId: String, body: String) {
        guard !body.isEmpty, let url = url(for: pageId, create: true) else { return }
        do {
            try Data(body.utf8).write(to: url, options: .atomic)
        } catch {
            // Match MeetingDraftStore: a silently-failing crash-draft write means recovery may be
            // unavailable (e.g. disk full) — surface it instead of swallowing. The draft filename is
            // a UUID pageId, so the error text leaks no note title.
            Log.vault.error(
                "note crash-draft write failed \u{2014} recovery may be unavailable: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Remove a page's draft — called once the durable body is saved.
    static func delete(pageId: String) {
        guard let url = url(for: pageId, create: false) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// At launch: recover any draft that is newer than its durable body (a crash orphan)
    /// and clear the rest. Safe to call before any editor loads — it reconciles straight
    /// into the durable `.md` so editors then load the recovered content naturally.
    static func reconcileOrphanedDrafts() {
        guard let dir = directory(create: false),
              let items = try? FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
              ) else { return }

        var recovered = 0
        for item in items where item.pathExtension == fileExtension {
            defer { try? FileManager.default.removeItem(at: item) }  // always clear the draft
            let pageId = item.deletingPathExtension().lastPathComponent
            guard NoteFileStorage.isValidPageId(pageId),
                  let draftBody = try? String(contentsOf: item, encoding: .utf8),
                  !draftBody.isEmpty else { continue }
            let draftDate = (try? item.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            let bodyDate = NoteFileStorage.bodyModificationDate(pageId: pageId) ?? .distantPast
            // Only recover when the draft is strictly newer than the durable body — if the
            // .md already caught up (clean save) or was updated externally after the crash,
            // the draft is stale and just gets cleared by the defer above.
            guard draftDate > bodyDate else { continue }
            NoteFileStorage.writeBody(pageId: pageId, content: draftBody)
            recovered += 1
        }
        if recovered > 0 {
            log.notice("Recovered \(recovered, privacy: .public) orphaned note draft(s) after an unclean shutdown")
        }
    }
}
