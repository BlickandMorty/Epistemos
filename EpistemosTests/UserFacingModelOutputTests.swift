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

    @Test("final text keeps natural answers that start with conversational openers")
    func finalTextKeepsNaturalAnswerThatStartsWithConversationalOpener() {
        let raw = """
        Let me start by giving the direct answer: the phrase refers to a modern power arrangement rather than a fixed technical doctrine.
        """

        #expect(
            UserFacingModelOutput.finalVisibleText(from: raw)
                == "Let me start by giving the direct answer: the phrase refers to a modern power arrangement rather than a fixed technical doctrine."
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

    // MARK: - Gemma 4 QAT bracket-delimited reasoning ([Start thinking] / [End thinking])
    //
    // These transcripts are the on-device E2B GGUF ground truth (llama-cli
    // b9370). Gemma brackets its chain-of-thought with `[Start thinking]` …
    // `[End thinking]` and emits the user-facing answer AFTER the close marker.
    // Before the markers were registered, the whole reasoning dump leaked into
    // the chat bubble welded to the answer — the user's "thinking is attached
    // to the answer, all cluttered, final answer sometimes never appears" bug.

    @Test("Gemma [Start thinking]…[End thinking] reasoning is stripped, answer surfaces")
    func gemmaBracketThinkingStripsToAnswer() {
        let raw = """
        [Start thinking]
        Thinking Process:

        1.  **Analyze the Request:** The user wants 17 times 4.
        2.  **Determine the Calculation:** 17 * 4 = 68.
        [End thinking]

        **68**

        17 × 4 = 68, computed as (10 × 4) + (7 × 4) = 40 + 28.
        """

        let answer = UserFacingModelOutput.finalVisibleText(from: raw)
        #expect(answer.contains("68"))
        #expect(!answer.contains("[Start thinking]"))
        #expect(!answer.contains("[End thinking]"))
        #expect(!answer.contains("Analyze the Request"))
        #expect(!answer.contains("Thinking Process"))
    }

    @Test("Gemma reasoning streaming in the [Start thinking] block stays out of visible text")
    func gemmaBracketThinkingStreamingSuppressed() {
        // Mid-stream: open marker seen, no close yet — nothing user-facing.
        let midStream = """
        [Start thinking]
        Thinking Process:

        1.  **Analyze the Request:** The user wants 17 times 4.
        """
        #expect(UserFacingModelOutput.streamingVisibleText(from: midStream).isEmpty)
    }

    @Test("Gemma lowercase [start thinking] bracket variant is also stripped")
    func gemmaLowercaseBracketThinkingStripped() {
        let raw = """
        [start thinking]
        Let me work through this carefully step by step.
        [end thinking]

        The capital of France is Paris.
        """
        let answer = UserFacingModelOutput.finalVisibleText(from: raw)
        #expect(answer.contains("Paris"))
        #expect(!answer.lowercased().contains("[start thinking]"))
        #expect(!answer.lowercased().contains("work through this"))
    }

    @Test("leaked dotted-namespace tool-call XML is stripped from the answer")
    func dottedToolCallXMLStripped() {
        // A local model tried to call a tool but the loop never executed it, so
        // the raw grammar leaked. It must not render as the answer (the user's
        // 2026-06-16 'second response only returned this crap' screenshot).
        let raw = """
        <file.search>
         <parameters>
          <pattern>essay</pattern>
          <path>.</path>
          <target>files</target>
         </parameters>
        </file.search>
        """
        #expect(UserFacingModelOutput.finalVisibleText(from: raw).isEmpty)

        // But a real answer that merely follows such a block survives.
        let withAnswer = raw + "\n\nThe essay's strongest section is the opening."
        let cleaned = UserFacingModelOutput.finalVisibleText(from: withAnswer)
        #expect(cleaned.contains("strongest section"))
        #expect(!cleaned.contains("<file.search>"))
        #expect(!cleaned.contains("<parameters>"))
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

    @Test("direct tool-call narration is suppressed in plain chat output")
    func directToolCallNarrationIsSuppressedInPlainChatOutput() {
        let raw = """
        I will call the read_file tool to read the file and then use the output to create a file containing the relevant content.

        ```tool_call
        {"name": "read_file", "arguments": {"path": "~/home/user/my_file.txt"}}
        ```
        """

        #expect(UserFacingModelOutput.streamingVisibleText(from: raw).isEmpty)
        #expect(UserFacingModelOutput.finalVisibleText(from: raw).isEmpty)
        #expect(
            UserFacingModelOutput.streamingReasoningText(from: raw)
                .contains("I will call the read_file tool")
        )
    }

    @Test("function call envelopes stay out of plain chat output")
    func functionCallEnvelopesStayOutOfPlainChatOutput() {
        let raw = """
        Let me try that first.

        <function_call>
        {"name":"note.research_digest","content":{"notes":["All Things Must Go"]}}
        </function_call>
        """

        #expect(UserFacingModelOutput.streamingVisibleText(from: raw).isEmpty)
        #expect(UserFacingModelOutput.finalVisibleText(from: raw).isEmpty)
    }

    @Test("action envelopes stay out of plain chat output")
    func actionEnvelopesStayOutOfPlainChatOutput() {
        let raw = """
        I will create the note if it does not exist.

        <action>
        {"type":"note.create","parameters":{"title":"Agent Research Inbox"}}
        </action>
        """

        #expect(UserFacingModelOutput.streamingVisibleText(from: raw).isEmpty)
        #expect(UserFacingModelOutput.finalVisibleText(from: raw).isEmpty)
    }

    @Test("incomplete function call envelopes suppress prelude-only control narration")
    func incompleteFunctionCallEnvelopesSuppressPreludeOnlyControlNarration() {
        let raw = """
        Let me call the tool.

        <function_call>
        {"name":"vault.search","arguments":{"query":"private"}}
        """

        #expect(UserFacingModelOutput.streamingVisibleText(from: raw).isEmpty)
        #expect(UserFacingModelOutput.finalVisibleText(from: raw).isEmpty)
    }

    @Test("explicit final answers remain visible after control envelopes")
    func explicitFinalAnswersRemainVisibleAfterControlEnvelopes() {
        let raw = """
        <function_call>
        {"name":"vault.search","arguments":{"query":"local models"}}
        </function_call>

        Final Answer:
        Use the local model route only after the harness witness passes.
        """

        #expect(
            UserFacingModelOutput.streamingVisibleText(from: raw)
                == "Use the local model route only after the harness witness passes."
        )
        #expect(
            UserFacingModelOutput.finalVisibleText(from: raw)
                == "Use the local model route only after the harness witness passes."
        )
    }

    @Test("streaming reasoning strips dangling final-answer markers without content")
    func streamingReasoningTextDropsDanglingAnswerMarker() {
        let raw = """
        <think>Inspecting the selected passage.</think>

        Final Answer:
        """

        #expect(UserFacingModelOutput.streamingReasoningText(from: raw).isEmpty)
        #expect(UserFacingModelOutput.streamingVisibleText(from: raw).isEmpty)
    }

    @Test("final text drops a dangling answer marker without surfacing it raw")
    func finalTextDropsDanglingAnswerMarker() {
        let raw = """
        <think>Inspecting the selected passage.</think>

        Final Answer:
        """

        #expect(UserFacingModelOutput.finalVisibleText(from: raw).isEmpty)
    }

    @Test("final text drops dangling fenced-language markers without surfacing them raw")
    func finalTextDropsDanglingFencedLanguageMarker() {
        let raw = """
        ```xml
        """

        #expect(UserFacingModelOutput.finalVisibleText(from: raw).isEmpty)
    }

    @Test("final text drops malformed repeated tool payload fragments without surfacing raw JSON")
    func finalTextDropsMalformedRepeatedToolPayloadFragments() {
        let raw = """
        {"name": "vault_search", "arguments": {"path": "tmp"}}{"name": "vault_search", "arguments": {"path": "tmp
        """

        #expect(UserFacingModelOutput.streamingVisibleText(from: raw).isEmpty)
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

    @Test("analysis-style prose prelude stays in reasoning and salvages the summary as the answer")
    func analysisStyleProsePreludeStaysInReasoning() {
        let raw = """
        I will analyze the provided text and provide an answer based on the content.

        Key points include:
        1. The author reframes free will around a veto system.
        2. The basal ganglia act as the gating mechanism.

        In summary, the essay argues that agency lives in regulatory veto power rather than magical authorship.
        """

        #expect(UserFacingModelOutput.streamingVisibleText(from: raw).isEmpty)
        #expect(
            UserFacingModelOutput.streamingReasoningText(from: raw)
                .contains("I will analyze the provided text")
        )
        #expect(
            UserFacingModelOutput.finalVisibleText(from: raw)
                == "In summary, the essay argues that agency lives in regulatory veto power rather than magical authorship."
        )
    }

    @Test("to-answer-this prose preludes stay in reasoning until the real answer arrives")
    func toAnswerThisPreludeStaysInReasoning() {
        let raw = """
        To answer this well, I should first compare the central claims, decide which objections matter most, and keep the framing careful.

        The essay's strongest move is shifting agency from magical authorship to the capacity to veto and regulate impulses.
        """

        #expect(UserFacingModelOutput.streamingVisibleText(from: raw).isEmpty)
        #expect(
            UserFacingModelOutput.streamingReasoningText(from: raw)
                .contains("To answer this well")
        )
        #expect(
            UserFacingModelOutput.finalVisibleText(from: raw)
                == "The essay's strongest move is shifting agency from magical authorship to the capacity to veto and regulate impulses."
        )
    }

    @Test("review-and-analyze local preludes stay in reasoning and keep the review in the final answer")
    func reviewAndAnalyzePreludeStaysInReasoning() {
        let raw = """
        I need to review the provided text and flag the biggest issues. Let me analyze the content:

        1. Philosophical Caution: The text should distinguish readiness-potential findings from broader claims about agency.
        2. Schurger et al. (2012): The reinterpretation matters because it weakens overconfident appeals to Libet.
        3. Retributive Desert: The essay should say more clearly why punishment becomes harder to justify on this view.
        """

        #expect(UserFacingModelOutput.streamingVisibleText(from: raw).isEmpty)
        #expect(
            UserFacingModelOutput.streamingReasoningText(from: raw)
                .contains("I need to review the provided text and flag the biggest issues")
        )
        #expect(
            UserFacingModelOutput.finalVisibleText(from: raw)
                == """
                1. Philosophical Caution: The text should distinguish readiness-potential findings from broader claims about agency.
                2. Schurger et al. (2012): The reinterpretation matters because it weakens overconfident appeals to Libet.
                3. Retributive Desert: The essay should say more clearly why punishment becomes harder to justify on this view.
                """
        )
    }
}

