import Testing
@testable import Epistemos

/// Validation of the native deterministic `/calc` Hermes parity command.
/// Doctrine §7 lane: Pro track parity (Core-side) — `/calc` is one of
/// the Core-native rows in the Hermes capability parity target doc.
@Suite("Hermes /calc Command")
struct HermesCalcCommandTests {

    // MARK: - Parser

    @Test("parse rejects non-/calc input")
    func parseRejectsNonCalcInput() {
        #expect(HermesCalcCommand.parse("/todo") == nil)
        #expect(HermesCalcCommand.parse("calc 1+1") == nil)
        #expect(HermesCalcCommand.parse("hello") == nil)
        #expect(HermesCalcCommand.parse("") == nil)
    }

    @Test("parse rejects /calc with no expression")
    func parseRejectsBareCalc() {
        #expect(HermesCalcCommand.parse("/calc") == nil)
        #expect(HermesCalcCommand.parse("/calc   ") == nil)
        #expect(HermesCalcCommand.parse("  /calc  ") == nil)
    }

    @Test("parse extracts the expression")
    func parseExtractsExpression() {
        let cmd = HermesCalcCommand.parse("/calc 2 + 3")
        #expect(cmd != nil)
        #expect(cmd?.expression == "2 + 3")
    }

    @Test("parse trims surrounding whitespace from the expression")
    func parseTrimsWhitespace() {
        let cmd = HermesCalcCommand.parse("/calc   1 + 1   ")
        #expect(cmd?.expression == "1 + 1")
    }

    // MARK: - Sanitization

    @Test("sanitize allows the deterministic-calculator alphabet")
    func sanitizeAllowsCalculatorAlphabet() {
        for input in ["1+1", "(2 * 3) - 4", "sqrt(9)", "ln(e)", "1.5e3", "100 / 5"] {
            let sanitized = HermesCalcCommand.sanitize(input)
            #expect(!sanitized.isEmpty, "should accept \(input)")
        }
    }

    @Test("sanitize rejects shell metacharacters")
    func sanitizeRejectsShellMetacharacters() {
        for input in ["1+1; rm -rf /", "$(whoami)", "`id`", "1+1 && echo", "1+1 | cat"] {
            let sanitized = HermesCalcCommand.sanitize(input)
            #expect(sanitized.isEmpty, "should reject shell payload \(input)")
        }
    }

    @Test("sanitize rejects backticks and pipe characters individually")
    func sanitizeRejectsIndividualMetacharacters() {
        #expect(HermesCalcCommand.sanitize("1`2").isEmpty)
        #expect(HermesCalcCommand.sanitize("1|2").isEmpty)
        #expect(HermesCalcCommand.sanitize("1>2").isEmpty)
        #expect(HermesCalcCommand.sanitize("1<2").isEmpty)
        #expect(HermesCalcCommand.sanitize("1&2").isEmpty)
    }

    @Test("sanitize strips trailing semicolons")
    func sanitizeStripsTrailingSemicolons() {
        #expect(HermesCalcCommand.sanitize("1+1;") == "1+1")
        #expect(HermesCalcCommand.sanitize("1+1;;;") == "1+1")
    }

    // MARK: - Evaluation — happy path

    @Test("evaluate returns success for a basic addition")
    func evaluatesAddition() {
        let cmd = HermesCalcCommand(expression: "2 + 3")
        switch cmd.evaluate() {
        case .success(_, let formatted):
            #expect(formatted == "5")
        case .failure(let reason):
            Issue.record("Expected success, got failure: \(reason)")
        }
    }

    @Test("evaluate returns success for parens and precedence")
    func evaluatesParensAndPrecedence() {
        let cmd = HermesCalcCommand(expression: "(2 + 3) * 4")
        switch cmd.evaluate() {
        case .success(_, let formatted):
            #expect(formatted == "20")
        case .failure(let reason):
            Issue.record("Expected success, got failure: \(reason)")
        }
    }

    @Test("evaluate handles fractional results without scientific notation")
    func evaluatesFractionalWithoutScientificDrift() {
        let cmd = HermesCalcCommand(expression: "1 / 8")
        switch cmd.evaluate() {
        case .success(_, let formatted):
            // 1/8 = 0.125 — never "1.25e-1"
            #expect(formatted == "0.125",
                    "expected 0.125, got \(formatted)")
        case .failure(let reason):
            Issue.record("Expected success, got failure: \(reason)")
        }
    }

    @Test("evaluate adds grouping separator for large integers")
    func evaluatesLargeIntegersWithGrouping() {
        let cmd = HermesCalcCommand(expression: "1000 * 1000")
        switch cmd.evaluate() {
        case .success(_, let formatted):
            #expect(formatted == "1,000,000")
        case .failure(let reason):
            Issue.record("Expected success, got failure: \(reason)")
        }
    }

    // MARK: - Evaluation — failure path

    @Test("evaluate fails cleanly on shell-payload input (sanitization gate)")
    func evaluateFailsOnShellPayload() {
        let cmd = HermesCalcCommand(expression: "1+1; rm -rf /")
        switch cmd.evaluate() {
        case .success:
            Issue.record("Shell payload must NOT evaluate")
        case .failure:
            // Pass — sanitization caught it
            break
        }
    }

    @Test("evaluate returns failure for empty-after-sanitize input")
    func evaluateFailsOnEmptyAfterSanitize() {
        let cmd = HermesCalcCommand(expression: "$$$")
        switch cmd.evaluate() {
        case .success:
            Issue.record("Garbage input must NOT evaluate")
        case .failure:
            break
        }
    }

    // MARK: - Trivial action class

    @Test("requiresApproval is false (Trivial action class per doctrine §A.7)")
    func requiresApprovalIsFalse() {
        let cmd = HermesCalcCommand(expression: "1+1")
        #expect(!cmd.requiresApproval)
    }
}
