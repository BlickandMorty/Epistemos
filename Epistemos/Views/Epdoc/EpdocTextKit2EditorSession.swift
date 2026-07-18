import Foundation

nonisolated enum EpdocTextKit2EditorSessionError: Error, Sendable, Hashable {
    case invalidCanonicalContent
    case unknownBlockID(String)
    case nonEditableNode(String)
    case invalidInlineChild(String)
    case invalidBlockID(String)
    case duplicateBlockID(String)
    case invalidUTF16Offset(Int)
    case blocksAreNotAdjacent(String, String)
    case nonInlineBlockStructure(String)
    case invalidReplacementBlockCount(Int)
    case mismatchedDocumentID(String)
}

nonisolated enum EpdocListMarkerPresentation: Sendable, Hashable {
    case bullet
    case ordered(itemNumber: Int)
    case checklist(isChecked: Bool)
}

nonisolated enum EpdocTableRolePresentation: Sendable, Hashable {
    case header
    case cell
}

nonisolated struct EpdocEditableBlockPresentation: Sendable, Hashable {
    let node: EpdocRichNode
    let listMarker: EpdocListMarkerPresentation?
    let listNestingLevel: Int
    let tableRole: EpdocTableRolePresentation?
}

nonisolated struct EpdocEditableBlockSnapshot: Sendable, Hashable {
    let revision: UInt64
    let nodes: [EpdocRichNode]
}

nonisolated enum EpdocCheckpointEncoder {
    static func encode(_ envelope: EpdocContentEnvelope) throws -> Data {
        try envelope.validate()
        return try JSONEncoder.epdocCanonical.encode(envelope)
    }
}

/// Mutable, engine-neutral Epdoc state used by the native TextKit 2 surface.
/// Nodes are reference-backed so an ordinary edit replaces one block without
/// rebuilding the complete JSON tree. The full value envelope is reconstructed
/// only at a durable checkpoint.
@MainActor
public final class EpdocTextKit2EditorSession {
    private final class MutableNode {
        let id: String?
        var type: EpdocNodeType
        var attributes: [String: EpdocJSONValue]
        var text: String?
        var marks: [EpdocTextMark]
        var children: [MutableNode]

        init(_ node: EpdocRichNode) {
            id = node.id
            type = node.type
            attributes = node.attributes
            text = node.text
            marks = node.marks
            children = node.children.map(MutableNode.init)
        }

        func snapshot() -> EpdocRichNode {
            EpdocRichNode(
                id: id,
                type: type,
                attributes: attributes,
                text: text,
                marks: marks,
                children: children.map { $0.snapshot() }
            )
        }
    }

    private let schemaVersion: UInt32
    private let format: String
    let documentID: String
    private var root: MutableNode
    private var nodesByID: [String: MutableNode] = [:]
    private var parentsByID: [String: MutableNode] = [:]
    private var editableBlockIDs: [String] = []
    private var textByBlockID: [String: String] = [:]

    private(set) var revision: UInt64
    private(set) var wordCount = 0
    private(set) var characterCount = 0

    var blockCount: Int { editableBlockIDs.count }

    init(contentJSON: Data) throws {
        guard let envelope = try? JSONDecoder.epdocCanonical.decode(
            EpdocContentEnvelope.self,
            from: contentJSON
        ),
        (try? envelope.validate()) != nil else {
            throw EpdocTextKit2EditorSessionError.invalidCanonicalContent
        }

        schemaVersion = envelope.schemaVersion
        format = envelope.format
        documentID = envelope.documentID
        revision = envelope.revision
        root = MutableNode(envelope.root)
        index(root, parent: nil)
    }

    func orderedEditableNodes() -> [EpdocRichNode] {
        editableBlockIDs.compactMap { nodesByID[$0]?.snapshot() }
    }

    func orderedEditableBlockPresentations() -> [EpdocEditableBlockPresentation] {
        editableBlockIDs.compactMap { presentation(blockID: $0) }
    }

