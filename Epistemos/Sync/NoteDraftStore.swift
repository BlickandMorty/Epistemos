import Foundation
import OSLog

/// NOTE-4 (audit 2026-07-03): crash-recovery drafts for note editing.
///
/// The vault `.md` body is written on a debounce, and on a HARD crash / kill -9 /
/// kernel panic no `willTerminate` fires — so edits since the last durable write need
/// a non-canonical recovery path. This mirrors `MeetingDraftStore`: the editor writes
/// the current body to a lightweight `.draft` file on a short (~1.5s) debounce and
/// deletes it once the body is durably saved. At launch, `reconcileOrphanedDrafts()`
/// offers newer crash drafts back through the vault-file-first recovery path and clears
/// the rest.
///
/// Drafts are non-canonical: the `.md` remains the source of truth. Recovery routes back
/// through the normalizing atomic writer, and a timestamp guard prevents clobbering a body
/// that was updated externally after the crash.
nonisolated enum NoteDraftStore {
    private static let directoryName = "Epistemos/NoteDrafts"
    private static let fileExtension = "draft"
    private static let log = Logger(subsystem: "com.epistemos.app", category: "NoteDraftStore")
    private static let fileLock = NSLock()

    private static func directory(create: Bool) -> URL? {
        let base = FoundationSafety.userApplicationSupportDirectory()
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

    /// Persist (or overwrite) the crash draft for a page. Atomic. An empty file
    /// represents an intentional clear and must remain recoverable.
    static func write(pageId: String, body: String) {
        guard let url = url(for: pageId, create: true) else { return }
        fileLock.withLock {
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
    }

    static func draftMatchesDurableBody(_ draftBody: String, durableBody: String) -> Bool {
        draftBody == durableBody
    }

    /// Remove a page's draft only when it represents the exact body that just
    /// became durable. A newer draft must survive an older save completion.
    @discardableResult
    static func deleteIfMatching(pageId: String, durableBody: String) -> Bool {
        guard let url = url(for: pageId, create: false) else { return false }
        return fileLock.withLock {
            guard let draftBody = try? String(contentsOf: url, encoding: .utf8),
                  draftMatchesDurableBody(draftBody, durableBody: durableBody) else {
                return false
            }
            do {
                try FileManager.default.removeItem(at: url)
                return true
            } catch {
                return false
            }
        }
    }

    /// At launch: recover any draft that is newer than its durable body (a crash orphan)
    /// and clear the rest. Safe to call before any editor loads — it reconciles straight
    /// into the durable `.md` so editors then load the recovered content naturally.
    static func reconcileOrphanedDrafts(
        recover: @Sendable (String, String, Date) async -> Bool
    ) async {
        guard let dir = directory(create: false),
              let items = try? FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
              ) else { return }

        var recovered = 0
        for item in items where item.pathExtension == fileExtension {
            let pageId = item.deletingPathExtension().lastPathComponent
            guard NoteFileStorage.isValidPageId(pageId),
                  let draftBody = try? String(contentsOf: item, encoding: .utf8) else { continue }
            let draftDate = (try? item.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            // Only recover when the draft is strictly newer than the durable body — if the
            // .md already caught up (clean save) or was updated externally after the crash,
            // the draft is stale and just gets cleared by the defer above. The vault service
            // owns that comparison because the canonical mtime lives on the vault `.md`, not
            // in the retired managed body cache.
            let didRecover = await recover(pageId, draftBody, draftDate)
            _ = deleteIfMatching(pageId: pageId, durableBody: draftBody)
            if didRecover {
                recovered += 1
            }
        }
        if recovered > 0 {
            log.notice("Recovered \(recovered, privacy: .public) orphaned note draft(s) after an unclean shutdown")
        }
    }
}
