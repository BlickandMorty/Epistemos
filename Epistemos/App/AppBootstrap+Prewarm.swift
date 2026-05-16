import Foundation
import SwiftData
import os

extension AppBootstrap {

    private nonisolated static let prewarmLog = Logger(
        subsystem: "com.epistemos",
        category: "AppBootstrap.Prewarm"
    )

    /// Pre-parses BlockMirror state for the K most-recently-modified pages so
    /// the BlockMirror first-parse cost (~10-200ms per note) moves from
    /// click-time to launch-time. Addresses ISSUE-2026-05-12-008 cause #1.
    ///
    /// Iter 2 (T-A) scope: pages whose inline `body` field still holds the
    /// markdown source. In production, `body` is cleared after `saveBody()`
    /// (the canonical store is the on-disk `filePath`) so this pass is a
    /// no-op for most production pages. Iter 3 must extend to the disk-load
    /// path via `SDPage.loadBodyAsyncFromPrimitives` to actually amortize
    /// the cost in production. The structure (descriptor + log fields) is
    /// stable for that extension.
    ///
    /// Returns the number of pages whose blocks were synced. Safe to call
    /// from any actor.
    @discardableResult
    nonisolated static func prewarmRecentBlockMirrors(
        modelContext: ModelContext,
        limit: Int = 5
    ) -> Int {
        let descriptor = SDPage.recentDescriptor(limit: limit)
        let pages: [SDPage]
        do {
            pages = try modelContext.fetch(descriptor)
        } catch {
            prewarmLog.error(
                "prewarmRecentBlockMirrors: fetch failed — \(error.localizedDescription, privacy: .public)"
            )
            return 0
        }

        var synced = 0
        var skippedDiskOnly = 0
        for page in pages {
            let body = page.body
            guard !body.isEmpty else {
                skippedDiskOnly += 1
                continue
            }
            BlockMirror.sync(
                pageId: page.id,
                body: body,
                modelContext: modelContext
            )
            synced += 1
        }

        if synced > 0 || skippedDiskOnly > 0 {
            prewarmLog.info(
                "prewarmRecentBlockMirrors: synced=\(synced, privacy: .public) skipped_disk_only=\(skippedDiskOnly, privacy: .public) of \(pages.count, privacy: .public) recent pages"
            )
        }
        return synced
    }
}
