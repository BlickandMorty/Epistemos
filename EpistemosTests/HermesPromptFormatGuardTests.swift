import Testing

/// Hermes Prompt Format Guard — locks the current load-bearing reality
/// from `MASTER_RESEARCH_INDEX_2026_05_02.md` §0 honest discovery H2:
///
/// > "Hermes-parity uses plain markdown prompts, NOT NousResearch ChatML
/// > XML. `agent_core/src/prompts.rs` opens with
/// > `BASE_SYSTEM_PROMPT = r#"You are Epistemos…"#` — no `<|im_start|>`
/// > markers."
///
/// This guard prevents a future agent from silently wiring full ChatML
/// role markers (`<|im_start|>system`, `<|im_end|>`, `<|im_start|>user`,
/// etc.) into the Swift `HermesPromptBuilder` or the Rust
/// `agent_core::prompts` module without an explicit deliberation brief.
///
/// **Note on tool-call XML tags.** The current Swift Hermes prompt uses
/// `<tools>`, `<tool_call>`, `<tool_response>`, `<think>`, and
/// `<scratch_pad>` — these are NousResearch's function-calling format,
/// **not** ChatML role markers. They are explicitly allowed by this guard.
/// Only the role-marker tokens (`<|im_start|>` / `<|im_end|>`) are
/// forbidden, because those are what would signal a migration of the
/// prompt boundary from plain markdown to true ChatML.
///
/// Doctrine §7 lane: Pro track — Hermes gateway protocol correctness.
@Suite("Hermes Prompt Format Guard")
struct HermesPromptFormatGuardTests {

    // MARK: - Swift HermesPromptBuilder

    @Test("Swift HermesPromptBuilder uses plain markdown, not ChatML role markers")
    func swiftHermesBuilderUsesPlainMarkdownNotChatML() throws {
        let source = try loadMirroredSourceTextFile(
            "Epistemos/LocalAgent/HermesPromptBuilder.swift"
        )

        // The forbidden ChatML role markers. If any of these appears in
        // the Swift Hermes builder, the prompt boundary has shifted from
        // plain markdown to true ChatML and downstream tokenization +
        // model selection assumptions break.
        let forbiddenChatMLMarkers = [
            "<|im_start|>",
            "<|im_end|>",
            "<|im_sep|>",
            "<|endoftext|>",
            "<|begin_of_text|>",
            "<|end_of_text|>",
        ]

        for marker in forbiddenChatMLMarkers {
            #expect(!source.contains(marker),
                    "HermesPromptBuilder.swift must NOT contain ChatML marker \(marker) — see MASTER_RESEARCH_INDEX §H2; migrating to ChatML requires a deliberation brief")
        }

