import AppKit
import os

// MARK: - PageStoragePool
// Static singleton storing per-page MarkdownTextStorage instances.
// Each page gets its own fully-styled storage that persists across tab switches.
// On revisit, the pre-styled storage is swapped in — zero styling work.
//
// Lifecycle:
//   First visit  → create MarkdownTextStorage, load + style content, store in pool
//   Revisit      → fetch existing storage from pool (instant, pre-styled)
//   Eviction     → LRU at 12 slots; evicted pages get fresh storage on next visit
//   Theme change → restyle active storage, evict all others (lazy invalidation)

@MainActor
final class PageStoragePool {
    static let shared = PageStoragePool()

    struct PageSlot {
        let storage: MarkdownTextStorage
        let undoManager: UndoManager
        var scrollY: CGFloat
        var selectionRange: NSRange
        var theme: EpistemosTheme
        var lastAccessedAt: Date
    }

    private var slots: [String: PageSlot] = [:]
    private let maxSlots = 12
    private var preWarmTask: Task<Void, Never>?

    private let log = Logger(subsystem: "com.epistemos", category: "StoragePool")

    private init() {}

    // MARK: - Get or Create

    /// Returns existing slot if cached and theme/font match, otherwise creates a new one.
    /// On first visit, the storage is loaded with progressive styling (same cost as today).
    /// On revisit, returns the pre-styled storage (zero styling work).
    func getOrCreate(
        pageId: String,
        bodyText: String,
        theme: EpistemosTheme
    ) -> PageSlot {
        if var existing = slots[pageId] {
            existing.storage.usesRenderedTableOverlays = true
            let contentChanged = existing.storage.string != bodyText
            let themeChanged = existing.theme != theme
            if themeChanged {
                existing.storage.isDark = theme.isDark
                existing.storage.theme = theme
                existing.theme = theme
            }
            if contentChanged {
                // Content differs — update storage in-place so pre-styled
                // line-level attributes (headings, lists) are preserved.
                let oldLen = existing.storage.length
                existing.storage.beginEditing()
                existing.storage.replaceCharacters(
                    in: NSRange(location: 0, length: oldLen), with: bodyText
                )
                existing.storage.endEditing()
                // Re-apply deferred inline styles for the full content.
                // Use storage.length (UTF-16) not bodyText.count (grapheme clusters).
                Self.chunkedInlineStyle(
                    storage: existing.storage, offset: 0, totalLength: existing.storage.length
                )
            } else if themeChanged {
                existing.storage.reapplyAllStyles()
            }
            existing.lastAccessedAt = .now
            slots[pageId] = existing
            if contentChanged {
                log.info("PageStoragePool: updated slot for \(pageId.prefix(8)) (\(bodyText.count) chars)")
            }
            return existing
        }

        // Create fresh storage
        let storage = MarkdownTextStorage()
        storage.isDark = theme.isDark
        storage.theme = theme
        storage.usesRenderedTableOverlays = true

        // Progressive styling: line-level first, inline deferred
        storage.skipInlineStyles = true
        let oldLen = storage.length
        storage.beginEditing()
        storage.replaceCharacters(in: NSRange(location: 0, length: oldLen), with: bodyText)
        storage.endEditing()
        storage.skipInlineStyles = false

        // Deferred inline styles — chunked across frames to avoid blocking scroll.
        // Each chunk styles ~5000 chars (~1ms). Visible content styles first frame,
        // rest fills in progressively. User never notices on typical documents.
        // Use storage.length (UTF-16 code units) — matches NSRange semantics used
        // inside chunkedInlineStyle, not bodyText.count (grapheme clusters).
        Self.chunkedInlineStyle(storage: storage, offset: 0, totalLength: storage.length)

        // Check DiskStyleCache for scroll position from previous session
        var scrollY: CGFloat = 0
        var selection = NSRange(location: 0, length: 0)
        if let diskCached = DiskStyleCache.shared.restore(
            pageId: pageId, currentBodyText: bodyText
        ) {
            scrollY = diskCached.scrollY
            selection = diskCached.selection
        }

        let slot = PageSlot(
            storage: storage,
            undoManager: UndoManager(),
            scrollY: scrollY,
            selectionRange: selection,
            theme: theme,
            lastAccessedAt: .now
        )
        slots[pageId] = slot
        evictIfNeeded()

        log.info("PageStoragePool: created slot for \(pageId.prefix(8)) (\(bodyText.count) chars)")
        return slot
    }

    // MARK: - Save State

    /// Updates scroll position and selection for a page in memory (cheap).
    /// Called continuously by scroll observer. Does NOT write to disk —
    /// disk persistence happens in dismantleNSView and explicit page-switch saves.
    func saveState(pageId: String, scrollY: CGFloat, selection: NSRange) {
        guard var slot = slots[pageId] else { return }
        slot.scrollY = scrollY
        slot.selectionRange = selection
        slot.lastAccessedAt = .now
        slots[pageId] = slot
    }

