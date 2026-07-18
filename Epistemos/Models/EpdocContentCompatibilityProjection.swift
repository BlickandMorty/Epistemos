import Foundation

/// Save/index-time compatibility adapter for subsystems that still consume the
/// old ProseMirror value shape. The returned tree is derived and never written
/// as a second canonical Epdoc authority.
nonisolated enum EpdocContentCompatibilityProjection {
    static func proseMirrorNode(from canonicalJSON: Data) -> ProseMirrorNode? {
        if let legacy = try? JSONDecoder().decode(ProseMirrorNode.self, from: canonicalJSON),
           legacy.type == "doc" {
            return legacy
        }
        guard let envelope = try? JSONDecoder.epdocCanonical.decode(
            EpdocContentEnvelope.self,
            from: canonicalJSON
        ),
        (try? envelope.validate()) != nil else {
            return nil
        }
        return project(envelope.root)
    }

    static func proseMirrorJSON(from canonicalJSON: Data) -> Data? {
        guard let node = proseMirrorNode(from: canonicalJSON) else { return nil }
        return try? JSONEncoder().encode(node)
    }

    private static func project(_ node: EpdocRichNode) -> ProseMirrorNode {
        let projectedChildren = node.children.map(project)
        let projectedMarks = node.marks.map { mark in
            ProseMirrorMark(
                type: proseMirrorMarkType(mark.type),
                attrs: proseMirrorAttributes(mark.attributes)
            )
        }
        return ProseMirrorNode(
            type: proseMirrorNodeType(node.type),
            attrs: proseMirrorAttributes(node.attributes, fallbackID: node.id),
            content: projectedChildren.isEmpty ? nil : projectedChildren,
            marks: projectedMarks.isEmpty ? nil : projectedMarks,
            text: node.text
        )
    }

    private static func proseMirrorNodeType(_ type: EpdocNodeType) -> String {
        switch type {
        case .document: "doc"
        case .codeBlock: "codeBlock"
        case .bulletList: "bulletList"
        case .orderedList: "orderedList"
        case .listItem: "listItem"
        case .checklist: "taskList"
        case .checklistItem: "taskItem"
        case .horizontalRule: "horizontalRule"
        case .hardBreak: "hardBreak"
        case .tableRow: "tableRow"
        case .tableHeader: "tableHeader"
        case .tableCell: "tableCell"
        case .mathBlock: "blockMath"
        case .opaqueLegacy: "paragraph"
        default: type.rawValue
        }
    }

    private static func proseMirrorMarkType(_ type: EpdocMarkType) -> String {
        switch type {
        case .bold: "strong"
        case .italic: "em"
        case .strikethrough: "strike"
        default: type.rawValue
        }
    }

    private static func proseMirrorAttributes(
        _ values: [String: EpdocJSONValue],
        fallbackID: String? = nil
    ) -> ProseMirrorAttrs? {
        let level = int(values["level"])
        let href = string(values["href"])
        let language = string(values["language"])
        let title = string(values["title"])
        let formula = string(values["formula"])
        let latex = string(values["latex"])
        let src = string(values["src"])
        let alt = string(values["alt"])
        let id = string(values["id"]) ?? fallbackID
        let checked = bool(values["checked"])
        let kind = string(values["kind"])
        guard level != nil || href != nil || language != nil || title != nil
                || formula != nil || latex != nil || src != nil || alt != nil
                || id != nil || checked != nil || kind != nil else {
            return nil
        }
        return ProseMirrorAttrs(
            level: level,
            href: href,
            language: language,
            title: title,
            formula: formula,
            latex: latex,
            src: src,
            alt: alt,
            id: id,
            checked: checked,
            kind: kind
        )
    }

    private static func string(_ value: EpdocJSONValue?) -> String? {
        guard case .string(let value) = value else { return nil }
        return value
    }

    private static func int(_ value: EpdocJSONValue?) -> Int? {
        guard case .int(let value) = value else { return nil }
        return value
    }

    private static func bool(_ value: EpdocJSONValue?) -> Bool? {
        guard case .bool(let value) = value else { return nil }
        return value
    }
}
