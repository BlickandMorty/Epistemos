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

/// Pure formatter: a `DeepResearchOutcome` → a single markdown assistant bubble.
/// The cited synthesis first, then a "Sources" provenance section listing each
/// sub-question `[id]` + its findings, so every `[id]` the report cites resolves
/// to a visible source. Deterministic + side-effect-free → unit-tested.
enum DeepResearchReportRenderer {
    static func render(_ outcome: DeepResearchOutcome) -> String {
        let report = outcome.report.trimmingCharacters(in: .whitespacesAndNewlines)
        let findings = outcome.findings

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
            let question = finding.question.trimmingCharacters(in: .whitespacesAndNewlines)
            let body = finding.findings.trimmingCharacters(in: .whitespacesAndNewlines)
            lines.append("")
            lines.append("**[\(finding.id)]** \(question.isEmpty ? "(sub-question)" : question)")
            lines.append(body.isEmpty ? "_(no findings recorded)_" : body)
        }
        return lines.joined(separator: "\n")
    }
}
