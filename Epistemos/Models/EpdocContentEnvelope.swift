import CryptoKit
import Foundation

/// Engine-neutral scalar/container values used by the canonical Epdoc rich
/// node tree. Keeping attributes typed prevents an editor adapter from owning
/// the on-disk schema while still allowing additive node metadata.
nonisolated public enum EpdocJSONValue: Codable, Sendable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    case array([EpdocJSONValue])
    case object([String: EpdocJSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([EpdocJSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: EpdocJSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported Epdoc JSON value"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}

nonisolated public struct EpdocNodeType: RawRepresentable, Codable, Sendable, Hashable,
    ExpressibleByStringLiteral
{
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: StringLiteralType) {
        self.init(rawValue: value)
    }

    public static let document: Self = "document"
    public static let paragraph: Self = "paragraph"
    public static let heading: Self = "heading"
    public static let blockquote: Self = "blockquote"
    public static let codeBlock: Self = "code_block"
    public static let bulletList: Self = "bullet_list"
    public static let orderedList: Self = "ordered_list"
    public static let listItem: Self = "list_item"
    public static let checklist: Self = "checklist"
    public static let checklistItem: Self = "checklist_item"
    public static let horizontalRule: Self = "horizontal_rule"
    public static let hardBreak: Self = "hard_break"
    public static let table: Self = "table"
    public static let tableRow: Self = "table_row"
    public static let tableHeader: Self = "table_header"
    public static let tableCell: Self = "table_cell"
    public static let image: Self = "image"
    public static let audio: Self = "audio"
    public static let drawing: Self = "drawing"
    public static let pdf: Self = "pdf"
    public static let callout: Self = "callout"
    public static let chart: Self = "chart"
    public static let mathBlock: Self = "math_block"
    public static let footnote: Self = "footnote"
    public static let text: Self = "text"
    public static let opaqueLegacy: Self = "opaque_legacy"

    var requiresStableID: Bool {
        self != .text && self != .hardBreak
    }
}

nonisolated public struct EpdocMarkType: RawRepresentable, Codable, Sendable, Hashable,
    ExpressibleByStringLiteral
{
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: StringLiteralType) {
        self.init(rawValue: value)
    }

    public static let bold: Self = "bold"
    public static let italic: Self = "italic"
    public static let underline: Self = "underline"
    public static let strikethrough: Self = "strikethrough"
    public static let code: Self = "code"
    public static let link: Self = "link"
    public static let highlight: Self = "highlight"
}

nonisolated public struct EpdocTextMark: Codable, Sendable, Hashable {
    public let type: EpdocMarkType
    public let attributes: [String: EpdocJSONValue]

    public init(
        type: EpdocMarkType,
        attributes: [String: EpdocJSONValue] = [:]
    ) {
        self.type = type
        self.attributes = attributes
    }
}

/// One canonical node in an Epdoc rich document. Block/object nodes require a
/// stable ID; text and hard-break leaves intentionally do not. The recursive
/// shape is independent of TextKit, Plate, Lexical, or ProseMirror.
nonisolated public struct EpdocRichNode: Codable, Sendable, Hashable {
    public let id: String?
    public let type: EpdocNodeType
    public let attributes: [String: EpdocJSONValue]
    public let text: String?
    public let marks: [EpdocTextMark]
    public let children: [EpdocRichNode]

    public init(
        id: String? = nil,
        type: EpdocNodeType,
        attributes: [String: EpdocJSONValue] = [:],
        text: String? = nil,
        marks: [EpdocTextMark] = [],
        children: [EpdocRichNode] = []
    ) {
        self.id = id
        self.type = type
        self.attributes = attributes
        self.text = text
        self.marks = marks
        self.children = children
    }
}

nonisolated public enum EpdocContentValidationError: Error, Sendable, Hashable {
    case schemaTooNew(UInt32)
    case unsupportedFormat(String)
    case emptyDocumentID
    case rootMustBeDocument
    case missingStableID(type: String, path: String)
    case duplicateNodeID(String)
    case malformedTextNode(path: String)
    case unexpectedText(type: String, path: String)
    case invalidChild(parent: String, child: String, path: String)
    case maximumDepthExceeded(Int)
}

/// Canonical `content.json` body for a JSON-native `.epdoc` package.
nonisolated public struct EpdocContentEnvelope: Codable, Sendable, Hashable {
    public static let currentSchemaVersion: UInt32 = 1
    public static let formatIdentifier = "epistemos.rich-blocks.v1"
    public static let maximumDepth = 128

    public let schemaVersion: UInt32
    public let format: String
    public let documentID: String
    public let revision: UInt64
    public let root: EpdocRichNode

    public init(
        schemaVersion: UInt32 = currentSchemaVersion,
        format: String = formatIdentifier,
        documentID: String,
        revision: UInt64 = 0,
        root: EpdocRichNode
    ) {
        self.schemaVersion = schemaVersion
        self.format = format
        self.documentID = documentID
        self.revision = revision
        self.root = root
    }

    public static func empty(documentID: String) -> Self {
        Self(
            documentID: documentID,
            root: EpdocRichNode(
                id: "\(documentID):root",
                type: .document,
                children: [
                    EpdocRichNode(
                        id: "\(documentID):paragraph:0",
                        type: .paragraph
                    ),
                ]
            )
        )
    }

    public func validate() throws {
        guard schemaVersion <= Self.currentSchemaVersion else {
            throw EpdocContentValidationError.schemaTooNew(schemaVersion)
        }
        guard format == Self.formatIdentifier else {
            throw EpdocContentValidationError.unsupportedFormat(format)
        }
        guard !documentID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EpdocContentValidationError.emptyDocumentID
        }
        guard root.type == .document else {
            throw EpdocContentValidationError.rootMustBeDocument
        }

        var nodeIDs = Set<String>()
        try Self.validate(
            root,
            path: "root",
            depth: 0,
            nodeIDs: &nodeIDs
        )
    }

    private static func validate(
        _ node: EpdocRichNode,
        path: String,
        depth: Int,
        nodeIDs: inout Set<String>
    ) throws {
        guard depth <= maximumDepth else {
            throw EpdocContentValidationError.maximumDepthExceeded(depth)
        }

        if node.type.requiresStableID {
            guard let id = node.id?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !id.isEmpty else {
                throw EpdocContentValidationError.missingStableID(
                    type: node.type.rawValue,
                    path: path
                )
            }
            guard nodeIDs.insert(id).inserted else {
                throw EpdocContentValidationError.duplicateNodeID(id)
            }
        }

        if node.type == .text {
            guard node.text != nil, node.children.isEmpty else {
                throw EpdocContentValidationError.malformedTextNode(path: path)
            }
        } else if node.text != nil {
            throw EpdocContentValidationError.unexpectedText(
                type: node.type.rawValue,
                path: path
            )
        }

        for (index, child) in node.children.enumerated() {
            guard allows(parent: node.type, child: child.type) else {
                throw EpdocContentValidationError.invalidChild(
                    parent: node.type.rawValue,
                    child: child.type.rawValue,
                    path: "\(path).children[\(index)]"
                )
            }
            try validate(
                child,
                path: "\(path).children[\(index)]",
                depth: depth + 1,
                nodeIDs: &nodeIDs
            )
        }
    }

    private static func allows(parent: EpdocNodeType, child: EpdocNodeType) -> Bool {
        switch parent {
        case .document:
            return child != .text && child != .hardBreak
        case .paragraph, .heading:
            return child == .text || child == .hardBreak || child == .image
                || child == .audio || child == .drawing || child == .footnote
        case .bulletList, .orderedList:
            return child == .listItem
        case .checklist:
            return child == .checklistItem
        case .table:
            return child == .tableRow
        case .tableRow:
            return child == .tableHeader || child == .tableCell
        case .tableHeader, .tableCell, .listItem, .checklistItem, .blockquote,
             .callout, .footnote:
            return child != .document
        case .codeBlock:
            return child == .text || child == .hardBreak
        case .opaqueLegacy:
            return child != .document
        case .text, .hardBreak, .horizontalRule, .image, .audio, .drawing, .pdf,
             .chart, .mathBlock:
            return false
        default:
            return child != .document
        }
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case format
        case documentID = "document_id"
        case revision
        case root
    }
}

nonisolated public struct EpdocContentMigrationReceipt: Codable, Sendable, Hashable {
    public let sourceFormat: String
    public let targetFormat: String
    public let migratedAt: Int64
    public let sourceByteCount: Int
    public let sourceSHA256: String
    public let sourceNodeCount: Int
    public let targetNodeCount: Int
    public let opaqueNodeCount: Int
    public let sourcePlainTextSHA256: String
    public let targetPlainTextSHA256: String
    public let warnings: [String]

    enum CodingKeys: String, CodingKey {
        case sourceFormat = "source_format"
        case targetFormat = "target_format"
        case migratedAt = "migrated_at"
        case sourceByteCount = "source_byte_count"
        case sourceSHA256 = "source_sha256"
        case sourceNodeCount = "source_node_count"
        case targetNodeCount = "target_node_count"
        case opaqueNodeCount = "opaque_node_count"
        case sourcePlainTextSHA256 = "source_plain_text_sha256"
        case targetPlainTextSHA256 = "target_plain_text_sha256"
        case warnings
    }
}

nonisolated public struct EpdocLegacyMigrationResult: Sendable, Hashable {
    public let envelope: EpdocContentEnvelope
    public let receipt: EpdocContentMigrationReceipt
    public let originalContent: Data
}

nonisolated public enum EpdocLegacyMigrationError: Error, Sendable, Hashable {
    case malformedProseMirrorJSON
    case plainTextDigestMismatch
}

/// One-way, deterministic importer for schema-v1 ProseMirror package bodies.
/// The returned original bytes are archived by the package layer until the
/// receipt and reopened canonical content have been verified.
nonisolated public enum EpdocLegacyProseMirrorMigrator {
    public static func migrate(
        _ data: Data,
        documentID: String,
        migratedAt: Int64
    ) throws -> EpdocLegacyMigrationResult {
        let decoder = JSONDecoder()
        guard let legacyRoot = try? decoder.decode(LegacyNode.self, from: data),
              legacyRoot.type == "doc" else {
            throw EpdocLegacyMigrationError.malformedProseMirrorJSON
        }

        var context = MigrationContext()
        let root = try migrateNode(
            legacyRoot,
            documentID: documentID,
            path: [],
            context: &context
        )
        let envelope = EpdocContentEnvelope(
            documentID: documentID,
            root: root
        )
        try envelope.validate()

        let sourcePlainText = legacyPlainText(legacyRoot)
        let targetPlainText = richPlainText(root)
        let sourcePlainTextDigest = sha256(Data(sourcePlainText.utf8))
        let targetPlainTextDigest = sha256(Data(targetPlainText.utf8))
        guard sourcePlainTextDigest == targetPlainTextDigest else {
            throw EpdocLegacyMigrationError.plainTextDigestMismatch
        }

        let receipt = EpdocContentMigrationReceipt(
            sourceFormat: "prosemirror.v1",
            targetFormat: EpdocContentEnvelope.formatIdentifier,
            migratedAt: migratedAt,
            sourceByteCount: data.count,
            sourceSHA256: sha256(data),
            sourceNodeCount: countLegacyNodes(legacyRoot),
            targetNodeCount: countRichNodes(root),
            opaqueNodeCount: context.opaqueNodeCount,
            sourcePlainTextSHA256: sourcePlainTextDigest,
            targetPlainTextSHA256: targetPlainTextDigest,
            warnings: context.warnings
        )
        return EpdocLegacyMigrationResult(
            envelope: envelope,
            receipt: receipt,
            originalContent: data
        )
    }

    private struct LegacyNode: Codable {
        let type: String
        let attrs: [String: EpdocJSONValue]?
        let content: [LegacyNode]?
        let text: String?
        let marks: [LegacyMark]?
    }

    private struct LegacyMark: Codable {
        let type: String
        let attrs: [String: EpdocJSONValue]?
    }

    private struct MigrationContext {
        var opaqueNodeCount = 0
        var warnings: [String] = []
    }

    private static func migrateNode(
        _ node: LegacyNode,
        documentID: String,
        path: [Int],
        context: inout MigrationContext
    ) throws -> EpdocRichNode {
        let mappedType = mappedNodeType(node.type)
        let isOpaque = mappedType == .opaqueLegacy
        var attributes = node.attrs ?? [:]
        if isOpaque {
            context.opaqueNodeCount += 1
            context.warnings.append(
                "Preserved unsupported ProseMirror node '\(node.type)' as opaque legacy content at \(pathLabel(path))."
            )
            attributes["legacy_type"] = .string(node.type)
            attributes["legacy_payload"] = try legacyPayload(node)
        }

        let migratedChildren = try (node.content ?? []).enumerated().map { index, child in
            try migrateNode(
                child,
                documentID: documentID,
                path: path + [index],
                context: &context
            )
        }
        let migratedMarks = (node.marks ?? []).map { mark in
            EpdocTextMark(
                type: mappedMarkType(mark.type),
                attributes: mark.attrs ?? [:]
            )
        }

        let id: String?
        if mappedType == .document {
            id = "\(documentID):root"
        } else if mappedType.requiresStableID {
            id = stableLegacyID(
                preferred: node.attrs?["id"],
                type: node.type,
                path: path
            )
        } else {
            id = nil
        }

        return EpdocRichNode(
            id: id,
            type: mappedType,
            attributes: attributes,
            text: mappedType == .text ? (node.text ?? "") : nil,
            marks: migratedMarks,
            children: migratedChildren
        )
    }

    private static func mappedNodeType(_ legacyType: String) -> EpdocNodeType {
        switch legacyType {
        case "doc": .document
        case "paragraph": .paragraph
        case "heading": .heading
        case "blockquote": .blockquote
        case "codeBlock", "code_block": .codeBlock
        case "bulletList", "bullet_list": .bulletList
        case "orderedList", "ordered_list": .orderedList
        case "listItem", "list_item": .listItem
        case "taskList", "checklist": .checklist
        case "taskItem", "checklist_item": .checklistItem
        case "horizontalRule", "horizontal_rule": .horizontalRule
        case "hardBreak", "hard_break": .hardBreak
        case "table": .table
        case "tableRow", "table_row": .tableRow
        case "tableHeader", "table_header": .tableHeader
        case "tableCell", "table_cell": .tableCell
        case "image": .image
        case "audio": .audio
        case "drawing": .drawing
        case "pdf": .pdf
        case "callout": .callout
        case "chart": .chart
        case "mathematics", "mathBlock", "math_block": .mathBlock
        case "footnote": .footnote
        case "text": .text
        default: .opaqueLegacy
        }
    }

    private static func mappedMarkType(_ legacyType: String) -> EpdocMarkType {
        switch legacyType {
        case "bold", "strong": .bold
        case "italic", "em": .italic
        case "underline": .underline
        case "strike", "strikethrough": .strikethrough
        case "code": .code
        case "link": .link
        case "highlight": .highlight
        default: EpdocMarkType(rawValue: "legacy.\(legacyType)")
        }
    }

    private static func stableLegacyID(
        preferred: EpdocJSONValue?,
        type: String,
        path: [Int]
    ) -> String {
        if case .string(let value) = preferred {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        let safeType = type.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(String(scalar)) : "-"
        }
        let suffix = path.isEmpty ? "root" : path.map(String.init).joined(separator: "-")
        return "legacy-\(String(safeType))-\(suffix)"
    }

    private static func legacyPayload(_ node: LegacyNode) throws -> EpdocJSONValue {
        let data = try JSONEncoder().encode(node)
        return try JSONDecoder().decode(EpdocJSONValue.self, from: data)
    }

    private static func pathLabel(_ path: [Int]) -> String {
        path.isEmpty ? "root" : "root." + path.map(String.init).joined(separator: ".")
    }

    private static func countLegacyNodes(_ node: LegacyNode) -> Int {
        1 + (node.content ?? []).reduce(0) { $0 + countLegacyNodes($1) }
    }

    private static func countRichNodes(_ node: EpdocRichNode) -> Int {
        1 + node.children.reduce(0) { $0 + countRichNodes($1) }
    }

    private static func legacyPlainText(_ node: LegacyNode) -> String {
        if node.type == "text" { return node.text ?? "" }
        if node.type == "hardBreak" || node.type == "hard_break" { return "\n" }
        let children = node.content ?? []
        let separator = legacyChildrenAreInline(children) ? "" : "\n"
        return children.map(legacyPlainText).joined(separator: separator)
    }

    private static func legacyChildrenAreInline(_ nodes: [LegacyNode]) -> Bool {
        nodes.allSatisfy { $0.type == "text" || $0.type == "hardBreak" || $0.type == "hard_break" }
    }

    private static func richPlainText(_ node: EpdocRichNode) -> String {
        if node.type == .text { return node.text ?? "" }
        if node.type == .hardBreak { return "\n" }
        let separator = node.children.allSatisfy {
            $0.type == .text || $0.type == .hardBreak
        } ? "" : "\n"
        return node.children.map(richPlainText).joined(separator: separator)
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
