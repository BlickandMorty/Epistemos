//
//  VaultReconciler.swift
//  Epistemos — KEELSTONE spine
//
//  The deterministic reconciliation state machine. FS events are advisory
//  triggers; THIS is where truth is re-derived. The invariant that the entire
//  release gate tests against:
//
//    incremental reconcile of a change set  ==  fresh rebuild from disk
//
//  If those two ever diverge, the index has silently become authoritative and
//  the thesis is broken. Convergence-equality is the witnessable done-bar.
//
//  This is a Swift actor. It never touches @MainActor. FS events land here off
//  the FSEvents dispatch queue; UI reads a published snapshot elsewhere.
//
//  Manifest row per file: { relativePath, inode, size, mtime, contentHash,
//  tombstone }. The cheap discriminator is size+mtime; hash only when those move
//  or when disambiguating content-vs-metadata. At 100k notes you cannot hash
//  every file on every event — quick-field-first is the scale strategy.
//
//  KEELSTONE-REVIEW (2026-07-06) — fixes applied to the original skeleton:
//   1. `while let … where …` is not valid Swift (removed in Swift 3) — rewritten.
//   2. `materializer.state(of:)` is an actor call — now `await`ed.
//   3. hash() used String.hashValue, which is RANDOMIZED PER LAUNCH — persisted
//      manifest hashes would never match across launches and every note would
//      re-index on every start. Replaced with real CryptoKit SHA-256.
//   4. Checkpoint key is per-vault (multi-vault isolation, plan §5).
//   5. The real vault indexes more than *.md (chats/**/*.json via
//      ShadowVaultBootstrapper) — `isIndexedFile` is the single predicate to
//      align with the repo's real indexed set.
//  INTEGRATION: the repo ALREADY has an FSEvents pipeline + reconcile path in
//  Epistemos/Sync/VaultSyncService.swift (startWatching :2397) + VaultIndexActor.
//  This actor REPLACES/refactors that path — never runs beside it. One stream,
//  one reconciler per vault.
//

import Foundation
import CryptoKit

public struct ManifestEntry: Sendable, Equatable {
    public var relativePath: String
    public var inode: UInt64?
    public var size: Int64
    public var mtime: Double
    public var contentHash: String?     // filled lazily, only when needed
    public var tombstone: Bool
}

public protocol IndexBackend: Sendable {
    func upsert(path: String, content: String, mtime: Double, hash: String) async throws
    func tombstone(path: String) async throws
    func rename(from: String, to: String) async throws
    func loadManifest() async throws -> [String: ManifestEntry]
    func fullRebuild(fromRoot: URL) async throws       // quarantine + rebuild
}

public protocol ActiveEditorBridge: Sendable {
    /// Relative path of the note currently open, if any.
    func activeRelativePath() async -> String?
    /// Base content-hash the editor opened against.
    func baseHash(for path: String) async -> String?
    /// True if the editor buffer diverges from what was loaded.
    func isDirty(for path: String) async -> Bool
    /// Editor is clean → safe silent reload from disk.
    func reload(path: String, diskContent: String) async
    /// Editor is dirty AND disk moved → hand to conflict flow (never clobber).
    func enterConflict(path: String, diskContent: String, baseHash: String?) async
}

