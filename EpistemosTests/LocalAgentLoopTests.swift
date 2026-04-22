import Foundation
import Testing
@testable import Epistemos

@Suite("Local Agent Loop")
struct LocalAgentLoopTests {
    @Test("tool call parsing reuses the shared Hermes tag format")
    func toolCallParsingReusesTheSharedHermesTagFormat() {
        let output = """
        <scratch_pad>Search first, then summarize.</scratch_pad>
        <tool_call>
        {"name":"vault_search","arguments":{"query":"transformer architecture","limit":2}}
        </tool_call>
        <tool_call>
        {"name":"vault_read","arguments":{"path":"ml/transformers.md"}}
        </tool_call>
        """

        let calls = LocalAgentLoop.parseToolCalls(from: output)

        #expect(calls.count == 2)
        #expect(calls[0].name == "vault_search")
        #expect(calls[0].argumentsJson.contains("\"query\":\"transformer architecture\""))
        #expect(calls[1].name == "vault_read")
        // JSONSerialization may escape forward slashes: ml/transformers.md → ml\/transformers.md
        let pathValue = calls[1].argumentsJson
            .replacingOccurrences(of: "\\/", with: "/")
        #expect(pathValue.contains("\"path\":\"ml/transformers.md\""))
    }

    @Test("history trimming keeps the original user message and newest context")
    func historyTrimmingKeepsTheOriginalUserMessageAndNewestContext() {
        let history = [
            LocalMessage(role: .user, content: String(repeating: "u", count: 80)),
            LocalMessage(role: .assistant, content: String(repeating: "a", count: 120)),
            LocalMessage(role: .tool, content: String(repeating: "t", count: 120)),
            LocalMessage(role: .assistant, content: String(repeating: "b", count: 120)),
            LocalMessage(role: .tool, content: String(repeating: "r", count: 120)),
        ]

        let trimmed = LocalAgentLoop.trimHistory(history, targetTokens: 75)

        #expect(trimmed.count < history.count)
        #expect(trimmed.first?.role == .user)
        #expect(trimmed.first?.content == history.first?.content)
        #expect(trimmed.last?.content == history.last?.content)
        #expect(LocalAgentLoop.approximateTokenCount(of: trimmed) <= 75)
    }

    @Test("local loop feeds tool responses into the next turn and returns final text")
    func localLoopFeedsToolResponsesIntoTheNextTurnAndReturnsFinalText() async throws {
        let promptRecorder = PromptRecorder()
        let responseQueue = ResponseQueue(outputs: [
            """
            <scratch_pad>Use the vault search tool.</scratch_pad>
            <tool_call>
            {"name":"vault_search","arguments":{"query":"transformer architecture"}}
            </tool_call>
            """,
            """
            <scratch_pad>Summarizing the returned notes.</scratch_pad>
            Transformer notes found: self-attention, multi-head attention, residual connections.
            """,
        ])

        let loop = LocalAgentLoop(
            generator: { prompt, _, _, _, _, onToken in
                await promptRecorder.record(prompt)
                let output = await responseQueue.nextOutput()
                await onToken(output)
                return output
            },
            toolExecutor: { name, argumentsJson in
                #expect(name == "vault_search")
                #expect(argumentsJson.contains("\"query\":\"transformer architecture\""))
                return LocalToolResult(
                    toolName: name,
                    resultJson: #"{"name":"vault_search","content":[{"path":"ml/transformers.md","excerpt":"Self-attention, MHA, residuals."}]}"#,
                    isError: false
                )
            }
        )

        let answer = try await loop.run(
            objective: "Find my transformer architecture notes and summarize them.",
            tools: [sampleTool()],
            maxTurns: 3,
            onToken: { _ in }
        )

        let prompts = await promptRecorder.snapshot()
        #expect(prompts.count == 2)
        #expect(prompts[0].contains("Find my transformer architecture notes and summarize them."))
        #expect(prompts[1].contains("<tool_response>"))
        #expect(answer == "Transformer notes found: self-attention, multi-head attention, residual connections.")
    }

