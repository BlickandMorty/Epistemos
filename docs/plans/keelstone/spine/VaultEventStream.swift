//
//  VaultEventStream.swift
//  Epistemos — KEELSTONE spine
//
//  The wide-area change-detection spine. FSEvents — NOT NSFilePresenter — is
//  the primary external-change source, because FSEvents observes ALL filesystem
//  mutations (raw POSIX writes, vim, VS Code, Syncthing, git checkouts) while
//  NSFilePresenter only hears changes made THROUGH NSFileCoordinator. A vault
//  co-edited by non-coordinating tools is the normal case, so the spine has to
//  see everything.
//
//  Flags:
//    kFSEventStreamCreateFlagFileEvents      — per-file granularity, not just dir
//    kFSEventStreamCreateFlagUseExtendedData — events arrive as dictionaries
//                                              carrying path + file ID (inode)
//    kFSEventStreamCreateFlagWatchRoot       — RootChanged if the vault root is
//                                              moved/renamed/deleted
//    kFSEventStreamCreateFlagNoDefer         — deliver the first batch promptly
//
//  KEELSTONE-REVIEW (2026-07-06) — fixes applied to the original skeleton:
//   1. `kFSEventStreamEventExtendedDataKeyInode` DOES NOT EXIST. The real
//      extended-data keys are kFSEventStreamEventExtendedDataPathKey ("path")
//      and kFSEventStreamEventExtendedFileIDKey ("fileID"). Fixed, with
//      `as String` bridging for NSDictionary subscripting.
//   2. File ID arrives as NSNumber — read via uint64Value.
//  INTEGRATION: VaultSyncService.swift already runs an FSEvents pipeline
//  (startWatching :2397 + flag handling ~:266). This class REPLACES that
//  path when wired — never run two streams over the same vault.
//
//  Truth-vs-advisory: FSEvents is a TRIGGER for reconciliation, not a reliable
//  per-file transcript. It coalesces, can collapse parent+child into one event,
//  and can DROP events — in which case it sets MustScanSubDirs and you must
//  rescan. RootChanged, KernelDropped, UserDropped, and Unmount all escalate to
//  a scan. Never treat an FSEvents payload as the authoritative delta.
//
//  Per-disk stream + persisted last event ID = replay-after-relaunch: catch
//  changes that happened while Epistemos wasn't running.
//
//  Sandbox: in a MAS build, events are delivered only for paths reachable
//  through the granted (security-scoped) vault subtree. That's fine — the whole
//  vault is exactly that subtree.
//

import Foundation
import CoreServices

public struct VaultFSEvent: Sendable {
    public enum Kind: Sendable {
        case changed          // created / modified / attribute change — classify by rescan
        case renamed          // matched via inode across the batch, or bare rename flag
        case removed
        case mustRescan(URL)  // MustScanSubDirs / dropped — rescan this subtree
        case rootChanged      // vault root moved/renamed/deleted — full reconcile + remount check
        case unmounted        // volume went away — freeze, don't touch disk
    }
    public let kind: Kind
    public let url: URL
    public let inode: UInt64?
    public let eventID: FSEventStreamEventId
}

public protocol VaultEventSink: AnyObject, Sendable {
    /// Called off the main thread with a coalesced batch. Handler MUST be
    /// lightweight — hand straight to the reconcile actor.
    func receive(_ batch: [VaultFSEvent], lastEventID: FSEventStreamEventId)
}

public final class VaultEventStream: @unchecked Sendable {

    private var stream: FSEventStreamRef?
    private let queue = DispatchQueue(label: "com.epistemos.vault.fsevents", qos: .utility)
    private weak var sink: VaultEventSink?

    /// Ignore vendor sync-metadata churn so a Dropbox/Syncthing housekeeping
    /// pass doesn't spin the reconciler. Extend as needed.
    private let ignoredComponents: Set<String> = [
        ".stversions", ".stfolder", ".sync", ".dropbox.cache",
        ".git", ".obsidian", ".trash", ".DS_Store", ".epcache"
    ]

    public init(sink: VaultEventSink) {
        self.sink = sink
    }

