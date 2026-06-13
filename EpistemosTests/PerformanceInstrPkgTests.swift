import Foundation
import Testing

/// Source-guard for the Wave 2.2 Tools/Performance.instrpkg
/// (`docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md`,
///  cross-ref dpp §1.1 Task 0.2).
///
/// The .instrpkg materialises the six OSSignposter categories declared
/// in Sig.swift (Wave 2.1) as Instruments.app tables. If the file
/// drifts out of sync with Sig.swift's category list, developers see
/// stale category names in Instruments — silent loss of observability.
///
/// This guard:
///   1. Confirms the file exists at the canonical path
///   2. Parses it as valid XML
///   3. Asserts every Sig category appears as an os-signpost-interval-schema
///   4. Asserts the canonical subsystem is referenced
///   5. Asserts every category from Sig.swift is mirrored here
///      (cross-checks both files via SourceMirror)
@Suite("Performance.instrpkg (Wave 2.2)")
nonisolated struct PerformanceInstrPkgTests {

    /// Sig.swift's six canonical OSSignposter categories. Mirror of
    /// `Epistemos/Telemetry/Sig.swift` — the test below confirms the
    /// mirror is exact.
    static let canonicalCategories: [String] = [
        "render", "mcp", "graph", "ffi", "storage", "inference",
    ]

    static let canonicalSubsystem = "io.epistemos.core"

    private static func loadText(_ relative: String) throws -> String {
        String(decoding: try loadMirroredSourceDataFile(relative), as: UTF8.self)
    }

    @Test("Performance.instrpkg mirrors Sig.swift")
    func instrPkgMirrorsSigSwift() throws {
        let url = try sourceMirrorURL(for: "Tools/Performance.instrpkg")
        #expect(
            FileManager.default.fileExists(atPath: url.path),
            "Tools/Performance.instrpkg must exist (Wave 2.2 deliverable)"
        )

        let xml = try Self.loadText("Tools/Performance.instrpkg")
        let shapeError = Self.xmlShapeError(in: xml)
        #expect(
            shapeError == nil,
            "Tools/Performance.instrpkg must parse as well-formed XML — \(shapeError ?? "unknown parser error")"
        )

        #expect(
            xml.contains("\"\(Self.canonicalSubsystem)\""),
            "Tools/Performance.instrpkg must reference subsystem \"\(Self.canonicalSubsystem)\" (matches Sig.swift)"
        )

        for category in Self.canonicalCategories {
            #expect(
                xml.contains("\"\(category)\""),
                "Tools/Performance.instrpkg must reference category \"\(category)\""
            )
            #expect(
                xml.contains("io.epistemos.core.\(category)-intervals"),
                "Tools/Performance.instrpkg must declare an interval schema id 'io.epistemos.core.\(category)-intervals'"
            )
        }

        let sigSource = try Self.loadText("Epistemos/Telemetry/Sig.swift")
        for category in Self.canonicalCategories {
            #expect(
                sigSource.contains("static let \(category)"),
                "Sig.swift must declare canonical category '\(category)' — mirror of PerformanceInstrPkgTests.canonicalCategories"
            )
        }
        // Also assert there is no EXTRA `static let X = OSSignposter(`
        // declaration in Sig.swift beyond our six. Cheap regex-y check
        // by counting OSSignposter inits.
        let signposterInitCount = sigSource.components(separatedBy: "OSSignposter(subsystem:").count - 1
        #expect(
            signposterInitCount == Self.canonicalCategories.count,
            "Sig.swift must declare exactly \(Self.canonicalCategories.count) OSSignposter instances; found \(signposterInitCount). Add the new category to Tools/Performance.instrpkg AND to PerformanceInstrPkgTests.canonicalCategories."
        )
    }

    private static func xmlShapeError(in xml: String) -> String? {
        let characters = Array(xml)
        var index = characters.startIndex
        var stack: [String] = []
        var rootCount = 0

        func starts(with token: String, at position: Int) -> Bool {
            let tokenCharacters = Array(token)
            guard position + tokenCharacters.count <= characters.count else { return false }
            return Array(characters[position..<(position + tokenCharacters.count)]) == tokenCharacters
        }

        func scan(until token: String, from position: Int) -> Int? {
            var cursor = position
            while cursor < characters.count {
                if starts(with: token, at: cursor) {
                    return cursor + token.count
                }
                cursor += 1
            }
            return nil
        }

        while index < characters.count {
            guard characters[index] == "<" else {
                index += 1
                continue
            }

            if starts(with: "<!--", at: index) {
                guard let next = scan(until: "-->", from: index + 4) else {
                    return "unterminated XML comment"
                }
                index = next
                continue
            }

            if starts(with: "<?", at: index) {
                guard let next = scan(until: "?>", from: index + 2) else {
                    return "unterminated XML processing instruction"
                }
                index = next
                continue
            }

            guard let closeIndex = scan(until: ">", from: index + 1) else {
                return "unterminated XML tag"
            }

            let rawTag = String(characters[(index + 1)..<(closeIndex - 1)])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawTag.isEmpty else {
                return "empty XML tag"
            }

            if rawTag.hasPrefix("/") {
                let name = rawTag.dropFirst()
                    .split(whereSeparator: { $0.isWhitespace })
                    .first
                    .map(String.init) ?? ""
                guard stack.popLast() == name else {
                    return "mismatched closing tag \(name)"
                }
            } else if !rawTag.hasPrefix("!") {
                let isSelfClosing = rawTag.hasSuffix("/")
                let name = rawTag
                    .dropLast(isSelfClosing ? 1 : 0)
                    .split(whereSeparator: { $0.isWhitespace })
                    .first
                    .map(String.init) ?? ""
                guard !name.isEmpty else {
                    return "missing XML tag name"
                }
                if stack.isEmpty {
                    rootCount += 1
                }
                if !isSelfClosing {
                    stack.append(name)
                }
            }

            index = closeIndex
        }

        if !stack.isEmpty {
            return "unclosed XML tags: \(stack.joined(separator: ", "))"
        }
        return rootCount == 1 ? nil : "expected one XML root element, found \(rootCount)"
    }
}