    @Test("local loop executes legacy Qwen XML tool calls before returning the final answer")
    func localLoopExecutesLegacyQwenXmlToolCalls() async throws {
        let promptRecorder = PromptRecorder()
        let responseQueue = ResponseQueue(outputs: [
            """
            <scratch_pad>Use the vault search tool.</scratch_pad>
            <tool_call><function=vault_search><parameter=query>transformer architecture</parameter></function></tool_call>
            """,
            """
            <scratch_pad>Summarizing the returned notes.</scratch_pad>
            Transformer notes found from legacy XML tool calling.
            """,
        ])

        let loop = LocalAgentLoop(
            generator: { prompt, _, _, _, _, onToken in
                await promptRecorder.record(prompt)
                let output = await responseQueue.nextOutput()
                await onToken(output)
                return output
            },
            toolExecutor: { name, argumentsJson in
                #expect(name == "vault_search")
                #expect(argumentsJson.contains("\"query\":\"transformer architecture\""))
                return LocalToolResult(
                    toolName: name,
                    resultJson: #"{"name":"vault_search","content":[{"path":"ml/transformers.md","excerpt":"Legacy XML path still triggers tools."}]}"#,
                    isError: false
                )
            }
        )

        let answer = try await loop.run(
            objective: "Find my transformer architecture notes and summarize them.",
            tools: [sampleTool()],
            maxTurns: 3,
            onToken: { _ in }
        )

        let prompts = await promptRecorder.snapshot()
        #expect(prompts.count == 2)
        #expect(prompts[1].contains("<tool_response>"))
        #expect(answer == "Transformer notes found from legacy XML tool calling.")
    }