public actor VaultReconciler: VaultEventSink {

    private let vaultRoot: URL
    private let vaultID: String            // KEELSTONE-REVIEW: per-vault isolation
    private let index: IndexBackend
    private let editor: ActiveEditorBridge
    private let materializer: iCloudMaterializer
    private var manifest: [String: ManifestEntry] = [:]
    private var lastEventID: FSEventStreamEventId = 0

    // Coalescing buffer — a 1k–100k sync pull arrives as many batches; we debounce.
    private var pending: [VaultFSEvent] = []
    private var flushTask: Task<Void, Never>?

    public init(
        vaultRoot: URL,
        vaultID: String,
        index: IndexBackend,
        editor: ActiveEditorBridge,
        materializer: iCloudMaterializer
    ) {
        self.vaultRoot = vaultRoot
        self.vaultID = vaultID
        self.index = index
        self.editor = editor
        self.materializer = materializer
    }

    public func primeManifest() async throws {
        manifest = try await index.loadManifest()
    }

    // MARK: VaultEventSink (called off the FSEvents queue)

    nonisolated public func receive(_ batch: [VaultFSEvent], lastEventID: FSEventStreamEventId) {
        Task { await self.ingest(batch, lastEventID: lastEventID) }
    }

    private func ingest(_ batch: [VaultFSEvent], lastEventID: FSEventStreamEventId) {
        pending.append(contentsOf: batch)
        self.lastEventID = lastEventID
        scheduleFlush()
    }

    private func scheduleFlush() {
        flushTask?.cancel()
        flushTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            await self?.flush()
        }
    }

    // MARK: State machine

    private func flush() async {
        let events = pending
        pending.removeAll()

        // Escalation short-circuits: if anything says "rescan," do the safe thing.
        if events.contains(where: { if case .mustRescan = $0.kind { return true }; return false }) {
            await rescanSubtrees(events)
        }
        if events.contains(where: { if case .rootChanged = $0.kind { return true }; return false }) {
            await handleRootChanged()
            return
        }
        if events.contains(where: { if case .unmounted = $0.kind { return true }; return false }) {
            await handleUnmount()
            return
        }

        for event in events {
            switch event.kind {
            case .mustRescan, .rootChanged, .unmounted:
                continue // handled above
            case .removed:
                await classifyRemoval(event)
            case .renamed:
                await classifyRename(event)
            case .changed:
                await classifyChange(event)
            }
        }
        persistCheckpoint()
    }

    /// KEELSTONE-REVIEW: align with the repo's REAL indexed set — the vault
    /// indexes notes/**/*.md AND chats/**/*.json (ShadowVaultBootstrapper).
    /// One predicate, shared with the rescan path.
    private func isIndexedFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ext == "md" || ext == "json"
    }

    private func rel(_ url: URL) -> String {
        // KEELSTONE-REVIEW: standardize both sides so /private symlinks and
        // trailing slashes can't produce mismatched keys.
        let root = vaultRoot.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(root + "/") else { return path }
        return String(path.dropFirst(root.count + 1))
    }

    /// The quick discriminator: has this file really changed, or is it a
    /// false-positive attribute touch? Returns nil when unreadable.
    private func liveEntry(for url: URL) -> ManifestEntry? {
        let keys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey]
        guard let v = try? url.resourceValues(forKeys: keys) else { return nil }
        let size = Int64(v.fileSize ?? 0)
        let mtime = v.contentModificationDate?.timeIntervalSince1970 ?? 0
        return ManifestEntry(
            relativePath: rel(url), inode: nil, size: size,
            mtime: mtime, contentHash: nil, tombstone: false
        )
    }

    private func classifyChange(_ event: VaultFSEvent) async {
        let url = event.url
        guard isIndexedFile(url) else { return }

        // Materialize if it's an undownloaded iCloud placeholder — async, no poll.
        // KEELSTONE-REVIEW: `await` added (actor call). Correctness note: even if
        // whenLocal times out, hydration completion will fire another FSEvents
        // change and we retry — whenLocal is a latency optimization, not truth.
        switch await materializer.state(of: url) {
        case .downloading:
            try? await materializer.whenLocal(url)
        case .failed:
            return // leave stale; a later event or rescan retries
        case .notUbiquitous, .alreadyLocal:
            break
        }

        guard let live = liveEntry(for: url) else { return }
        let path = live.relativePath
        let prior = manifest[path]

        // Quick reject: size+mtime unchanged → attribute touch, no-op.
        if let prior, prior.size == live.size, prior.mtime == live.mtime, !prior.tombstone {
            return
        }

        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        let hash = Self.hash(content)
        if let prior, prior.contentHash == hash { // content identical despite mtime bump
            manifest[path] = live.with(hash: hash)
            return
        }

        // Open-editor conflict branch.
        if await editor.activeRelativePath() == path {
            if await editor.isDirty(for: path) {
                let base = await editor.baseHash(for: path)
                await editor.enterConflict(path: path, diskContent: content, baseHash: base)
                return // never clobber a dirty buffer
            } else {
                await editor.reload(path: path, diskContent: content)
            }
        }

        try? await index.upsert(path: path, content: content, mtime: live.mtime, hash: hash)
        manifest[path] = live.with(hash: hash)
    }

    private func classifyRename(_ event: VaultFSEvent) async {
        // Correlate via inode across the batch when available; if the inode
        // maps to a known entry at a new path, it's a move — don't re-embed.
        guard let inode = event.inode else { await classifyChange(event); return }
        if let existing = manifest.first(where: { $0.value.inode == inode })?.value,
           FileManager.default.fileExists(atPath: event.url.path) {
            let newPath = rel(event.url)
            if existing.relativePath != newPath {
                try? await index.rename(from: existing.relativePath, to: newPath)
                manifest[newPath] = existing.with(path: newPath)
                manifest[existing.relativePath] = nil
                return
            }
        }
        await classifyChange(event)
    }

    private func classifyRemoval(_ event: VaultFSEvent) async {
        let path = rel(event.url)
        // Guard against iCloud dehydration masquerading as deletion.
        if FileManager.default.fileExists(atPath: event.url.path) { return }
        try? await index.tombstone(path: path)
        manifest[path]?.tombstone = true
    }

    private func rescanSubtrees(_ events: [VaultFSEvent]) async {
        let roots: [URL] = events.compactMap {
            if case .mustRescan(let u) = $0.kind { return u }; return nil
        }
        for root in roots {
            let e = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
            )
            // KEELSTONE-REVIEW: `while let … where …` is invalid Swift — rewritten.
            while let obj = e?.nextObject() as? URL {
                guard isIndexedFile(obj) else { continue }
                await classifyChange(.init(kind: .changed, url: obj, inode: nil, eventID: 0))
            }
        }
    }

    private func handleRootChanged() async {
        // Root moved/renamed/deleted. Re-verify the mount, then converge fully.
        try? await index.fullRebuild(fromRoot: vaultRoot)
        manifest = (try? await index.loadManifest()) ?? [:]
    }

    private func handleUnmount() async {
        // Volume gone. Freeze. Editor buffers stay dirty in memory. Do NOT
        // interpret this as deletion. Resume only after remount + reconcile.
        // (Lifecycle machine flips vault state to .volumeUnavailable.)
    }

    private func persistCheckpoint() {
        // KEELSTONE-REVIEW: per-vault key — multi-vault isolation (plan §5).
        UserDefaults.standard.set(
            String(lastEventID),
            forKey: "keelstone.lastEventID.\(vaultID)"
        )
    }

    /// KEELSTONE-REVIEW: real content hash. The original used String.hashValue,
    /// which is seeded per-process — persisted values are garbage across
    /// launches. SHA-256 hex is stable, fast, and what the manifest stores.
    static func hash(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

private extension ManifestEntry {
    func with(hash: String) -> ManifestEntry { var c = self; c.contentHash = hash; return c }
    func with(path: String) -> ManifestEntry { var c = self; c.relativePath = path; return c }
}