@Suite("ThinkTagStreamRouter")
struct ThinkTagStreamRouterTests {
    @Test("splits XML <think> reasoning from visible answer")
    func splitsXmlThinkTag() {
        let router = ThinkTagStreamRouter()
        let emit = router.ingest("<think>reasoning here</think>The answer is 42.")
        #expect(emit.visible == "The answer is 42.")
        #expect(emit.thinking == "reasoning here")
    }

    @Test("splits Gemma [Start thinking] reasoning from the post-marker answer")
    func splitsGemmaBracketThinking() {
        let router = ThinkTagStreamRouter()
        let emit = router.ingest("[Start thinking]\nstep one\nstep two\n[End thinking]\n\n**68**")
        #expect(emit.thinking.contains("step one"))
        #expect(emit.thinking.contains("step two"))
        #expect(emit.visible.contains("68"))
        #expect(!emit.visible.contains("[Start thinking]"))
        #expect(!emit.visible.contains("[End thinking]"))
        #expect(!emit.visible.contains("step one"))
    }

    @Test("holds a Gemma open marker split across stream chunks until it resolves")
    func holdsGemmaMarkerSplitAcrossChunks() {
        let router = ThinkTagStreamRouter()
        // The 16-char "[Start thinking]" marker arrives in two network chunks.
        // The half-formed "[Start think" must NOT leak as visible text.
        let first = router.ingest("[Start think")
        #expect(first.visible.isEmpty)
        #expect(first.thinking.isEmpty)
        let second = router.ingest("ing]\ndeliberating\n[End thinking]\nDone.")
        #expect(second.thinking.contains("deliberating"))
        #expect(second.visible.contains("Done."))
        #expect(!second.visible.contains("[Start think"))
    }

