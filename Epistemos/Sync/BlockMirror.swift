import Foundation
import SwiftData

enum BlockMirror {

    nonisolated static func sync(pageId: String, body: String, modelContext: ModelContext) {
        let descriptor = FetchDescriptor<SDBlock>(
            predicate: #Predicate<SDBlock> { $0.pageId == pageId },
            sortBy: [SortDescriptor(\.order)]
        )
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        let parsed = BlockParser.parse(body)

        if parsed.isEmpty {
            for block in existing {
                modelContext.delete(block)
            }
            return
        }

        let mappedExisting = reconcile(existing: existing, parsed: parsed)
        let now = Date.now
        var mirrored = [SDBlock]()
        mirrored.reserveCapacity(parsed.count)

        for (index, parsedBlock) in parsed.enumerated() {
            let block = mappedExisting[index] ?? SDBlock(
                pageId: pageId,
                content: parsedBlock.content,
                depth: parsedBlock.depth,
                order: parsedBlock.order * 1000,
                sourceRange: parsedBlock.utf16Range
            )

            if mappedExisting[index] == nil {
                modelContext.insert(block)
            }

            let nextOrder = parsedBlock.order * 1000
            let nextStart = parsedBlock.utf16Range.lowerBound
            let nextEnd = parsedBlock.utf16Range.upperBound
            let didChange =
                block.pageId != pageId
                || block.content != parsedBlock.content
                || block.depth != parsedBlock.depth
                || block.order != nextOrder
                || block.sourceStartUTF16 != nextStart
                || block.sourceEndUTF16 != nextEnd

            block.pageId = pageId
            block.content = parsedBlock.content
            block.depth = parsedBlock.depth
            block.order = nextOrder
            block.sourceStartUTF16 = nextStart
            block.sourceEndUTF16 = nextEnd
            if didChange {
                block.updatedAt = now
            }
            mirrored.append(block)
        }

        let keptIds = Set(mirrored.map(\.id))
        for block in existing where !keptIds.contains(block.id) {
            modelContext.delete(block)
        }

        var depthStack = [(depth: Int, block: SDBlock)]()
        for block in mirrored {
            while let last = depthStack.last, last.depth >= block.depth {
                depthStack.removeLast()
            }
            let nextParentId = block.depth > 0 ? depthStack.last?.block.id : nil
            if block.parentBlockId != nextParentId {
                block.parentBlockId = nextParentId
                block.updatedAt = now
            }
            depthStack.append((block.depth, block))
        }
    }

    nonisolated static func rewrittenBody(body: String, block: SDBlock, newContent: String) -> String? {
        let parsed = BlockParser.parse(body)
        guard let match = parsedBlock(in: parsed, for: block) else { return nil }
        let newRaw = reconstructRaw(match: match, newContent: newContent)
        return applyRewrite(body: body, match: match, newRaw: newRaw)
    }

    nonisolated static func parsedBlock(in body: String, for block: SDBlock) -> BlockParser.ParsedBlock? {
        parsedBlock(in: BlockParser.parse(body), for: block)
    }

    nonisolated private static func parsedBlock(
        in parsed: [BlockParser.ParsedBlock],
        for block: SDBlock
    ) -> BlockParser.ParsedBlock? {
        guard block.sourceEndUTF16 > block.sourceStartUTF16 else { return nil }
        return parsed.first {
            $0.utf16Range.lowerBound == block.sourceStartUTF16
                && $0.utf16Range.upperBound == block.sourceEndUTF16
        }
    }

    nonisolated private static func reconcile(
        existing: [SDBlock],
        parsed: [BlockParser.ParsedBlock]
    ) -> [SDBlock?] {
        var mapped = Array<SDBlock?>(repeating: nil, count: parsed.count)
        let anchors = exactAnchors(existing: existing, parsed: parsed)
        var oldLower = 0
        var newLower = 0

        for anchorIndex in 0...anchors.count {
            let oldUpper = anchorIndex < anchors.count ? anchors[anchorIndex].oldIndex : existing.count
            let newUpper = anchorIndex < anchors.count ? anchors[anchorIndex].newIndex : parsed.count

            for assignment in alignRun(
                existing: existing,
                oldRange: oldLower..<oldUpper,
                parsed: parsed,
                newRange: newLower..<newUpper
            ) {
                mapped[assignment.newIndex] = existing[assignment.oldIndex]
            }

            guard anchorIndex < anchors.count else { break }
            let anchor = anchors[anchorIndex]
            mapped[anchor.newIndex] = existing[anchor.oldIndex]
            oldLower = anchor.oldIndex + 1
            newLower = anchor.newIndex + 1
        }

        return mapped
    }

