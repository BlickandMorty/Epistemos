import Testing
import Foundation
@testable import Epistemos

/// SS-H keystone (owner's #2 priority): local chat must SEE the skills catalog even
/// when it can't drive the tool loop, and a non-agent model's tool-needing queries
/// must route to a fitting agent-capable model instead of silently degrading to a
/// tool-less / skill-less stream.
@Suite("Skills keystone (SS-H)")
struct SkillsKeystoneTests {

    @Test("the direct (tool-loop-less) stream injects the ChatLite skills catalog")
    func directStreamInjectsCatalog() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Engine/PipelineService.swift")
        // A skills-catalog block is built + appended to the direct-stream systemParts.
        #expect(src.contains("chatLiteSkillsCatalogBlock(operatingMode: operatingMode)"))
        #expect(src.contains("Skills available to Epistemos"))
    }

    @Test("a non-agent model routes tool-needing queries to a fitting agent model, not toolless")
    func nonAgentRoutesToFittingAgentModel() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Engine/PipelineService.swift")
        // PART 2: the no-execution-plan non-agent branch checks for a fitting agent
        // model + tool-need before degrading. fittingLocalAgentTextModelID only
        // returns a model that fits memory (no OOM swap).
        #expect(src.contains("if Self.autoToolRouteArmed, inference.fittingLocalAgentTextModelID != nil"))
        #expect(src.contains("Self.autoRouteNeedsTools(query: query, tools: candidateTools) == true"))
    }
}