    @Test("thinking-trace display strips raw markdown emphasis and heading syntax")
    func thinkingDisplayDeMarkdowns() {
        let raw = """
        ### Plan
        1. **Analyze the Request:** parse it.
        2. __Draft__ the reply.

        > a quoted aside
        """
        let shown = ProcessDisclosureTextBlock.displayText(for: raw)
        #expect(shown.contains("Plan"))
        #expect(!shown.contains("**"))
        #expect(!shown.contains("__"))
        #expect(!shown.contains("#"))
        #expect(shown.contains("Analyze the Request:"))
        #expect(shown.contains("1.")) // list markers preserved
        #expect(shown.contains("a quoted aside"))
        #expect(!shown.contains(">"))
    }

    @Test("unterminated Gemma reasoning streams as thinking, never leaks as visible")
    func tracksThinkingStateForBracketBlock() {
        let router = ThinkTagStreamRouter()
        // Reasoning after an unclosed [Start thinking] streams out the thinking
        // channel live (NOT held until flush) and never leaks into visible text.
        let emit = router.ingest("[Start thinking]\nstill reasoning")
        #expect(emit.thinking.contains("still reasoning"))
        #expect(emit.visible.isEmpty)
        #expect(router.isCurrentlyThinking)
        // A partial close marker split across chunks is held back, then flushed
        // into the thinking channel at stream end — never dropped, never visible.
        let emit2 = router.ingest(" wrapping up [End think")
        #expect(emit2.visible.isEmpty)
        #expect(emit2.thinking.contains("wrapping up"))
        let flushed = router.flush()
        #expect(flushed.visible.isEmpty)
    }
}