    @Test("local loop executes inline training-style tool call JSON before returning the final answer")
    func localLoopExecutesInlineTrainingStyleToolCallJson() async throws {
        let promptRecorder = PromptRecorder()
        let responseQueue = ResponseQueue(outputs: [
            #"""
            **[OBSERVE]:** ready
            **[REASON]:** <think>I should use the vault search tool.</think>
            **[ACT]:** `{"toolName":"vault_search","argumentsJson":"{\"query\":\"transformer architecture\"}","agentName":"notes"}`
            """#,
            """
            Transformer notes found from inline training-style tool calling.
            """,
        ])

        let loop = LocalAgentLoop(
            generator: { prompt, _, _, _, _, onToken in
                await promptRecorder.record(prompt)
                let output = await responseQueue.nextOutput()
                await onToken(output)
                return output
            },
            toolExecutor: { name, argumentsJson in
                #expect(name == "vault_search")
                #expect(argumentsJson.contains("\"query\":\"transformer architecture\""))
                return LocalToolResult(
                    toolName: name,
                    resultJson: #"{"name":"vault_search","content":[{"path":"ml/transformers.md","excerpt":"Inline training JSON now triggers tools."}]}"#,
                    isError: false
                )
            }
        )

        let answer = try await loop.run(
            objective: "Find my transformer architecture notes and summarize them.",
            tools: [sampleTool()],
            maxTurns: 3,
            onToken: { _ in }
        )

        let prompts = await promptRecorder.snapshot()
        #expect(prompts.count == 2)
        #expect(prompts[1].contains("<tool_response>"))
        #expect(answer == "Transformer notes found from inline training-style tool calling.")
    }

    @Test("local loop executes tool_call fenced JSON before returning the final answer")
    func localLoopExecutesToolCallFenceJson() async throws {
        let responseQueue = ResponseQueue(outputs: [
            """
            ```tool_call
            {"name":"vault_search","arguments":{"query":"transformer architecture"}}
            ```
            """,
            """
            Transformer notes found from fenced tool_call JSON.
            """,
        ])

        let loop = LocalAgentLoop(
            generator: { _, _, _, _, _, onToken in
                let output = await responseQueue.nextOutput()
                await onToken(output)
                return output
            },
            toolExecutor: { name, argumentsJson in
                #expect(name == "vault_search")
                #expect(argumentsJson.contains("\"query\":\"transformer architecture\""))
                return LocalToolResult(
                    toolName: name,
                    resultJson: #"{"name":"vault_search","content":[{"path":"ml/transformers.md","excerpt":"Fenced tool_call JSON now triggers tools."}]}"#,
                    isError: false
                )
            }
        )

        let answer = try await loop.run(
            objective: "Find my transformer architecture notes and summarize them.",
            tools: [sampleTool()],
            maxTurns: 3,
            onToken: { _ in }
        )

        #expect(answer == "Transformer notes found from fenced tool_call JSON.")
    }

    @Test("local loop canonicalizes case-variant tool calls to the declared schema")
    func localLoopCanonicalizesCaseVariantToolCalls() async throws {
        let responseQueue = ResponseQueue(outputs: [
            """
            {"NAME":"VAULT_SEARCH","ARGUMENTS":{"QUERY":"transformer architecture"}}
            """,
            """
            Transformer notes found after case-variant tool normalization.
            """,
        ])

        let loop = LocalAgentLoop(
            generator: { _, _, _, _, _, onToken in
                let output = await responseQueue.nextOutput()
                await onToken(output)
                return output
            },
            toolExecutor: { name, argumentsJson in
                #expect(name == "vault_search")
                #expect(argumentsJson.contains("\"query\":\"transformer architecture\""))
                return LocalToolResult(
                    toolName: name,
                    resultJson: #"{"name":"vault_search","content":[{"path":"ml/transformers.md","excerpt":"Case-variant JSON now resolves to the declared tool schema."}]}"#,
                    isError: false
                )
            }
        )

        let answer = try await loop.run(
            objective: "Find my transformer architecture notes and summarize them.",
            tools: [sampleTool()],
            maxTurns: 3,
            onToken: { _ in }
        )

        #expect(answer == "Transformer notes found after case-variant tool normalization.")
    }

    @Test("local loop executes function-wrapper tool call JSON before returning the final answer")
    func localLoopExecutesFunctionWrapperToolCallJson() async throws {
        let responseQueue = ResponseQueue(outputs: [
            """
            {"function":"vault_search","parameters":{"query":"transformer architecture"}}
            """,
            """
            Transformer notes found after function-wrapper tool normalization.
            """,
        ])

        let loop = LocalAgentLoop(
            generator: { _, _, _, _, _, onToken in
                let output = await responseQueue.nextOutput()
                await onToken(output)
                return output
            },
            toolExecutor: { name, argumentsJson in
                #expect(name == "vault_search")
                #expect(argumentsJson.contains("\"query\":\"transformer architecture\""))
                return LocalToolResult(
                    toolName: name,
                    resultJson: #"{"name":"vault_search","content":[{"path":"ml/transformers.md","excerpt":"Function-wrapper JSON now resolves to the declared tool schema."}]}"#,
                    isError: false
                )
            }
        )

        let answer = try await loop.run(
            objective: "Find my transformer architecture notes and summarize them.",
            tools: [sampleTool()],
            maxTurns: 3,
            onToken: { _ in }
        )

        #expect(answer == "Transformer notes found after function-wrapper tool normalization.")
    }

    @Test("reflex mode hides tool call markup and stops streaming once the tool call closes")
    @MainActor
    func reflexModeHidesToolCallMarkupAndStopsStreamingAtToolBoundary() async throws {
        let streamQueue = StreamChunkQueue(streams: [
            [
                "Planning the next step. ",
                """
                <tool_call>
                {"name":"vault_search","arguments":{"query":"transformer architecture"}}
                </tool_call>
                """,
                "THIS SHOULD NEVER REACH THE USER",
            ],
            [
                "Transformer notes found after reflex execution.",
            ],
        ])

        var visibleText = ""
        let toolRecorder = ToolInvocationRecorder()

        let loop = LocalAgentLoop(
            generator: { _, _, _, _, _, _ in
                Issue.record("Reflex mode should stay on the streaming path.")
                return ""
            },
            streamingGenerator: { _, _, _, _, _ in
                let chunks = await streamQueue.nextStream()
                return AsyncThrowingStream<String, Error> { continuation in
                    let task = Task {
                        for chunk in chunks {
                            guard !Task.isCancelled else {
                                continuation.finish()
                                return
                            }
                            continuation.yield(chunk)
                            try? await Task.sleep(for: .milliseconds(1))
                        }
                        continuation.finish()
                    }
                    continuation.onTermination = { _ in task.cancel() }
                }
            },
            toolExecutor: { name, argumentsJson in
                await toolRecorder.append(name)
                #expect(argumentsJson.contains("\"query\":\"transformer architecture\""))
                return LocalToolResult(
                    toolName: name,
                    resultJson: #"{"name":"vault_search","content":[{"path":"ml/transformers.md","excerpt":"Reflex mode executed the search immediately."}]}"#,
                    isError: false
                )
            }
        )

        let answer = try await loop.run(
            objective: "Find my transformer architecture notes and summarize them.",
            tools: [sampleTool()],
            maxTurns: 3,
            reflexMode: true,
            onToken: { token in
                visibleText += token
            }
        )

        let executedToolNames = await toolRecorder.snapshot()
        #expect(executedToolNames == ["vault_search"])
        #expect(visibleText.contains("Planning the next step. "))
        #expect(visibleText.contains("Transformer notes found after reflex execution."))
        #expect(!visibleText.contains("<tool_call>"))
        #expect(!visibleText.contains("\"vault_search\""))
        #expect(!visibleText.contains("THIS SHOULD NEVER REACH THE USER"))
        #expect(answer == "Transformer notes found after reflex execution.")
    }

    @Test("reflex mode retries when a tool-capable turn emits only hidden scratchpad")
    @MainActor
    func reflexModeRetriesInvisibleScratchpadOnlyTurns() async throws {
        let promptRecorder = PromptRecorder()
        let streamQueue = StreamChunkQueue(streams: [
            [
                """
                <scratch_pad>I should search before answering.</scratch_pad>
                """,
            ],
            [
                """
                <tool_call>
                {"name":"vault_search","arguments":{"query":"hegemony"}}
                </tool_call>
                """,
            ],
            [
                "Hegemony notes found after the repair retry.",
            ],
        ])

        let toolRecorder = ToolInvocationRecorder()
        let loop = LocalAgentLoop(
            generator: { _, _, _, _, _, _ in
                Issue.record("Reflex mode should stay on the streaming path.")
                return ""
            },
            streamingGenerator: { prompt, _, _, _, _ in
                await promptRecorder.record(prompt)
                let chunks = await streamQueue.nextStream()
                return AsyncThrowingStream<String, Error> { continuation in
                    let task = Task {
                        for chunk in chunks {
                            guard !Task.isCancelled else {
                                continuation.finish()
                                return
                            }
                            continuation.yield(chunk)
                        }
                        continuation.finish()
                    }
                    continuation.onTermination = { _ in task.cancel() }
                }
            },
            toolExecutor: { name, argumentsJson in
                await toolRecorder.append(name)
                #expect(name == "vault_search")
                #expect(argumentsJson.contains("\"query\":\"hegemony\""))
                return LocalToolResult(
                    toolName: name,
                    resultJson: #"{"name":"vault_search","content":[{"path":"politics/hegemony.md","excerpt":"Repair retry forced a visible tool step."}]}"#,
                    isError: false
                )
            }
        )

        let answer = try await loop.run(
            objective: "Search my notes for hegemony and summarize what matters.",
            tools: [sampleTool()],
            maxTurns: 4,
            reflexMode: true,
            onToken: { _ in }
        )

        let prompts = await promptRecorder.snapshot()
        let executedToolNames = await toolRecorder.snapshot()
        #expect(prompts.count == 3)
        #expect(prompts[1].contains("You have not produced any user-visible answer yet."))
        #expect(executedToolNames == ["vault_search"])
        #expect(answer == "Hegemony notes found after the repair retry.")
    }

    @Test("local loop prefers the structured generator when one is available")
    func localLoopPrefersTheStructuredGeneratorWhenOneIsAvailable() async throws {
        let promptRecorder = PromptRecorder()
        let loop = LocalAgentLoop(
            generator: { _, _, _, _, _, _ in
                Issue.record("Expected the structured generator to run before the fallback generator.")
                return "Fallback output."
            },
            structuredGenerator: { prompt, _, plan, _, _, _, _ in
                await promptRecorder.record(prompt)
                #expect(plan.fallbackGrammar.validToolNames == ["vault_search"])
                return """
                <think>Use the constrained path.</think>
                Structured final answer.
                """
            },
            toolExecutor: { _, _ in
                Issue.record("Structured final answer should not call tools.")
                return LocalToolResult(
                    toolName: "vault_search",
                    resultJson: #"{"name":"vault_search","content":[]}"#,
                    isError: false
                )
            }
        )

        let answer = try await loop.run(
            objective: "Summarize my note locally.",
            tools: [sampleTool()],
            maxTurns: 2,
            onToken: { _ in }
        )

        let prompts = await promptRecorder.snapshot()
        #expect(prompts.count == 1)
        #expect(prompts[0].contains("Summarize my note locally."))
        #expect(answer == "Structured final answer.")
    }

    @Test("local loop stops when tool calls never converge")
    func localLoopStopsWhenToolCallsNeverConverge() async {
        let loop = LocalAgentLoop(
            generator: { _, _, _, _, _, onToken in
                let output = """
                <tool_call>
                {"name":"vault_search","arguments":{"query":"stuck"}}
                </tool_call>
                """
                await onToken(output)
                return output
            },
            toolExecutor: { name, _ in
                LocalToolResult(
                    toolName: name,
                    resultJson: #"{"name":"vault_search","content":[]}"#,
                    isError: false
                )
            }
        )

        await #expect(throws: LocalAgentLoopError.self) {
            try await loop.run(
                objective: "Keep searching forever.",
                tools: [sampleTool()],
                maxTurns: 2,
                onToken: { _ in }
            )
        }
    }

    @Test("local loop strips an unclosed scratch pad when the final answer follows")
    func localLoopStripsUnclosedScratchPadWhenAnswerFollows() async throws {
        let loop = LocalAgentLoop(
            generator: { _, _, _, _, _, onToken in
                let output = """
                <scratch_pad>
                The tool call failed because the guessed path was missing.

                The attached note compares app stages to organs because each stage has a specialized job inside one coordinated system.
                """
                await onToken(output)
                return output
            },
            toolExecutor: { _, _ in
                Issue.record("The final answer should not call tools.")
                return LocalToolResult(
                    toolName: "vault_search",
                    resultJson: #"{"name":"vault_search","content":[]}"#,
                    isError: false
                )
            }
        )

        let answer = try await loop.run(
            objective: "Summarize the attached note.",
            tools: [sampleTool()],
            maxTurns: 2,
            onToken: { _ in }
        )

        #expect(
            answer
                == "The attached note compares app stages to organs because each stage has a specialized job inside one coordinated system."
        )
    }

    @Test("weak local tiers are rejected before the loop starts")
    func weakLocalTiersAreRejectedBeforeTheLoopStarts() async {
        let loop = LocalAgentLoop(
            generator: { _, _, _, _, _, onToken in
                await onToken("Should never run.")
                return "Should never run."
            },
            toolExecutor: { _, _ in
                LocalToolResult(
                    toolName: "vault_search",
                    resultJson: #"{"name":"vault_search","content":[]}"#,
                    isError: false
                )
            },
            modelID: LocalTextModelID.qwen35_2B4Bit.rawValue
        )

        do {
            _ = try await loop.run(
                objective: "Act like a multi-step local agent.",
                tools: [sampleTool()],
                maxTurns: 1,
                onToken: { _ in }
            )
            Issue.record("Expected the local loop to reject the unsupported model tier.")
        } catch let error as LocalAgentLoopError {
            #expect(error == .unsupportedModel(LocalTextModelID.qwen35_2B4Bit.rawValue))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @MainActor
    @Test("constrained generator bridge declines unavailable constrained decoding")
    func constrainedGeneratorBridgeDeclinesUnavailableConstrainedDecoding() async throws {
        let constrainedDecoding = ConstrainedDecodingService()
        let generator = LocalAgentLoop.constrainedGenerator(using: constrainedDecoding)
        let plan = LocalToolGrammar.buildToolCallingPlan(
            tools: [sampleTool()],
            forceThinking: true
        )

        let output = try await generator(
            "PROMPT",
            nil,
            plan,
            256,
            .fast,
            LocalTextModelID.qwen35_4B4Bit.rawValue,
            { _ in }
        )

        #expect(output == nil)
    }

    @MainActor
    @Test("constrained generator bridge reuses the existing constrained decoding service")
    func constrainedGeneratorBridgeReusesTheExistingConstrainedDecodingService() async throws {
        let constrainedDecoding = ConstrainedDecodingService()
        constrainedDecoding.setGenerator(
            FakeGrammarConstrainedGenerator(
                output: """
                <think>Constrained path.</think>
                Existing constrained service output.
                """
            )
        )

        let generator = LocalAgentLoop.constrainedGenerator(using: constrainedDecoding)
        let plan = LocalToolGrammar.buildToolCallingPlan(
            tools: [sampleTool()],
            forceThinking: true
        )

        let output = try await generator(
            "PROMPT",
            nil,
            plan,
            256,
            .fast,
            LocalTextModelID.qwen35_4B4Bit.rawValue,
            { _ in
                Issue.record("Existing constrained decoding path should not fake token streaming.")
            }
        )

        #expect(output == """
        <think>Constrained path.</think>
        Existing constrained service output.
        """)
    }

    private func sampleTool() -> OmegaToolDefinition {
        OmegaToolDefinition(
            name: "vault_search",
            agent: "notes",
            description: "Search the vault.",
            argumentsExample: #"{"query":"transformers"}"#,
            schemaJson: #"{"type":"object","properties":{"query":{"type":"string"}},"required":["query"]}"#,
            destructive: false,
            requiresConfirmation: false
        )
    }
}

private actor PromptRecorder {
    private var prompts: [String] = []

    func record(_ prompt: String) {
        prompts.append(prompt)
    }

    func snapshot() -> [String] {
        prompts
    }
}

private actor ResponseQueue {
    private var outputs: [String]

    init(outputs: [String]) {
        self.outputs = outputs
    }

    func nextOutput() -> String {
        guard !outputs.isEmpty else {
            return "No queued output."
        }
        return outputs.removeFirst()
    }
}

private actor StreamChunkQueue {
    private var streams: [[String]]

    init(streams: [[String]]) {
        self.streams = streams
    }

    func nextStream() -> [String] {
        guard !streams.isEmpty else {
            return []
        }
        return streams.removeFirst()
    }
}

private actor ToolInvocationRecorder {
    private var names: [String] = []

    func append(_ name: String) {
        names.append(name)
    }

    func snapshot() -> [String] {
        names
    }
}

private struct FakeGrammarConstrainedGenerator: GrammarConstrainedGenerator {
    let output: String
    let isFullyConstraining: Bool = true

    func generate(
        prompt: String,
        systemPrompt: String?,
        grammar: ToolSchemaGrammar.CompiledGrammar,
        maxTokens: Int
    ) async throws -> String {
        _ = prompt
        _ = systemPrompt
        _ = grammar
        _ = maxTokens
        return output
    }
}
