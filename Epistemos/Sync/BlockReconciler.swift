import Foundation
import SwiftData

// MARK: - BlockReconciler
// Keeps SDBlock entities in sync with the markdown text edited in NSTextView.
// Runs on the existing 5-second debounce timer (same cadence as body persistence).
//
// Algorithm:
//   1. Parse the current markdown into [ParsedBlock] via BlockParser.
//   2. Fetch existing SDBlock entities for this page, sorted by order.
//   3. Diff: match parsed blocks to existing blocks by content similarity (Jaccard).
//      - Unchanged: content matches an existing block — keep UUID (stable references).
//      - Modified: content similar (Jaccard > 0.4) — update content/depth/order, keep UUID.
//      - Inserted: no matching existing block — create new SDBlock with fresh UUID.
//      - Deleted: existing block has no match — delete the SDBlock.
//
// Performance: O(n × m) worst case, practically O(n) for typical sequential edits.
// For a 200-block note, reconciliation takes under 1ms.

@MainActor
enum BlockReconciler {

    struct ReconcileResult {
        let created: Int
        let updated: Int
        let deleted: Int
        let unchanged: Int
    }

    /// Reconcile markdown text with existing SDBlock entities.
    /// Call from ProseEditorView.debouncedSave() after writing body to disk.
    @discardableResult
    static func reconcile(
        pageId: String,
        markdown: String,
        context: ModelContext
    ) -> ReconcileResult {
        let parsed = BlockParser.parse(markdown)

        // Fetch existing blocks for this page
        let descriptor = FetchDescriptor<SDBlock>(
            predicate: #Predicate<SDBlock> { $0.pageId == pageId },
            sortBy: [SortDescriptor(\SDBlock.order)]
        )
        let existing = (try? context.fetch(descriptor)) ?? []

        // Build parent chain: for each parsed block at depth > 0, find its parent
        // (the closest preceding block at depth - 1).
        let parentIds = computeParentIds(parsed: parsed)

        // Match parsed blocks to existing blocks using content similarity.
        // Two-pass bipartite matching: collect all candidate pairs above threshold,
        // sort by score descending, then greedily assign best matches first.
        // This prevents a low-scoring early match from stealing a high-scoring later one,
        // which would break block reference UUID stability.
        var candidates: [(parsedIdx: Int, existingIdx: Int, score: Double)] = []
        let threshold = 0.4 // Minimum Jaccard threshold (same as LineDiff)

        for (pi, parsedBlock) in parsed.enumerated() {
            for (ei, existingBlock) in existing.enumerated() {
                let score = jaccardSimilarity(parsedBlock.content, existingBlock.content)
                if score > threshold {
                    candidates.append((pi, ei, score))
                }
            }
        }

        // Sort by score descending — best matches assigned first.
        candidates.sort {
            if $0.score != $1.score { return $0.score > $1.score }
            return abs($0.parsedIdx - $0.existingIdx) < abs($1.parsedIdx - $1.existingIdx)
        }

        var usedParsed = Set<Int>()
        var usedExisting = Set<Int>()
        var matches: [(parsedIdx: Int, existingIdx: Int?)] = Array(
            repeating: (0, nil), count: parsed.count
        )
        for i in parsed.indices { matches[i] = (i, nil) }

        for candidate in candidates {
            guard !usedParsed.contains(candidate.parsedIdx),
                  !usedExisting.contains(candidate.existingIdx) else { continue }
            usedParsed.insert(candidate.parsedIdx)
            usedExisting.insert(candidate.existingIdx)
            matches[candidate.parsedIdx] = (candidate.parsedIdx, candidate.existingIdx)
        }

        // Apply changes
        var created = 0
        var updated = 0
        var unchanged = 0

        // Map from parsed index → SDBlock reference (for parent resolution in second pass)
        var indexToBlock: [Int: SDBlock] = [:]

        for (parsedIdx, existingIdx) in matches {
            let parsedBlock = parsed[parsedIdx]
            let blockOrder = parsedBlock.order * 1000

            if let ei = existingIdx {
                let block = existing[ei]
                indexToBlock[parsedIdx] = block

                // Check if anything changed
                if block.content == parsedBlock.content
                    && block.depth == parsedBlock.depth
                    && block.order == blockOrder {
                    unchanged += 1
                } else {
                    block.content = parsedBlock.content
                    block.depth = parsedBlock.depth
                    block.order = blockOrder
                    block.updatedAt = .now
                    updated += 1
                }
            } else {
                // Create new block — keep direct reference (no re-fetch needed)
                let block = SDBlock(
                    pageId: pageId,
                    content: parsedBlock.content,
                    depth: parsedBlock.depth,
                    order: blockOrder
                )
                context.insert(block)
                indexToBlock[parsedIdx] = block
                created += 1
            }
        }

        // Set parent IDs (second pass — uses direct references, no fetching)
        for (parsedIdx, _) in matches {
            let parentParsedIdx = parentIds[parsedIdx]
            let parentBlockId = parentParsedIdx.flatMap { indexToBlock[$0]?.id }

            if let block = indexToBlock[parsedIdx], block.parentBlockId != parentBlockId {
                block.parentBlockId = parentBlockId
            }
        }

        // Delete unmatched existing blocks
        let deletedBlocks = existing.enumerated()
            .filter { !usedExisting.contains($0.offset) }
            .map(\.element)
        for block in deletedBlocks {
            context.delete(block)
        }

        // Save
        try? context.save()

        return ReconcileResult(
            created: created,
            updated: updated,
            deleted: deletedBlocks.count,
            unchanged: unchanged
        )
    }