    nonisolated private static func exactAnchors(
        existing: [SDBlock],
        parsed: [BlockParser.ParsedBlock]
    ) -> [(oldIndex: Int, newIndex: Int)] {
        let oldSignatures = existing.map { ($0.depth, $0.content) }
        let newSignatures = parsed.map { ($0.depth, $0.content) }
        let oldCount = oldSignatures.count
        let newCount = newSignatures.count

        guard oldCount > 0, newCount > 0 else { return [] }

        var lengths = Array(
            repeating: Array(repeating: 0, count: newCount + 1),
            count: oldCount + 1
        )

        for oldIndex in stride(from: oldCount - 1, through: 0, by: -1) {
            for newIndex in stride(from: newCount - 1, through: 0, by: -1) {
                if oldSignatures[oldIndex] == newSignatures[newIndex] {
                    lengths[oldIndex][newIndex] = lengths[oldIndex + 1][newIndex + 1] + 1
                } else {
                    lengths[oldIndex][newIndex] = max(
                        lengths[oldIndex + 1][newIndex],
                        lengths[oldIndex][newIndex + 1]
                    )
                }
            }
        }

        var anchors = [(oldIndex: Int, newIndex: Int)]()
        var oldIndex = 0
        var newIndex = 0

        while oldIndex < oldCount, newIndex < newCount {
            if oldSignatures[oldIndex] == newSignatures[newIndex] {
                anchors.append((oldIndex, newIndex))
                oldIndex += 1
                newIndex += 1
            } else if lengths[oldIndex + 1][newIndex] >= lengths[oldIndex][newIndex + 1] {
                oldIndex += 1
            } else {
                newIndex += 1
            }
        }

        return anchors
    }

    nonisolated private static func alignRun(
        existing: [SDBlock],
        oldRange: Range<Int>,
        parsed: [BlockParser.ParsedBlock],
        newRange: Range<Int>
    ) -> [(oldIndex: Int, newIndex: Int)] {
        let oldIndices = Array(oldRange)
        let newIndices = Array(newRange)
        let oldCount = oldIndices.count
        let newCount = newIndices.count

        guard oldCount > 0, newCount > 0 else { return [] }

        var costs = Array(
            repeating: Array(repeating: 0.0, count: newCount + 1),
            count: oldCount + 1
        )
        var moves = Array(
            repeating: Array(repeating: Move.substitute, count: newCount + 1),
            count: oldCount + 1
        )

        for oldOffset in 1...oldCount {
            costs[oldOffset][0] = Double(oldOffset)
            moves[oldOffset][0] = .delete
        }
        for newOffset in 1...newCount {
            costs[0][newOffset] = Double(newOffset)
            moves[0][newOffset] = .insert
        }

        for oldOffset in 1...oldCount {
            for newOffset in 1...newCount {
                let substituteCost =
                    costs[oldOffset - 1][newOffset - 1]
                    + substitutionCost(
                        existing[oldIndices[oldOffset - 1]],
                        parsed[newIndices[newOffset - 1]]
                    )
                let deleteCost = costs[oldOffset - 1][newOffset] + 1.0
                let insertCost = costs[oldOffset][newOffset - 1] + 1.0

                var bestCost = substituteCost
                var bestMove = Move.substitute

                if deleteCost < bestCost {
                    bestCost = deleteCost
                    bestMove = .delete
                }
                if insertCost < bestCost {
                    bestCost = insertCost
                    bestMove = .insert
                }

                costs[oldOffset][newOffset] = bestCost
                moves[oldOffset][newOffset] = bestMove
            }
        }

        var assignments = [(oldIndex: Int, newIndex: Int)]()
        var oldOffset = oldCount
        var newOffset = newCount

        while oldOffset > 0 || newOffset > 0 {
            switch moves[oldOffset][newOffset] {
            case .substitute:
                assignments.append((
                    oldIndices[oldOffset - 1],
                    newIndices[newOffset - 1]
                ))
                oldOffset -= 1
                newOffset -= 1
            case .delete:
                oldOffset -= 1
            case .insert:
                newOffset -= 1
            }
        }

        return assignments.reversed()
    }

