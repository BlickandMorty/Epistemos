import Testing
import Foundation
@testable import Epistemos

/// DeerFlow slice 5e — locks the PURE chat-bubble renderer for a finished
/// deep-research outcome: the cited synthesis first, then a Sources section that
/// resolves every `[id]` the report cites to a visible sub-question + findings.
/// Pure + deterministic, so it's unit-tested without the FFI / Pro gate.
@Suite("Deep research report renderer")
struct DeepResearchReportRendererTests {

    private func finding(_ id: String, _ q: String, _ f: String) -> DeepResearchFinding {
        DeepResearchFinding(id: id, question: q, findings: f)
    }

    @Test("renders the report then a Sources section resolving each cited [id]")
    func rendersReportAndSources() {
        let outcome = DeepResearchOutcome(
            objective: "How does X work?",
            report: "X works via A [q1] and B [q2].",
            findings: [
                finding("q1", "What is A?", "A is the first mechanism."),
                finding("q2", "What is B?", "B is the second mechanism."),
            ]
        )
        let out = DeepResearchReportRenderer.render(outcome)
        // Synthesis first.
        #expect(out.hasPrefix("X works via A [q1] and B [q2]."))
        // Sources header with the count + plural.
        #expect(out.contains("**Sources** · 2 sub-questions"))
        // Every cited [id] resolves to its question + findings.
        #expect(out.contains("**[q1]** What is A?"))
        #expect(out.contains("A is the first mechanism."))
        #expect(out.contains("**[q2]** What is B?"))
        #expect(out.contains("B is the second mechanism."))
        // A horizontal rule separates synthesis from sources.
        #expect(out.contains("\n---\n"))
    }

    @Test("a single sub-question uses singular wording")
    func singularWording() {
        let out = DeepResearchReportRenderer.render(
            DeepResearchOutcome(
                objective: "obj",
                report: "answer [q1]",
                findings: [finding("q1", "q?", "a.")]
            )
        )
        #expect(out.contains("**Sources** · 1 sub-question\n"))
        #expect(!out.contains("1 sub-questions"))
    }

    @Test("no findings → just the report, no dangling Sources header")
    func noFindingsNoHeader() {
        let out = DeepResearchReportRenderer.render(
            DeepResearchOutcome(objective: "obj", report: "Just an answer.", findings: [])
        )
        #expect(out == "Just an answer.")
        #expect(!out.contains("Sources"))
    }

    @Test("empty report but findings present → honest marker + the findings")
    func emptyReportWithFindings() {
        let out = DeepResearchReportRenderer.render(
            DeepResearchOutcome(
                objective: "obj",
                report: "   ",
                findings: [finding("q1", "q?", "raw finding.")]
            )
        )
        #expect(out.contains("No synthesis was produced"))
        #expect(out.contains("**[q1]** q?"))
        #expect(out.contains("raw finding."))
    }

    @Test("fully empty outcome → a single honest marker, never a crash or blank")
    func fullyEmpty() {
        let out = DeepResearchReportRenderer.render(
            DeepResearchOutcome(objective: "obj", report: "", findings: [])
        )
        #expect(out == "_(Deep research produced no report.)_")
    }

    @Test("blank question / findings fall back to placeholders (no empty bullets)")
    func blankFieldsGetPlaceholders() {
        let out = DeepResearchReportRenderer.render(
            DeepResearchOutcome(
                objective: "obj",
                report: "answer [x]",
                findings: [finding("x", "   ", "   ")]
            )
        )
        #expect(out.contains("**[x]** (sub-question)"))
        #expect(out.contains("_(no findings recorded)_"))
    }

    @Test("renderer caps report and source fields from runtime output")
    func rendererCapsReportAndSourceFieldsFromRuntimeOutput() {
        let longReport = String(repeating: "r", count: DeepResearchReportBounds.maxReportCharacters + 32)
        let longID = String(repeating: "i", count: DeepResearchReportBounds.maxFindingIDCharacters + 32)
        let longQuestion = String(repeating: "q", count: DeepResearchReportBounds.maxFindingQuestionCharacters + 32)
        let longBody = String(repeating: "b", count: DeepResearchReportBounds.maxFindingBodyCharacters + 32)
        let findings = (0..<(DeepResearchReportBounds.maxRenderedFindings + 2)).map { index in
            finding(index == 0 ? longID : "q\(index)", index == 0 ? longQuestion : "Question \(index)", index == 0 ? longBody : "Body \(index)")
        }

        let out = DeepResearchReportRenderer.render(
            DeepResearchOutcome(objective: "obj", report: longReport, findings: findings)
        )

        #expect(out.contains("**Sources** · \(DeepResearchReportBounds.maxRenderedFindings) sub-questions"))
        #expect(out.hasPrefix(String(repeating: "r", count: DeepResearchReportBounds.maxReportCharacters - 3) + "..."))
        #expect(out.contains("**[\(String(repeating: "i", count: DeepResearchReportBounds.maxFindingIDCharacters - 3))...]**"))
        #expect(out.contains(String(repeating: "q", count: DeepResearchReportBounds.maxFindingQuestionCharacters - 3) + "..."))
        #expect(out.contains(String(repeating: "b", count: DeepResearchReportBounds.maxFindingBodyCharacters - 3) + "..."))
        #expect(out.contains("2 additional source entries omitted from display"))
        #expect(!out.contains("q\(DeepResearchReportBounds.maxRenderedFindings)"))
    }
}