    /// Initial population: create SDBlock entities from markdown for a page that has none.
    /// Called lazily on first page open (not during app startup).
    static func initialPopulate(
        pageId: String,
        markdown: String,
        context: ModelContext
    ) {
        let parsed = BlockParser.parse(markdown)
        guard !parsed.isEmpty else { return }

        let parentIds = computeParentIds(parsed: parsed)
        var indexToBlock: [Int: SDBlock] = [:]

        for (i, p) in parsed.enumerated() {
            let block = SDBlock(
                pageId: pageId,
                content: p.content,
                depth: p.depth,
                order: p.order * 1000
            )
            context.insert(block)
            indexToBlock[i] = block
        }

        // Set parent IDs using direct references (no re-fetch)
        for (i, _) in parsed.enumerated() {
            if let parentIdx = parentIds[i],
               let parentBlock = indexToBlock[parentIdx],
               let block = indexToBlock[i] {
                block.parentBlockId = parentBlock.id
            }
        }

        try? context.save()
    }

    // MARK: - Private

    /// Compute parent indices for each parsed block.
    /// For block at depth D, parent is the closest preceding block at depth D-1.
    private static func computeParentIds(parsed: [BlockParser.ParsedBlock]) -> [Int?] {
        var parents: [Int?] = Array(repeating: nil, count: parsed.count)
        // Stack of (depth, parsedIndex) — tracks the most recent block at each depth.
        var depthStack: [(depth: Int, index: Int)] = []

        for (i, block) in parsed.enumerated() {
            // Pop stack entries at depth >= current (they can't be parents)
            while let last = depthStack.last, last.depth >= block.depth {
                depthStack.removeLast()
            }

            // Parent is top of stack (closest preceding block at depth - 1)
            if block.depth > 0, let parent = depthStack.last {
                parents[i] = parent.index
            }

            depthStack.append((block.depth, i))
        }

        return parents
    }

    /// Jaccard similarity between two strings (word-level).
    /// Same algorithm as LineDiff.jaccardSimilarity.
    private static func jaccardSimilarity(_ a: String, _ b: String) -> Double {
        let aWords = Set(a.split(omittingEmptySubsequences: true, whereSeparator: \.isWhitespace))
        let bWords = Set(b.split(omittingEmptySubsequences: true, whereSeparator: \.isWhitespace))
        guard !aWords.isEmpty || !bWords.isEmpty else { return 1.0 }
        let intersection = aWords.intersection(bWords).count
        let union = aWords.union(bWords).count
        return Double(intersection) / Double(union)
    }
}
