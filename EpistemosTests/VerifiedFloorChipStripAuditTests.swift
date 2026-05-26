import Foundation
import Testing

// UAS-EXEMPT: source-audit test fixture, not persisted substrate data.
@Suite("Verified Floor Chip Strip Audit")
struct VerifiedFloorChipStripAuditTests {
    @Test("no Settings HealthRow chip strip ships green without a passing falsifier artifact")
    func noGreenChipStripWithoutPassingFalsifierArtifact() throws {
        let healthRowURLs = try mirroredSourceFileURLs(
            under: "Epistemos/Views/Settings",
            includingExtensions: ["swift"]
        )
        .filter { $0.lastPathComponent.hasSuffix("HealthRow.swift") }

        #expect(healthRowURLs.count >= 24)

        var violations: [String] = []
        for url in healthRowURLs {
            let source = try String(contentsOf: url, encoding: .utf8)
            violations.append(
                contentsOf: Self.greenClaimViolations(
                    in: source,
                    path: url.lastPathComponent,
                    artifactPasses: Self.falsifierArtifactPasses
                )
            )
        }

        #expect(violations.isEmpty, Comment(rawValue: violations.joined(separator: "\n")))
    }

    @Test("probe row with dishonest production green is rejected by the audit")
    func probeDishonestProductionGreenIsRejected() {
        let probe = """
        import SwiftUI

        // UAS-EXEMPT: probe source string, not compiled substrate data.
        struct DishonestProbeHealthRow: View {
            var body: some View {
                VerifiedFloorChipStrip(
                    flag: "on",
                    substrate: "production fake",
                    substrateTint: .green
                )
            }
        }
        """

        let violations = Self.greenClaimViolations(
            in: probe,
            path: "DishonestProbeHealthRow.swift",
            artifactPasses: { _ in false }
        )

        #expect(violations.count == 1)
        #expect(violations[0].contains("missing `falsifier:`"))
    }

    @Test("probe row with production green and PASS artifact is accepted")
    func probeProductionGreenWithPassArtifactIsAccepted() {
        let probe = """
        import SwiftUI

        // UAS-EXEMPT: probe source string, not compiled substrate data.
        struct HonestProbeHealthRow: View {
            var body: some View {
                VerifiedFloorChipStrip(
                    flag: "on",
                    substrate: "production gate active",
                    substrateTint: .green,
                    falsifier: "probe_pass"
                )
            }
        }
        """

        let violations = Self.greenClaimViolations(
            in: probe,
            path: "HonestProbeHealthRow.swift",
            artifactPasses: { $0 == "probe_pass" }
        )

        #expect(violations.isEmpty)
    }

    private static func greenClaimViolations(
        in source: String,
        path: String,
        artifactPasses: (String) -> Bool
    ) -> [String] {
        chipStripCalls(in: source).flatMap { call -> [String] in
            guard call.contains(".green") else { return [] }
            guard let falsifier = firstFalsifierName(in: call) else {
                return ["\(path): green VerifiedFloorChipStrip is missing `falsifier:`"]
            }
            guard artifactPasses(falsifier) else {
                return [
                    "\(path): green VerifiedFloorChipStrip points at artifacts/falsifiers/\(falsifier)/result.json, but it is missing or not PASS"
                ]
            }
            return []
        }
    }

    private static func chipStripCalls(in source: String) -> [String] {
        var calls: [String] = []
        var searchStart = source.startIndex

        while let start = source.range(
            of: "VerifiedFloorChipStrip(",
            range: searchStart..<source.endIndex
        )?.lowerBound {
            var index = start
            var depth = 0
            var inString = false
            var escaped = false
            var callEnd: String.Index?

            while index < source.endIndex {
                let character = source[index]
                if inString {
                    if escaped {
                        escaped = false
                    } else if character == "\\" {
                        escaped = true
                    } else if character == "\"" {
                        inString = false
                    }
                } else if character == "\"" {
                    inString = true
                } else if character == "(" {
                    depth += 1
                } else if character == ")" {
                    depth -= 1
                    if depth == 0 {
                        callEnd = source.index(after: index)
                        break
                    }
                }
                index = source.index(after: index)
            }

            guard let callEnd else { break }
            calls.append(String(source[start..<callEnd]))
            searchStart = callEnd
        }

        return calls
    }

    private static func firstFalsifierName(in call: String) -> String? {
        guard let key = call.range(of: "falsifier:") else { return nil }
        let tail = call[key.upperBound...]
        guard let firstQuote = tail.firstIndex(of: "\"") else { return nil }
        let afterFirstQuote = tail.index(after: firstQuote)
        guard let secondQuote = tail[afterFirstQuote...].firstIndex(of: "\"") else { return nil }
        let value = tail[afterFirstQuote..<secondQuote]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func falsifierArtifactPasses(_ name: String) -> Bool {
        guard let url = try? sourceMirrorURL(
            for: "artifacts/falsifiers/\(name)/result.json"
        ),
            let data = try? Data(contentsOf: url),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return false
        }

        if let status = json["status"] as? String,
           status.uppercased() == "PASS" {
            return true
        }

        if let overallPass = json["overall_pass"] as? Bool {
            return overallPass
        }

        return false
    }
}