    /// Persists current scroll/selection state to disk for the given page.
    /// Called on page switch (updateNSView) and dismantleNSView only.
    func saveToDisk(pageId: String) {
        guard let slot = slots[pageId] else { return }
        DiskStyleCache.shared.save(
            pageId: pageId,
            bodyText: slot.storage.string,
            scrollY: slot.scrollY,
            selection: slot.selectionRange
        )
    }

    // MARK: - Theme Invalidation

    /// Evicts all cached storages EXCEPT the active page.
    /// Called when isDark changes (theme toggle).
    /// The active page's storage is restyled in-place by the Coordinator.
    func invalidateExcept(activePageId: String?) {
        let keysToRemove = slots.keys.filter { $0 != activePageId }
        for key in keysToRemove {
            slots.removeValue(forKey: key)
        }
        log.info("PageStoragePool: invalidated \(keysToRemove.count) slots (theme/font change)")
    }

    // MARK: - Pre-Warming

    /// Maximum pages to pre-warm per folder expansion.
    private static let maxPreWarmPerFolder = 6
    /// Maximum pages to pre-warm on app launch.
    private static let maxPreWarmOnLaunch = 3

    /// Pre-warms storage slots for a batch of pages, spreading work across frames.
    /// Already-cached pages are skipped. Work is scheduled as a cancellable task
    /// so repeated folder expands don't leave stale queued warmups behind.
    /// Maximum page body size (chars) for pre-warming. Pages larger than this
    /// are skipped — a 435K char page was being pre-warmed which is wasteful.
    private static let maxPreWarmBodySize = 50_000

    func preWarm(pages: [(id: String, body: String)], theme: EpistemosTheme) {
        preWarmTask?.cancel()

        // Filter to pages not already in the pool and skip oversized pages
        let uncached = pages.filter { slots[$0.id] == nil && $0.body.count <= Self.maxPreWarmBodySize }
        guard !uncached.isEmpty else { return }

        let count = min(uncached.count, Self.maxPreWarmPerFolder)
        log.info("PageStoragePool: pre-warming \(count) pages")

        let scheduledPages = Array(uncached.prefix(count))
        preWarmTask = Task(priority: .utility) { @MainActor [weak self] in
            guard let self else { return }
            defer { self.preWarmTask = nil }

            for (index, page) in scheduledPages.enumerated() {
                if index > 0 {
                    try? await Task.sleep(for: .milliseconds(16))
                }
                guard !Task.isCancelled else { return }
                guard self.slots[page.id] == nil else { continue }
                _ = self.getOrCreate(pageId: page.id, bodyText: page.body, theme: theme)
            }
        }
    }

    /// Pre-warms the N most recently updated pages. Called once at app launch.
    func preWarmRecent(pages: [(id: String, body: String)], theme: EpistemosTheme) {
        let capped = Array(pages.prefix(Self.maxPreWarmOnLaunch))
        preWarm(pages: capped, theme: theme)
    }

    // MARK: - Removal

    /// Read the current body text from a pooled storage (if cached).
    func bodyText(for pageId: String) -> String? {
        slots[pageId]?.storage.string
    }

    func remove(pageId: String) { slots.removeValue(forKey: pageId) }

    func removeAll() {
        preWarmTask?.cancel()
        preWarmTask = nil
        slots.removeAll()
    }

    // MARK: - Eviction

    private func evictIfNeeded() {
        guard slots.count > maxSlots else { return }
        let sorted = slots.sorted { $0.value.lastAccessedAt < $1.value.lastAccessedAt }
        let toEvict = sorted.prefix(slots.count - maxSlots)
        for (key, _) in toEvict {
            slots.removeValue(forKey: key)
        }
    }

    // MARK: - Chunked Inline Styling

    /// Applies inline styles (bold, italic, code, links, etc.) in ~5000-char
    /// chunks across frames. First chunk runs immediately for visible content,
    /// remaining chunks queue on main async so scrolling isn't blocked.
    private static let inlineChunkSize = 5000

    private static func chunkedInlineStyle(
        storage: MarkdownTextStorage, offset: Int, totalLength: Int
    ) {
        guard offset < totalLength, storage.length > 0 else { return }
        DispatchQueue.main.async {
            guard storage.length > 0 else { return }
            let end = min(offset + inlineChunkSize, storage.length)
            let range = NSRange(location: offset, length: end - offset)
            storage.beginEditing()
            storage.applyInlineStyles(fullRange: range)
            storage.edited(.editedAttributes, range: range, changeInLength: 0)
            storage.endEditing()
            // Schedule next chunk
            if end < totalLength {
                chunkedInlineStyle(storage: storage, offset: end, totalLength: totalLength)
            }
        }
    }
}
