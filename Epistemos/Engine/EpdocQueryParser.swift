import Foundation

// MARK: - EpdocQueryParser
//
// Wave 7.13.b of the Extended Program Plan.
//
// Recursive-descent parser for the Logseq-borrowed s-expression query
// surface. Reads source text → `EpdocQueryAST` (W7.13.a) which the
// evaluator runs against the W7.13 EpdocDatabase actor.
//
// ## Grammar (V1)
//
//     query     := atom | combinator
//     combinator := '(' head ws+ query (ws+ query)* ws* ')'
//     head      := 'and' | 'or' | 'not' | 'property' | 'property-any-of'
//                | 'between' | 'title-contains' | 'kind' | 'rule'
//                | 'always-true' | 'always-false'
//     atom      := bare-token  (treated as title-contains shorthand)
//
//     // property forms
//     '(property' <id> <value-expr> ')'
//     '(property-any-of' <id> '[' <value-expr>+ ']' ')'
//
//     // value-expr is dispatched on the FIRST token:
//     value-expr := select <token>          ; .select
//                 | multi-select '[' tokens ']'
//                 | date <iso-or-bare>
//                 | number <numeric>
//                 | checkbox (true|false)
//                 | url <token>
//                 | email <token>
//                 | text <token-or-quoted>
//
//     // between
//     '(between' <field> <time-ref> <time-ref> ')'
//     field     := 'created-at' | 'updated-at' | 'property' <id>
//     time-ref  := 'now' | 'today' | <signed-N><'d'|'w'|'m'|'y'> | <iso8601>
//
// Strings can be quoted with `"…"` to embed whitespace; escapes follow
// the standard `\\`, `\"`, `\n`, `\t` set.
//
// ## Examples
//
//     (and (property status (select doing)) (title-contains alpha))
//     (or (kind document) (kind note))
//     (not (property status (select done)))
//     (between created-at -7d today)
//     (between (property due) today +30d)
//     (rule has-property (property status (select any)))

nonisolated public enum EpdocQueryParseError: Error, CustomStringConvertible {
    case unexpectedCharacter(String, position: Int)
    case unexpectedEndOfInput
    case unbalancedParens
    case unknownHead(String, position: Int)
    case malformedTimeRef(String)
    case malformedNumber(String)
    case malformedBoolean(String)
    case malformedKind(String)

    public var description: String {
        switch self {
        case let .unexpectedCharacter(c, p): return "EpdocQueryParser: unexpected '\(c)' at position \(p)"
        case .unexpectedEndOfInput:          return "EpdocQueryParser: unexpected end of input"
        case .unbalancedParens:              return "EpdocQueryParser: unbalanced parentheses"
        case let .unknownHead(s, p):         return "EpdocQueryParser: unknown head '\(s)' at position \(p)"
        case let .malformedTimeRef(s):       return "EpdocQueryParser: malformed time-ref '\(s)' (try today / -7d / +1y / ISO date)"
        case let .malformedNumber(s):        return "EpdocQueryParser: malformed number '\(s)'"
        case let .malformedBoolean(s):       return "EpdocQueryParser: malformed boolean '\(s)' (expected true/false)"
        case let .malformedKind(s):          return "EpdocQueryParser: malformed kind '\(s)' (expected ArtifactKind raw value)"
        }
    }
}

