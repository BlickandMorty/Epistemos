import Foundation

nonisolated enum SearchRequestBoundsError: Error, Equatable, Sendable {
    case invalidResultLimit
    case invalidQuery
}

/// Value-only request validation shared by synchronous and actor-isolated
/// search entry points. It must remain nonisolated so FTS reads do not need a
/// main-actor hop before they can reject unsafe input.
nonisolated enum SearchRequestBounds {
    static let maximumResultCount = FusionWeights.maximumResultCount
    static let maximumQueryUTF8ByteCount = 4_096
    static let maximumQueryUnicodeScalarCount = 2_048
    static let maximumQueryGraphemeCount = 500

    static func validatedResultLimit(_ limit: Int) throws -> Int {
        guard limit >= 1, limit <= maximumResultCount else {
            throw SearchRequestBoundsError.invalidResultLimit
        }
        return limit
    }

    static func validatedQuery(_ query: String) throws -> String? {
        var byteCount = 0
        var scalarCount = 0
        var hasNonWhitespaceScalar = false

        for scalar in query.unicodeScalars {
            byteCount += scalar.utf8.count
            guard byteCount <= maximumQueryUTF8ByteCount else {
                throw SearchRequestBoundsError.invalidQuery
            }

            scalarCount += 1
            guard scalarCount <= maximumQueryUnicodeScalarCount,
                  !isDisallowedControl(scalar) else {
                throw SearchRequestBoundsError.invalidQuery
            }

            if !CharacterSet.whitespacesAndNewlines.contains(scalar) {
                hasNonWhitespaceScalar = true
            }
        }

        var graphemeCount = 0
        for _ in query {
            graphemeCount += 1
            guard graphemeCount <= maximumQueryGraphemeCount else {
                throw SearchRequestBoundsError.invalidQuery
            }
        }

        guard hasNonWhitespaceScalar else { return nil }

        return query
    }

    private static func isDisallowedControl(_ scalar: UnicodeScalar) -> Bool {
        switch scalar.value {
        case 0...8, 11...12, 14...31, 127...159:
            return true
        default:
            return false
        }
    }
}
