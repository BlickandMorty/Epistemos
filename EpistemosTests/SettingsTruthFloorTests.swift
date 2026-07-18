import Foundation
import Testing

@Suite("Settings Truth Floor (T0)")
struct SettingsTruthFloorTests {

    private static let auditedSettingsRows: [String] = [
        "Epistemos/Views/Settings/AnswerPacketHealthRow.swift",
        "Epistemos/Views/Settings/ArenaHealthRow.swift",
        "Epistemos/Views/Settings/CLIDiscoveryHealthRow.swift",
        "Epistemos/Views/Settings/DeploymentProfileHealthRow.swift",
        "Epistemos/Views/Settings/EditorBundleHealthRow.swift",
        "Epistemos/Views/Settings/EidosHealthRow.swift",
        "Epistemos/Views/Settings/KnowledgeCoreReadParityHealthRow.swift",
        "Epistemos/Views/Settings/KnowledgeCoreRuntimeHealthRow.swift",
        "Epistemos/Views/Settings/OpLogProjectionHealthRow.swift",
        "Epistemos/Views/Settings/ProcessMemoryHealthRow.swift",
        "Epistemos/Views/Settings/SearchFusionHealthRow.swift",
        "Epistemos/Views/Settings/ShadowSearchHealthRow.swift",
        "Epistemos/Views/Settings/VaultRecallHealthRow.swift",
    ]

    @Test("every audited Settings row carries the verified-floor chip strip")
    func everyAuditedSettingsRowCarriesVerifiedFloorChipStrip() throws {
        for path in Self.auditedSettingsRows {
            let source = try loadMirroredSourceTextFile(path)
            #expect(source.contains("VerifiedFloorChipStrip("),
                    "\(path) must surface the verified-floor truth chip")
        }
    }

    @Test("chip-strip call sites expose production wiring and PASS-witness gates")
    func chipStripCallSitesExposeTruthContract() throws {
        for path in Self.auditedSettingsRows {
            let source = try loadMirroredSourceTextFile(path)
            let blocks = Self.verifiedFloorCallBlocks(in: source)
            #expect(!blocks.isEmpty, "\(path) must have a VerifiedFloorChipStrip call")

            for block in blocks {
                #expect(block.contains("productionWired:"),
                        "\(path) chip strip must name the production wiring predicate")
                #expect(block.contains("falsifierPassed:"),
                        "\(path) chip strip must name the PASS witness predicate")
                #expect(block.contains("falsifier:"),
                        "\(path) chip strip must link the falsifier/audit path")
                #expect(block.contains("wiredToday:"),
                        "\(path) chip strip must explain what is wired today")
                #expect(block.contains("stillStub:"),
                        "\(path) chip strip must explain what is still stub/status-only")
                #expect(!block.contains("substrateTint:"),
                        "\(path) must not directly color the substrate chip")
            }
        }
    }

    @Test("VerifiedFloorChipStrip gates green on production wiring plus PASS witness")
    func verifiedFloorChipStripGreenGateIsConjunctive() throws {
        let source = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/SettingsSurfaceComponents.swift"
        )

        #expect(source.contains("productionWired && falsifierPassed"),
                "green eligibility must require both production wiring and a PASS witness")
        #expect(source.contains("Green requires production wiring plus primary PASS witness."),
                "the row tooltip must spell out the T0 truth rule")
    }

    private static func verifiedFloorCallBlocks(in source: String) -> [String] {
        var blocks: [String] = []
        var searchStart = source.startIndex

        while let range = source.range(
            of: "VerifiedFloorChipStrip(",
            range: searchStart..<source.endIndex
        ) {
            var index = range.lowerBound
            var depth = 0
            var sawOpen = false

            while index < source.endIndex {
                let char = source[index]
                if char == "(" {
                    depth += 1
                    sawOpen = true
                } else if char == ")" {
                    depth -= 1
                    if sawOpen && depth == 0 {
                        let end = source.index(after: index)
                        blocks.append(String(source[range.lowerBound..<end]))
                        searchStart = end
                        break
                    }
                }
                index = source.index(after: index)
            }

            if searchStart == range.lowerBound {
                break
            }
        }

        return blocks
    }
}