    /// Start (or resume) watching. Pass the last persisted event ID to replay
    /// changes since the app was last running; pass nil for a fresh "since now".
    public func start(vaultRoot: URL, resumeAfter lastEventID: FSEventStreamEventId?) {
        guard stream == nil else { return }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil, release: nil, copyDescription: nil
        )

        let paths = [vaultRoot.path] as CFArray
        let since = lastEventID ?? FSEventStreamEventId(kFSEventStreamEventIdSinceNow)
        let latency: CFTimeInterval = 0.15   // coalescing window; tune per plan §12.7

        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents      |
            kFSEventStreamCreateFlagUseExtendedData |
            kFSEventStreamCreateFlagWatchRoot       |
            kFSEventStreamCreateFlagNoDefer
        )

        let callback: FSEventStreamCallback = { _, info, count, rawPaths, rawFlags, ids in
            let me = Unmanaged<VaultEventStream>.fromOpaque(info!).takeUnretainedValue()
            me.handle(count: count, rawPaths: rawPaths, flags: rawFlags, ids: ids)
        }

        guard let created = FSEventStreamCreate(
            kCFAllocatorDefault, callback, &context,
            paths, since, latency, flags
        ) else { return }

        FSEventStreamSetDispatchQueue(created, queue)
        FSEventStreamStart(created)
        stream = created
    }

    /// Real teardown. Must run on disconnect, permission loss, and unmount.
    public func stop() {
        guard let s = stream else { return }
        FSEventStreamStop(s)
        FSEventStreamInvalidate(s)
        FSEventStreamRelease(s)
        stream = nil
    }

    deinit { stop() }

    private func handle(
        count: Int,
        rawPaths: UnsafeMutableRawPointer,
        flags: UnsafePointer<FSEventStreamEventFlags>,
        ids: UnsafePointer<FSEventStreamEventId>
    ) {
        // UseExtendedData => paths arrive as an array of dictionaries.
        guard let dicts = unsafeBitCast(rawPaths, to: NSArray.self) as? [NSDictionary] else {
            return
        }

        var batch: [VaultFSEvent] = []
        var lastID: FSEventStreamEventId = 0

        for i in 0..<count {
            let dict = dicts[i]
            // KEELSTONE-REVIEW: real extended-data keys — PathKey + FileIDKey
            // (there is no "...DataKeyInode" constant). FileID is the inode.
            guard let path = dict[kFSEventStreamEventExtendedDataPathKey as String] as? String
            else { continue }
            let inode = (dict[kFSEventStreamEventExtendedFileIDKey as String] as? NSNumber)?
                .uint64Value
            let f = flags[i]
            let id = ids[i]
            lastID = id
            let url = URL(fileURLWithPath: path)

            if url.pathComponents.contains(where: { ignoredComponents.contains($0) }) {
                continue
            }

            // Escalation flags take priority — these mean "you can't trust the
            // fine-grained detail, go rescan."
            if f & FSEventStreamEventFlags(kFSEventStreamEventFlagMustScanSubDirs) != 0
                || f & FSEventStreamEventFlags(kFSEventStreamEventFlagKernelDropped) != 0
                || f & FSEventStreamEventFlags(kFSEventStreamEventFlagUserDropped) != 0 {
                batch.append(.init(kind: .mustRescan(url), url: url, inode: inode, eventID: id))
                continue
            }
            if f & FSEventStreamEventFlags(kFSEventStreamEventFlagRootChanged) != 0 {
                batch.append(.init(kind: .rootChanged, url: url, inode: inode, eventID: id))
                continue
            }
            if f & FSEventStreamEventFlags(kFSEventStreamEventFlagUnmount) != 0 {
                batch.append(.init(kind: .unmounted, url: url, inode: inode, eventID: id))
                continue
            }

            let renamed = f & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRenamed) != 0
            let removed = f & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved) != 0

            let kind: VaultFSEvent.Kind =
                renamed ? .renamed : (removed ? .removed : .changed)
            batch.append(.init(kind: kind, url: url, inode: inode, eventID: id))
        }

        guard !batch.isEmpty else { return }
        sink?.receive(batch, lastEventID: lastID)
    }
}