    func presentation(blockID: String) -> EpdocEditableBlockPresentation? {
        guard let block = nodesByID[blockID] else { return nil }
        var listMarker: EpdocListMarkerPresentation?
        var listNestingLevel = 0
        var tableRole: EpdocTableRolePresentation?
        var cursor: MutableNode? = block

        while let node = cursor {
            if listMarker == nil, Self.firstEditableLeaf(in: node) === block {
                if node.type == .checklistItem {
                    listMarker = .checklist(
                        isChecked: node.attributes["checked"]?.boolValue ?? false
                    )
                } else if node.type == .listItem,
                          let nodeID = node.id,
                          let parent = parentsByID[nodeID] {
                    if parent.type == .bulletList {
                        listMarker = .bullet
                    } else if parent.type == .orderedList {
                        let itemNumber = parent.children.firstIndex(where: { $0 === node })
                            .map { $0 + 1 } ?? 1
                        listMarker = .ordered(itemNumber: itemNumber)
                    }
                }
            }
            if node.type == .bulletList || node.type == .orderedList || node.type == .checklist {
                listNestingLevel += 1
            }
            if tableRole == nil {
                if node.type == .tableHeader {
                    tableRole = .header
                } else if node.type == .tableCell {
                    tableRole = .cell
                }
            }
            guard let nodeID = node.id, let parent = parentsByID[nodeID] else { break }
            cursor = parent
        }

        return EpdocEditableBlockPresentation(
            node: block.snapshot(),
            listMarker: listMarker,
            listNestingLevel: listNestingLevel,
            tableRole: tableRole
        )
    }

    func node(id: String) -> EpdocRichNode? {
        nodesByID[id]?.snapshot()
    }

    func editableBlockSnapshot(
        blockIDs: [String]
    ) throws -> EpdocEditableBlockSnapshot {
        var seen = Set<String>()
        let nodes = try blockIDs.compactMap { blockID -> EpdocRichNode? in
            guard seen.insert(blockID).inserted else { return nil }
            guard let block = nodesByID[blockID] else {
                throw EpdocTextKit2EditorSessionError.unknownBlockID(blockID)
            }
            guard Self.isEditableLeaf(block) else {
                throw EpdocTextKit2EditorSessionError.nonInlineBlockStructure(blockID)
            }
            return block.snapshot()
        }
        return EpdocEditableBlockSnapshot(revision: revision, nodes: nodes)
    }

    func restoreEditableBlockSnapshot(
        _ snapshot: EpdocEditableBlockSnapshot
    ) throws {
        let replacements = try snapshot.nodes.map { node -> (MutableNode, EpdocRichNode) in
            guard let blockID = node.id,
                  let block = nodesByID[blockID] else {
                throw EpdocTextKit2EditorSessionError.unknownBlockID(node.id ?? "")
            }
            guard Self.isEditableLeaf(block),
                  Self.isEditableBlock(node.type),
                  node.children.allSatisfy({ Self.isInlineNode($0.type) }),
                  Self.children(node.children, areAllowedBy: node.type),
                  let parent = parentsByID[blockID],
                  Self.parent(parent.type, allowsEditableChild: node.type) else {
                throw EpdocTextKit2EditorSessionError.nonInlineBlockStructure(blockID)
            }
            return (block, node)
        }

        for (block, node) in replacements {
            try replaceInlineContentWithoutAdvancingRevision(
                block: block,
                children: node.children
            )
            block.type = node.type
            block.attributes = node.attributes
        }
        revision = snapshot.revision
    }

    func previousEditableBlockID(before blockID: String) -> String? {
        guard let index = editableBlockIDs.firstIndex(of: blockID), index > 0 else {
            return nil
        }
        return editableBlockIDs[index - 1]
    }

    func replaceInlineContent(
        blockID: String,
        children: [EpdocRichNode]
    ) throws {
        try replaceInlineContents([(blockID: blockID, children: children)])
    }

    func replaceInlineContents(
        _ replacements: [(blockID: String, children: [EpdocRichNode])]
    ) throws {
        guard !replacements.isEmpty else { return }
        var seen = Set<String>()
        let validated = try replacements.map { replacement -> (MutableNode, [EpdocRichNode]) in
            guard seen.insert(replacement.blockID).inserted,
                  let block = nodesByID[replacement.blockID] else {
                throw EpdocTextKit2EditorSessionError.unknownBlockID(replacement.blockID)
            }
            guard Self.isEditableLeaf(block) else {
                throw EpdocTextKit2EditorSessionError.nonInlineBlockStructure(
                    replacement.blockID
                )
            }
            guard replacement.children.allSatisfy({ Self.isInlineNode($0.type) }),
                  Self.children(replacement.children, areAllowedBy: block.type) else {
                throw EpdocTextKit2EditorSessionError.invalidInlineChild(
                    replacement.blockID
                )
            }
            return (block, replacement.children)
        }
        for (block, children) in validated {
            try replaceInlineContentWithoutAdvancingRevision(
                block: block,
                children: children
            )
        }
        revision &+= 1
    }

