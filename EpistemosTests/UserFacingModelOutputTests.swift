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

    @Test("structured local analysis plans stay out of the visible answer stream")
    func structuredLocalAnalysisPlansStayOutOfVisibleAnswerStream() {
        let raw = """
        1. Query:
        - Summarize the key findings of these academic references on neuroscience and free will.

        2. Detailed Analysis with chunk_reduce:
        Input Text: The list of references formatted into a text file.
        Instructions: Extract key points from methodology, findings, and implications.
        Reduce Strategy: Select only the most relevant passages.

        3. Pattern Identification:
        - After processing, identify recurring themes such as readiness potentials and unconscious processing.

        This approach will efficiently summarize the references and surface common research threads.
        """

        #expect(UserFacingModelOutput.streamingVisibleText(from: raw).isEmpty)
        #expect(UserFacingModelOutput.finalVisibleText(from: raw).isEmpty)
        #expect(
            UserFacingModelOutput.streamingReasoningText(from: raw)
                .contains("Detailed Analysis with chunk_reduce")
        )
    }

    @Test("tool-planning prose stays inside reasoning instead of the visible answer stream")
    func toolPlanningProseStaysInReasoning() {
        let raw = """
        I'll begin by testing the functions available to ensure they are working as expected. Let me start by calling the find_symbol function with some sample parameters.

        Here is the function call:
        {"name":"find_symbol","arguments":{"symbol":"Foo","max_results":10}}
        """

        #expect(UserFacingModelOutput.streamingVisibleText(from: raw).isEmpty)
        #expect(UserFacingModelOutput.finalVisibleText(from: raw).isEmpty)
        #expect(
            UserFacingModelOutput.streamingReasoningText(from: raw)
                .contains("Here is the function call")
        )
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

    @Test("streaming text recovers an answer marker inside an unclosed think block")
    func streamingTextRecoversAnswerInsideUnclosedThinkBlock() {
        let raw = """
        <think>
        I should inspect the framing first.

        Final Answer:
        Use the local Qwen path and answer directly.
        """

        #expect(
            UserFacingModelOutput.streamingVisibleText(from: raw)
                == "Use the local Qwen path and answer directly."
        )
    }

    @Test("final text recovers an answer inside an unclosed think block")
    func finalTextRecoversAnswerInsideUnclosedThinkBlock() {
        let raw = """
        <think>
        I should compare the tradeoffs first.

        The stronger recommendation is to keep Thinking enabled for deeper local analysis.
        """

        #expect(
            UserFacingModelOutput.finalVisibleText(from: raw)
                == "The stronger recommendation is to keep Thinking enabled for deeper local analysis."
        )
    }

    @Test("streaming text strips orphan closing think tags before the visible answer")
    func streamingTextStripsOrphanClosingThinkTagPrelude() {
        let raw = """
        Okay, the user has a file and wants suggestions on edits. I need to ask for more details about the file and their goals.
        </think>

        Sure! Please provide the file and the specific edits or changes you'd like me to suggest, and I'll help with the most appropriate edits.
        """

        #expect(
            UserFacingModelOutput.streamingVisibleText(from: raw)
                == "Sure! Please provide the file and the specific edits or changes you'd like me to suggest, and I'll help with the most appropriate edits."
        )
    }

    @Test("final text strips orphan closing think tags before the visible answer")
    func finalTextStripsOrphanClosingThinkTagPrelude() {
        let raw = """
        Okay, so I need to come up with a very short title for a chat conversation that starts with the query: "need help making an app"
        I should make sure to keep the response concise and informative.
        </think>

        Great! Let's help you create boilerplate code for an iOS app. Below is a basic structure to get you started:
        """

        #expect(
            UserFacingModelOutput.finalVisibleText(from: raw)
                == "Great! Let's help you create boilerplate code for an iOS app. Below is a basic structure to get you started:"
        )
    }

    @Test("streaming text suppresses scratch pad tool scaffolding until an answer appears")
    func streamingTextSuppressesScratchPadToolScaffolding() {
        let partial = """
        <scratch_pad>
        <name>vault_recall</name>
        <arguments>
        <query>Metal philosophy</query>
        </arguments>
        """

        #expect(UserFacingModelOutput.streamingVisibleText(from: partial).isEmpty)

        let completed = """
        <scratch_pad>
        <name>vault_recall</name>
        <arguments>
        <query>Metal philosophy</query>
        <top_k>5</top_k>
        </arguments>
        </scratch_pad>

        Final Answer:
        Metal is compared to organs here as an analogy for tightly coordinated subsystems.
        """

        #expect(
            UserFacingModelOutput.streamingVisibleText(from: completed)
                == "Metal is compared to organs here as an analogy for tightly coordinated subsystems."
        )
    }

    @Test("final text strips scratch pad tool plans that never produce a user answer")
    func finalTextStripsScratchPadToolPlansWithoutAnswer() {
        let raw = """
        <scratch_pad>
        <name>vault_recall</name>
        <arguments>
        <query>Metal philosophy</query>
        <top_k>5</top_k>
        </arguments>
        </scratch_pad>
        """

        #expect(UserFacingModelOutput.finalVisibleText(from: raw).isEmpty)
    }

    @Test("final text strips malformed XML tool scaffolding before the answer")
    func finalTextStripsMalformedXmlToolScaffolding() {
        let raw = """
        <tool_call<name>read_file</name<arguments><path>~/workspace/neurology/metal_philosophy_notes.txt</path><limit>500</limit><offset>1</offset></arguments></tool_call>

        Final Answer:
        The attached note argues that Metal coordinates compute stages the way organs coordinate bodily functions.
        """

        #expect(
            UserFacingModelOutput.finalVisibleText(from: raw)
                == "The attached note argues that Metal coordinates compute stages the way organs coordinate bodily functions."
        )
    }

    @Test("final text recovers an answer inside an unclosed scratch pad block")
    func finalTextRecoversAnswerInsideUnclosedScratchPadBlock() {
        let raw = """
        <scratch_pad>
        The tool call failed because the guessed path was missing.

        The attached note compares app stages to organs because each stage has a distinct role that only makes sense inside the larger coordinated system.
        """

        #expect(
            UserFacingModelOutput.finalVisibleText(from: raw)
                == "The attached note compares app stages to organs because each stage has a distinct role that only makes sense inside the larger coordinated system."
        )
    }
}
