import Testing
@testable import Epistemos

@Suite("UserFacingModelOutput")
struct UserFacingModelOutputTests {
    @Test("streaming text suppresses think blocks until answer appears")
    func streamingTextSuppressesThinkBlocksUntilAnswerAppears() {
        let partial = "<think>I should inspect this first"
        #expect(UserFacingModelOutput.streamingVisibleText(from: partial).isEmpty)

        let completed = """
        <think>I should inspect this first.</think>

        Final Answer:
        Use the prepared router as the default local model.
        """

        #expect(
            UserFacingModelOutput.streamingVisibleText(from: completed)
                == "Use the prepared router as the default local model."
        )
    }

    @Test("final text strips explicit thinking prelude")
    func finalTextStripsExplicitThinkingPrelude() {
        let raw = """
        Thinking Process:
        I should compare the assumptions first.

        Final Answer:
        The direct answer is to treat the phrase as a loose descriptor, not a fixed term.
        """

        #expect(
            UserFacingModelOutput.finalVisibleText(from: raw)
                == "The direct answer is to treat the phrase as a loose descriptor, not a fixed term."
        )
    }

    @Test("final text strips explicit answer markers at the start of cleaned output")
    func finalTextStripsLeadingAnswerMarker() {
        let raw = """
        <think>I should inspect the framing first.</think>

        Final Answer:
        Treat it as a modern hegemonic label unless the source defines it more narrowly.
        """

        #expect(
            UserFacingModelOutput.finalVisibleText(from: raw)
                == "Treat it as a modern hegemonic label unless the source defines it more narrowly."
        )
    }

    @Test("final text drops leading reasoning-only sections when an answer follows")
    func finalTextDropsLeadingReasoningOnlySections() {
        let raw = """
        Here's a thinking process that leads to the comparison:

        1. Deconstruct the Request:
        - Identify the topic.
        - Clarify the comparison target.

        Self-Correction during drafting: I should avoid overstating the claim.

        The stronger interpretation is that the phrase refers to modern US-led hegemony rather than a formal scholarly category.
        """

        #expect(
            UserFacingModelOutput.finalVisibleText(from: raw)
                == "The stronger interpretation is that the phrase refers to modern US-led hegemony rather than a formal scholarly category."
        )
    }

    @Test("final text suppresses reasoning dumps that never produce a user-facing answer")
    func finalTextSuppressesReasoningDumpWithoutAnswer() {
        let raw = """
        Here's a thinking process that leads to the comparison:

        1. Deconstruct the Request:
        - Identify the topic.
        - Clarify the comparison target.

        Self-Correction during drafting: I should avoid overstating the claim.

        Wait, one more possibility: the phrase might refer to a broader bloc.

        Let's check if the wording is anchored to a specific authorial frame first.
        """

        #expect(UserFacingModelOutput.finalVisibleText(from: raw).isEmpty)
    }

    @Test("streaming text stays silent during prose reasoning until an explicit answer appears")
    func streamingTextSuppressesProseReasoningPrelude() {
        let partial = """
        Thinking Process:
        Ice floats because solid water is less dense than liquid water.
        """

        #expect(UserFacingModelOutput.streamingVisibleText(from: partial).isEmpty)

        let completed = """
        Thinking Process:
        Ice floats because solid water is less dense than liquid water.

        Final Answer:
        Ice floats because hydrogen bonds create an open lattice.
        """

        #expect(
            UserFacingModelOutput.streamingVisibleText(from: completed)
                == "Ice floats because hydrogen bonds create an open lattice."
        )
    }

    @Test("streaming text suppresses incomplete reasoning lead-ins")
    func streamingTextSuppressesIncompleteReasoningLeadIns() {
        #expect(UserFacingModelOutput.streamingVisibleText(from: "Here's a thinking").isEmpty)
        #expect(UserFacingModelOutput.streamingVisibleText(from: "Thinking Process").isEmpty)
        #expect(UserFacingModelOutput.streamingVisibleText(from: "Thought Process").isEmpty)
    }
}