    func setBlockType(
        blockID: String,
        type: EpdocNodeType,
        attributes: [String: EpdocJSONValue]
    ) throws {
        try setBlockTypes(blockIDs: [blockID], type: type, attributes: attributes)
    }

    func setBlockTypes(
        blockIDs: [String],
        type: EpdocNodeType,
        attributes: [String: EpdocJSONValue]
    ) throws {
        guard !blockIDs.isEmpty else { return }
        guard Self.isEditableBlock(type) else {
            throw EpdocTextKit2EditorSessionError.nonEditableNode(type.rawValue)
        }
        let blocks = try blockIDs.map { blockID in
            guard let block = nodesByID[blockID] else {
                throw EpdocTextKit2EditorSessionError.unknownBlockID(blockID)
            }
            guard Self.isEditableLeaf(block),
                  Self.children(
                      block.children.map { $0.snapshot() },
                      areAllowedBy: type
                  ),
                  let parent = parentsByID[blockID],
                  Self.parent(parent.type, allowsEditableChild: type) else {
                throw EpdocTextKit2EditorSessionError.nonInlineBlockStructure(blockID)
            }
            return block
        }
        for block in blocks {
            block.type = type
            block.attributes = attributes
        }
        revision &+= 1
    }

    @discardableResult
    func replaceEditableBlockRange(
        blockIDs: [String],
        type: EpdocNodeType,
        attributes: [String: EpdocJSONValue],
        children: [EpdocRichNode]
    ) throws -> String {
        guard let firstID = blockIDs.first,
              Self.isEditableBlock(type),
              children.allSatisfy({ Self.isInlineNode($0.type) }),
              Self.children(children, areAllowedBy: type) else {
            throw EpdocTextKit2EditorSessionError.invalidReplacementBlockCount(
                blockIDs.count
            )
        }
        let blocks = try blockIDs.map { blockID -> MutableNode in
            guard let block = nodesByID[blockID] else {
                throw EpdocTextKit2EditorSessionError.unknownBlockID(blockID)
            }
            guard Self.isEditableLeaf(block) else {
                throw EpdocTextKit2EditorSessionError.nonInlineBlockStructure(blockID)
            }
            return block
        }
        guard Set(blockIDs).count == blockIDs.count,
              let parent = parentsByID[firstID],
              Self.parent(parent.type, allowsEditableChild: type),
              let firstIndex = parent.children.firstIndex(where: { $0 === blocks[0] }) else {
            throw EpdocTextKit2EditorSessionError.nonInlineBlockStructure(firstID)
        }
        let expectedIndexes = Array(firstIndex..<(firstIndex + blocks.count))
        guard expectedIndexes.last.map({ $0 < parent.children.count }) == true,
              zip(expectedIndexes, blocks).allSatisfy({ pair in
                  parent.children[pair.0] === pair.1
              }) else {
            throw EpdocTextKit2EditorSessionError.blocksAreNotAdjacent(
                firstID,
                blockIDs.last ?? firstID
            )
        }

        let previousTexts = blocks.map { block in
            block.id.flatMap { textByBlockID[$0] } ?? Self.plainText(in: block)
        }
        let leading = blocks[0]
        for child in leading.children {
            removeIndexes(for: child)
        }
        for block in blocks.dropFirst() {
            removeIndexes(for: block)
        }
        if blocks.count > 1 {
            parent.children.removeSubrange((firstIndex + 1)..<(firstIndex + blocks.count))
        }

        leading.type = type
        leading.attributes = attributes
        leading.children = children.map(MutableNode.init)
        for child in leading.children {
            Self.assignParent(leading, to: child, parentsByID: &parentsByID)
            Self.indexNode(child, nodesByID: &nodesByID)
        }
        let replacementText = Self.plainText(in: leading)
        textByBlockID[firstID] = replacementText
        characterCount += replacementText.count - previousTexts.reduce(0) { $0 + $1.count }
        wordCount += Self.countWords(replacementText)
            - previousTexts.reduce(0) { $0 + Self.countWords($1) }
        revision &+= 1
        return firstID
    }