        // Sanity: the existing function-calling XML tags ARE expected. If
        // these disappear, someone removed Hermes function-calling support
        // entirely — which would also need a deliberation brief.
        #expect(source.contains("<tools>"),
                "HermesPromptBuilder must keep the <tools> XML wrapper for the function-calling format")
        #expect(source.contains("<tool_call>"),
                "HermesPromptBuilder must keep the <tool_call> XML wrapper for the function-calling format")
        #expect(source.contains("<tool_response>"),
                "HermesPromptBuilder must keep the <tool_response> XML wrapper for the function-calling format")
        #expect(source.contains("<think>"),
                "HermesPromptBuilder must keep the <think> XML wrapper for hidden reasoning")
    }

    @Test("Swift HermesPromptBuilder reaffirms the gateway boundary lines")
    func swiftHermesBuilderEmitsGatewayBoundaryLines() throws {
        let source = try loadMirroredSourceTextFile(
            "Epistemos/LocalAgent/HermesPromptBuilder.swift"
        )

        // The two boundary lines from HermesGatewayPolicy must be injected
        // into the system prompt so the model sees them at every turn.
        // If a refactor drops the interpolation, the model loses the
        // architectural reminder that Hermes is the cloud/gateway membrane,
        // not the substrate authority.
        #expect(source.contains("HermesGatewayPolicy.externalTierBoundaryLine"),
                "HermesPromptBuilder must inject HermesGatewayPolicy.externalTierBoundaryLine into the system prompt")
        #expect(source.contains("HermesGatewayPolicy.localCoreBoundaryLine"),
                "HermesPromptBuilder must inject HermesGatewayPolicy.localCoreBoundaryLine into the system prompt")
    }

    @Test("Swift Hermes mirrors prefer Rust Hermes bridge when bindings are present")
    func swiftHermesMirrorsPreferRustBridgeWhenPresent() throws {
        let promptBuilder = try loadMirroredSourceTextFile(
            "Epistemos/LocalAgent/HermesPromptBuilder.swift"
        )
        let parser = try loadMirroredSourceTextFile(
            "Epistemos/Omega/Inference/ToolCallParser.swift"
        )
        let bridge = try loadMirroredSourceTextFile("agent_core/src/bridge.rs")

        #expect(promptBuilder.contains("#if canImport(agent_coreFFI)"))
        #expect(promptBuilder.contains("hermesBuildSystemPrompt(inputJson: json)"),
                "HermesPromptBuilder must call Rust hermes_build_system_prompt when agent_coreFFI is linked")
        #expect(parser.contains("hermesParseToolCalls(text: text)"),
                "ToolCallParser must call Rust hermes_parse_tool_calls before Swift fallback strategies")
        #expect(bridge.contains("pub fn hermes_build_system_prompt"))
        #expect(bridge.contains("pub fn hermes_parse_tool_calls"))
    }

    // Hermes Expert Mode runner removed in slice 1 of the Hermes UI
    // teardown (2026-05-05). The Rust runtime path itself stays — the
    // canonical /ask flow now lives in the main chat surface; tests
    // for the prompt format + function-call parser remain in the
    // Rust agent_core/tests/hermes_runtime.rs integration suite.

    // MARK: - Rust agent_core::prompts

    @Test("Rust agent_core/src/prompts.rs uses plain markdown, not ChatML role markers")
    func rustPromptsModuleUsesPlainMarkdownNotChatML() throws {
        let source = try loadMirroredSourceTextFile("agent_core/src/prompts.rs")

        let forbiddenChatMLMarkers = [
            "<|im_start|>",
            "<|im_end|>",
            "<|im_sep|>",
            "<|endoftext|>",
            "<|begin_of_text|>",
            "<|end_of_text|>",
        ]

        for marker in forbiddenChatMLMarkers {
            #expect(!source.contains(marker),
                    "agent_core/src/prompts.rs must NOT contain ChatML marker \(marker) — see MASTER_RESEARCH_INDEX §H2; migrating to ChatML requires a deliberation brief")
        }

        // Sanity: the canonical opening line per §H2 must remain.
        #expect(source.contains("You are Epistemos"),
                "BASE_SYSTEM_PROMPT must keep its canonical opening line; if you intentionally rewrote it, update MASTER_RESEARCH_INDEX §H2 and this test in the same patch")
    }

    @Test("Rust prompt mode enum stays at the four documented modes")
    func rustPromptModeEnumStaysAtFourModes() throws {
        let source = try loadMirroredSourceTextFile("agent_core/src/prompts.rs")

        // The four PromptMode variants are referenced by every caller of
        // build_system_prompt. Adding a fifth variant silently is a wire-
        // contract change.
        for variant in ["General", "Research", "Code", "LocalFallback"] {
            #expect(source.contains(variant),
                    "PromptMode must keep variant \(variant)")
        }
        #expect(source.contains("pub enum PromptMode {"),
                "PromptMode must remain a public enum")
    }

    // MARK: - Cross-file invariant — no other file is sneaking in ChatML

    @Test("no other Swift or Rust source in the repo introduces ChatML role markers")
    func noOtherSourceIntroducesChatMLMarkers() throws {
        // Spot-check the obvious adjacent surfaces. If a future patch adds
        // a second prompt-building site, this list is incomplete — but the
        // gate is still useful for everything currently named here.
        let adjacent = [
            "Epistemos/LocalAgent/LocalAgentLoop.swift",
            "Epistemos/LocalAgent/LocalToolGrammar.swift",
            "Epistemos/LocalAgent/ConfidenceRouter.swift",
            "Epistemos/Engine/MLXInferenceService.swift",
            "agent_core/src/agent_loop.rs",
            "agent_core/src/providers/claude.rs",
            "agent_core/src/providers/perplexity.rs",
        ]

        for relativePath in adjacent {
            let source = try loadMirroredSourceTextFile(relativePath)
            #expect(!source.contains("<|im_start|>"),
                    "\(relativePath) must NOT contain ChatML <|im_start|> — see MASTER_RESEARCH_INDEX §H2")
            #expect(!source.contains("<|im_end|>"),
                    "\(relativePath) must NOT contain ChatML <|im_end|> — see MASTER_RESEARCH_INDEX §H2")
        }
    }
}
