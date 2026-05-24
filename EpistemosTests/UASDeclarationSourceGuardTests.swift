import Foundation
import Testing

@testable import Epistemos

// UAS-EXEMPT: source-guard test suite, not product substrate data.
@Suite("UAS Declaration Source Guard")
struct UASDeclarationSourceGuardTests {

    @Test("Swift guard catches an orphan class declaration")
    func catchesOrphanClassDeclaration() {
        let source = """
        final class OrphanTelemetry {}
        """

        let violations = uasDeclarationViolations(in: source)
        #expect(violations.count == 1)
        #expect(violations.first?.contains("OrphanTelemetry") == true)
    }

    @Test("Swift guard accepts UAS plane residency comments")
    func acceptsFullUasHeader() {
        let source = """
        // UAS: settings/example
        // Plane: RuntimePlane::Verification
        // Residency: ResidencyTier::CurrentApp
        public struct TaggedSettingsRow {}
        """

        #expect(uasDeclarationViolations(in: source).isEmpty)
    }

    @Test("Swift guard accepts explicit UAS exemption")
    func acceptsExplicitExemption() {
        let source = """
        // UAS-EXEMPT: preview-only fixture.
        private final class PreviewFixture {}
        """

        #expect(uasDeclarationViolations(in: source).isEmpty)
    }

    @Test("PlanePlacementHealthRow carries UAS declaration metadata")
    func planePlacementHealthRowCarriesUasMetadata() throws {
        let source = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/PlanePlacementHealthRow.swift"
        )

        #expect(uasDeclarationViolations(in: source).isEmpty)
    }

    private func uasDeclarationViolations(in source: String) -> [String] {
        var violations: [String] = []
        var preceding: [String] = []

        for (offset, line) in source.components(separatedBy: .newlines).enumerated() {
            if declarationRequiresUasMetadata(line), !hasUasDeclarationHeader(preceding) {
                violations.append("\(offset + 1): \(line.trimmingCharacters(in: .whitespaces))")
            }
            preceding.append(line)
            if preceding.count > 16 {
                preceding.removeFirst()
            }
        }

        return violations
    }

    private func hasUasDeclarationHeader(_ preceding: [String]) -> Bool {
        let window = Array(preceding.suffix(12))
        if window.contains(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("// UAS-EXEMPT:") }) {
            return true
        }

        let hasUas = window.contains(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("// UAS:") })
        let hasPlane = window.contains(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("// Plane:") })
        let hasResidency = window.contains(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("// Residency:") })
        return hasUas && hasPlane && hasResidency
    }

    private func declarationRequiresUasMetadata(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") || trimmed.hasPrefix("*") {
            return false
        }

        let separators = CharacterSet.whitespaces.union(CharacterSet(charactersIn: "<:("))
        let words = trimmed
            .components(separatedBy: separators)
            .filter { !$0.isEmpty }

        for word in words {
            let clean = word.trimmingCharacters(in: CharacterSet(charactersIn: "{"))
            if ["struct", "enum", "class", "actor"].contains(clean) {
                return true
            }
            if isDeclarationModifier(clean) {
                continue
            }
            return false
        }
        return false
    }

    private func isDeclarationModifier(_ word: String) -> Bool {
        [
            "public",
            "private",
            "fileprivate",
            "internal",
            "open",
            "final",
            "nonisolated",
            "@MainActor",
            "@unchecked",
            "indirect",
        ].contains(word)
    }
}