    /// Replaces one inline range with one or more sibling editable blocks in
    /// a single canonical revision. The original block keeps its identity;
    /// later pasted lines receive new stable block IDs.
    @discardableResult
    func replaceInlineRangeWithBlocks(
        blockID: String,
        range: NSRange,
        replacementBlocks: [[EpdocRichNode]],
        requestedBlockIDs: [String]? = nil
    ) throws -> [String] {
        guard !replacementBlocks.isEmpty else {
            throw EpdocTextKit2EditorSessionError.invalidReplacementBlockCount(0)
        }
        guard let block = nodesByID[blockID] else {
            throw EpdocTextKit2EditorSessionError.unknownBlockID(blockID)
        }
        guard Self.isEditableLeaf(block),
              let parent = parentsByID[blockID],
              let siblingIndex = parent.children.firstIndex(where: { $0 === block }) else {
            throw EpdocTextKit2EditorSessionError.nonInlineBlockStructure(blockID)
        }
        guard replacementBlocks.allSatisfy({ children in
            children.allSatisfy { Self.isInlineNode($0.type) }
        }) else {
            throw EpdocTextKit2EditorSessionError.invalidInlineChild(blockID)
        }
        if let requestedBlockIDs,
           requestedBlockIDs.count != replacementBlocks.count - 1 {
            throw EpdocTextKit2EditorSessionError.invalidReplacementBlockCount(
                requestedBlockIDs.count
            )
        }

        let prefixSplit = try Self.splitInlineChildren(
            block.children,
            atUTF16Offset: range.location
        )
        let selectionSplit = try Self.splitInlineChildren(
            prefixSplit.trailing,
            atUTF16Offset: range.length
        )
        let generatedIDs = try (0..<max(0, replacementBlocks.count - 1)).map { index in
            let candidate = requestedBlockIDs?[index]
                ?? "\(documentID):block:\(UUID().uuidString.lowercased())"
            guard !candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw EpdocTextKit2EditorSessionError.invalidBlockID(candidate)
            }
            guard candidate != blockID,
                  nodesByID[candidate] == nil else {
                throw EpdocTextKit2EditorSessionError.duplicateBlockID(candidate)
            }
            return candidate
        }
        guard Set(generatedIDs).count == generatedIDs.count else {
            throw EpdocTextKit2EditorSessionError.duplicateBlockID(
                generatedIDs.first ?? blockID
            )
        }

        let previousText = textByBlockID[blockID] ?? Self.plainText(in: block)
        for child in block.children {
            removeIndexes(for: child)
        }

        let firstChildren = prefixSplit.leading.map { $0.snapshot() }
            + replacementBlocks[0]
            + (replacementBlocks.count == 1
                ? selectionSplit.trailing.map { $0.snapshot() }
                : [])
        block.children = firstChildren.map(MutableNode.init)
        for child in block.children {
            Self.assignParent(block, to: child, parentsByID: &parentsByID)
            Self.indexNode(child, nodesByID: &nodesByID)
        }

        var insertedBlocks: [MutableNode] = []
        for index in replacementBlocks.indices.dropFirst() {
            var children = replacementBlocks[index]
            if index == replacementBlocks.index(before: replacementBlocks.endIndex) {
                children += selectionSplit.trailing.map { $0.snapshot() }
            }
            let inserted = MutableNode(
                EpdocRichNode(
                    id: generatedIDs[index - 1],
                    type: block.type,
                    attributes: block.attributes,
                    children: children
                )
            )
            insertedBlocks.append(inserted)
        }
        parent.children.insert(contentsOf: insertedBlocks, at: siblingIndex + 1)

        for inserted in insertedBlocks {
            guard let insertedID = inserted.id else { continue }
            nodesByID[insertedID] = inserted
            parentsByID[insertedID] = parent
            for child in inserted.children {
                Self.assignParent(inserted, to: child, parentsByID: &parentsByID)
                Self.indexNode(child, nodesByID: &nodesByID)
            }
        }
        if let editableIndex = editableBlockIDs.firstIndex(of: blockID) {
            editableBlockIDs.insert(
                contentsOf: generatedIDs,
                at: editableIndex + 1
            )
        }

