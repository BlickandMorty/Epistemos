import Foundation

// MARK: - LineDiff
// Pure diff engine — no UI, no SwiftData dependency.
// Splits two strings into lines, computes insertions/removals/modifications,
// and produces word-level highlights for modified lines.
// Uses Swift's CollectionDifference (Myers algorithm) for both line and word diffs.

enum DiffLineKind: Equatable {
    case unchanged(String)
    case added(String)
    case removed(String)
    case modified(old: String, new: String)
}

struct DiffStats: Equatable {
    let added: Int
    let removed: Int
    let modified: Int
}

struct LineDiff: Equatable {
    let lines: [DiffLineKind]
    let stats: DiffStats

    static func compute(old: String, new: String) -> LineDiff {
        let oldLines = old.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let newLines = new.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        let changes = newLines.difference(from: oldLines)

        var removals: [(offset: Int, element: String)] = []
        var insertions: [(offset: Int, element: String)] = []

        for change in changes {
            switch change {
            case .remove(let offset, let element, _):
                removals.append((offset, element))
            case .insert(let offset, let element, _):
                insertions.append((offset, element))
            }
        }

        // Pair similar removals + insertions as modifications (Jaccard > 0.4)
        var usedInsertions: Set<Int> = []
        var pairedRemovals: [Int: Int] = [:]

        for removal in removals {
            var bestIdx: Int?
            var bestScore = 0.4

            for (idx, ins) in insertions.enumerated() where !usedInsertions.contains(idx) {
                let score = jaccardSimilarity(removal.element, ins.element)
                if score > bestScore {
                    bestScore = score
                    bestIdx = idx
                }
            }

            if let idx = bestIdx {
                pairedRemovals[removal.offset] = idx
                usedInsertions.insert(idx)
            }
        }

        let removedOffsets = Set(removals.map(\.offset))

        // Walk old lines, emit unchanged/removed/modified; track insertion positions
        var result: [DiffLineKind] = []
        let insertionQueue = insertions.enumerated()
            .filter { !usedInsertions.contains($0.offset) }
            .map { $0.element }
            .sorted { $0.offset < $1.offset }
        var insertIdx = 0

        for (oldIdx, oldLine) in oldLines.enumerated() {
            // Emit any pending insertions whose target offset matches current new-side position
            let newSidePosition = oldIdx + result.filter {
                if case .added = $0 { return true }; return false
            }.count
            while insertIdx < insertionQueue.count, insertionQueue[insertIdx].offset <= newSidePosition {
                result.append(.added(insertionQueue[insertIdx].element))
                insertIdx += 1
            }

            if removedOffsets.contains(oldIdx) {
                if let pairedInsIdx = pairedRemovals[oldIdx] {
                    result.append(.modified(old: oldLine, new: insertions[pairedInsIdx].element))
                } else {
                    result.append(.removed(oldLine))
                }
            } else {
                result.append(.unchanged(oldLine))
            }
        }

        // Remaining insertions at the end
        while insertIdx < insertionQueue.count {
            result.append(.added(insertionQueue[insertIdx].element))
            insertIdx += 1
        }

        let addedCount = result.filter { if case .added = $0 { return true }; return false }.count
        let removedCount = result.filter { if case .removed = $0 { return true }; return false }.count
        let modifiedCount = result.filter { if case .modified = $0 { return true }; return false }.count

        return LineDiff(
            lines: result,
            stats: DiffStats(added: addedCount, removed: removedCount, modified: modifiedCount)
        )
    }

    // MARK: - Word-Level Diff

    struct WordChange: Equatable {
        let range: Range<String.Index>
    }

    static func wordDiffs(old: String, new: String) -> (removed: [WordChange], added: [WordChange]) {
        let oldTokens = tokenize(old)
        let newTokens = tokenize(new)

        let changes = newTokens.map(\.text).difference(from: oldTokens.map(\.text))

        var removedChanges: [WordChange] = []
        var addedChanges: [WordChange] = []

        for change in changes {
            switch change {
            case .remove(let offset, _, _):
                if offset < oldTokens.count {
                    removedChanges.append(WordChange(range: oldTokens[offset].range))
                }
            case .insert(let offset, _, _):
                if offset < newTokens.count {
                    addedChanges.append(WordChange(range: newTokens[offset].range))
                }
            }
        }

        return (removedChanges, addedChanges)
    }

