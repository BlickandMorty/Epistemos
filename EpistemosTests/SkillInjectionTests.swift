import Testing
@testable import Epistemos

// Skills are generated to disk by SkillGenerator, but before this seam existed
// SkillManifest.loadSkillContent had ZERO callers — generated skills never reached
// any prompt. LocalAgentPromptBuilder.foldingSkillContent is the seam that folds
// them into the system prompt's additional instructions (Procedural Memory). These
// tests pin that fold so the feature can't silently regress to dead-weight again.

@Suite("Skill Injection")
struct SkillInjectionTests {

    @Test("empty or blank skills leave the instructions untouched")
    func emptySkillsLeaveInstructionsUnchanged() {
        #expect(LocalAgentPromptBuilder.foldingSkillContent("", into: "base") == "base")
        #expect(LocalAgentPromptBuilder.foldingSkillContent("   \n  ", into: "base") == "base")
        #expect(LocalAgentPromptBuilder.foldingSkillContent("", into: nil) == nil)
    }

    @Test("skills with no prior instructions become the Procedural Memory block")
    func skillsWithoutInstructionsBecomeBlock() {
        let folded = LocalAgentPromptBuilder.foldingSkillContent(
            "--- Writing Voice ---\nPrefer terse, concrete sentences.",
            into: nil
        )
        let result = try? #require(folded)
        #expect(result?.contains("## Procedural Memory") == true)
        #expect(result?.contains("Prefer terse, concrete sentences.") == true)
    }

    @Test("skills append after existing instructions, instructions kept first")
    func skillsAppendAfterInstructions() {
        let folded = LocalAgentPromptBuilder.foldingSkillContent(
            "--- Guardrails ---\nNever fabricate citations.",
            into: "Answer concisely."
        )
        let result = try? #require(folded)
        #expect(result?.contains("Answer concisely.") == true)
        #expect(result?.contains("## Procedural Memory") == true)
        #expect(result?.contains("Never fabricate citations.") == true)
        // Instructions precede the procedural-memory block.
        if let result,
           let instrRange = result.range(of: "Answer concisely."),
           let memoRange = result.range(of: "## Procedural Memory") {
            #expect(instrRange.lowerBound < memoRange.lowerBound)
        }
    }
}