        let resultIDs = [blockID] + generatedIDs
        let resultTexts = resultIDs.map { id in
            nodesByID[id].map(Self.plainText) ?? ""
        }
        for (id, text) in zip(resultIDs, resultTexts) {
            textByBlockID[id] = text
        }
        characterCount += resultTexts.reduce(0) { $0 + $1.count } - previousText.count
        wordCount += resultTexts.reduce(0) { $0 + Self.countWords($1) }
            - Self.countWords(previousText)
        revision &+= 1
        return resultIDs
    }

    @discardableResult
    func splitBlock(
        blockID: String,
        atUTF16Offset offset: Int,
        newBlockID requestedID: String? = nil
    ) throws -> String {
        guard let block = nodesByID[blockID] else {
            throw EpdocTextKit2EditorSessionError.unknownBlockID(blockID)
        }
        guard Self.isEditableBlock(block.type) else {
            throw EpdocTextKit2EditorSessionError.nonEditableNode(block.type.rawValue)
        }
        guard block.children.allSatisfy({ Self.isInlineNode($0.type) }) else {
            throw EpdocTextKit2EditorSessionError.nonInlineBlockStructure(blockID)
        }
        guard let parent = parentsByID[blockID],
              let siblingIndex = parent.children.firstIndex(where: { $0 === block }) else {
            throw EpdocTextKit2EditorSessionError.nonInlineBlockStructure(blockID)
        }

        let newBlockID = requestedID ?? "\(documentID):block:\(UUID().uuidString.lowercased())"
        guard !newBlockID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EpdocTextKit2EditorSessionError.invalidBlockID(newBlockID)
        }
        guard nodesByID[newBlockID] == nil else {
            throw EpdocTextKit2EditorSessionError.duplicateBlockID(newBlockID)
        }

        let previousText = textByBlockID[blockID] ?? Self.plainText(in: block)
        let split = try Self.splitInlineChildren(block.children, atUTF16Offset: offset)
        block.children = split.leading
        let trailing = MutableNode(
            EpdocRichNode(
                id: newBlockID,
                type: block.type,
                attributes: block.attributes,
                children: split.trailing.map { $0.snapshot() }
            )
        )
        parent.children.insert(trailing, at: siblingIndex + 1)

        nodesByID[newBlockID] = trailing
        parentsByID[newBlockID] = parent
        for child in trailing.children {
            Self.assignParent(trailing, to: child, parentsByID: &parentsByID)
            Self.indexNode(child, nodesByID: &nodesByID)
        }
        if let editableIndex = editableBlockIDs.firstIndex(of: blockID) {
            editableBlockIDs.insert(newBlockID, at: editableIndex + 1)
        } else {
            editableBlockIDs.append(newBlockID)
        }

        let leadingText = Self.plainText(in: block)
        let trailingText = Self.plainText(in: trailing)
        textByBlockID[blockID] = leadingText
        textByBlockID[newBlockID] = trailingText
        characterCount += leadingText.count + trailingText.count - previousText.count
        wordCount += Self.countWords(leadingText) + Self.countWords(trailingText)
            - Self.countWords(previousText)
        revision &+= 1
        return newBlockID
    }

    func mergeBlocks(
        leadingBlockID: String,
        trailingBlockID: String
    ) throws {
        guard let leading = nodesByID[leadingBlockID] else {
            throw EpdocTextKit2EditorSessionError.unknownBlockID(leadingBlockID)
        }
        guard let trailing = nodesByID[trailingBlockID] else {
            throw EpdocTextKit2EditorSessionError.unknownBlockID(trailingBlockID)
        }
        guard Self.isEditableBlock(leading.type), Self.isEditableBlock(trailing.type) else {
            throw EpdocTextKit2EditorSessionError.nonEditableNode(trailing.type.rawValue)
        }
        guard leading.children.allSatisfy({ Self.isInlineNode($0.type) }),
              trailing.children.allSatisfy({ Self.isInlineNode($0.type) }) else {
            throw EpdocTextKit2EditorSessionError.nonInlineBlockStructure(trailingBlockID)
        }
        guard let parent = parentsByID[leadingBlockID],
              let trailingParent = parentsByID[trailingBlockID],
              trailingParent === parent,
              let leadingIndex = parent.children.firstIndex(where: { $0 === leading }),
              let trailingIndex = parent.children.firstIndex(where: { $0 === trailing }),
              trailingIndex == leadingIndex + 1 else {
            throw EpdocTextKit2EditorSessionError.blocksAreNotAdjacent(
                leadingBlockID,
                trailingBlockID
            )
        }

        let leadingTextBefore = textByBlockID[leadingBlockID] ?? Self.plainText(in: leading)
        let trailingTextBefore = textByBlockID[trailingBlockID] ?? Self.plainText(in: trailing)
        for child in trailing.children {
            Self.assignParent(leading, to: child, parentsByID: &parentsByID)
        }
        leading.children.append(contentsOf: trailing.children)
        parent.children.remove(at: trailingIndex)
        nodesByID.removeValue(forKey: trailingBlockID)
        parentsByID.removeValue(forKey: trailingBlockID)
        editableBlockIDs.removeAll { $0 == trailingBlockID }
        textByBlockID.removeValue(forKey: trailingBlockID)

        let mergedText = Self.plainText(in: leading)
        textByBlockID[leadingBlockID] = mergedText
        characterCount += mergedText.count - leadingTextBefore.count - trailingTextBefore.count
        wordCount += Self.countWords(mergedText) - Self.countWords(leadingTextBefore)
            - Self.countWords(trailingTextBefore)
        revision &+= 1
    }

    @discardableResult
    func replaceAcrossBlocks(
        leadingBlockID: String,
        leadingUTF16Offset: Int,
        trailingBlockID: String,
        trailingUTF16Offset: Int,
        replacement: [EpdocRichNode]
    ) throws -> [String] {
        guard let leading = nodesByID[leadingBlockID] else {
            throw EpdocTextKit2EditorSessionError.unknownBlockID(leadingBlockID)
        }
        guard let trailing = nodesByID[trailingBlockID] else {
            throw EpdocTextKit2EditorSessionError.unknownBlockID(trailingBlockID)
        }
        guard replacement.allSatisfy({ Self.isInlineNode($0.type) }) else {
            throw EpdocTextKit2EditorSessionError.invalidInlineChild(leadingBlockID)
        }
        guard Self.isEditableLeaf(leading), Self.isEditableLeaf(trailing) else {
            throw EpdocTextKit2EditorSessionError.nonInlineBlockStructure(trailingBlockID)
        }
        guard let parent = parentsByID[leadingBlockID],
              let trailingParent = parentsByID[trailingBlockID],
              trailingParent === parent,
              let leadingIndex = parent.children.firstIndex(where: { $0 === leading }),
              let trailingIndex = parent.children.firstIndex(where: { $0 === trailing }),
              leadingIndex < trailingIndex else {
            throw EpdocTextKit2EditorSessionError.blocksAreNotAdjacent(
                leadingBlockID,
                trailingBlockID
            )
        }

        let consumed = Array(parent.children[leadingIndex...trailingIndex])
        guard consumed.allSatisfy(Self.isEditableLeaf) else {
            throw EpdocTextKit2EditorSessionError.nonInlineBlockStructure(trailingBlockID)
        }
        let leadingSplit = try Self.splitInlineChildren(
            leading.children,
            atUTF16Offset: leadingUTF16Offset
        )
        let trailingSplit = try Self.splitInlineChildren(
            trailing.children,
            atUTF16Offset: trailingUTF16Offset
        )
        let removedBlockIDs = consumed.dropFirst().compactMap(\.id)
        let previousTexts = consumed.map { node in
            node.id.flatMap { textByBlockID[$0] } ?? Self.plainText(in: node)
        }

        for child in leading.children {
            removeIndexes(for: child)
        }
        for node in consumed.dropFirst() {
            removeIndexes(for: node)
        }
        parent.children.removeSubrange((leadingIndex + 1)...trailingIndex)

        leading.children = leadingSplit.leading
            + replacement.map(MutableNode.init)
            + trailingSplit.trailing
        for child in leading.children {
            Self.assignParent(leading, to: child, parentsByID: &parentsByID)
            Self.indexNode(child, nodesByID: &nodesByID)
        }
        editableBlockIDs.removeAll { removedBlockIDs.contains($0) }
        for removedID in removedBlockIDs {
            textByBlockID.removeValue(forKey: removedID)
        }

        let mergedText = Self.plainText(in: leading)
        textByBlockID[leadingBlockID] = mergedText
        characterCount += mergedText.count - previousTexts.reduce(0) { $0 + $1.count }
        wordCount += Self.countWords(mergedText)
            - previousTexts.reduce(0) { $0 + Self.countWords($1) }
        revision &+= 1
        return removedBlockIDs
    }

    func checkpointSnapshot() -> EpdocContentEnvelope {
        EpdocContentEnvelope(
            schemaVersion: schemaVersion,
            format: format,
            documentID: documentID,
            revision: revision,
            root: root.snapshot()
        )
    }

    func checkpointEnvelope() throws -> EpdocContentEnvelope {
        let envelope = checkpointSnapshot()
        try envelope.validate()
        return envelope
    }

    func checkpointData() throws -> Data {
        try EpdocCheckpointEncoder.encode(checkpointSnapshot())
    }

    func restore(_ envelope: EpdocContentEnvelope) throws {
        try envelope.validate()
        guard envelope.documentID == documentID,
              envelope.schemaVersion == schemaVersion,
              envelope.format == format else {
            throw EpdocTextKit2EditorSessionError.mismatchedDocumentID(
                envelope.documentID
            )
        }
        root = MutableNode(envelope.root)
        revision = envelope.revision
        nodesByID.removeAll(keepingCapacity: true)
        parentsByID.removeAll(keepingCapacity: true)
        editableBlockIDs.removeAll(keepingCapacity: true)
        textByBlockID.removeAll(keepingCapacity: true)
        wordCount = 0
        characterCount = 0
        index(root, parent: nil)
    }

    private func replaceInlineContentWithoutAdvancingRevision(
        block: MutableNode,
        children: [EpdocRichNode]
    ) throws {
        guard let blockID = block.id else {
            throw EpdocTextKit2EditorSessionError.invalidBlockID("")
        }
        let previousText = textByBlockID[blockID] ?? Self.plainText(in: block)
        for child in block.children {
            removeIndexes(for: child)
        }
        block.children = children.map(MutableNode.init)
        for child in block.children {
            Self.assignParent(block, to: child, parentsByID: &parentsByID)
            Self.indexNode(child, nodesByID: &nodesByID)
        }
        let replacementText = Self.plainText(in: block)
        textByBlockID[blockID] = replacementText
        characterCount += replacementText.count - previousText.count
        wordCount += Self.countWords(replacementText) - Self.countWords(previousText)
    }

    private func index(_ node: MutableNode, parent: MutableNode?) {
        if let id = node.id {
            nodesByID[id] = node
            if let parent {
                parentsByID[id] = parent
            }
            if Self.isEditableLeaf(node) {
                editableBlockIDs.append(id)
                let text = Self.plainText(in: node)
                textByBlockID[id] = text
                characterCount += text.count
                wordCount += Self.countWords(text)
            }
        }
        for child in node.children {
            index(child, parent: node)
        }
    }

    private func removeIndexes(for node: MutableNode) {
        for child in node.children {
            removeIndexes(for: child)
        }
        guard let id = node.id else { return }
        nodesByID.removeValue(forKey: id)
        parentsByID.removeValue(forKey: id)
        editableBlockIDs.removeAll { $0 == id }
        textByBlockID.removeValue(forKey: id)
    }

    private static func splitInlineChildren(
        _ children: [MutableNode],
        atUTF16Offset offset: Int
    ) throws -> (leading: [MutableNode], trailing: [MutableNode]) {
        let totalLength = children.reduce(0) { $0 + inlineUTF16Length($1) }
        guard offset >= 0, offset <= totalLength else {
            throw EpdocTextKit2EditorSessionError.invalidUTF16Offset(offset)
        }

        var leading: [MutableNode] = []
        var trailing: [MutableNode] = []
        var remaining = offset
        for child in children {
            let length = inlineUTF16Length(child)
            if remaining == 0 {
                trailing.append(child)
                continue
            }
            if remaining >= length {
                leading.append(child)
                remaining -= length
                continue
            }

            guard child.type == .text, let text = child.text else {
                throw EpdocTextKit2EditorSessionError.invalidUTF16Offset(offset)
            }
            let utf16 = text.utf16
            let splitUTF16Index = utf16.index(utf16.startIndex, offsetBy: remaining)
            guard let splitIndex = String.Index(splitUTF16Index, within: text) else {
                throw EpdocTextKit2EditorSessionError.invalidUTF16Offset(offset)
            }
            let leadingText = String(text[..<splitIndex])
            let trailingText = String(text[splitIndex...])
            if !leadingText.isEmpty {
                leading.append(
                    MutableNode(
                        EpdocRichNode(type: .text, text: leadingText, marks: child.marks)
                    )
                )
            }
            if !trailingText.isEmpty {
                trailing.append(
                    MutableNode(
                        EpdocRichNode(type: .text, text: trailingText, marks: child.marks)
                    )
                )
            }
            remaining = 0
        }
        guard remaining == 0 else {
            throw EpdocTextKit2EditorSessionError.invalidUTF16Offset(offset)
        }
        return (leading, trailing)
    }

    private static func inlineUTF16Length(_ node: MutableNode) -> Int {
        if node.type == .text { return node.text?.utf16.count ?? 0 }
        if node.type == .hardBreak { return 1 }
        return isInlineNode(node.type) ? 1 : 0
    }

    private static func assignParent(
        _ parent: MutableNode,
        to node: MutableNode,
        parentsByID: inout [String: MutableNode]
    ) {
        if let id = node.id {
            parentsByID[id] = parent
        }
        for child in node.children {
            assignParent(node, to: child, parentsByID: &parentsByID)
        }
    }

    private static func indexNode(
        _ node: MutableNode,
        nodesByID: inout [String: MutableNode]
    ) {
        if let id = node.id {
            nodesByID[id] = node
        }
        for child in node.children {
            indexNode(child, nodesByID: &nodesByID)
        }
    }

    private static func isEditableBlock(_ type: EpdocNodeType) -> Bool {
        switch type {
        case .paragraph, .heading, .blockquote, .codeBlock, .listItem,
             .checklistItem, .tableHeader, .tableCell, .callout:
            true
        default:
            false
        }
    }

    private static func children(
        _ children: [EpdocRichNode],
        areAllowedBy type: EpdocNodeType
    ) -> Bool {
        switch type {
        case .codeBlock:
            return children.allSatisfy { $0.type == .text || $0.type == .hardBreak }
        case .paragraph, .heading:
            return children.allSatisfy {
                $0.type == .text || $0.type == .hardBreak || $0.type == .image
                    || $0.type == .audio || $0.type == .drawing || $0.type == .footnote
            }
        default:
            return children.allSatisfy { isInlineNode($0.type) }
        }
    }

    private static func parent(
        _ parent: EpdocNodeType,
        allowsEditableChild child: EpdocNodeType
    ) -> Bool {
        switch parent {
        case .document:
            return child != .text && child != .hardBreak
        case .bulletList, .orderedList:
            return child == .listItem
        case .checklist:
            return child == .checklistItem
        case .tableRow:
            return child == .tableHeader || child == .tableCell
        case .text, .hardBreak, .horizontalRule, .image, .audio, .drawing, .pdf,
             .chart, .mathBlock, .codeBlock:
            return false
        default:
            return child != .document
        }
    }

    private static func isEditableLeaf(_ node: MutableNode) -> Bool {
        isEditableBlock(node.type)
            && node.children.allSatisfy { isInlineNode($0.type) }
    }

    private static func firstEditableLeaf(in node: MutableNode) -> MutableNode? {
        if isEditableLeaf(node) {
            return node
        }
        for child in node.children {
            if let editable = firstEditableLeaf(in: child) {
                return editable
            }
        }
        return nil
    }

    private static func isInlineNode(_ type: EpdocNodeType) -> Bool {
        switch type {
        case .text, .hardBreak, .image, .audio, .drawing, .footnote:
            true
        default:
            false
        }
    }

    private static func plainText(in node: MutableNode) -> String {
        if node.type == .text { return node.text ?? "" }
        if node.type == .hardBreak { return "\n" }
        return node.children.map(plainText).joined()
    }

    private static func countWords(_ text: String) -> Int {
        var count = 0
        var insideWord = false
        for scalar in text.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                if !insideWord {
                    count += 1
                    insideWord = true
                }
            } else {
                insideWord = false
            }
        }
        return count
    }
}

private extension EpdocJSONValue {
    var boolValue: Bool? {
        guard case .bool(let value) = self else { return nil }
        return value
    }
}