    // MARK: - Private

    private struct WordToken {
        let text: String
        let range: Range<String.Index>
    }

    private static func tokenize(_ string: String) -> [WordToken] {
        var tokens: [WordToken] = []
        var idx = string.startIndex
        while idx < string.endIndex {
            while idx < string.endIndex, string[idx].isWhitespace {
                string.formIndex(after: &idx)
            }
            guard idx < string.endIndex else { break }
            let start = idx
            while idx < string.endIndex, !string[idx].isWhitespace {
                string.formIndex(after: &idx)
            }
            tokens.append(WordToken(text: String(string[start..<idx]), range: start..<idx))
        }
        return tokens
    }

    private static func jaccardSimilarity(_ a: String, _ b: String) -> Double {
        let aWords = Set(a.split(separator: " "))
        let bWords = Set(b.split(separator: " "))
        guard !aWords.isEmpty || !bWords.isEmpty else { return 1.0 }
        let intersection = aWords.intersection(bWords).count
        let union = aWords.union(bWords).count
        return Double(intersection) / Double(union)
    }

    // MARK: - Context Folding

    /// A line with its original index, for rendering and scroll targeting.
    struct IndexedLine: Identifiable {
        let index: Int
        let line: DiffLineKind
        var id: Int { index }
    }

    /// A section of the diff — either visible lines (near changes) or collapsed unchanged lines.
    struct DiffSection: Identifiable {
        let id: Int  // first line index in this section
        let kind: SectionKind
    }

    enum SectionKind {
        case visible([IndexedLine])
        case collapsed([IndexedLine])
    }

    /// Group lines into visible sections (near changes) and collapsed sections (far from changes).
    /// `contextLines` controls how many unchanged lines to show around each change.
    func sectioned(contextLines: Int = 3) -> [DiffSection] {
        guard !lines.isEmpty else { return [] }

        // Find all change indices
        let changeIndices = lines.enumerated().compactMap { idx, line -> Int? in
            if case .unchanged = line { return nil }
            return idx
        }

        // If no changes, show everything visible
        if changeIndices.isEmpty {
            let items = lines.enumerated().map { IndexedLine(index: $0.offset, line: $0.element) }
            return [DiffSection(id: 0, kind: .visible(items))]
        }

        // Mark lines near changes as visible
        var visibleIndices = Set<Int>()
        for ci in changeIndices {
            for i in max(0, ci - contextLines)...min(lines.count - 1, ci + contextLines) {
                visibleIndices.insert(i)
            }
        }

        // Group into sections
        var sections: [DiffSection] = []
        var currentVisible: [IndexedLine] = []
        var currentCollapsed: [IndexedLine] = []

        for (idx, line) in lines.enumerated() {
            let item = IndexedLine(index: idx, line: line)
            if visibleIndices.contains(idx) {
                if !currentCollapsed.isEmpty {
                    sections.append(DiffSection(id: currentCollapsed[0].index, kind: .collapsed(currentCollapsed)))
                    currentCollapsed = []
                }
                currentVisible.append(item)
            } else {
                if !currentVisible.isEmpty {
                    sections.append(DiffSection(id: currentVisible[0].index, kind: .visible(currentVisible)))
                    currentVisible = []
                }
                currentCollapsed.append(item)
            }
        }

        if !currentVisible.isEmpty {
            sections.append(DiffSection(id: currentVisible[0].index, kind: .visible(currentVisible)))
        }
        if !currentCollapsed.isEmpty {
            sections.append(DiffSection(id: currentCollapsed[0].index, kind: .collapsed(currentCollapsed)))
        }

        return sections
    }

    /// Indices of the first changed line in each contiguous chunk (for next/prev navigation).
    var chunkStartIndices: [Int] {
        var indices: [Int] = []
        var inChange = false
        for (idx, line) in lines.enumerated() {
            let isChange: Bool
            if case .unchanged = line { isChange = false } else { isChange = true }
            if isChange && !inChange {
                indices.append(idx)
            }
            inChange = isChange
        }
        return indices
    }
}
