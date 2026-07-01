import Foundation
import SwiftData
import os

extension AppBootstrap {

    private nonisolated static let prewarmLog = Logger(
        subsystem: "com.epistemos",
        category: "AppBootstrap.Prewarm"
    )

    nonisolated enum PrewarmDiagnostics {
        static let maxLogMessageCharacters = 240
        private static let maxDomainCharacters = 80

        static func logMessage(for error: Error, fallback: String) -> String {
            let nsError = error as NSError
            return logMessage(
                "\(fallback) (domain=\(safeDomain(nsError.domain)) code=\(nsError.code))",
                fallback: fallback
            )
        }

        static func logMessage(_ message: String, fallback: String = "Prewarm failed") -> String {
            let bounded = String(message.prefix(maxLogMessageCharacters + 32))
            let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return fallback }
            guard trimmed.count > maxLogMessageCharacters else { return trimmed }

            let suffix = "..."
            let end = trimmed.index(
                trimmed.startIndex,
                offsetBy: max(0, maxLogMessageCharacters - suffix.count)
            )
            return String(trimmed[..<end]) + suffix
        }

        private static func safeDomain(_ domain: String) -> String {
            let bounded = String(domain.prefix(maxDomainCharacters + 32))
            let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return "Error" }
            let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
            guard trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
                return "Error"
            }
            guard trimmed.count <= maxDomainCharacters else {
                let end = trimmed.index(trimmed.startIndex, offsetBy: maxDomainCharacters)
                return String(trimmed[..<end])
            }
            return trimmed
        }
    }

    /// Pre-parses BlockMirror state for the K most-recently-modified pages so
    /// the BlockMirror first-parse cost (~10-200ms per note) moves from
    /// click-time to launch-time. Addresses ISSUE-2026-05-12-008 cause #1.
    ///
    /// Body acquisition uses the canonical R.3 fallback chain via
    /// `SDPage.loadBodyAsyncFromPrimitives` so disk-only pages (the
    /// production majority, since `SDPage.body` is cleared after
    /// `saveBody()`) are prewarmed just like inline-body pages. The fallback
    /// chain is (1) managed-body sidecar → (2) R.3 gateway resolve+read →
    /// (3) inline body → (4) raw vault file at `filePath`.
    ///
    /// Each page's `(id, filePath, body)` is snapshotted into Sendable
    /// primitives before any `await`, so the per-page suspend can't be
    /// invalidated by SwiftData object lifecycle.
    ///
    /// Returns the number of pages whose blocks were synced. Safe to call
    /// from any actor.
    @discardableResult
    nonisolated static func prewarmRecentBlockMirrors(
        modelContainer: ModelContainer,
        limit: Int = 5
    ) async -> Int {
        let modelContext = ModelContext(modelContainer)
        let descriptor = SDPage.recentDescriptor(limit: limit)
        let pages: [SDPage]
        do {
            pages = try modelContext.fetch(descriptor)
        } catch {
            let message = PrewarmDiagnostics.logMessage(
                for: error,
                fallback: "prewarmRecentBlockMirrors: fetch failed"
            )
            prewarmLog.error(
                "\(message, privacy: .public)"
            )
            return 0
        }

        let snapshots: [(id: String, filePath: String?, body: String)] = pages.map {
            (id: $0.id, filePath: $0.filePath, body: $0.body)
        }

        var synced = 0
        var skippedEmpty = 0
        for snap in snapshots {
            let body = await SDPage.loadBodyAsyncFromPrimitives(
                pageId: snap.id,
                filePath: snap.filePath,
                inlineBody: snap.body
            )
            guard !body.isEmpty else {
                skippedEmpty += 1
                continue
            }
            BlockMirror.sync(
                pageId: snap.id,
                body: body,
                modelContext: modelContext
            )
            synced += 1
        }

        if synced > 0 {
            do {
                try modelContext.save()
            } catch {
                let message = PrewarmDiagnostics.logMessage(
                    for: error,
                    fallback: "prewarmRecentBlockMirrors: save failed"
                )
                prewarmLog.error(
                    "\(message, privacy: .public)"
                )
            }
        }

        if synced > 0 || skippedEmpty > 0 {
            prewarmLog.info(
                "prewarmRecentBlockMirrors: synced=\(synced, privacy: .public) skipped_empty=\(skippedEmpty, privacy: .public) of \(snapshots.count, privacy: .public) recent pages"
            )
        }
        return synced
    }
}
