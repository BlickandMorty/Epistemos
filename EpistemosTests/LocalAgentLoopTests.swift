import Foundation
import Testing
@testable import Epistemos

@MainActor
private final class LocalAgentEventSink {
    private(set) var events: [AgentProvenanceEvent] = []

    func append(_ event: AgentProvenanceEvent) -> Bool {
        events.append(event)
        return true
    }
}

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
                #expect(name == "vault.search")
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

    @Test("reflex mode without a streaming generator uses one-shot generation")
    func reflexModeWithoutStreamingGeneratorUsesOneShotGeneration() async throws {
        let promptRecorder = PromptRecorder()
        let responseQueue = ResponseQueue(outputs: ["Plain answer."])
        let loop = LocalAgentLoop(
            generator: { prompt, _, _, _, _, onToken in
                await promptRecorder.record(prompt)
                let output = await responseQueue.nextOutput()
                await onToken(output)
                return output
            },
            toolExecutor: { name, _ in
                Issue.record("No tool should execute without a parsed tool call: \(name)")
                return LocalToolResult(
                    toolName: name,
                    resultJson: #"{"error":"unexpected tool execution"}"#,
                    isError: true
                )
            }
        )

        var emitted = ""
        let output = try await loop.run(
            objective: "Answer plainly.",
            tools: [],
            reflexMode: true,
            onToken: { token in emitted += token }
        )

        #expect(output == "Plain answer.")
        #expect(emitted == "Plain answer.")
        #expect(await promptRecorder.snapshot().count == 1)
    }

    @Test("local loop records successful tool provenance")
    @MainActor
    func localLoopRecordsSuccessfulToolProvenance() async throws {
        let responseQueue = ResponseQueue(outputs: [
            """
            <tool_call>
            {"name":"vault_search","arguments":{"query":"transformer architecture"}}
            </tool_call>
            """,
            "Transformer notes found.",
        ])
        let sink = LocalAgentEventSink()
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 321 },
            persist: { event in sink.append(event) }
        )
        let loop = LocalAgentLoop(
            generator: { _, _, _, _, _, _ in
                await responseQueue.nextOutput()
            },
            toolExecutor: { name, argumentsJson in
                #expect(name == "vault.search")
                #expect(argumentsJson.contains("\"query\":\"transformer architecture\""))
                return LocalToolResult(
                    toolName: name,
                    resultJson: #"{"content":[{"path":"ml/transformers.md"}]}"#,
                    isError: false
                )
            },
            agentProvenanceRecorder: recorder,
            provenanceMetadata: ["mission_packet_id": "mission-loop"]
        )

        let answer = try await loop.run(
            objective: "Find transformer notes.",
            tools: [sampleTool()],
            maxTurns: 3,
            runID: "mission-loop-run",
            onToken: { _ in }
        )

        #expect(answer == "Transformer notes found.")
        #expect(sink.events.map(\.kind) == [.toolCallRequested, .toolCallStarted, .toolCallCompleted])
        #expect(Set(sink.events.map(\.runID)) == ["mission-loop-run"])
        #expect(sink.events.allSatisfy { $0.tool?.toolCallID == "local-agent-tool:1" })
        #expect(sink.events.allSatisfy { $0.tool?.toolName == "vault.search" })
        #expect(sink.events.allSatisfy { $0.metadata["source"] == "local_agent_loop" })
        #expect(sink.events.allSatisfy { $0.metadata["surface"] == "local_agent" })
        #expect(sink.events.allSatisfy { $0.metadata["mission_packet_id"] == "mission-loop" })
        #expect(sink.events.last?.tool?.status == .completed)
        #expect(sink.events.last?.tool?.durationMs != nil)
        #expect(sink.events.last?.tool?.resultJSON?.contains("transformers.md") == true)
    }

    @Test("local loop records failed tool provenance")
    @MainActor
    func localLoopRecordsFailedToolProvenance() async throws {
        let responseQueue = ResponseQueue(outputs: [
            """
            <tool_call>
            {"name":"vault_search","arguments":{"query":"missing"}}
            </tool_call>
            """,
            "Nothing found.",
        ])
        let sink = LocalAgentEventSink()
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 654 },
            persist: { event in sink.append(event) }
        )
        let loop = LocalAgentLoop(
            generator: { _, _, _, _, _, _ in
                await responseQueue.nextOutput()
            },
            toolExecutor: { name, _ in
                LocalToolResult(
                    toolName: name,
                    resultJson: #"{"error":"missing"}"#,
                    isError: true
                )
            },
            agentProvenanceRecorder: recorder
        )

        let answer = try await loop.run(
            objective: "Find missing notes.",
            tools: [sampleTool()],
            maxTurns: 3,
            onToken: { _ in }
        )

        #expect(answer == "Nothing found.")
        #expect(sink.events.map(\.kind) == [.toolCallRequested, .toolCallStarted, .toolCallFailed])
        #expect(sink.events.last?.tool?.status == .failed)
        #expect(sink.events.last?.tool?.errorMessage?.contains("missing") == true)
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
                #expect(name == "vault.search")
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
                #expect(name == "vault.search")
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
                #expect(name == "vault.search")
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

    @Test("local loop executes embedded JSON tool calls hidden inside reasoning tags")
    func localLoopExecutesEmbeddedJsonToolCallInsideThinkingTags() async throws {
        let responseQueue = ResponseQueue(outputs: [
            """
            <think>
            I should create the scratch file first.
            {"name":"write_file","arguments":{"path":"/tmp/epistemos_local_tool_smoke.txt","content":"tool smoke ok"}}
            </think>
            """,
            """
            tool smoke ok
            """,
        ])

        let writeTool = OmegaToolDefinition(
            name: "write_file",
            agent: "file",
            description: "Write a file.",
            argumentsExample: #"{"path":"/tmp/example.txt","content":"hello"}"#,
            schemaJson: #"{"type":"object","properties":{"path":{"type":"string"},"content":{"type":"string"}},"required":["path","content"]}"#,
            destructive: false,
            requiresConfirmation: false
        )

        let loop = LocalAgentLoop(
            generator: { _, _, _, _, _, onToken in
                let output = await responseQueue.nextOutput()
                await onToken(output)
                return output
            },
            toolExecutor: { name, argumentsJson in
                #expect(name == "file.write")
                #expect(argumentsJson.contains("\"path\":\"/tmp/epistemos_local_tool_smoke.txt\""))
                #expect(argumentsJson.contains("\"content\":\"tool smoke ok\""))
                return LocalToolResult(
                    toolName: name,
                    resultJson: #"{"success":true}"#,
                    isError: false
                )
            }
        )

        let answer = try await loop.run(
            objective: "Write a scratch file and then read it back.",
            tools: [writeTool],
            maxTurns: 3,
            onToken: { _ in }
        )

        #expect(answer == "tool smoke ok")
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
                #expect(name == "vault.search")
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
                #expect(name == "vault.search")
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
        #expect(executedToolNames == ["vault.search"])
        #expect(visibleText.contains("Planning the next step. "))
        #expect(visibleText.contains("Transformer notes found after reflex execution."))
        #expect(!visibleText.contains("<tool_call>"))
        #expect(!visibleText.contains("\"vault_search\""))
        #expect(!visibleText.contains("THIS SHOULD NEVER REACH THE USER"))
        #expect(answer == "Transformer notes found after reflex execution.")
    }

    @Test("reflex mode flushes trailing tag-prefix plaintext once at stream end")
    @MainActor
    func reflexModeFlushesTrailingTagPrefixPlaintextOnceAtStreamEnd() async throws {
        let streamQueue = StreamChunkQueue(streams: [
            [
                "The relation is A ",
                "<",
            ],
        ])

        var visibleText = ""
        let loop = LocalAgentLoop(
            generator: { _, _, _, _, _, _ in
                Issue.record("Reflex mode should stay on the streaming path.")
                return ""
            },
            streamingGenerator: { _, _, _, _, _ in
                let chunks = await streamQueue.nextStream()
                return AsyncThrowingStream<String, Error> { continuation in
                    for chunk in chunks {
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                }
            },
            toolExecutor: { _, _ in
                Issue.record("No tool should execute for plain text.")
                return LocalToolResult(toolName: "unexpected", resultJson: "{}", isError: true)
            }
        )

        let answer = try await loop.run(
            objective: "Answer directly.",
            tools: [sampleTool()],
            maxTurns: 1,
            reflexMode: true,
            onToken: { token in
                visibleText += token
            }
        )

        #expect(visibleText == "The relation is A <")
        #expect(answer == "The relation is A <")
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
                #expect(name == "vault.search")
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
        #expect(executedToolNames == ["vault.search"])
        #expect(answer == "Hegemony notes found after the repair retry.")
    }

    @Test("reflex mode rejects guessed direct answers until the explicit file round-trip tools finish")
    @MainActor
    func reflexModeRejectsGuessedDirectAnswersUntilExplicitFileRoundTripToolsFinish() async throws {
        let promptRecorder = PromptRecorder()
        let streamQueue = StreamChunkQueue(streams: [
            [
                "tool smoke ok",
            ],
            [
                """
                <tool_call>
                {"name":"write_file","arguments":{"content":"tool smoke ok","path":"tmp/tool-smoke.txt"}}
                </tool_call>
                """,
            ],
            [
                "tool smoke ok",
            ],
            [
                """
                <tool_call>
                {"name":"read_file","arguments":{"path":"tmp/tool-smoke.txt"}}
                </tool_call>
                """,
            ],
            [
                "tool smoke ok",
            ],
        ])
        let toolCalls = ToolCallRecorder()
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
                await toolCalls.record(name, argumentsJson)
                return LocalToolResult(
                    toolName: name,
                    resultJson: name == "file.read"
                        ? #"{"name":"read_file","content":"tool smoke ok","success":true}"#
                        : #"{"name":"write_file","success":true}"#,
                    isError: false
                )
            }
        )

        let answer = try await loop.run(
            objective: "Use write_file to write exactly tool smoke ok to tmp/tool-smoke.txt, then use read_file on that same path and reply with only the file contents.",
            tools: [writeTool(), readTool()],
            maxTurns: 6,
            reflexMode: true,
            onToken: { _ in }
        )

        let prompts = await promptRecorder.snapshot()
        let executedCalls = await toolCalls.snapshot()
        #expect(prompts.count == 4)
        if prompts.count >= 4 {
            #expect(prompts[1].contains("missing required tool step"))
            #expect(prompts[1].contains("file.write"))
            #expect(prompts[3].contains("missing required tool step"))
            #expect(prompts[3].contains("file.read"))
        }
        #expect(executedCalls.map(\.name) == ["file.write", "file.read"])
        #expect(answer == "tool smoke ok")
    }

    @Test("reflex mode rejects example-path tool drift until the exact requested file path is used")
    @MainActor
    func reflexModeRejectsExamplePathToolDriftUntilExactRequestedFilePathIsUsed() async throws {
        let promptRecorder = PromptRecorder()
        let streamQueue = StreamChunkQueue(streams: [
            [
                """
                <tool_call>
                {"name":"read_file","arguments":{"path":"tmp/example.txt"}}
                </tool_call>
                """,
            ],
            [
                """
                <tool_call>
                {"name":"write_file","arguments":{"content":"tool smoke ok","path":"tmp/epistemos_live_tool_smoke.txt"}}
                </tool_call>
                """,
            ],
            [
                """
                <tool_call>
                {"name":"read_file","arguments":{"path":"tmp/epistemos_live_tool_smoke.txt"}}
                </tool_call>
                """,
            ],
            [
                "tool smoke ok",
            ],
        ])
        let toolCalls = ToolCallRecorder()

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
                await toolCalls.record(name, argumentsJson)
                return LocalToolResult(
                    toolName: name,
                    resultJson: name == "file.read"
                        ? #"{"name":"read_file","content":"tool smoke ok","success":true}"#
                        : #"{"name":"write_file","success":true}"#,
                    isError: false
                )
            }
        )

        let answer = try await loop.run(
            objective: "Use write_file to write exactly tool smoke ok to tmp/epistemos_live_tool_smoke.txt, then use read_file on that exact same path and reply with only the file contents.",
            tools: [writeTool(), readTool()],
            maxTurns: 5,
            reflexMode: true,
            onToken: { _ in }
        )

        let prompts = await promptRecorder.snapshot()
        let executedCalls = await toolCalls.snapshot()
        #expect(prompts.count == 3)
        if prompts.count >= 2 {
            #expect(prompts[1].contains("tmp/epistemos_live_tool_smoke.txt"))
            #expect(prompts[1].contains("tmp/example.txt"))
            #expect(prompts[1].contains("file.write"))
        }
        #expect(executedCalls.map(\.name) == ["file.write", "file.read"])
        if executedCalls.count == 2 {
            let normalizedWriteArguments = executedCalls[0].argumentsJson
                .replacingOccurrences(of: "\\/", with: "/")
            let normalizedReadArguments = executedCalls[1].argumentsJson
                .replacingOccurrences(of: "\\/", with: "/")
            #expect(normalizedWriteArguments.contains("\"path\":\"tmp/epistemos_live_tool_smoke.txt\""))
            #expect(normalizedReadArguments.contains("\"path\":\"tmp/epistemos_live_tool_smoke.txt\""))
        }
        #expect(answer == "tool smoke ok")
    }

    @Test("reflex mode rejects example-path drift for explicit absolute filesystem paths")
    @MainActor
    func reflexModeRejectsExamplePathDriftForExplicitAbsoluteFilesystemPaths() async throws {
        let promptRecorder = PromptRecorder()
        let streamQueue = StreamChunkQueue(streams: [
            [
                """
                <tool_call>
                {"name":"read_file","arguments":{"path":"tmp/example.txt"}}
                </tool_call>
                """,
            ],
            [
                """
                <tool_call>
                {"name":"read_file","arguments":{"path":"/tmp/absolute-tool-smoke.txt"}}
                </tool_call>
                """,
            ],
        ])
        let toolCalls = ToolCallRecorder()

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
                await toolCalls.record(name, argumentsJson)
                let normalizedArguments = argumentsJson.replacingOccurrences(of: "\\/", with: "/")
                if normalizedArguments.contains("\"path\":\"/tmp/absolute-tool-smoke.txt\"") {
                    return LocalToolResult(
                        toolName: name,
                        resultJson: #"{"content":"1\toutside tool smoke ok\n2\tsecond line","path":"/tmp/absolute-tool-smoke.txt","showing":{"from":1,"to":2},"total_lines":2}"#,
                        isError: false
                    )
                }
                return LocalToolResult(
                    toolName: name,
                    resultJson: #"{"error":"file 'tmp/example.txt' does not exist","success":false}"#,
                    isError: true
                )
            }
        )

        let answer = try await loop.run(
            objective: "Use tools to read the local file /tmp/absolute-tool-smoke.txt and reply with only the first line exactly.",
            tools: [readTool()],
            maxTurns: 4,
            reflexMode: true,
            onToken: { _ in }
        )

        let prompts = await promptRecorder.snapshot()
        let executedCalls = await toolCalls.snapshot()
        #expect(prompts.count == 2)
        if prompts.count >= 2 {
            #expect(prompts[1].contains(#"exact path "/tmp/absolute-tool-smoke.txt""#))
            #expect(prompts[1].contains("tmp/example.txt"))
            #expect(prompts[1].contains("file.read"))
            #expect(prompts[1].contains("Do not reuse example paths such as tmp/example.txt"))
        }
        #expect(executedCalls.map(\.name) == ["file.read"])
        if let executedCall = executedCalls.first {
            let normalizedArguments = executedCall.argumentsJson.replacingOccurrences(of: "\\/", with: "/")
            #expect(normalizedArguments.contains("\"path\":\"/tmp/absolute-tool-smoke.txt\""))
        }
        #expect(answer == "outside tool smoke ok")
    }

    @Test("reflex mode falls back to one-shot generation when streaming turns stay empty")
    @MainActor
    func reflexModeFallsBackToOneShotGenerationWhenStreamingTurnsStayEmpty() async throws {
        let streamQueue = StreamChunkQueue(streams: [
            [],
            [],
        ])
        let fallbackResponses = ResponseQueue(outputs: [
            """
            <tool_call>
            {"name":"write_file","arguments":{"content":"tool smoke ok","path":"/tmp/tool-smoke.txt"}}
            </tool_call>
            """,
            "tool smoke ok",
        ])
        let toolCalls = ToolCallRecorder()
        var visibleText = ""

        let loop = LocalAgentLoop(
            generator: { _, _, _, _, _, _ in
                await fallbackResponses.nextOutput()
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
                        }
                        continuation.finish()
                    }
                    continuation.onTermination = { _ in task.cancel() }
                }
            },
            toolExecutor: { name, argumentsJson in
                await toolCalls.record(name, argumentsJson)
                return LocalToolResult(
                    toolName: name,
                    resultJson: #"{"name":"write_file","ok":true}"#,
                    isError: false
                )
            }
        )

        let answer = try await loop.run(
            objective: "Write tool smoke ok to /tmp/tool-smoke.txt and then tell me the contents.",
            tools: [writeTool()],
            maxTurns: 3,
            reflexMode: true,
            onToken: { token in
                visibleText += token
            }
        )

        let executedCalls = await toolCalls.snapshot()
        #expect(executedCalls.count == 1)
        #expect(executedCalls[0].name == "file.write")
        let argumentsData = try #require(executedCalls[0].argumentsJson.data(using: .utf8))
        let argumentsObject = try #require(
            JSONSerialization.jsonObject(with: argumentsData) as? [String: Any]
        )
        #expect(argumentsObject["path"] as? String == "/tmp/tool-smoke.txt")
        #expect(argumentsObject["content"] as? String == "tool smoke ok")
        #expect(visibleText.isEmpty)
        #expect(answer == "tool smoke ok")
    }

    @Test("reflex mode synthesizes explicit-file round-trip steps after repeated empty repairs")
    @MainActor
    func reflexModeSynthesizesExplicitFileRoundTripStepsAfterRepeatedEmptyRepairs() async throws {
        let streamQueue = StreamChunkQueue(streams: [
            [],
            [],
        ])
        let fallbackResponses = ResponseQueue(outputs: [
            "",
            "",
        ])
        let toolCalls = ToolCallRecorder()

        let loop = LocalAgentLoop(
            generator: { _, _, _, _, _, _ in
                await fallbackResponses.nextOutput()
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
                        }
                        continuation.finish()
                    }
                    continuation.onTermination = { _ in task.cancel() }
                }
            },
            toolExecutor: { name, argumentsJson in
                await toolCalls.record(name, argumentsJson)
                return LocalToolResult(
                    toolName: name,
                    resultJson: name == "file.read"
                        ? #"{"name":"read_file","content":"tool smoke ok","success":true}"#
                        : #"{"name":"write_file","success":true}"#,
                    isError: false
                )
            }
        )

        let answer = try await loop.run(
            objective: "Use write_file to write exactly tool smoke ok to tmp/tool-smoke.txt, then use read_file on that exact same path and reply with only the file contents.",
            tools: [writeTool(), readTool()],
            maxTurns: 2,
            reflexMode: true,
            onToken: { _ in }
        )

        let executedCalls = await toolCalls.snapshot()
        #expect(executedCalls.map(\.name) == ["file.write", "file.read"])
        if executedCalls.count == 2 {
            let normalizedWriteArguments = executedCalls[0].argumentsJson
                .replacingOccurrences(of: "\\/", with: "/")
            let normalizedReadArguments = executedCalls[1].argumentsJson
                .replacingOccurrences(of: "\\/", with: "/")
            #expect(normalizedWriteArguments.contains("\"content\":\"tool smoke ok\""))
            #expect(normalizedWriteArguments.contains("\"path\":\"tmp/tool-smoke.txt\""))
            #expect(normalizedReadArguments.contains("\"path\":\"tmp/tool-smoke.txt\""))
        }
        #expect(answer == "tool smoke ok")
    }

    @Test("reflex mode treats dangling xml fence repairs as invisible and continues the explicit file round-trip")
    @MainActor
    func reflexModeTreatsDanglingXmlFenceRepairAsInvisible() async throws {
        let streamQueue = StreamChunkQueue(streams: [
            [],
            [],
        ])
        let fallbackResponses = ResponseQueue(outputs: [
            "```xml\n",
            "```xml\n",
        ])
        let toolCalls = ToolCallRecorder()

        let loop = LocalAgentLoop(
            generator: { _, _, _, _, _, _ in
                await fallbackResponses.nextOutput()
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
                        }
                        continuation.finish()
                    }
                    continuation.onTermination = { _ in task.cancel() }
                }
            },
            toolExecutor: { name, argumentsJson in
                await toolCalls.record(name, argumentsJson)
                return LocalToolResult(
                    toolName: name,
                    resultJson: name == "file.read"
                        ? #"{"content":"1\ttool smoke ok","path":"tmp/tool-smoke.txt","showing":{"from":1,"to":1},"total_lines":1}"#
                        : #"{"name":"write_file","success":true}"#,
                    isError: false
                )
            }
        )

        let answer = try await loop.run(
            objective: "Use write_file to write exactly tool smoke ok to tmp/tool-smoke.txt, then use read_file on that exact same path and reply with only the file contents.",
            tools: [writeTool(), readTool()],
            maxTurns: 3,
            reflexMode: true,
            onToken: { _ in }
        )

        let executedCalls = await toolCalls.snapshot()
        #expect(executedCalls.map(\.name) == ["file.write", "file.read"])
        #expect(answer == "tool smoke ok")
    }

    @Test("reflex mode synthesizes create-path writes that specify exact content in a trailing block")
    @MainActor
    func reflexModeSynthesizesCreatePathWritesWithTrailingExactContentBlock() async throws {
        let streamQueue = StreamChunkQueue(streams: [
            [],
            [],
        ])
        let fallbackResponses = ResponseQueue(outputs: [
            "```xml\n",
            "```xml\n",
        ])
        let toolCalls = ToolCallRecorder()

        let loop = LocalAgentLoop(
            generator: { _, _, _, _, _, _ in
                await fallbackResponses.nextOutput()
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
                        }
                        continuation.finish()
                    }
                    continuation.onTermination = { _ in task.cancel() }
                }
            },
            toolExecutor: { name, argumentsJson in
                await toolCalls.record(name, argumentsJson)
                return LocalToolResult(
                    toolName: name,
                    resultJson: name == "file.read"
                        ? #"{"content":"1\tmini inside roundtrip ok","path":"/private/tmp/epistemos_smoke_vault/mini_inside_roundtrip_20260422.txt","showing":{"from":1,"to":1},"total_lines":1}"#
                        : #"{"name":"write_file","success":true}"#,
                    isError: false
                )
            }
        )

        let answer = try await loop.run(
            objective: """
            Use write_file to create /private/tmp/epistemos_smoke_vault/mini_inside_roundtrip_20260422.txt with exactly this content and nothing else:
            mini inside roundtrip ok
            Then use read_file on that same path and reply with only the file contents.
            """,
            tools: [writeTool(), readTool()],
            maxTurns: 3,
            reflexMode: true,
            onToken: { _ in }
        )

        let executedCalls = await toolCalls.snapshot()
        #expect(executedCalls.map(\.name) == ["file.write", "file.read"])
        if executedCalls.count == 2 {
            let normalizedWriteArguments = executedCalls[0].argumentsJson
                .replacingOccurrences(of: "\\/", with: "/")
            let normalizedReadArguments = executedCalls[1].argumentsJson
                .replacingOccurrences(of: "\\/", with: "/")
            #expect(normalizedWriteArguments.contains("\"path\":\"/private/tmp/epistemos_smoke_vault/mini_inside_roundtrip_20260422.txt\""))
            #expect(normalizedWriteArguments.contains("\"content\":\"mini inside roundtrip ok\""))
            #expect(normalizedReadArguments.contains("\"path\":\"/private/tmp/epistemos_smoke_vault/mini_inside_roundtrip_20260422.txt\""))
        }
        #expect(answer == "mini inside roundtrip ok")
    }

    @Test("explicit file round-trip strips numbered read_file content from the final answer")
    @MainActor
    func explicitFileRoundTripStripsNumberedReadFileContentFromFinalAnswer() async throws {
        let responseQueue = ResponseQueue(outputs: [
            """
            <tool_call>
            {"name":"write_file","arguments":{"content":"tool smoke ok","path":"tmp/tool-smoke.txt"}}
            </tool_call>
            """,
            """
            <tool_call>
            {"name":"read_file","arguments":{"path":"tmp/tool-smoke.txt"}}
            </tool_call>
            """,
        ])

        let loop = LocalAgentLoop(
            generator: { _, _, _, _, _, onToken in
                let output = await responseQueue.nextOutput()
                await onToken(output)
                return output
            },
            toolExecutor: { name, _ in
                let resultJson: String
                switch name {
                case "file.write":
                    resultJson = #"{"name":"write_file","success":true}"#
                case "file.read":
                    resultJson = #"{"content":"1\ttool smoke ok","path":"tmp/tool-smoke.txt","showing":{"from":1,"to":1},"total_lines":1}"#
                default:
                    Issue.record("Unexpected tool call: \(name)")
                    resultJson = #"{"error":"unexpected tool"}"#
                }
                return LocalToolResult(
                    toolName: name,
                    resultJson: resultJson,
                    isError: false
                )
            }
        )

        let answer = try await loop.run(
            objective: "Use write_file to write exactly tool smoke ok to tmp/tool-smoke.txt, then use read_file on that exact same path and reply with only the file contents.",
            tools: [writeTool(), readTool()],
            maxTurns: 3,
            onToken: { _ in }
        )

        #expect(answer == "tool smoke ok")
    }

    @Test("reflex mode uses explicit-file invisible-turn repair prompts for stalled file requests")
    @MainActor
    func reflexModeUsesExplicitFileInvisibleTurnRepairPromptForStalledFileRequests() async throws {
        let streamQueue = StreamChunkQueue(streams: [
            [],
            [
                """
                <tool_call>
                {"name":"read_file","arguments":{"path":"tmp/tool-smoke.txt"}}
                </tool_call>
                """
            ],
            ["tool smoke ok"],
        ])
        let promptRecorder = PromptRecorder()
        let toolCalls = ToolCallRecorder()

        let loop = LocalAgentLoop(
            generator: { prompt, _, _, _, _, _ in
                await promptRecorder.record(prompt)
                return """
                <tool_call>
                {"name":"write_file","arguments":{"content":"tool smoke ok","path":"tmp/tool-smoke.txt"}}
                </tool_call>
                """
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
                        }
                        continuation.finish()
                    }
                    continuation.onTermination = { _ in task.cancel() }
                }
            },
            toolExecutor: { name, argumentsJson in
                await toolCalls.record(name, argumentsJson)
                let resultJson: String
                switch name {
                case "file.write":
                    resultJson = #"{"name":"write_file","success":true}"#
                case "file.read":
                    resultJson = #"{"name":"read_file","content":"tool smoke ok"}"#
                default:
                    resultJson = #"{"name":"unknown"}"#
                }
                return LocalToolResult(
                    toolName: name,
                    resultJson: resultJson,
                    isError: false
                )
            }
        )

        let answer = try await loop.run(
            objective: "Use write_file to write exactly tool smoke ok to tmp/tool-smoke.txt, then use read_file on that exact same path and reply with only the file contents.",
            tools: [writeTool(), readTool()],
            maxTurns: 4,
            reflexMode: true,
            onToken: { _ in }
        )

        let prompts = await promptRecorder.snapshot()
        let executedCalls = await toolCalls.snapshot()
        #expect(prompts.count == 1)
        if let prompt = prompts.first {
            #expect(prompt.contains("The next required tool step is file.write"))
            #expect(prompt.contains(#"exact path "tmp/tool-smoke.txt""#))
            #expect(prompt.contains("Do not output prose"))
        }
        #expect(executedCalls.map(\.name) == ["file.write", "file.read"])
        #expect(answer == "tool smoke ok")
    }

    @Test("live loop repairs empty streaming turns with one-shot local generation")
    @MainActor
    func liveLoopRepairsEmptyStreamingTurnsWithOneShotLocalGeneration() async throws {
        let client = QueueingLocalLLMClient(
            generateOutputs: [
                """
                <tool_call>
                {"name":"write_file","arguments":{"content":"tool smoke ok","path":"/tmp/tool-smoke.txt"}}
                </tool_call>
                """,
                "tool smoke ok",
            ],
            streamOutputs: [
                [],
                [],
            ]
        )
        let toolCalls = ToolCallRecorder()
        var visibleText = ""

        let loop = LocalAgentLoop.liveLoop(
            using: client,
            toolExecutor: { name, argumentsJson in
                await toolCalls.record(name, argumentsJson)
                return LocalToolResult(
                    toolName: name,
                    resultJson: #"{"name":"write_file","ok":true}"#,
                    isError: false
                )
            },
            modelID: LocalTextModelID.qwen3_4B4Bit.rawValue
        )

        let answer = try await loop.run(
            objective: "Write tool smoke ok to /tmp/tool-smoke.txt and then tell me the contents.",
            tools: [writeTool()],
            maxTurns: 3,
            reflexMode: true,
            onToken: { token in
                visibleText += token
            }
        )

        let executedCalls = await toolCalls.snapshot()
        #expect(executedCalls.count == 1)
        #expect(executedCalls[0].name == "file.write")
        #expect(client.streamRequestCount == 2)
        #expect(client.generateRequestCount == 2)
        #expect(visibleText.isEmpty)
        #expect(answer == "tool smoke ok")
    }

    @Test("reflex mode falls back to constrained structured generation when streaming and one-shot repair stay empty")
    @MainActor
    func reflexModeFallsBackToStructuredGenerationWhenStreamingAndOneShotRepairStayEmpty() async throws {
        let streamQueue = StreamChunkQueue(streams: [
            [],
            [],
        ])
        let structuredResponses = ResponseQueue(outputs: [
            """
            <tool_call>
            {"name":"write_file","arguments":{"content":"tool smoke ok","path":"tmp/tool-smoke.txt"}}
            </tool_call>
            """,
            "tool smoke ok",
        ])
        let toolCalls = ToolCallRecorder()
        var visibleText = ""

        let loop = LocalAgentLoop(
            generator: { _, _, _, _, _, _ in
                ""
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
                        }
                        continuation.finish()
                    }
                    continuation.onTermination = { _ in task.cancel() }
                }
            },
            structuredGenerator: { _, _, _, _, _, _, _ in
                await structuredResponses.nextOutput()
            },
            toolExecutor: { name, argumentsJson in
                await toolCalls.record(name, argumentsJson)
                return LocalToolResult(
                    toolName: name,
                    resultJson: #"{"name":"write_file","ok":true}"#,
                    isError: false
                )
            }
        )

        let answer = try await loop.run(
            objective: "Write tool smoke ok to tmp/tool-smoke.txt and then tell me the contents.",
            tools: [writeTool()],
            maxTurns: 3,
            reflexMode: true,
            onToken: { token in
                visibleText += token
            }
        )

        let executedCalls = await toolCalls.snapshot()
        #expect(executedCalls.count == 1)
        #expect(executedCalls[0].name == "file.write")
        let argumentsData = try #require(executedCalls[0].argumentsJson.data(using: .utf8))
        let argumentsObject = try #require(
            JSONSerialization.jsonObject(with: argumentsData) as? [String: Any]
        )
        #expect(argumentsObject["path"] as? String == "tmp/tool-smoke.txt")
        #expect(argumentsObject["content"] as? String == "tool smoke ok")
        #expect(visibleText.isEmpty)
        #expect(answer == "tool smoke ok")
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
                #expect(plan.fallbackGrammar.validToolNames == ["vault.search"])
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

    @Test("local loop falls back to unconstrained generation when structured output stays invisible")
    func localLoopFallsBackToUnconstrainedGenerationWhenStructuredOutputStaysInvisible() async throws {
        let fallbackResponses = ResponseQueue(outputs: [
            """
            <tool_call>
            {"name":"write_file","arguments":{"content":"tool smoke ok","path":"/tmp/tool-smoke.txt"}}
            </tool_call>
            """,
            "tool smoke ok",
        ])
        let structuredResponses = ResponseQueue(outputs: [
            "<think>Need to write the file first.</think>",
            "<think>The tool result is ready.</think>",
        ])
        let toolCalls = ToolCallRecorder()
        let loop = LocalAgentLoop(
            generator: { _, _, _, _, _, onToken in
                let output = await fallbackResponses.nextOutput()
                await onToken(output)
                return output
            },
            structuredGenerator: { _, _, _, _, _, _, _ in
                await structuredResponses.nextOutput()
            },
            toolExecutor: { name, argumentsJson in
                await toolCalls.record(name, argumentsJson)
                return LocalToolResult(
                    toolName: name,
                    resultJson: #"{"name":"write_file","ok":true}"#,
                    isError: false
                )
            }
        )

        let answer = try await loop.run(
            objective: "Write tool smoke ok to /tmp/tool-smoke.txt and then tell me the contents.",
            tools: [writeTool()],
            maxTurns: 3,
            onToken: { _ in }
        )

        let executedCalls = await toolCalls.snapshot()
        #expect(executedCalls.count == 1)
        #expect(executedCalls[0].name == "file.write")
        let argumentsData = try #require(executedCalls[0].argumentsJson.data(using: .utf8))
        let argumentsObject = try #require(
            JSONSerialization.jsonObject(with: argumentsData) as? [String: Any]
        )
        #expect(argumentsObject["path"] as? String == "/tmp/tool-smoke.txt")
        #expect(argumentsObject["content"] as? String == "tool smoke ok")
        #expect(answer == "tool smoke ok")
    }

    @Test("local loop repairs explicit note creation before accepting a hallucinated success")
    func localLoopRepairsExplicitNoteCreationBeforeAcceptingAHallucinatedSuccess() async throws {
        let promptRecorder = PromptRecorder()
        let responses = ResponseQueue(outputs: [
            #"I created the note titled "Quick Thought" and the body is main note smoke ok."#,
            """
            <tool_call>
            {"name":"vault_write","arguments":{"content":"main note smoke ok","path":"Quick Thought.md"}}
            </tool_call>
            """,
            """
            <tool_call>
            {"name":"vault_read","arguments":{"path":"Quick Thought.md"}}
            </tool_call>
            """,
            "main note smoke ok",
        ])
        let toolCalls = ToolCallRecorder()
        let loop = LocalAgentLoop(
            generator: { prompt, _, _, _, _, onToken in
                await promptRecorder.record(prompt)
                let output = await responses.nextOutput()
                await onToken(output)
                return output
            },
            toolExecutor: { name, argumentsJson in
                await toolCalls.record(name, argumentsJson)
                return LocalToolResult(
                    toolName: name,
                    resultJson: #"{"content":"main note smoke ok"}"#,
                    isError: false
                )
            }
        )

        let answer = try await loop.run(
            objective: "Create a new note in the vault titled Quick Thought with the exact body main note smoke ok, then read it back and reply with only the exact note body.",
            tools: [vaultWriteTool(), vaultReadTool()],
            maxTurns: 5,
            onToken: { _ in }
        )

        let prompts = await promptRecorder.snapshot()
        let executedCalls = await toolCalls.snapshot()

        #expect(prompts.contains(where: { $0.contains("You have not satisfied the user's explicit note request yet.") }))
        #expect(executedCalls.count == 2)
        #expect(executedCalls[0].name == "vault.write")
        #expect(executedCalls[1].name == "vault.read")
        #expect(answer == "main note smoke ok")
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

        do {
            _ = try await loop.run(
                objective: "Keep searching forever.",
                tools: [sampleTool()],
                maxTurns: 2,
                onToken: { _ in }
            )
            Issue.record("Expected the maxTurns ceiling to fire and throw .maxTurnsExceeded(2).")
        } catch let error as LocalAgentLoopError {
            #expect(error == .maxTurnsExceeded(2))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("local loop stops after repeated invisible repair turns")
    func localLoopStopsAfterRepeatedInvisibleRepairTurns() async {
        let promptRecorder = PromptRecorder()
        let responseQueue = ResponseQueue(outputs: ["", ""])
        let loop = LocalAgentLoop(
            generator: { prompt, _, _, _, _, onToken in
                await promptRecorder.record(prompt)
                let output = await responseQueue.nextOutput()
                await onToken(output)
                return output
            },
            toolExecutor: { _, _ in
                Issue.record("Invisible repair loop should fail before any tool executes.")
                return LocalToolResult(
                    toolName: "vault_search",
                    resultJson: #"{"name":"vault_search","content":[]}"#,
                    isError: false
                )
            }
        )

        do {
            _ = try await loop.run(
                objective: "Answer the question directly.",
                tools: [sampleTool()],
                maxTurns: 5,
                onToken: { _ in }
            )
            Issue.record("Expected the invisible repair circuit breaker to fire.")
        } catch let error as LocalAgentLoopError {
            #expect(error == .invisibleRepairLoop(2))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        let prompts = await promptRecorder.snapshot()
        #expect(prompts.count == 2)
        #expect(prompts[1].contains("You have not produced any user-visible answer yet."))
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

    @Test("local loop salvages a final answer hidden entirely inside scratch pad tags")
    func localLoopSalvagesHiddenScratchPadAnswerBeforeRetrying() async throws {
        let promptRecorder = PromptRecorder()
        let loop = LocalAgentLoop(
            generator: { prompt, _, _, _, _, onToken in
                await promptRecorder.record(prompt)
                let output = """
                <scratch_pad>
                I already have the note content in the provided context.

                Answer: CMS v2 makes moral coherence a constitutive property of the model architecture rather than a post-hoc filter.
                </scratch_pad>
                """
                await onToken(output)
                return output
            },
            toolExecutor: { _, _ in
                Issue.record("Hidden-answer salvage should finish without calling tools.")
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

        let prompts = await promptRecorder.snapshot()
        #expect(prompts.count == 1)
        #expect(
            answer
                == "CMS v2 makes moral coherence a constitutive property of the model architecture rather than a post-hoc filter."
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
    @Test("mlx one-shot generator uses direct generation")
    func mlxOneShotGeneratorUsesDirectGeneration() async throws {
        let client = RecordingLocalClient(streamChunks: ["hello", " world"])
        let generator = LocalAgentLoop.mlxOneShotGenerator(using: client)
        var streamed = ""

        let output = try await generator(
            "PROMPT",
            nil,
            64,
            .fast,
            LocalTextModelID.qwen35_4B4Bit.rawValue,
            { chunk in streamed.append(chunk) }
        )

        #expect(output == "hello world")
        #expect(streamed == "hello world")
        #expect(client.generateCallCount == 1)
        #expect(client.streamCallCount == 0)
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

    private func writeTool() -> OmegaToolDefinition {
        OmegaToolDefinition(
            name: "write_file",
            agent: "file",
            description: "Write a file.",
            argumentsExample: #"{"path":"/tmp/tool-smoke.txt","content":"tool smoke ok"}"#,
            schemaJson: #"{"type":"object","properties":{"path":{"type":"string"},"content":{"type":"string"}},"required":["path","content"]}"#,
            destructive: false,
            requiresConfirmation: false
        )
    }

    private func readTool() -> OmegaToolDefinition {
        OmegaToolDefinition(
            name: "read_file",
            agent: "file",
            description: "Read a file.",
            argumentsExample: #"{"path":"tmp/tool-smoke.txt"}"#,
            schemaJson: #"{"type":"object","properties":{"path":{"type":"string"}},"required":["path"]}"#,
            destructive: false,
            requiresConfirmation: false
        )
    }

    private func vaultWriteTool() -> OmegaToolDefinition {
        OmegaToolDefinition(
            name: "vault_write",
            agent: "notes",
            description: "Create or update a vault note.",
            argumentsExample: #"{"path":"Quick Thought.md","content":"main note smoke ok"}"#,
            schemaJson: #"{"type":"object","properties":{"path":{"type":"string"},"content":{"type":"string"}},"required":["path","content"]}"#,
            destructive: false,
            requiresConfirmation: false
        )
    }

    private func vaultReadTool() -> OmegaToolDefinition {
        OmegaToolDefinition(
            name: "vault_read",
            agent: "notes",
            description: "Read a vault note.",
            argumentsExample: #"{"path":"Quick Thought.md"}"#,
            schemaJson: #"{"type":"object","properties":{"path":{"type":"string"}},"required":["path"]}"#,
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

@MainActor
private final class RecordingLocalClient: LocalConfigurableLLMClient {
    private let streamChunks: [String]
    private(set) var generateCallCount = 0
    private(set) var streamCallCount = 0

    init(streamChunks: [String]) {
        self.streamChunks = streamChunks
    }

    func generate(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String {
        generateCallCount += 1
        return streamChunks.joined()
    }

    func stream(prompt: String, systemPrompt: String?, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        stream(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            reasoningMode: .fast,
            modelID: nil,
            steeringHintsJSON: nil
        )
    }

    func testConnection() async -> ConnectionTestResult {
        ConnectionTestResult(success: true, message: "ok")
    }

    func configSnapshot() -> LLMSnapshot {
        LLMSnapshot(provider: .localMLX, model: "test", reasoningMode: .fast)
    }

    func generate(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        modelID: String?,
        steeringHintsJSON: String?
    ) async throws -> String {
        generateCallCount += 1
        return streamChunks.joined()
    }

    func stream(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        modelID: String?,
        steeringHintsJSON: String?
    ) -> AsyncThrowingStream<String, Error> {
        streamCallCount += 1
        return AsyncThrowingStream { continuation in
            for chunk in streamChunks {
                continuation.yield(chunk)
            }
            continuation.finish()
        }
    }
}

private actor ToolCallRecorder {
    private var calls: [(name: String, argumentsJson: String)] = []

    func record(_ name: String, _ argumentsJson: String) {
        calls.append((name, argumentsJson))
    }

    func snapshot() -> [(name: String, argumentsJson: String)] {
        calls
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

@MainActor
private final class QueueingLocalLLMClient: LocalConfigurableLLMClient {
    private let generateQueue: ResponseQueue
    private let streamQueue: StreamChunkQueue

    private(set) var generateRequestCount = 0
    private(set) var streamRequestCount = 0

    init(generateOutputs: [String], streamOutputs: [[String]]) {
        self.generateQueue = ResponseQueue(outputs: generateOutputs)
        self.streamQueue = StreamChunkQueue(streams: streamOutputs)
    }

    func generate(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String {
        try await generate(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            reasoningMode: .fast,
            modelID: nil,
            steeringHintsJSON: nil
        )
    }

    func stream(prompt: String, systemPrompt: String?, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        stream(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            reasoningMode: .fast,
            modelID: nil,
            steeringHintsJSON: nil
        )
    }

    func generate(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        modelID: String?,
        steeringHintsJSON: String?
    ) async throws -> String {
        _ = prompt
        _ = systemPrompt
        _ = maxTokens
        _ = reasoningMode
        _ = modelID
        _ = steeringHintsJSON
        generateRequestCount += 1
        return await generateQueue.nextOutput()
    }

    func stream(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        modelID: String?,
        steeringHintsJSON: String?
    ) -> AsyncThrowingStream<String, Error> {
        _ = prompt
        _ = systemPrompt
        _ = maxTokens
        _ = reasoningMode
        _ = modelID
        _ = steeringHintsJSON
        streamRequestCount += 1

        return AsyncThrowingStream<String, Error> { continuation in
            let task = Task {
                let chunks = await self.streamQueue.nextStream()
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
    }

    func testConnection() async -> ConnectionTestResult {
        ConnectionTestResult(success: true, message: "ok")
    }

    func configSnapshot() -> LLMSnapshot {
        LLMSnapshot(
            provider: .localMLX,
            model: LocalTextModelID.qwen3_4B4Bit.rawValue,
            reasoningMode: .fast
        )
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
