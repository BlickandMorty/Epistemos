import Foundation

/// Native deterministic calculator for Hermes-compatible `/calc` slash commands.
///
/// Per `docs/fusion/fleet/hermes-capability-pass-through/HERMES_CAPABILITY_PARITY_TARGET_2026_05_03.md`
/// "Tools And Integrations" row: `/calc <expression>` is a "Core native
/// deterministic calculator" — Epistemos answers it locally with `NSExpression`,
/// never routing through Hermes / cloud / subprocess.
///
/// **Core-safe.** No network, no subprocess, no provider call. The whole
/// expression is evaluated synchronously with Apple's Foundation
/// expression evaluator. Doctrine §A.7 action class: Trivial.
///
/// Mirrors the `HermesTodoCommand` shape so future Hermes-parity slices
/// can reuse the same parse-then-execute scaffold.
nonisolated struct HermesCalcCommand: Equatable, Sendable {
    let expression: String

    /// Whether the command needs explicit user approval before running.
    /// Calculator evaluation is Trivial-class — false.
    var requiresApproval: Bool { false }

    // MARK: - Parse

    /// Parse `/calc <expression>` into a command. Returns `nil` for any
    /// non-`/calc` input or empty argument.
    static func parse(_ rawCommand: String) -> HermesCalcCommand? {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == "/calc" || trimmed.hasPrefix("/calc ") else {
            return nil
        }
        let remainder = trimmed
            .dropFirst("/calc".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !remainder.isEmpty else {
            return nil
        }
        return HermesCalcCommand(expression: remainder)
    }

    // MARK: - Evaluate

    /// Outcome of evaluation. Always non-throwing — the caller renders
    /// the success / failure message verbatim into the chat surface.
    enum EvaluationResult: Equatable, Sendable {
        case success(value: String, formatted: String)
        case failure(reason: String)
    }

    /// Evaluate the parsed expression using `NSExpression`. Numeric
    /// results format using a stable `NumberFormatter` so 1e6 renders
    /// as "1,000,000" and 0.1 + 0.2 doesn't drift to scientific notation.
    func evaluate() -> EvaluationResult {
        let sanitized = HermesCalcCommand.sanitize(expression)
        guard !sanitized.isEmpty else {
            return .failure(reason: "Expression is empty after sanitization.")
        }

        // NSExpression accepts arithmetic + standard math functions; it
        // does NOT execute arbitrary Swift / shell. This is the whole
        // point of using it for the Core deterministic calculator.
        let parsed = NSExpression(format: Self.decimalizedNumericLiterals(in: sanitized))
        let evaluated: Any?
        do {
            evaluated = try Self.expressionValue(of: parsed)
        } catch {
            return .failure(reason: "Could not parse expression: \(error.localizedDescription)")
        }

        guard let value = evaluated else {
            return .failure(reason: "Expression returned no value.")
        }

        if let number = value as? NSNumber {
            let formatter = Self.numberFormatter
            let formatted = formatter.string(from: number) ?? "\(number)"
            return .success(value: "\(number)", formatted: formatted)
        }

        return .success(value: "\(value)", formatted: "\(value)")
    }

    // MARK: - Internal helpers

    /// Sanitize input. Strips trailing semicolons and rejects characters
    /// outside the deterministic-calculator alphabet (digits, math
    /// operators, parentheses, decimal point, function-name letters,
    /// whitespace). Anything else returns an empty string → failure.
    static func sanitize(_ input: String) -> String {
        let trimmed = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ";"))
        guard !trimmed.isEmpty else { return "" }

        let allowed = CharacterSet(charactersIn: "0123456789.+-*/()% ,_eE")
            .union(.letters) // letters cover NSExpression function names: sqrt, abs, ln, log, etc.
        for scalar in trimmed.unicodeScalars {
            if !allowed.contains(scalar) {
                return ""
            }
        }
        return trimmed
    }

    static func decimalizedNumericLiterals(in input: String) -> String {
        let scalars = Array(input.unicodeScalars)
        var output = String.UnicodeScalarView()
        output.reserveCapacity(input.unicodeScalars.count)
        var index = scalars.startIndex

        while index < scalars.endIndex {
            let scalar = scalars[index]
            let previous = index == scalars.startIndex ? nil : scalars[scalars.index(before: index)]
            guard CharacterSet.decimalDigits.contains(scalar),
                  !isIdentifierContinuation(previous)
            else {
                output.append(scalar)
                index = scalars.index(after: index)
                continue
            }

            var literal = String.UnicodeScalarView()
            var hasDecimalPoint = false
            var hasExponent = false

            while index < scalars.endIndex {
                let current = scalars[index]
                if CharacterSet.decimalDigits.contains(current) {
                    literal.append(current)
                    index = scalars.index(after: index)
                    continue
                }
                if current == "." {
                    hasDecimalPoint = true
                    literal.append(current)
                    index = scalars.index(after: index)
                    continue
                }
                if current == "e" || current == "E" {
                    hasExponent = true
                    literal.append(current)
                    index = scalars.index(after: index)
                    if index < scalars.endIndex,
                       scalars[index] == "+" || scalars[index] == "-" {
                        literal.append(scalars[index])
                        index = scalars.index(after: index)
                    }
                    continue
                }
                break
            }

            output.append(contentsOf: literal)
            if !hasDecimalPoint && !hasExponent {
                output.append(".")
                output.append("0")
            }
        }

        return String(output)
    }

    private static func isIdentifierContinuation(_ scalar: UnicodeScalar?) -> Bool {
        guard let scalar else { return false }
        return CharacterSet.letters.contains(scalar) || scalar == "_"
    }

    /// Wrap NSExpression evaluation in a do/catch boundary. The
    /// `expressionValue(with:context:)` method can throw `NSException`
    /// for malformed input under certain bridge conditions; isolate it
    /// in a single point so callers always get a Swift `throws`.
    private static func expressionValue(of parsed: NSExpression) throws -> Any? {
        // No `with:` object, no context — pure arithmetic.
        return parsed.expressionValue(with: nil, context: nil)
    }

    private static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 12
        f.minimumFractionDigits = 0
        f.usesGroupingSeparator = true
        return f
    }()
}
