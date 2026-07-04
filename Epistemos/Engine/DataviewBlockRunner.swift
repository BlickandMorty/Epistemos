import Foundation
import SwiftData

// MARK: - DataviewBlockRunner
// Wires the (previously orphaned) DataviewService into a runnable path: given a note's text and a
// character location inside a ```dataview fenced code block, parse + execute the DQL against the
// vault and return the rendered markdown table.
//
// This is a PURE, testable seam with zero cost on the editor's hot path — nothing runs unless a UI
// action explicitly invokes it (a "Run Dataview" command / result sheet consumes `run`). It does
// NOT alter the editor's normal rendering, so it carries no risk to note display. The live INLINE
// render of a dataview block is a separate, flag-gated increment (SS-FOLLOWON) that builds on top
// of this seam.
@MainActor
enum DataviewBlockRunner {

    struct RunResult: Equatable {
        /// `DataviewService.renderMarkdown` output — a markdown table, or "*No results*".
        let markdown: String
        /// The DQL that was executed (for display above the result).
        let dql: String
    }

    /// If `location` sits inside a ```dataview fenced block in `text`, parse + execute the DQL and
    /// return the rendered markdown. Returns nil when there's no dataview block at the location or
    /// the DQL doesn't parse (so callers can no-op cleanly).
    static func run(in text: String, at location: Int, context: ModelContext) -> RunResult? {
        guard let dql = dataviewDQL(in: text, at: location) else { return nil }
        let service = DataviewService()
        guard let query = service.parse(dql) else { return nil }
        let result = service.execute(query, context: context)
        return RunResult(markdown: service.renderMarkdown(result), dql: dql)
    }

    /// Extract the DQL body of a ```dataview fenced block that contains `location`, or nil. The
    /// info string must be exactly `dataview` (case-insensitive) — a plain ``` or ```swift block is
    /// ignored. Pure + testable; no SwiftData needed.
    static func dataviewDQL(in text: String, at location: Int) -> String? {
        let ns = text as NSString
        guard location >= 0, location <= ns.length else { return nil }
        var cursor = 0
        var fenceLineStart: Int?     // opening-fence line start; nil = not currently inside a fence
        var bodyStart = 0            // DQL body start (first char after the opening-fence line)
        var isDataview = false
        while cursor < ns.length {
            let lineRange = ns.lineRange(for: NSRange(location: cursor, length: 0))
            let line = ns.substring(with: lineRange)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("```") {
                if let openStart = fenceLineStart {
                    // Closing fence: is `location` inside this whole block, and was it dataview?
                    let block = NSRange(location: openStart, length: NSMaxRange(lineRange) - openStart)
                    if isDataview, NSLocationInRange(location, block) {
                        let bodyRange = NSRange(
                            location: bodyStart, length: max(0, lineRange.location - bodyStart))
                        return ns.substring(with: bodyRange)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    fenceLineStart = nil
                    isDataview = false
                } else {
                    // Opening fence: capture its info string.
                    let info = line.dropFirst(3).trimmingCharacters(in: .whitespaces).lowercased()
                    isDataview = (info == "dataview")
                    fenceLineStart = lineRange.location
                    bodyStart = NSMaxRange(lineRange)
                }
            }
            let next = NSMaxRange(lineRange)
            guard next > cursor else { break }
            cursor = next
        }
        return nil
    }
}
