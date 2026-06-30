import Foundation

// DeerFlow slice 5e — the finished multi-agent deep-research result + a PURE
// renderer that turns it into a chat-ready markdown bubble. These are pure data
// + formatting (no FFI, MAS-safe), so they are ALWAYS compiled and unit-tested;
// only the FFI-CALLING `DeepResearchService` (Epistemos/Bridge/DeepResearchBridge
// .swift) that PRODUCES an outcome is Pro-gated (#if !EPISTEMOS_APP_STORE).

/// One sub-question's findings — the provenance behind a cited `[id]` claim in
/// the synthesized report.
struct DeepResearchFinding: Sendable, Equatable, Identifiable {
    let id: String
    let question: String
    let findings: String
}

/// The finished multi-agent report: the objective, the `[id]`-cited synthesis,
/// and the per-sub-question findings it rests on.
struct DeepResearchOutcome: Sendable, Equatable {
    let objective: String
    let report: String
    let findings: [DeepResearchFinding]
}

enum DeepResearchReportBounds {
    static let maxReportCharacters = 12_000
    static let maxRenderedFindings = 20
    static let maxFindingIDCharacters = 80
    static let maxFindingQuestionCharacters = 500
    static let maxFindingBodyCharacters = 4_000

    static func report(_ value: String) -> String {
        capped(value, limit: maxReportCharacters)
    }

    static func findingID(_ value: String) -> String {
        let id = capped(value, limit: maxFindingIDCharacters)
        return id.isEmpty ? "source" : id
    }

    static func findingQuestion(_ value: String) -> String {
        capped(value, limit: maxFindingQuestionCharacters)
    }

    static func findingBody(_ value: String) -> String {
        capped(value, limit: maxFindingBodyCharacters)
    }

    private static func capped(_ value: String, limit: Int) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else {
            return trimmed
        }
        return String(trimmed.prefix(limit)) + "..."
    }
}

/// Pure formatter: a `DeepResearchOutcome` → a single markdown assistant bubble.
/// The cited synthesis first, then a "Sources" provenance section listing each
/// rendered sub-question `[id]` + its findings inside bounded display limits.
/// Deterministic + side-effect-free → unit-tested.
enum DeepResearchReportRenderer {
    static func render(_ outcome: DeepResearchOutcome) -> String {
        let report = DeepResearchReportBounds.report(outcome.report)
        let findings = Array(outcome.findings.prefix(DeepResearchReportBounds.maxRenderedFindings))
        let omittedFindings = max(0, outcome.findings.count - findings.count)

        // No findings → just the report (or an honest empty marker), no dangling
        // "Sources" header.
        guard !findings.isEmpty else {
            return report.isEmpty ? "_(Deep research produced no report.)_" : report
        }

        let head = report.isEmpty
            ? "_(No synthesis was produced; the raw findings are below.)_"
            : report
        let plural = findings.count == 1 ? "" : "s"
        var lines: [String] = [
            head,
            "",
            "---",
            "",
            "**Sources** · \(findings.count) sub-question\(plural)",
        ]
        for finding in findings {
            let id = DeepResearchReportBounds.findingID(finding.id)
            let question = DeepResearchReportBounds.findingQuestion(finding.question)
            let body = DeepResearchReportBounds.findingBody(finding.findings)
            lines.append("")
            lines.append("**[\(id)]** \(question.isEmpty ? "(sub-question)" : question)")
            lines.append(body.isEmpty ? "_(no findings recorded)_" : body)
        }
        if omittedFindings > 0 {
            lines.append("")
            lines.append("_(\(omittedFindings) additional source entries omitted from display.)_")
        }
        return lines.joined(separator: "\n")
    }
}