    nonisolated private static func substitutionCost(
        _ existing: SDBlock,
        _ parsed: BlockParser.ParsedBlock
    ) -> Double {
        let similarity = contentSimilarity(existing.content, parsed.content)
        // Below 30% similarity the content is unrelated — prohibitive cost forces
        // delete+insert (2.0) so the old block ID is retired and a new one is created.
        guard similarity >= 0.3 else { return 10.0 }
        let depthPenalty = existing.depth == parsed.depth ? 0.0 : 0.2
        return depthPenalty + (1.0 - similarity) * 1.5
    }

    nonisolated private static func contentSimilarity(_ lhs: String, _ rhs: String) -> Double {
        if lhs == rhs {
            return 1.0
        }

        let left = Array(lhs.utf16)
        let right = Array(rhs.utf16)
        guard !left.isEmpty, !right.isEmpty else { return 0.0 }

        var previous = Array(0...right.count)
        var current = Array(repeating: 0, count: right.count + 1)

        for (leftIndex, leftValue) in left.enumerated() {
            current[0] = leftIndex + 1
            for (rightIndex, rightValue) in right.enumerated() {
                let substitution = previous[rightIndex] + (leftValue == rightValue ? 0 : 1)
                let insertion = current[rightIndex] + 1
                let deletion = previous[rightIndex + 1] + 1
                current[rightIndex + 1] = min(substitution, insertion, deletion)
            }
            swap(&previous, &current)
        }

        let distance = previous[right.count]
        return 1.0 - (Double(distance) / Double(max(left.count, right.count)))
    }

    nonisolated private static func reconstructRaw(
        match: BlockParser.ParsedBlock,
        newContent: String
    ) -> String {
        let rawFirstLine = match.rawContent.prefix(while: { $0 != "\n" })
        let contentFirstLine = match.content.prefix(while: { $0 != "\n" })
        let firstLinePrefix: String
        if rawFirstLine.hasSuffix(contentFirstLine) {
            firstLinePrefix = String(rawFirstLine.dropLast(contentFirstLine.count))
        } else {
            firstLinePrefix = ""
        }

        if firstLinePrefix.isEmpty || !newContent.contains("\n") {
            return firstLinePrefix + newContent
        }

        let continuationIndent = String(repeating: " ", count: firstLinePrefix.count)
        let lines = newContent.split(separator: "\n", omittingEmptySubsequences: false)
        var rebuilt = [firstLinePrefix + lines[0]]
        for line in lines.dropFirst() {
            rebuilt.append(continuationIndent + line)
        }
        return rebuilt.joined(separator: "\n")
    }

    nonisolated private static func applyRewrite(
        body: String,
        match: BlockParser.ParsedBlock,
        newRaw: String
    ) -> String? {
        let utf16View = body.utf16
        let safeStart = min(match.utf16Range.lowerBound, utf16View.count)
        let safeEnd = min(match.utf16Range.upperBound, utf16View.count)
        let startIndex = utf16View.index(utf16View.startIndex, offsetBy: safeStart)
        let endIndex = utf16View.index(utf16View.startIndex, offsetBy: safeEnd)

        guard let stringStart = startIndex.samePosition(in: body),
              let stringEnd = endIndex.samePosition(in: body) else { return nil }

        var rewritten = body
        rewritten.replaceSubrange(stringStart..<stringEnd, with: newRaw)
        return rewritten
    }
}

private enum Move {
    case substitute
    case delete
    case insert
}
