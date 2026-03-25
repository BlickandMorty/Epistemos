import Foundation

// MARK: - AX Semantic Selector

/// CSS-style semantic selectors for AX tree element targeting.
/// Selectors use XPath-like syntax:
///   `//AXApplication[@AXTitle='Safari']//AXButton[@AXTitle='New Tab']`
///
/// This replaces brittle index-based targeting with semantic queries
/// that survive UI layout changes.
///
/// Selector syntax:
///   `//Role` — match any element with this role
///   `//Role[@Attr='Value']` — match role + attribute value
///   `//Role[contains(@Attr,'Substr')]` — match role + attribute substring
///   Chain with `//` to walk descendant axis
enum AXSemanticSelector {

    /// A parsed selector segment.
    struct Segment: Sendable {
        let role: String
        let predicates: [Predicate]
    }

    /// A predicate on an AX element attribute.
    enum Predicate: Sendable {
        case equals(attribute: String, value: String)
        case contains(attribute: String, substring: String)
    }

    /// A matched element from the AX tree.
    struct Match: Sendable {
        let index: Int
        let role: String
        let title: String
        let description: String
        let position: (x: Double, y: Double)?
        let size: (w: Double, h: Double)?
        let isInteractive: Bool
    }

    // MARK: - Parsing

    /// Parse a selector string into segments.
    /// e.g. `//AXApplication[@AXTitle='Safari']//AXButton[@AXTitle='New Tab']`
    static func parse(_ selector: String) -> [Segment] {
        // Split on "//" (descendant axis separator)
        let parts = selector.components(separatedBy: "//").filter { !$0.isEmpty }
        return parts.compactMap { parseSegment($0) }
    }

    private static func parseSegment(_ raw: String) -> Segment? {
        var s = raw.trimmingCharacters(in: .whitespaces)
        var predicates: [Predicate] = []

        // Extract predicates in [...] brackets
        while let bracketStart = s.firstIndex(of: "["),
              let bracketEnd = s[bracketStart...].firstIndex(of: "]") {
            let predicateStr = String(s[s.index(after: bracketStart)..<bracketEnd])
            if let pred = parsePredicate(predicateStr) {
                predicates.append(pred)
            }
            s = String(s[s.startIndex..<bracketStart]) + String(s[s.index(after: bracketEnd)...])
        }

        let role = s.trimmingCharacters(in: .whitespaces)
        guard !role.isEmpty else { return nil }
        return Segment(role: role, predicates: predicates)
    }

    private static func parsePredicate(_ raw: String) -> Predicate? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)

        // contains(@Attr,'Value')
        if trimmed.hasPrefix("contains(") && trimmed.hasSuffix(")") {
            let inner = String(trimmed.dropFirst(9).dropLast(1))
            let parts = inner.components(separatedBy: ",")
            guard parts.count == 2 else { return nil }
            let attr = parts[0].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "@", with: "")
            let val = parts[1].trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
            return .contains(attribute: attr, substring: val)
        }

        // @Attr='Value'
        if trimmed.contains("=") {
            let parts = trimmed.components(separatedBy: "=")
            guard parts.count == 2 else { return nil }
            let attr = parts[0].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "@", with: "")
            let val = parts[1].trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
            return .equals(attribute: attr, value: val)
        }

        return nil
    }

    // MARK: - Resolution

    /// Resolve a selector against an AX tree JSON (from omega-ax walkAxTreeJson).
    /// Returns all matching elements.
    static func resolve(selector: String, axTreeJson: String) -> [Match] {
        let segments = parse(selector)
        guard !segments.isEmpty else { return [] }

        guard let data = axTreeJson.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let elements = json["elements"] as? [[String: Any]] else {
            return []
        }

        // Progressive filtering: each segment narrows the candidate set
        var candidates = Array(elements.enumerated())

        for segment in segments {
            candidates = candidates.filter { (_, elem) in
                matchesSegment(elem, segment: segment)
            }
        }

        return candidates.map { (idx, elem) in
            let pos: (Double, Double)?
            if let x = elem["position_x"] as? Double, let y = elem["position_y"] as? Double {
                pos = (x, y)
            } else {
                pos = nil
            }
            let size: (Double, Double)?
            if let w = elem["size_width"] as? Double, let h = elem["size_height"] as? Double {
                size = (w, h)
            } else {
                size = nil
            }
            return Match(
                index: idx,
                role: elem["role"] as? String ?? "",
                title: elem["title"] as? String ?? "",
                description: elem["description"] as? String ?? "",
                position: pos,
                size: size,
                isInteractive: elem["is_interactive"] as? Bool ?? false
            )
        }
    }

    /// Find the best match: interactive elements preferred, then by specificity.
    static func resolveBest(selector: String, axTreeJson: String) -> Match? {
        let matches = resolve(selector: selector, axTreeJson: axTreeJson)
        // Prefer interactive elements
        if let interactive = matches.first(where: { $0.isInteractive }) {
            return interactive
        }
        return matches.first
    }

    /// Build a selector string from a match (reverse: element → selector).
    static func buildSelector(role: String, title: String? = nil, description: String? = nil) -> String {
        var selector = "//\(role)"
        if let title, !title.isEmpty {
            selector += "[@AXTitle='\(title)']"
        }
        if let desc = description, !desc.isEmpty {
            selector += "[@AXDescription='\(desc)']"
        }
        return selector
    }

    // MARK: - Matching

    private static func matchesSegment(_ element: [String: Any], segment: Segment) -> Bool {
        let role = element["role"] as? String ?? ""
        guard role == segment.role else { return false }

        for predicate in segment.predicates {
            switch predicate {
            case .equals(let attr, let value):
                let attrValue = attributeValue(element, attribute: attr)
                guard attrValue == value else { return false }
            case .contains(let attr, let substring):
                let attrValue = attributeValue(element, attribute: attr)
                guard attrValue.localizedCaseInsensitiveContains(substring) else { return false }
            }
        }
        return true
    }

    private static func attributeValue(_ element: [String: Any], attribute: String) -> String {
        switch attribute {
        case "AXTitle": return element["title"] as? String ?? ""
        case "AXDescription": return element["description"] as? String ?? ""
        case "AXValue": return element["value"] as? String ?? ""
        case "AXRole": return element["role"] as? String ?? ""
        default: return element[attribute] as? String ?? ""
        }
    }
}