nonisolated public enum EpdocQueryParser {

    /// Parse a complete query string into an AST.
    public static func parse(_ source: String) throws -> EpdocQueryAST {
        var p = Parser(source: source)
        let ast = try p.parseQuery()
        p.skipWhitespace()
        guard p.eof else {
            throw EpdocQueryParseError.unexpectedCharacter(String(p.peek() ?? Character(" ")),
                                                           position: p.position)
        }
        return ast
    }

    // MARK: - Tokenizer + parser state

    fileprivate struct Parser {
        let source: [Character]
        var idx: Int = 0
        init(source: String) { self.source = Array(source) }

        var eof: Bool { idx >= source.count }
        var position: Int { idx }
        func peek() -> Character? { eof ? nil : source[idx] }
        mutating func advance() { idx += 1 }
        mutating func consume(_ c: Character) -> Bool {
            if peek() == c { advance(); return true }
            return false
        }

        mutating func skipWhitespace() {
            while !eof, source[idx].isWhitespace { idx += 1 }
        }

        /// Read the next bare token (run of non-whitespace, non-paren,
        /// non-bracket chars). Empty string when at a delimiter.
        mutating func readBareToken() -> String {
            skipWhitespace()
            var out = ""
            while !eof {
                let c = source[idx]
                if c.isWhitespace || c == "(" || c == ")" || c == "[" || c == "]" { break }
                out.append(c)
                idx += 1
            }
            return out
        }

        /// Read either a quoted string or a bare token.
        mutating func readToken() throws -> String {
            skipWhitespace()
            guard !eof else { throw EpdocQueryParseError.unexpectedEndOfInput }
            if source[idx] == "\"" { return try readQuotedString() }
            return readBareToken()
        }

        private mutating func readQuotedString() throws -> String {
            // Caller guaranteed peek == "
            advance()
            var out = ""
            while !eof {
                let c = source[idx]
                if c == "\"" { advance(); return out }
                if c == "\\" {
                    advance()
                    guard !eof else { throw EpdocQueryParseError.unexpectedEndOfInput }
                    switch source[idx] {
                    case "n":  out.append("\n")
                    case "t":  out.append("\t")
                    case "\\": out.append("\\")
                    case "\"": out.append("\"")
                    default:   out.append(source[idx])
                    }
                    advance()
                    continue
                }
                out.append(c)
                advance()
            }
            throw EpdocQueryParseError.unexpectedEndOfInput
        }

        // MARK: - Query

        mutating func parseQuery() throws -> EpdocQueryAST {
            skipWhitespace()
            guard !eof else { throw EpdocQueryParseError.unexpectedEndOfInput }
            if source[idx] == "(" {
                return try parseSExpr()
            }
            // Bare atom → title-contains shorthand for ergonomics.
            let token = try readToken()
            return .titleContains(token)
        }

        mutating func parseSExpr() throws -> EpdocQueryAST {
            // Caller checked peek == "("
            let openPos = idx
            advance()  // (
            skipWhitespace()
            let head = readBareToken()
            switch head {
            case "and":
                let children = try parseQueryList()
                try expectClose()
                return .and(children)
            case "or":
                let children = try parseQueryList()
                try expectClose()
                return .or(children)
            case "not":
                skipWhitespace()
                let child = try parseQuery()
                try expectClose()
                return .not(child)
            case "property":
                skipWhitespace()
                let id = try readToken()
                let value = try parsePropertyValue()
                try expectClose()
                return .property(id: id, equals: value)
            case "property-any-of":
                skipWhitespace()
                let id = try readToken()
                let values = try parsePropertyValueList()
                try expectClose()
                return .propertyAnyOf(id: id, equalsAny: values)
            case "between":
                skipWhitespace()
                let field = try parseBetweenField()
                skipWhitespace()
                let start = try parseTimeRef(readToken())
                skipWhitespace()
                let end = try parseTimeRef(readToken())
                try expectClose()
                return .between(field: field, start: start, end: end)
            case "title-contains":
                skipWhitespace()
                let needle = try readToken()
                try expectClose()
                return .titleContains(needle)
            case "kind":
                skipWhitespace()
                let raw = try readToken()
                guard let intRaw = UInt8(raw), let kind = ArtifactKind(rawValue: intRaw) else {
                    throw EpdocQueryParseError.malformedKind(raw)
                }
                try expectClose()
                return .kind(kind)
            case "rule":
                skipWhitespace()
                let name = try readToken()
                let args = try parseQueryList()
                try expectClose()
                return .rule(name: name, args: args)
            case "always-true":
                try expectClose()
                return .alwaysTrue
            case "always-false":
                try expectClose()
                return .alwaysFalse
            default:
                throw EpdocQueryParseError.unknownHead(head, position: openPos)
            }
        }

        mutating func parseQueryList() throws -> [EpdocQueryAST] {
            var out: [EpdocQueryAST] = []
            while true {
                skipWhitespace()
                guard !eof else { throw EpdocQueryParseError.unexpectedEndOfInput }
                if source[idx] == ")" { return out }
                out.append(try parseQuery())
            }
        }

        mutating func expectClose() throws {
            skipWhitespace()
            guard !eof else { throw EpdocQueryParseError.unexpectedEndOfInput }
            guard source[idx] == ")" else {
                throw EpdocQueryParseError.unbalancedParens
            }
            advance()
        }

        // MARK: - Property values

        mutating func parsePropertyValue() throws -> EpdocPropertyValue {
            skipWhitespace()
            guard !eof else { throw EpdocQueryParseError.unexpectedEndOfInput }
            if source[idx] == "(" {
                advance()  // (
                skipWhitespace()
                let kindToken = readBareToken()
                let value = try parsePropertyValueBody(kind: kindToken)
                try expectClose()
                return value
            }
            // Bare value (no kind tag) → infer text.
            return .text(try readToken())
        }

        mutating func parsePropertyValueList() throws -> [EpdocPropertyValue] {
            skipWhitespace()
            guard !eof, source[idx] == "[" else {
                throw EpdocQueryParseError.unexpectedCharacter(String(peek() ?? Character(" ")),
                                                              position: idx)
            }
            advance()  // [
            var out: [EpdocPropertyValue] = []
            while true {
                skipWhitespace()
                guard !eof else { throw EpdocQueryParseError.unexpectedEndOfInput }
                if source[idx] == "]" { advance(); return out }
                out.append(try parsePropertyValue())
            }
        }

        mutating func parsePropertyValueBody(kind: String) throws -> EpdocPropertyValue {
            skipWhitespace()
            switch kind {
            case "select":
                return .select(try readToken())
            case "multi-select":
                guard consume("[") else {
                    throw EpdocQueryParseError.unexpectedCharacter(String(peek() ?? Character(" ")),
                                                                  position: idx)
                }
                var values: [String] = []
                while true {
                    skipWhitespace()
                    guard !eof else { throw EpdocQueryParseError.unexpectedEndOfInput }
                    if source[idx] == "]" { advance(); return .multiSelect(values) }
                    values.append(try readToken())
                }
            case "date":
                return .date(try readToken())
            case "number":
                let raw = try readToken()
                guard let d = Double(raw) else { throw EpdocQueryParseError.malformedNumber(raw) }
                return .number(d)
            case "checkbox":
                let raw = try readToken()
                switch raw {
                case "true":  return .checkbox(true)
                case "false": return .checkbox(false)
                default:      throw EpdocQueryParseError.malformedBoolean(raw)
                }
            case "url":   return .url(try readToken())
            case "email": return .email(try readToken())
            case "text":  return .text(try readToken())
            default:      throw EpdocQueryParseError.unknownHead(kind, position: idx)
            }
        }

        // MARK: - Between field + time refs

        mutating func parseBetweenField() throws -> BetweenField {
            skipWhitespace()
            if source[idx] == "(" {
                advance()
                let head = readBareToken()
                guard head == "property" else {
                    throw EpdocQueryParseError.unknownHead(head, position: idx)
                }
                skipWhitespace()
                let id = try readToken()
                try expectClose()
                return .property(id: id)
            }
            let token = readBareToken()
            switch token {
            case "created-at": return .createdAt
            case "updated-at": return .updatedAt
            default:           throw EpdocQueryParseError.unknownHead(token, position: idx)
            }
        }

        mutating func parseTimeRef(_ token: String) throws -> TimeRef {
            switch token {
            case "now":   return .now
            case "today": return .today
            default:
                if let signed = parseRelativeDays(token) { return .daysFromToday(signed) }
                // Last fallback: explicit ISO-8601.
                if Self.isProbablyISODate(token) { return .iso8601(token) }
                throw EpdocQueryParseError.malformedTimeRef(token)
            }
        }

        /// Parse `-7d`, `+30d`, `-1w`, `+2y`, etc. into a signed day
        /// count. Hours / minutes intentionally omitted — date-grain
        /// suffices for the V1 between filter.
        private func parseRelativeDays(_ token: String) -> Int? {
            guard let firstChar = token.first,
                  firstChar == "+" || firstChar == "-" else { return nil }
            guard let lastChar = token.last,
                  let unitMultiplier = Self.unitMultiplier(for: lastChar) else { return nil }
            let mid = token.index(after: token.startIndex)
            let beforeUnit = token.index(before: token.endIndex)
            guard mid < beforeUnit else { return nil }
            let body = String(token[mid..<beforeUnit])
            guard let n = Int(body) else { return nil }
            let sign: Int = firstChar == "-" ? -1 : 1
            return sign * n * unitMultiplier
        }

        private static func unitMultiplier(for char: Character) -> Int? {
            switch char {
            case "d": return 1
            case "w": return 7
            case "m": return 30           // approximate; calendar exact in V2
            case "y": return 365
            default:  return nil
            }
        }

        private static func isProbablyISODate(_ token: String) -> Bool {
            // Cheap heuristic — `YYYY-MM-DD` shape.
            guard token.count >= 10 else { return false }
            let chars = Array(token)
            return chars[4] == "-" && chars[7] == "-"
        }
    }
}
