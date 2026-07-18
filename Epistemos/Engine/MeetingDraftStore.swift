import Foundation
import OSLog

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
/// `nonisolated` (the module defaults types to `@MainActor`): file access is
/// serialized by the private coordinator and runs off the main actor.
nonisolated enum MeetingDraftStore {
    private static let directoryName = "Epistemos/MeetingDrafts"
    private static let fileExtension = "txt"
    private static let maxEncodedDraftBytes = 16_004_096
    private static let log = Logger(subsystem: "Epistemos", category: "MeetingDraftStore")
    private static let coordinator = IOCoordinator()

    private final class IOCoordinator: @unchecked Sendable {
        private let queue = DispatchQueue(
            label: "com.epistemos.meeting-draft-store",
            qos: .utility
        )
        private var latestRevisionByDraft: [String: UInt64] = [:]
        private var terminalDrafts: Set<String> = []

        func enqueueWrite(
            draftKey: String,
            revision: UInt64,
            operation: @escaping @Sendable () -> Void
        ) {
            queue.async { [self] in
                let currentRevision = latestRevisionByDraft[draftKey] ?? 0
                guard !terminalDrafts.contains(draftKey),
                      revision > currentRevision else { return }
                latestRevisionByDraft[draftKey] = revision
                operation()
            }
        }

        func enqueueTerminalDelete(
            draftKey: String,
            revision: UInt64,
            operation: @escaping @Sendable () -> Void
        ) {
            queue.async { [self] in
                let currentRevision = latestRevisionByDraft[draftKey] ?? 0
                let terminalRevision: UInt64
                if currentRevision == .max {
                    terminalRevision = .max
                } else {
                    terminalRevision = max(revision, currentRevision + 1)
                }
                latestRevisionByDraft[draftKey] = terminalRevision
                terminalDrafts.insert(draftKey)
                operation()
            }
        }

        func waitForPendingOperations() {
            queue.sync {}
        }
    }

    private static func directory(create: Bool, baseDirectory: URL?) -> URL? {
        let base = baseDirectory ?? FoundationSafety.userApplicationSupportDirectory()
        let dir = base.appendingPathComponent(directoryName, isDirectory: true)
        if create {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private static func url(
        for sessionId: String,
        create: Bool,
        baseDirectory: URL?
    ) -> URL? {
        guard !sessionId.isEmpty,
              !sessionId.contains("/"),
              !sessionId.contains("\\"),
              let dir = directory(create: create, baseDirectory: baseDirectory) else { return nil }
        return dir.appendingPathComponent(sessionId).appendingPathExtension(fileExtension)
    }

    private static func draftKey(sessionId: String, baseDirectory: URL?) -> String {
        let base = baseDirectory?.standardizedFileURL.path ?? "<application-support>"
        return "\(base)|\(sessionId)"
    }

    /// Persist (or overwrite) the draft for a session. No-op for an empty transcript.
    static func write(
        sessionId: String,
        transcript: String,
        revision: UInt64,
        baseDirectory: URL? = nil
    ) {
        guard !sessionId.isEmpty else { return }
        let key = draftKey(sessionId: sessionId, baseDirectory: baseDirectory)
        coordinator.enqueueWrite(draftKey: key, revision: revision) {
            let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  let url = url(
                    for: sessionId,
                    create: true,
                    baseDirectory: baseDirectory
                  ) else { return }
            let data = Data(transcript.utf8)
            guard data.count <= maxEncodedDraftBytes else {
                log.warning("meeting crash-draft exceeds its recovery byte limit")
                return
            }
            do {
                try AtomicVaultWriter.writeSynchronously(data, to: url)
            } catch {
                log.warning("meeting crash-draft write failed — recovery may be unavailable")
            }
        }
    }

    /// Remove a session's draft — called once the meeting is saved.
    static func delete(
        sessionId: String,
        revision: UInt64,
        baseDirectory: URL? = nil
    ) {
        guard !sessionId.isEmpty else { return }
        let key = draftKey(sessionId: sessionId, baseDirectory: baseDirectory)
        coordinator.enqueueTerminalDelete(draftKey: key, revision: revision) {
            guard let url = url(
                for: sessionId,
                create: false,
                baseDirectory: baseDirectory
            ), FileManager.default.fileExists(atPath: url.path) else { return }
            do {
                try FileManager.default.removeItem(at: url)
                try AtomicVaultWriter.synchronizeParentDirectory(of: url)
            } catch {
                log.warning("meeting crash-draft cleanup failed")
            }
        }
    }

    static func waitForPendingOperations() {
        coordinator.waitForPendingOperations()
    }

    struct RecoverableDraft: Equatable, Sendable {
        let sessionId: String
        let transcript: String
        let modifiedAt: Date
    }

    /// The most recently modified orphaned draft, excluding the currently-active
    /// session. Returns nil when there is nothing to recover.
    static func latestRecoverable(
        excluding activeSessionId: String?,
        baseDirectory: URL? = nil
    ) -> RecoverableDraft? {
        coordinator.waitForPendingOperations()
        guard let dir = directory(create: false, baseDirectory: baseDirectory),
              let items = try? FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [
                    .contentModificationDateKey,
                    .fileSizeKey,
                    .isRegularFileKey,
                    .isSymbolicLinkKey,
                ],
                options: [.skipsHiddenFiles]
              ) else { return nil }

        var best: RecoverableDraft?
        for item in items where item.pathExtension == fileExtension {
            let sessionId = item.deletingPathExtension().lastPathComponent
            if let activeSessionId, sessionId == activeSessionId { continue }
            guard let values = try? item.resourceValues(forKeys: [
                .contentModificationDateKey,
                .fileSizeKey,
                .isRegularFileKey,
                .isSymbolicLinkKey,
            ]),
                  values.isRegularFile == true,
                  values.isSymbolicLink != true,
                  let fileSize = values.fileSize,
                  fileSize >= 0,
                  fileSize <= maxEncodedDraftBytes,
                  let data = try? Data(contentsOf: item, options: .mappedIfSafe),
                  data.count <= maxEncodedDraftBytes,
                  let text = String(data: data, encoding: .utf8),
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            let modifiedAt = values.contentModificationDate ?? .distantPast
            if best == nil || modifiedAt > best!.modifiedAt {
                best = RecoverableDraft(sessionId: sessionId, transcript: text, modifiedAt: modifiedAt)
            }
        }
        return best
    }
}
