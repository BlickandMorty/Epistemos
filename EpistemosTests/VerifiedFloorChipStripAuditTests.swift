import Foundation
import Testing
@testable import Epistemos

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

    // ── Real-API guard (P4 honest-tier, 2026-06-20) ────────────────────────────────
    // The `.green`-string audit above predates the current VerifiedFloorChipStrip API.
    // The real component takes `productionWired` + `falsifierPassed` BOOLS and computes
    // green internally as `productionWired && falsifierPassed` (no call site passes a
    // `substrateTint:` color), so `.contains(".green")` matches ZERO real rows — the guard
    // had gone vacuous against the actual API. This restores it: a row that HARDCODES
    // `falsifierPassed: true` claims a primary PASS witness statically, so it must name a
    // `falsifier:` whose artifact actually passes. Runtime-computed `falsifierPassed`
    // (a live witness, e.g. `gateSnapshot.allPassed`) and literal `false` (never green)
    // are honest and exempt — so this passes today (no row hardcodes a witness) and arms
    // the guard against a future hardcoded fake-green.

    @Test("the component still computes green from productionWired && falsifierPassed (the bool scan is the right lens)")
    func componentComputesGreenFromBothBools() throws {
        let src = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/SettingsSurfaceComponents.swift")
        #expect(src.contains("productionWired && falsifierPassed"))
        #expect(src.contains("artifactSatisfied && liveBackingSatisfied"))
        #expect(src.contains("let productionWired: Bool"))
        #expect(src.contains("let falsifierPassed: Bool"))
        #expect(src.contains("requiresArtifactAtPath: String? = nil"))
        #expect(src.contains("nonisolated enum VerifiedFloorArtifactBackingPolicy"))
        #expect(src.contains("VerifiedFloorArtifactBackingPolicy.isSatisfied(path: requiresArtifactAtPath)"))
        #expect(src.contains("destinationOfSymbolicLink(atPath: path)"))
        #expect(src.contains("FileAttributeType"))
        #expect(src.contains(".typeRegular"))
        #expect(src.contains("requiresLiveBacking: VerifiedFloorLiveBacking = .none"))
    }

    @Test("artifact backing policy requires readable regular non-symlink files")
    func artifactBackingPolicyRequiresReadableRegularNonSymlinkFiles() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("verified-floor-artifact-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let artifact = root.appendingPathComponent("artifact.json")
        let directory = root.appendingPathComponent("artifact-dir", isDirectory: true)
        let symlink = root.appendingPathComponent("linked.json")
        let missing = root.appendingPathComponent("missing.json")

        try #"{"overall_pass":true}"#.write(to: artifact, atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: artifact)

        #expect(VerifiedFloorArtifactBackingPolicy.isSatisfied(path: artifact.path))
        #expect(!VerifiedFloorArtifactBackingPolicy.isSatisfied(path: ""))
        #expect(!VerifiedFloorArtifactBackingPolicy.isSatisfied(path: missing.path))
        #expect(!VerifiedFloorArtifactBackingPolicy.isSatisfied(path: directory.path))
        #expect(!VerifiedFloorArtifactBackingPolicy.isSatisfied(path: symlink.path))
    }

    @Test("chip eligibility requires artifact and live backing when declared")
    func chipEligibilityRequiresDeclaredBacking() {
        #expect(VerifiedFloorChipEligibility(
            productionWired: true,
            falsifierPassed: true,
            artifactSatisfied: true,
            liveBackingSatisfied: true
        ).greenEligible)

        let missingArtifact = VerifiedFloorChipEligibility(
            productionWired: true,
            falsifierPassed: true,
            artifactSatisfied: false,
            liveBackingSatisfied: true
        )
        #expect(!missingArtifact.greenEligible)
        #expect(missingArtifact.witnessLabel == "no artifact")

        let emptyBacking = VerifiedFloorChipEligibility(
            productionWired: true,
            falsifierPassed: true,
            artifactSatisfied: true,
            liveBackingSatisfied: false
        )
        #expect(!emptyBacking.greenEligible)
        #expect(emptyBacking.witnessLabel == "empty")
    }

    @Test("provenance diagnostics opt into live ledger backing")
    func provenanceDiagnosticsRequireLiveLedgerBacking() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Settings/AnswerPacketHealthRow.swift")
        #expect(src.contains("requiresLiveBacking: .ledger"))
    }

    @Test("no HealthRow hardcodes falsifierPassed: true without a passing falsifier artifact (real API)")
    func hardcodedPassWitnessRequiresPassingFalsifierArtifact() throws {
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
                contentsOf: Self.hardcodedWitnessViolations(
                    in: source,
                    path: url.lastPathComponent,
                    artifactPasses: Self.falsifierArtifactPasses
                )
            )
        }

        #expect(violations.isEmpty, Comment(rawValue: violations.joined(separator: "\n")))
    }

    @Test("probe: hardcoded falsifierPassed: true with a missing falsifier artifact is rejected (real API)")
    func probeHardcodedPassWithoutArtifactRejected() {
        let probe = """
        VerifiedFloorChipStrip(
            flag: "on",
            substrate: "claims a witness it does not have",
            productionWired: true,
            falsifierPassed: true,
            falsifier: "missing_probe",
            wiredToday: "x",
            stillStub: "y"
        )
        """
        let violations = Self.hardcodedWitnessViolations(
            in: probe, path: "DishonestWitnessProbeHealthRow.swift", artifactPasses: { _ in false })
        #expect(violations.count == 1)
        #expect(violations[0].contains("missing or not PASS"))
    }

    @Test("probe: hardcoded falsifierPassed: true with a PASS artifact is accepted (real API)")
    func probeHardcodedPassWithArtifactAccepted() {
        let probe = """
        VerifiedFloorChipStrip(
            flag: "on",
            substrate: "honest green",
            productionWired: true,
            falsifierPassed: true,
            falsifier: "probe_pass",
            wiredToday: "x",
            stillStub: "y"
        )
        """
        let violations = Self.hardcodedWitnessViolations(
            in: probe, path: "HonestWitnessProbeHealthRow.swift", artifactPasses: { $0 == "probe_pass" })
        #expect(violations.isEmpty)
    }

    @Test("probe: an orange row (productionWired: true, falsifierPassed: false) is not a green claim (real API)")
    func probeOrangeRowIsNotGreenClaim() {
        // The LatticeWBO / LocalAgentDiagnostics shape: always-on, no PASS witness → orange,
        // never green. A literal-false witness must NOT require a passing falsifier artifact.
        let probe = """
        VerifiedFloorChipStrip(
            flag: "n/a",
            substrate: "always-on accountant",
            productionWired: true,
            falsifierPassed: false,
            falsifier: "F_WBO_DRIFT_LEDGER_2026_05_18",
            wiredToday: "x",
            stillStub: "y"
        )
        """
        let violations = Self.hardcodedWitnessViolations(
            in: probe, path: "LatticeWBOHealthRow.swift", artifactPasses: { _ in false })
        #expect(violations.isEmpty)
    }

    /// A row that HARDCODES `falsifierPassed: true` claims a primary PASS witness statically;
    /// it must name a `falsifier:` whose artifact actually passes. Runtime-computed witnesses
    /// and literal `false` are honest and produce no violation.
    private static func hardcodedWitnessViolations(
        in source: String,
        path: String,
        artifactPasses: (String) -> Bool
    ) -> [String] {
        chipStripCalls(in: source).flatMap { call -> [String] in
            guard boolArgumentIsLiteralTrue(key: "falsifierPassed", in: call) else { return [] }
            guard let falsifier = firstFalsifierName(in: call) else {
                return ["\(path): VerifiedFloorChipStrip hardcodes falsifierPassed: true but is missing `falsifier:`"]
            }
            guard artifactPasses(falsifier) else {
                return ["\(path): VerifiedFloorChipStrip hardcodes falsifierPassed: true, but artifacts/falsifiers/\(falsifier)/result.json is missing or not PASS"]
            }
            return []
        }
    }

    /// True only when the argument for `key:` is the literal `true` (not a runtime expression).
    /// Argument values in the real rows are simple (no nested commas/parens), so a flat scan to
    /// the next `,`/`)` is sufficient and keeps the probe honest.
    private static func boolArgumentIsLiteralTrue(key: String, in call: String) -> Bool {
        guard let range = call.range(of: "\(key):") else { return false }
        let value = call[range.upperBound...]
            .prefix { $0 != "," && $0 != ")" }
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value == "true"
    }
}
