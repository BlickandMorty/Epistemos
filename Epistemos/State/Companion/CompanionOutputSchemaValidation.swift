import Foundation

/// Retired validator for older Companion rows that stored an output-structure
/// JSON field. Kept pure + `nonisolated` for compatibility with existing tests.
///
/// It deliberately does NOT fully validate JSON Schema — only that the text is a
/// JSON object shaped like a schema (`type` or `properties`) — so honest schemas
/// pass while obvious mistakes (trailing commas, a bare string, a non-schema
/// object) are caught with an actionable message.
nonisolated enum CompanionOutputSchemaValidation {
    enum Result: Equatable {
        /// No schema entered — valid, since the field is optional.
        case empty
        case valid
        case invalid(String)

        /// Whether the form may be saved with this value.
        var isAcceptable: Bool {
            switch self {
            case .empty, .valid: true
            case .invalid: false
            }
        }

        var errorMessage: String? {
            if case .invalid(let reason) = self { return reason }
            return nil
        }
    }

    static func validate(_ raw: String) -> Result {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }
        guard let data = trimmed.data(using: .utf8) else {
            return .invalid("Couldn't read the schema text.")
        }
        guard !containsTrailingCommaBeforeClose(trimmed) else {
            return .invalid("Not valid JSON — check for trailing commas or unquoted keys.")
        }
        let parsed: Any
        do {
            parsed = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            return .invalid("Not valid JSON — check for trailing commas or unquoted keys.")
        }
        guard let object = parsed as? [String: Any] else {
            return .invalid(#"The schema must be a JSON object, e.g. {"type":"object", ...}."#)
        }
        guard object["type"] != nil || object["properties"] != nil else {
            return .invalid(#"Add a "type" or "properties" key so it reads as a schema."#)
        }
        return .valid
    }

    private static func containsTrailingCommaBeforeClose(_ source: String) -> Bool {
        var inString = false
        var isEscaped = false
        var previousSignificant: Character?

        for character in source {
            if inString {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    inString = false
                }
                continue
            }

            if character == "\"" {
                inString = true
                previousSignificant = character
                continue
            }

            if character.isWhitespace {
                continue
            }

            if (character == "}" || character == "]"), previousSignificant == "," {
                return true
            }

            previousSignificant = character
        }

        return false
    }
}
