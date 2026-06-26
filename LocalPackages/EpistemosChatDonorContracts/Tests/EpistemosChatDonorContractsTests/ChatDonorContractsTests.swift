import EpistemosChatDonorContracts
import XCTest

final class ChatDonorContractsTests: XCTestCase {
    func testCatalogCoversEverySwiftChatDonor() {
        let donors = Set(ChatDonorContractCatalog.swiftChat20260625.map(\.donor))
        XCTAssertEqual(donors, Set(ChatDonorID.allCases))
    }

    func testCatalogContractsValidate() {
        let failures = ChatDonorContractCatalog.validationFailures
        XCTAssertTrue(failures.isEmpty, "Unexpected donor contract failures: \(failures)")
    }

    func testUnknownLicenseDonorsStayCleanRoom() {
        let unknownLicenseContracts = ChatDonorContractCatalog.swiftChat20260625.filter {
            $0.licenseDisposition == .unknownStudyOnly
        }

        XCTAssertFalse(unknownLicenseContracts.isEmpty)
        for contract in unknownLicenseContracts {
            XCTAssertEqual(contract.importMode, .cleanRoomStudy)
            XCTAssertTrue(
                contract.status == .cleanRoomPending || contract.status == .adaptedWithTests,
                contract.id
            )
        }
    }

    func testAdaptedContractsDeclareImplementationPaths() {
        let adaptedContracts = ChatDonorContractCatalog.swiftChat20260625.filter {
            $0.status == .adaptedWithTests
        }

        XCTAssertFalse(adaptedContracts.isEmpty)
        for contract in adaptedContracts {
            XCTAssertFalse(contract.implementationPaths.isEmpty, contract.id)
            XCTAssertFalse(contract.validationFailures.contains(.missingImplementationPath), contract.id)
        }
    }

    func testRuntimeContractsRequireOffMainWorkAndCancellation() {
        for contract in ChatDonorContractCatalog.swiftChat20260625 {
            let hasRuntimeSeam = contract.destinationSeams.contains(where: \.requiresRuntimeOffMainActor)
            guard hasRuntimeSeam else { continue }

            XCTAssertTrue(contract.threading.runtimeWorkOffMainActor, contract.id)
            XCTAssertTrue(contract.threading.requiresCancellation, contract.id)
            XCTAssertTrue(contract.threading.usesStructuredConcurrency, contract.id)
            XCTAssertFalse(contract.memory.allowsUnboundedStreams, contract.id)
        }
    }

    func testContractCodableRoundTrip() throws {
        let contract = try XCTUnwrap(ChatDonorContractCatalog.contracts(for: .swarm).first)
        let data = try JSONEncoder().encode(contract)
        let decoded = try JSONDecoder().decode(ChatDonorFeatureContract.self, from: data)

        XCTAssertEqual(decoded, contract)
    }

    func testBoundedStreamKeepsNewestEventsWhenProducerOutrunsConsumer() async throws {
        var contract = try XCTUnwrap(ChatDonorContractCatalog.contracts(for: .swarm).first)
        contract.memory = ChatDonorMemoryPolicy(
            maxBufferedEvents: 2,
            maxInMemoryAttachmentBytes: 128,
            maxVisibleTranscriptCharacters: 512,
            allowsUnboundedStreams: false,
            spillLargeInputsToResourceChips: true,
            preallocateHotBuffers: true
        )

        let boundedStream = ChatDonorBoundedStream<Int>(contract: contract)
        for value in 0..<8 {
            await boundedStream.yield(value)
        }
        await boundedStream.finish()

        var collected: [Int] = []
        for await value in boundedStream.stream {
            collected.append(value)
        }

        let receipt = await boundedStream.receipt()
        XCTAssertEqual(collected, [6, 7])
        XCTAssertEqual(receipt.maxBufferedEvents, 2)
        XCTAssertEqual(receipt.eventCount, 8)
        XCTAssertTrue(receipt.droppedEventCount > 0)
        XCTAssertTrue(receipt.provesBoundedStream)
    }

    func testBoundedStreamReceiptRecordsCancellation() async throws {
        let contract = try XCTUnwrap(ChatDonorContractCatalog.contracts(for: .mcpSwiftSDK).first)
        let boundedStream = ChatDonorBoundedStream<String>(contract: contract)

        await boundedStream.yield("tool-started")
        await boundedStream.cancel()

        let receipt = await boundedStream.receipt()
        XCTAssertEqual(receipt.termination, .cancelled)
        XCTAssertTrue(receipt.cancellationObserved)
        XCTAssertEqual(receipt.eventCount, 1)
    }

    func testRuntimeReceiptCodableRoundTrip() async throws {
        let contract = try XCTUnwrap(ChatDonorContractCatalog.contracts(for: .agentSDK).first)
        let recorder = ChatDonorRuntimeRecorder(contract: contract)

        await recorder.record(.enqueued(remainingCapacity: 12))
        await recorder.complete()
        let receipt = await recorder.receipt()

        let data = try JSONEncoder().encode(receipt)
        let decoded = try JSONDecoder().decode(ChatDonorRuntimeReceipt.self, from: data)

        XCTAssertEqual(decoded, receipt)
        XCTAssertEqual(decoded.termination, .completed)
        XCTAssertTrue(decoded.isContractValid)
    }

    func testUnboundedRuntimePoliciesFailValidation() throws {
        var contract = try XCTUnwrap(ChatDonorContractCatalog.contracts(for: .swarm).first)
        contract.memory.allowsUnboundedStreams = true

        XCTAssertTrue(contract.validationFailures.contains(.unboundedStream))
    }

    func testSwiftedMindFragmentBufferPreservesSparseOrder() {
        var buffer = ChatDonorContentFragmentBuffer(maxFragmentCount: 4, maxTotalCharacters: 32)

        XCTAssertEqual(buffer.append("world", at: 2), .appended(index: 2, totalCharacters: 5))
        XCTAssertEqual(buffer.append("hello", at: 0), .appended(index: 0, totalCharacters: 10))
        XCTAssertEqual(buffer.append(" ", at: 0), .appended(index: 0, totalCharacters: 11))
        XCTAssertEqual(buffer.assign("there", at: 2), .assigned(index: 2, totalCharacters: 11))

        XCTAssertEqual(buffer.fragments, ["hello ", "", "there"])
        XCTAssertEqual(buffer.nonEmptyFragments, ["hello ", "there"])
        XCTAssertEqual(buffer.joined(), "hello there")
    }

    func testSwiftedMindFragmentBufferRejectsInvalidGrowth() {
        var buffer = ChatDonorContentFragmentBuffer(maxFragmentCount: 2, maxTotalCharacters: 5)

        XCTAssertEqual(buffer.append("hey", at: 0), .appended(index: 0, totalCharacters: 3))
        XCTAssertEqual(buffer.append("!", at: -1), .rejected(reason: .negativeIndex))
        XCTAssertEqual(buffer.append("x", at: 2), .rejected(reason: .indexExceedsFragmentBudget))
        XCTAssertEqual(buffer.append("there", at: 1), .rejected(reason: .characterBudgetExceeded))
        XCTAssertEqual(buffer.joined(), "hey")
    }

    func testSwiftedMindTokenUsageMergesSparseCounters() {
        let first = ChatDonorTokenUsage(
            inputTokens: 10,
            outputTokens: nil,
            totalTokens: 12,
            cachedTokens: 4,
            reasoningTokens: nil
        )
        let second = ChatDonorTokenUsage(
            inputTokens: 2,
            outputTokens: 6,
            totalTokens: nil,
            cachedTokens: nil,
            reasoningTokens: 3
        )

        let merged = first.merged(with: second)

        XCTAssertEqual(merged.inputTokens, 12)
        XCTAssertEqual(merged.outputTokens, 6)
        XCTAssertEqual(merged.totalTokens, 12)
        XCTAssertEqual(merged.cachedTokens, 4)
        XCTAssertEqual(merged.reasoningTokens, 3)
        XCTAssertEqual(ChatDonorTokenUsage(inputTokens: 5, outputTokens: 7).resolvedTotalTokens, 12)
    }

    func testSwiftedMindTokenUsageSaturatesOnOverflow() {
        let merged = ChatDonorTokenUsage(inputTokens: Int.max)
            .merged(with: ChatDonorTokenUsage(inputTokens: 1))

        XCTAssertEqual(merged.inputTokens, Int.max)
    }

    func testSwiftedMindTranscriptUpsertPreservesEntryOrder() {
        var transcript = ChatDonorTranscript()
        transcript.upsert(
            ChatDonorTranscriptEntry(
                id: "response",
                role: .response,
                status: .streaming,
                text: "hel"
            )
        )
        transcript.upsert(
            ChatDonorTranscriptEntry(
                id: "tool",
                role: .toolCall,
                status: .pending,
                text: "search"
            )
        )
        transcript.upsert(
            ChatDonorTranscriptEntry(
                id: "response",
                role: .response,
                status: .completed,
                text: "hello"
            )
        )

        XCTAssertEqual(transcript.entries.map(\.id), ["response", "tool"])
        XCTAssertEqual(transcript[id: "response"]?.text, "hello")
        XCTAssertEqual(transcript[id: "response"]?.status, .completed)
    }

    func testAgentKitRetryPolicyCapsBackoffAndSupportsDeterministicJitter() {
        let policy = ChatDonorAgentKitRetryPolicy(
            maxAttempts: 5,
            baseDelayNanoseconds: 100,
            maxDelayNanoseconds: 450,
            jitterPermille: 100
        )

        XCTAssertEqual(policy.delayNanoseconds(afterAttempt: 1), 100)
        XCTAssertEqual(policy.delayNanoseconds(afterAttempt: 2), 200)
        XCTAssertEqual(policy.delayNanoseconds(afterAttempt: 3), 400)
        XCTAssertEqual(policy.delayNanoseconds(afterAttempt: 4), 450)
        XCTAssertEqual(policy.delayNanoseconds(afterAttempt: 2, jitterSeed: 50), 210)
        XCTAssertTrue(policy.shouldRetry(afterAttempt: 4))
        XCTAssertFalse(policy.shouldRetry(afterAttempt: 5))
    }

    func testAgentKitRetrierRecordsRetryDelaysAndSuccessReceipt() async {
        let retrier = ChatDonorAgentKitRetrier(policy: ChatDonorAgentKitRetryPolicy(
            maxAttempts: 3,
            baseDelayNanoseconds: 10,
            maxDelayNanoseconds: 100
        ))

        let output = await retrier.run(
            operation: { attempt in
                if attempt < 3 {
                    throw AgentKitErgonomicsTestError.transient
                }
                return "ok"
            },
            sleep: { _ in }
        )

        switch output {
        case .success(let value, let receipt):
            XCTAssertEqual(value, "ok")
            XCTAssertEqual(receipt.attemptsStarted, 3)
            XCTAssertEqual(receipt.retryDelaysNanoseconds, [10, 20])
            XCTAssertEqual(receipt.termination, .success)
            XCTAssertFalse(receipt.cancellationObserved)
        case .failure(let receipt):
            XCTFail("Expected retry success, got \(receipt)")
        }
    }

    func testAgentKitRetrierStopsOnNonRetryableFailure() async {
        let retrier = ChatDonorAgentKitRetrier(policy: ChatDonorAgentKitRetryPolicy(
            maxAttempts: 3,
            baseDelayNanoseconds: 10,
            maxDelayNanoseconds: 100
        ))

        let output = await retrier.run(
            operation: { _ in
                throw AgentKitErgonomicsTestError.permanent
            },
            shouldRetryError: { error in
                guard let error = error as? AgentKitErgonomicsTestError else { return true }
                return error != .permanent
            },
            sleep: { _ in }
        )

        let receipt = output.receipt
        XCTAssertEqual(receipt.attemptsStarted, 1)
        XCTAssertEqual(receipt.retryDelaysNanoseconds, [])
        XCTAssertEqual(receipt.termination, .nonRetryableFailure)
        XCTAssertFalse(receipt.cancellationObserved)
    }

    func testAgentKitConversationWindowDropsDanglingEntriesAndKeepsRecentTranscript() {
        var window = ChatDonorAgentKitConversationWindow(maxEntries: 4)
        let transcript = ChatDonorTranscript(entries: [
            ChatDonorTranscriptEntry(id: "orphan", role: .response, status: .completed, text: "orphan"),
            ChatDonorTranscriptEntry(id: "p1", role: .prompt, status: .completed, text: "old prompt"),
            ChatDonorTranscriptEntry(id: "r1", role: .response, status: .completed, text: "old response"),
            ChatDonorTranscriptEntry(id: "p2", role: .prompt, status: .completed, text: "recent prompt"),
            ChatDonorTranscriptEntry(id: "tool", role: .toolOutput, status: .completed, text: "tool output"),
            ChatDonorTranscriptEntry(id: "p3", role: .prompt, status: .completed, text: "new prompt"),
            ChatDonorTranscriptEntry(id: "r3", role: .response, status: .completed, text: "new response")
        ])

        let managed = window.apply(to: transcript)

        XCTAssertEqual(managed.entries.map(\.id), ["p2", "tool", "p3", "r3"])
        XCTAssertEqual(window.removedEntryCount, 3)
    }

    func testAgentKitConversationWindowReducesContextAndTruncatesToolOutput() {
        var window = ChatDonorAgentKitConversationWindow(
            maxEntries: 8,
            reductionStride: 2,
            maxToolOutputCharacters: 5
        )
        let transcript = ChatDonorTranscript(entries: [
            ChatDonorTranscriptEntry(id: "p1", role: .prompt, status: .completed, text: "old prompt"),
            ChatDonorTranscriptEntry(id: "r1", role: .response, status: .completed, text: "old response"),
            ChatDonorTranscriptEntry(id: "p2", role: .prompt, status: .completed, text: "recent prompt"),
            ChatDonorTranscriptEntry(id: "tool", role: .toolOutput, status: .completed, text: "abcdefghijklmnopqrstuvwxyz"),
            ChatDonorTranscriptEntry(id: "r2", role: .response, status: .completed, text: "recent response")
        ])

        let reduced = window.reduceContext(for: transcript)

        XCTAssertEqual(reduced.entries.map(\.id), ["p2", "tool", "r2"])
        XCTAssertEqual(window.removedEntryCount, 2)
        XCTAssertEqual(reduced[id: "tool"]?.text.hasPrefix("abcde"), true)
        XCTAssertEqual(reduced[id: "tool"]?.text.contains("Tool output truncated"), true)
    }

    func testAgentKitCallbackLogAssignsStableOrderAndRejectsEventsAfterEnd() {
        var log = ChatDonorAgentKitCallbackLog()

        XCTAssertEqual(log.append(kind: .text, payload: "hello"), .appended(sequence: 0))
        XCTAssertEqual(log.append(kind: .toolUse, payload: "search"), .appended(sequence: 1))
        XCTAssertEqual(log.append(kind: .message, payload: "assistant message"), .appended(sequence: 2))
        XCTAssertEqual(log.append(kind: .end), .appended(sequence: 3))
        XCTAssertEqual(log.append(kind: .text, payload: "late"), .rejectedAfterEnd)

        XCTAssertTrue(log.isTerminated)
        XCTAssertTrue(log.hasValidOrdering)
        XCTAssertEqual(log.events.map(\.sequence), [0, 1, 2, 3])
        XCTAssertEqual(log.events.map(\.kind), [.text, .toolUse, .message, .end])
    }

    func testAgentKitMCPConfigurationDecodesMixedServersAndFiltersActiveOnes() throws {
        let json = """
        {
          "mcpServers": {
            "default-server": {
              "url": "http://127.0.0.1:8080/mcp",
              "disabled": false,
              "timeout": 60000
            },
            "another-server": {
              "command": "node",
              "args": ["build/index.js", "--debug"],
              "env": {
                "API_KEY": "your-api-key",
                "DEBUG": "true"
              }
            },
            "disabled-server": {
              "command": "node",
              "disabled": true
            },
            "bad-timeout": {
              "url": "http://127.0.0.1:9000/mcp",
              "timeout": 0
            }
          }
        }
        """.data(using: .utf8)!

        let configuration = try JSONDecoder().decode(ChatDonorAgentKitMCPConfiguration.self, from: json)

        XCTAssertEqual(configuration.servers.map(\.name), [
            "another-server",
            "bad-timeout",
            "default-server",
            "disabled-server"
        ])
        XCTAssertEqual(configuration["default-server"]?.transport, .http(url: "http://127.0.0.1:8080/mcp"))
        XCTAssertEqual(
            configuration["another-server"]?.transport,
            .stdio(command: "node", args: ["build/index.js", "--debug"], env: ["API_KEY": "your-api-key", "DEBUG": "true"])
        )
        XCTAssertEqual(configuration["default-server"]?.timeoutDecision, .valid(milliseconds: 60000))
        XCTAssertEqual(configuration["bad-timeout"]?.timeoutDecision, .invalidNonPositive)
        XCTAssertEqual(configuration["bad-timeout"]?.validationFailures, [.invalidTimeout])
        XCTAssertEqual(configuration["disabled-server"]?.validationFailures, [.disabled])
        XCTAssertEqual(configuration.activeServers.map(\.name), ["another-server", "default-server"])

        let data = try JSONEncoder().encode(configuration)
        let decoded = try JSONDecoder().decode(ChatDonorAgentKitMCPConfiguration.self, from: data)
        XCTAssertEqual(decoded, configuration)
    }

    func testAgentKitMCPClientCatalogRoutesToolsAndBuildsWrappers() throws {
        let weather = ChatDonorMCPToolDescriptor(
            name: "weather",
            description: "Get weather",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "city": .object(["type": "string"])
                ])
            ])
        )
        let fxRate = ChatDonorMCPToolDescriptor(name: "fx_rate", description: "Get FX rate")
        let catalog = ChatDonorAgentKitMCPClientCatalog(clients: [
            ChatDonorAgentKitMCPClientDescriptor(name: "weather-server", tools: [weather]),
            ChatDonorAgentKitMCPClientDescriptor(name: "finance-server", tools: [fxRate])
        ])

        XCTAssertEqual(catalog.listToolNames(), ["weather", "fx_rate"])
        XCTAssertEqual(catalog.clientName(forTool: "weather"), "weather-server")
        XCTAssertEqual(catalog.clientName(forTool: "missing"), nil)

        let route = try catalog.route(toolName: "fx_rate", arguments: ["pair": "USD/EUR"])
        XCTAssertEqual(route.clientName, "finance-server")
        XCTAssertEqual(route.tool.name, "fx_rate")
        XCTAssertEqual(route.arguments["pair"], "USD/EUR")

        let wrappers = catalog.asToolWrappers()
        XCTAssertEqual(wrappers.map(\.description), ["MCPToolWrapper(weather)", "MCPToolWrapper(fx_rate)"])
        XCTAssertEqual(wrappers[0].toolDescription, "Get weather")
        XCTAssertEqual(wrappers[0].inputSchemaJSONString, #"{"properties":{"city":{"type":"string"}},"type":"object"}"#)

        XCTAssertThrowsError(try catalog.route(toolName: "missing", arguments: [:])) { error in
            XCTAssertEqual(error as? ChatDonorAgentKitMCPError, .unknownTool("missing"))
        }
    }

    func testAgentKitMCPToolInputDecoderUsesWholeObjectThenInputFallback() throws {
        let direct = try ChatDonorAgentKitMCPToolInputDecoder.decode(
            AgentKitMCPTestInput.self,
            from: ["message": "Hello"]
        )
        XCTAssertEqual(direct, AgentKitMCPTestInput(message: "Hello"))

        let fallback = try ChatDonorAgentKitMCPToolInputDecoder.decode(
            String.self,
            from: ["input": "raw prompt"]
        )
        XCTAssertEqual(fallback, "raw prompt")

        XCTAssertThrowsError(
            try ChatDonorAgentKitMCPToolInputDecoder.decode(String.self, from: ["message": "missing fallback"])
        ) { error in
            XCTAssertEqual(error as? ChatDonorAgentKitMCPError, .missingParameter("input"))
        }
    }

    func testAgentKitMCPServerDescriptorAssemblesCapabilitiesResourcesAndPrompts() throws {
        let tool = ChatDonorMCPToolDescriptor(name: "echo", description: "Echo input")
        let prompt = try ChatDonorAgentKitMCPPromptTemplate(
            name: "greeting",
            description: "Build a greeting",
            template: "Hello {name}",
            parameters: ["name": "Name to greet"]
        )
        var server = ChatDonorAgentKitMCPServerDescriptor(
            name: "EpistemosMCP",
            transport: .stdio,
            tools: [tool],
            prompts: [prompt],
            resources: [
                .text(
                    name: "Docs",
                    uri: "docs://agentkit",
                    content: "AgentKit MCP docs",
                    description: "Developer documentation",
                    mimeType: "text/markdown"
                )
            ]
        )

        XCTAssertEqual(server.capabilities, ChatDonorAgentKitMCPServerCapabilities(tools: true, prompts: true, resources: true))
        XCTAssertEqual(try server.tool(named: "echo").description, "Echo input")
        XCTAssertEqual(try server.resourceContent(uri: "docs://agentkit").text, "AgentKit MCP docs")
        XCTAssertEqual(try server.renderPrompt(named: "greeting", arguments: ["name": "Ada"]), "Hello Ada")
        XCTAssertEqual(prompt.descriptor.requiredArgumentNames, ["name"])

        server.registerResources([
            .binary(name: "Logo", uri: "images://logo", data: Data([1, 2, 3]), mimeType: "image/png")
        ])
        XCTAssertEqual(server.resources.count, 2)
        XCTAssertEqual(try server.resourceContent(uri: "images://logo").blob, Data([1, 2, 3]).base64EncodedString())

        XCTAssertThrowsError(try server.renderPrompt(named: "greeting", arguments: [:])) { error in
            XCTAssertEqual(error as? ChatDonorAgentKitMCPError, .missingPromptValue("name"))
        }
        XCTAssertThrowsError(
            try ChatDonorAgentKitMCPPromptTemplate(
                name: "bad",
                description: "Bad prompt",
                template: "Hello {name}",
                parameters: [:]
            )
        ) { error in
            XCTAssertEqual(error as? ChatDonorAgentKitMCPError, .missingPromptParameters(["name"]))
        }

        let data = try JSONEncoder().encode(server)
        let decoded = try JSONDecoder().decode(ChatDonorAgentKitMCPServerDescriptor.self, from: data)
        XCTAssertEqual(decoded, server)
    }

    func testAgentSDKTypedToolDescriptorsFilterByRunContextCapabilities() {
        let readTool = ChatDonorAgentSDKToolDescriptor(
            name: "read_file",
            description: "Read a file",
            parameters: [
                ChatDonorAgentSDKToolParameter(
                    name: "path",
                    description: "Path to read",
                    type: .string
                ),
                ChatDonorAgentSDKToolParameter(
                    name: "limit",
                    description: "Maximum bytes",
                    type: .number,
                    required: false
                )
            ],
            availability: .requiresAllCapabilities(["file.read"])
        )
        let writeTool = ChatDonorAgentSDKToolDescriptor(
            name: "write_file",
            description: "Write a file",
            availability: .requiresAllCapabilities(["file.write"])
        )
        let agent = ChatDonorAgentSDKAgentDescriptor(
            name: "ToolsAgent",
            instructions: "Use tools carefully.",
            tools: [readTool, writeTool]
        )
        let context = ChatDonorAgentSDKRunContext(
            sessionID: "session-1",
            enabledCapabilities: ["file.read"]
        )

        let enabled = agent.enabledTools(for: context)

        XCTAssertEqual(enabled.map(\.name), ["read_file"])
        XCTAssertEqual(readTool.requiredParameterNames, ["path"])
        XCTAssertEqual(readTool.parameters[0].type.jsonType, "string")
        XCTAssertEqual(readTool.parameters[1].type.jsonType, "number")
    }

    func testAgentSDKGuardrailPipelineMapsInputAndOutputRejections() {
        let agent = ChatDonorAgentSDKAgentDescriptor(
            name: "GuardedAgent",
            instructions: "Stay inside policy.",
            inputGuardrails: [.maxCharacters(8)],
            outputGuardrails: [
                .blockSubstring("secret"),
                .requireSubstring("summary")
            ]
        )

        let acceptedInput = agent.validateInput("short")
        let rejectedInput = agent.validateInput("this is too long")
        let rejectedOutput = agent.validateOutput("the secret is here")
        let missingRequiredOutput = agent.validateOutput("plain answer")
        let acceptedOutput = agent.validateOutput("summary: done")

        XCTAssertTrue(acceptedInput.allowed)
        XCTAssertEqual(acceptedInput.scope, .input)
        XCTAssertFalse(rejectedInput.allowed)
        XCTAssertEqual(rejectedInput.scope, .input)
        XCTAssertEqual(rejectedInput.reason?.contains("8 characters"), true)
        XCTAssertFalse(rejectedOutput.allowed)
        XCTAssertEqual(rejectedOutput.scope, .output)
        XCTAssertEqual(rejectedOutput.reason?.contains("blocked content"), true)
        XCTAssertFalse(missingRequiredOutput.allowed)
        XCTAssertEqual(missingRequiredOutput.reason?.contains("required content"), true)
        XCTAssertTrue(acceptedOutput.allowed)
        XCTAssertEqual(acceptedOutput.scope, .output)
    }

    func testAgentSDKHandoffRuleEmitsTargetAndMatchedKeywords() {
        let agent = ChatDonorAgentSDKAgentDescriptor(
            name: "PrimaryAgent",
            instructions: "Route specialist work.",
            handoffs: [
                ChatDonorAgentSDKHandoffRule(
                    targetAgentName: "ResearchAgent",
                    keywords: ["research", "sources"]
                ),
                ChatDonorAgentSDKHandoffRule(
                    targetAgentName: "CodeAgent",
                    keywords: ["Build"],
                    caseSensitive: true
                )
            ]
        )

        let researchDecision = agent.handoffDecision(for: "Please RESEARCH with sources")
        let codeDecision = agent.handoffDecision(for: "please build this")

        XCTAssertEqual(researchDecision?.targetAgentName, "ResearchAgent")
        XCTAssertEqual(researchDecision?.matchedKeywords, ["research", "sources"])
        XCTAssertNil(codeDecision)
    }

    func testAgentSDKToolUseBehaviorResolvesFinalOutput() {
        let results = [
            ChatDonorAgentSDKToolCallResult(id: "1", name: "search", output: "search output"),
            ChatDonorAgentSDKToolCallResult(id: "2", name: "finalize", output: "final answer")
        ]

        XCTAssertNil(ChatDonorAgentSDKToolUseBehavior.runLLMAgain.finalOutput(from: results))
        XCTAssertEqual(ChatDonorAgentSDKToolUseBehavior.stopOnFirstTool.finalOutput(from: results), "search output")
        XCTAssertEqual(ChatDonorAgentSDKToolUseBehavior.stopAtTools(["finalize"]).finalOutput(from: results), "final answer")
        XCTAssertNil(ChatDonorAgentSDKToolUseBehavior.stopAtTools(["missing"]).finalOutput(from: results))
    }

    func testAgentSDKUsageMergesAndCodableRoundTripsAgentDescriptor() throws {
        var usage = ChatDonorAgentSDKUsage()
        usage.record(inputTokens: 10, outputTokens: 5)
        usage.merge(ChatDonorAgentSDKUsage(requests: 2, inputTokens: 3, outputTokens: 4, totalTokens: 8))

        XCTAssertEqual(usage.requests, 3)
        XCTAssertEqual(usage.inputTokens, 13)
        XCTAssertEqual(usage.outputTokens, 9)
        XCTAssertEqual(usage.totalTokens, 23)

        let descriptor = ChatDonorAgentSDKAgentDescriptor(
            name: "RoundTripAgent",
            instructions: "Typed boundary.",
            handoffDescription: "Handles typed boundary tests.",
            tools: [
                ChatDonorAgentSDKToolDescriptor(
                    name: "ask_user",
                    description: "Ask for clarification",
                    availability: .requiresAnyCapability(["approval", "question"])
                )
            ],
            inputGuardrails: [.maxCharacters(100)],
            outputGuardrails: [.blockSubstring("forbidden")],
            handoffs: [
                ChatDonorAgentSDKHandoffRule(targetAgentName: "FallbackAgent", keywords: ["fallback"])
            ],
            modelSettings: ChatDonorAgentSDKModelSettings(
                modelName: "epistemos-local",
                temperature: 0.2,
                maxTokens: 512,
                toolChoice: .auto,
                parallelToolCalls: true,
                reasoningEffort: .low
            ),
            toolUseBehavior: .stopAtTools(["ask_user"]),
            resetToolChoice: false
        )

        let data = try JSONEncoder().encode(descriptor)
        let decoded = try JSONDecoder().decode(ChatDonorAgentSDKAgentDescriptor.self, from: data)

        XCTAssertEqual(decoded, descriptor)
    }

    func testMCPSemanticToolDescriptorPreservesAnnotationsAndSchemas() throws {
        let tool = ChatDonorMCPToolDescriptor(
            name: "search_files",
            title: "Search Files",
            description: "Search project files",
            inputSchema: [
                "type": "object",
                "properties": [
                    "query": ["type": "string"]
                ],
                "required": ["query"]
            ],
            outputSchema: [
                "type": "object",
                "properties": [
                    "matches": ["type": "array"]
                ]
            ],
            annotations: ChatDonorMCPToolAnnotations(
                title: "Search",
                readOnlyHint: true,
                destructiveHint: false,
                idempotentHint: true,
                openWorldHint: false
            ),
            metadata: ["source": "epistemos"]
        )

        XCTAssertEqual(tool.displayName, "Search Files")
        XCTAssertFalse(tool.requiresExplicitApproval)
        XCTAssertEqual(tool.inputSchema.objectValue?["required"], ["query"])

        let data = try JSONEncoder().encode(tool)
        let decoded = try JSONDecoder().decode(ChatDonorMCPToolDescriptor.self, from: data)
        XCTAssertEqual(decoded, tool)
    }

    func testMCPSemanticResourcesEncodeTextBinaryAndClampPriority() throws {
        let annotations = ChatDonorMCPResourceAnnotations(
            audience: [.user, .assistant],
            priority: 1.5,
            lastModified: "2026-06-25T14:00:00Z"
        )
        let descriptor = ChatDonorMCPResourceDescriptor(
            name: "Vault Note",
            uri: "epistemos://vault/note",
            mimeType: "text/markdown",
            size: -4,
            annotations: annotations
        )
        let text = ChatDonorMCPResourceContent.text("# Note", uri: descriptor.uri, mimeType: descriptor.mimeType)
        let binary = ChatDonorMCPResourceContent.binary(Data("abc".utf8), uri: "epistemos://blob", mimeType: "application/octet-stream")
        let template = ChatDonorMCPResourceTemplate(uriTemplate: "epistemos://vault/{id}", name: "Vault item")

        XCTAssertEqual(descriptor.size, 0)
        XCTAssertEqual(descriptor.annotations?.priority, 1)
        XCTAssertEqual(text.text, "# Note")
        XCTAssertEqual(binary.blob, Data("abc".utf8).base64EncodedString())
        XCTAssertEqual(template.uriTemplate, "epistemos://vault/{id}")

        let data = try JSONEncoder().encode([text, binary])
        let decoded = try JSONDecoder().decode([ChatDonorMCPResourceContent].self, from: data)
        XCTAssertEqual(decoded, [text, binary])
    }

    func testMCPSemanticPromptsTrackRequiredArgumentsAndMessages() throws {
        let prompt = ChatDonorMCPPromptDescriptor(
            name: "summarize",
            title: "Summarize",
            arguments: [
                .init(name: "topic", required: true),
                .init(name: "style", required: false)
            ]
        )
        let messages: [ChatDonorMCPPromptMessage] = [
            .user(.text("Summarize the attached note")),
            .assistant(.resourceLink(uri: "epistemos://vault/note", name: "Note"))
        ]

        XCTAssertEqual(prompt.requiredArgumentNames, ["topic"])
        XCTAssertEqual(prompt.missingRequiredArguments(in: ["style": "brief"]), ["topic"])
        XCTAssertEqual(prompt.missingRequiredArguments(in: ["topic": "Swift Chat"]), [])

        let data = try JSONEncoder().encode(messages)
        let decoded = try JSONDecoder().decode([ChatDonorMCPPromptMessage].self, from: data)
        XCTAssertEqual(decoded, messages)
    }

    func testMCPSemanticProgressTrackerRejectsWrongTokenAndNonMonotonicUpdates() {
        let token = ChatDonorMCPProgressToken.string("run-1")
        var tracker = ChatDonorMCPProgressTracker(token: token)

        let first = ChatDonorMCPProgressNotification(token: token, progress: 1, total: 4, message: "one")
        let second = ChatDonorMCPProgressNotification(token: token, progress: 3, total: 4, message: "three")
        let stale = ChatDonorMCPProgressNotification(token: token, progress: 2, total: 4, message: "two")
        let wrongToken = ChatDonorMCPProgressNotification(token: .string("other"), progress: 4)

        XCTAssertEqual(tracker.append(first), .appended(count: 1))
        XCTAssertEqual(tracker.append(second), .appended(count: 2))
        XCTAssertEqual(tracker.append(stale), .rejectedNonMonotonic)
        XCTAssertEqual(tracker.append(wrongToken), .rejectedTokenMismatch)
        XCTAssertEqual(second.fractionComplete, 0.75)
        XCTAssertEqual(ChatDonorMCPProgressNotification.method, "notifications/progress")
    }

    func testMCPSemanticCancellationMatchesSpecificAndGlobalRequests() {
        let specific = ChatDonorMCPCancellationNotice(requestID: "request-1", reason: "timeout")
        let global = ChatDonorMCPCancellationNotice(reason: "disconnect")

        XCTAssertTrue(specific.matches(requestID: "request-1"))
        XCTAssertFalse(specific.matches(requestID: "request-2"))
        XCTAssertTrue(global.matches(requestID: "request-2"))
        XCTAssertEqual(ChatDonorMCPCancellationNotice.method, "notifications/cancelled")
    }

    func testMCPSemanticElicitationSchemasAndResults() throws {
        let schema = ChatDonorMCPElicitationSchema(
            title: "Approval",
            properties: [
                "reason": ["type": "string"],
                "approved": ["type": "boolean"]
            ],
            required: ["reason", "approved"]
        )
        let form = ChatDonorMCPElicitationRequest.form(message: "Approve this tool?", schema: schema)
        let url = ChatDonorMCPElicitationRequest.url(
            message: "Authenticate",
            url: "https://example.com/auth",
            elicitationID: "elicit-1"
        )
        let accepted = ChatDonorMCPElicitationResult(
            action: .accept,
            content: ["reason": "ok", "approved": true]
        )
        let declined = ChatDonorMCPElicitationResult(
            action: .decline,
            content: ["ignored": "value"]
        )

        XCTAssertEqual(schema.missingRequiredFields(in: ["reason": "ok"]), ["approved"])
        XCTAssertEqual(form.mode, .form)
        XCTAssertEqual(url.mode, .url)
        XCTAssertEqual(url.elicitationID, "elicit-1")
        XCTAssertEqual(accepted.content["approved"], true)
        XCTAssertTrue(declined.content.isEmpty)

        let data = try JSONEncoder().encode(form)
        let decoded = try JSONDecoder().decode(ChatDonorMCPElicitationRequest.self, from: data)
        XCTAssertEqual(decoded, form)
    }

    func testMCPSemanticOAuthPolicyValidatesURLsPrivateHostsAndTokenExpiry() {
        let strict = ChatDonorMCPOAuthURLPolicy()
        let loopbackAuth = ChatDonorMCPOAuthURLPolicy(allowLoopbackHTTPAuthorizationServer: true)

        XCTAssertEqual(strict.validate("https://example.com/mcp", kind: .resourceEndpoint), .allowed)
        XCTAssertEqual(strict.validate("http://localhost:8080/mcp", kind: .resourceEndpoint), .allowed)
        XCTAssertNotEqual(strict.validate("http://example.com/mcp", kind: .resourceEndpoint), .allowed)
        XCTAssertNotEqual(strict.validate("https://example.com/mcp#frag", kind: .resourceEndpoint), .allowed)
        XCTAssertNotEqual(strict.validate("http://localhost:8080", kind: .authorizationServer), .allowed)
        XCTAssertEqual(loopbackAuth.validate("http://localhost:8080", kind: .authorizationServer), .allowed)
        XCTAssertEqual(strict.validate("http://127.0.0.1/callback", kind: .redirectURI), .allowed)
        XCTAssertTrue(ChatDonorMCPOAuthURLPolicy.isPrivateIPHost("169.254.169.254"))
        XCTAssertFalse(ChatDonorMCPOAuthURLPolicy.isPrivateIPHost("example.com"))

        let expiring = ChatDonorMCPOAuthToken(
            value: "token",
            expiresAt: Date(timeIntervalSince1970: 1_000),
            scopes: ["tools.read"],
            authorizationServer: "https://auth.example.com"
        )
        XCTAssertTrue(expiring.isExpired(now: Date(timeIntervalSince1970: 1_020), skewSeconds: 30))
        XCTAssertFalse(expiring.isExpired(now: Date(timeIntervalSince1970: 900), skewSeconds: 30))
    }

    func testSwiftAgentPermissionRulesMatchPrefixesPathsAndMCPWildcards() {
        let gitRule = ChatDonorPermissionRule.bash("git:*")
        XCTAssertTrue(gitRule.matches(.init(toolName: "Bash", arguments: ["command": "git"])))
        XCTAssertTrue(gitRule.matches(.init(toolName: "Bash", arguments: ["command": "git status"])))
        XCTAssertTrue(gitRule.matches(.init(toolName: "Bash", arguments: ["command": "git-flow init"])))
        XCTAssertFalse(gitRule.matches(.init(toolName: "Bash", arguments: ["command": "gitsomething"])))

        let writeEtc = ChatDonorPermissionRule.write("/etc/*")
        XCTAssertTrue(writeEtc.matches(.init(
            toolName: "Write",
            arguments: ["file_path": "/tmp/../etc/passwd"]
        )))

        let githubMCP = ChatDonorPermissionRule.mcp("github")
        XCTAssertTrue(githubMCP.matches(.init(toolName: "mcp:github:create_pr")))
        XCTAssertFalse(githubMCP.matches(.init(toolName: "mcp:slack:send")))

        let parsed = ChatDonorPermissionRule.parse("Bash(git status) Read Write(/tmp/*)")
        XCTAssertEqual(parsed, [.bash("git status"), .tool("Read"), .write("/tmp/*")])
    }

    func testSwiftAgentPermissionPolicyHonorsEvaluationOrderAndOverrides() {
        let dangerous = ChatDonorToolInvocation(toolName: "Bash", arguments: ["command": "rm -rf /tmp/demo"])
        let finalPolicy = ChatDonorPermissionPolicy(
            allow: [.tool("Bash")],
            finalDeny: [.bash("rm -rf:*")],
            overrides: [.bash("rm -rf:*")],
            defaultDecision: .allow
        )
        XCTAssertEqual(
            finalPolicy.evaluate(dangerous),
            .denied(reason: .finalDeny, matchedRule: .bash("rm -rf:*"))
        )

        let interactiveRemove = ChatDonorToolInvocation(toolName: "Bash", arguments: ["command": "rm -i stale.tmp"])
        let overridePolicy = ChatDonorPermissionPolicy(
            deny: [.bash("rm:*")],
            overrides: [.bash("rm -i:*")],
            dynamicAllow: [.bash("rm -i:*")],
            defaultDecision: .deny
        )
        XCTAssertEqual(
            overridePolicy.evaluate(interactiveRemove),
            .allowed(reason: .dynamicAllowRule, matchedRule: .bash("rm -i:*"))
        )

        let unknown = ChatDonorToolInvocation(toolName: "Bash", arguments: ["command": "python build.py"])
        XCTAssertTrue(ChatDonorPermissionPolicy.standard.evaluate(unknown, approvalID: "approval-1").requiresApproval)
    }

    func testSwiftAgentPermissionSessionRecordsApprovalDecisions() async throws {
        let invocation = ChatDonorToolInvocation(
            toolName: "Bash",
            arguments: ["command": "python build.py"],
            sessionID: "session-1",
            toolUseID: "tool-1"
        )
        let policy = ChatDonorPermissionPolicy(defaultDecision: .ask, enableSessionMemory: true)
        let session = ChatDonorPermissionSession()

        let first = await session.evaluate(invocation, policy: policy, approvalID: "approval-session")
        guard case .requiresApproval(let request) = first else {
            return XCTFail("Expected approval request")
        }
        XCTAssertEqual(request.risk, .high)
        XCTAssertEqual(request.invocation.operationDescription, "Execute: python build.py")

        let optionalReceipt = await session.resolve(first, response: .alwaysAllow)
        let receipt = try XCTUnwrap(optionalReceipt)
        XCTAssertTrue(receipt.allowedExecution)
        XCTAssertEqual(receipt.rememberedSessionDecision, .alwaysAllowed)

        let second = await session.evaluate(invocation, policy: policy)
        XCTAssertEqual(second, .allowed(reason: .sessionMemory, matchedRule: nil))

        let finalDenyPolicy = ChatDonorPermissionPolicy(
            finalDeny: [.bash("python:*")],
            defaultDecision: .ask,
            enableSessionMemory: true
        )
        let denied = await session.evaluate(invocation, policy: finalDenyPolicy)
        XCTAssertEqual(denied, .denied(reason: .finalDeny, matchedRule: .bash("python:*")))
    }

    func testSwiftAgentPluginPermissionModePromptsOrDeniesEscalation() {
        let workspaceTool = ChatDonorToolInvocation(
            toolName: "plugin.write_file",
            metadata: ["requiredPermissionMode": ChatDonorPluginToolPermission.workspaceWrite.requiredMode.rawValue]
        )
        XCTAssertEqual(
            ChatDonorPermissionPolicy.readOnly.evaluate(workspaceTool),
            .denied(reason: .permissionMode, matchedRule: nil)
        )

        let dangerousTool = ChatDonorToolInvocation(
            toolName: "plugin.root_shell",
            metadata: ["requiredPermissionMode": ChatDonorPluginToolPermission.dangerFullAccess.requiredMode.rawValue]
        )
        XCTAssertTrue(ChatDonorPermissionPolicy.standard.evaluate(dangerousTool, approvalID: "approval-danger").requiresApproval)

        var allowPolicy = ChatDonorPermissionPolicy.standard
        allowPolicy.mode = .allow
        XCTAssertEqual(
            allowPolicy.evaluate(dangerousTool),
            .allowed(reason: .permissionMode, matchedRule: nil)
        )
    }

    func testSwiftAgentSandboxPolicyValidatesTimeoutAndRestrictions() {
        let restrictive = ChatDonorSandboxPolicy.restrictive
        let valid = restrictive.requirement(timeoutSeconds: 120)

        XCTAssertTrue(valid.requiresSandbox)
        XCTAssertEqual(valid.networkPolicy, .none)
        XCTAssertEqual(valid.filePolicy, .readOnly)
        XCTAssertFalse(valid.allowSubprocesses)
        XCTAssertTrue(valid.canStart)

        let invalid = restrictive.requirement(timeoutSeconds: 0)
        XCTAssertEqual(invalid.timeoutDecision, .invalidNonPositive)
        XCTAssertFalse(invalid.canStart)

        let tooLong = restrictive.requirement(timeoutSeconds: ChatDonorSandboxPolicy.maxTimeoutSeconds + 1)
        XCTAssertEqual(tooLong.timeoutDecision, .exceedsMaximum(maximum: ChatDonorSandboxPolicy.maxTimeoutSeconds))

        let disabled = ChatDonorSandboxPolicy.disabled.requirement(timeoutSeconds: 10)
        XCTAssertFalse(disabled.requiresSandbox)
    }

    func testSwiftAgentTurnCancellationTokenRecordsCancellation() async throws {
        let token = ChatDonorTurnCancellationToken()

        let initiallyCancelled = await token.isCancelled
        XCTAssertFalse(initiallyCancelled)
        try await token.checkCancellation()

        await token.cancel(reason: "user stopped run")
        await token.cancel(reason: "late duplicate")

        let finallyCancelled = await token.isCancelled
        XCTAssertTrue(finallyCancelled)
        do {
            try await token.checkCancellation()
            XCTFail("Expected cancellation")
        } catch let error as ChatDonorTurnCancellationError {
            XCTAssertEqual(error.reason, "user stopped run")
        }

        let receipt = await token.receipt()
        XCTAssertEqual(receipt.reason, "user stopped run")
        XCTAssertEqual(receipt.cancellationCount, 2)

        let data = try JSONEncoder().encode(receipt)
        let decoded = try JSONDecoder().decode(ChatDonorTurnCancellationReceipt.self, from: data)
        XCTAssertEqual(decoded, receipt)
    }

    func testSwiftAIAgentOutputNormalizationAndToolCallParsing() throws {
        let call = """
        {"name":"getWeather","args":{"city":"Sydney","date":{"month":"Jan"},"count":2}}
        """
        let batch = ChatDonorSwiftAIAgentOutputBatch([
            .text("hello"),
            .functionCalls([call]),
            .structured(["status": "ok"]),
            .image(Data([1, 2, 3]))
        ])

        XCTAssertEqual(batch.firstText, "hello")
        XCTAssertEqual(batch.allTexts, ["hello"])
        XCTAssertEqual(batch.allFunctionCalls, [call])
        XCTAssertTrue(batch.normalizedTranscriptText.contains("AI generated image"))
        XCTAssertTrue(batch.normalizedTranscriptText.contains(#""status":"ok""#))

        let parsed = try XCTUnwrap(batch.parsedToolCalls.first)
        XCTAssertEqual(parsed.name, "getWeather")
        XCTAssertEqual(parsed.arguments["city"], "Sydney")
        XCTAssertEqual(parsed.arguments["date"], ["month": "Jan"])
        XCTAssertEqual(parsed.arguments["count"], 2)
        XCTAssertEqual(parsed.argumentsJSON, #"{"city":"Sydney","count":2,"date":{"month":"Jan"}}"#)
    }

    func testSwiftAIAgentLoopCompletesWhenNoToolCalls() async throws {
        let runner = ChatDonorSwiftAIAgentLoopRunner(
            configuration: ChatDonorSwiftAIAgentConfiguration(maxToolIterations: 3, toolExecutionDelayNanoseconds: 0)
        )

        let result = try await runner.run(
            prompt: "summarize",
            model: { prompt, _ in
                return [.text("answer: \(prompt)")]
            },
            executeTools: { _ in
                XCTFail("No tools should execute")
                return []
            },
            sleep: { _ in }
        )

        guard case .completed(let outputs, let receipt) = result else {
            return XCTFail("Expected completed result")
        }
        XCTAssertEqual(ChatDonorSwiftAIAgentOutputBatch(outputs).allTexts, ["answer: summarize"])
        XCTAssertEqual(receipt.iterations, 1)
        XCTAssertEqual(receipt.termination, .completed)
        XCTAssertFalse(receipt.finalNoToolsCallMade)
    }

    func testSwiftAIAgentLoopStopsAtMaxIterationsAndMakesFinalNoToolsCall() async throws {
        let runner = ChatDonorSwiftAIAgentLoopRunner(
            configuration: ChatDonorSwiftAIAgentConfiguration(maxToolIterations: 2, toolExecutionDelayNanoseconds: 0)
        )
        let recorder = SwiftAIModelRecorder()

        let result = try await runner.run(
            prompt: "research",
            model: { prompt, allowTools in
                await recorder.record(prompt: prompt, allowTools: allowTools)
                if allowTools {
                    return [.text("need weather"), .functionCalls([#"{"name":"getWeather","args":{"city":"Sydney"}}"#])]
                }
                return [.text("final without tools")]
            },
            executeTools: { calls in
                [.text("tool result: \(calls.map(\.name).joined(separator: ","))")]
            },
            sleep: { _ in }
        )

        guard case .maxIterationsReached(let lastOutputs, let finalOutputs, let receipt) = result else {
            return XCTFail("Expected max-iterations result")
        }
        XCTAssertEqual(ChatDonorSwiftAIAgentOutputBatch(lastOutputs).allFunctionCalls.count, 1)
        XCTAssertEqual(ChatDonorSwiftAIAgentOutputBatch(finalOutputs).allTexts, ["final without tools"])
        XCTAssertEqual(receipt.iterations, 2)
        XCTAssertEqual(receipt.toolCallCounts, [1, 1])
        XCTAssertTrue(receipt.finalNoToolsCallMade)
        XCTAssertEqual(receipt.termination, .maxIterationsReached)
        XCTAssertTrue(receipt.finalPrompt.contains("<tool_execution_results>"))

        let allowToolFlags = await recorder.allowToolsFlags
        XCTAssertEqual(allowToolFlags, [true, true, false])
    }

    func testSwiftAIAgentWorkflowSequenceParallelAndConditional() async throws {
        let sequence = ChatDonorSwiftAIWorkflowStep.sequence([
            .single(agentID: "A"),
            .single(agentID: "B")
        ])
        let sequenced = try await sequence.run(prompt: "start") { agentID, prompt in
            [.text("\(agentID):\(prompt)")]
        }
        XCTAssertEqual(ChatDonorSwiftAIAgentOutputBatch(sequenced).allTexts, ["B:A:start"])

        let parallel = ChatDonorSwiftAIWorkflowStep.parallel([
            .single(agentID: "A"),
            .single(agentID: "B")
        ])
        let parallelResult = try await parallel.run(prompt: "start") { agentID, prompt in
            [.text("\(agentID):\(prompt)")]
        }
        let parallelTexts = ChatDonorSwiftAIAgentOutputBatch(parallelResult).allTexts.sorted()
        XCTAssertEqual(parallelTexts, ["A:start", "B:start"])

        let conditional = ChatDonorSwiftAIWorkflowStep.conditional(
            requiredText: "run",
            .single(agentID: "C")
        )
        let skipped = try await conditional.run(prompt: "skip") { _, _ in [.text("should not run")] }
        let executed = try await conditional.run(prompt: "please run") { agentID, prompt in
            [.text("\(agentID):\(prompt)")]
        }
        XCTAssertTrue(skipped.isEmpty)
        XCTAssertEqual(ChatDonorSwiftAIAgentOutputBatch(executed).allTexts, ["C:please run"])
    }

    func testSwiftAIAgentGoalPlanValidationAndWorkflowShape() throws {
        let empty = ChatDonorSwiftAIGoalPlan(name: "", details: "", subTasks: [])
        XCTAssertTrue(empty.validationFailures().contains(.emptyName))
        XCTAssertTrue(empty.validationFailures().contains(.emptyDetails))
        XCTAssertTrue(empty.validationFailures().contains(.noSubtasks))
        XCTAssertNil(empty.workflowStep())

        let plan = ChatDonorSwiftAIGoalPlan(
            name: "Build report",
            details: "Create a researched report",
            runSubTasksInParallel: true,
            subTasks: [
                .init(name: "Research", details: "Gather facts", tools: ["web_search"], temperature: 0.2),
                .init(name: "Draft", details: "Write the report", tools: ["write"], temperature: 2.5)
            ]
        )

        XCTAssertEqual(plan.validationFailures(), [.temperatureOutOfRange("Draft")])
        XCTAssertTrue(plan.agentSetup.contains("Collaborative execution with 2 specialized agents"))
        XCTAssertTrue(plan.agentSetup.contains("Execution mode: Parallel"))
        XCTAssertEqual(plan.workflowStep(), .parallel([.single(agentID: "Research"), .single(agentID: "Draft")]))
        XCTAssertEqual(
            plan.workflowStep(configuration: ChatDonorSwiftAIGoalConfiguration(enableParallelExecution: false)),
            .sequence([.single(agentID: "Research"), .single(agentID: "Draft")])
        )

        let receipt = ChatDonorSwiftAIGoalReceipt(
            goal: "Build report",
            states: [.idle, .clarifying, .planning, .executing, .completed],
            finalOutputCount: 2
        )
        let data = try JSONEncoder().encode(receipt)
        let decoded = try JSONDecoder().decode(ChatDonorSwiftAIGoalReceipt.self, from: data)
        XCTAssertEqual(decoded, receipt)
    }

    func testFoundationModelRuntimeStatusBuildsPickerOptions() {
        let onDeviceDisabled = ChatDonorFoundationModelRuntimeStatus(
            runtime: .onDevice,
            isAvailable: false,
            reason: .appleIntelligenceNotEnabled
        )
        let pccMissingEntitlement = ChatDonorFoundationModelRuntimeStatus(
            runtime: .privateCloudCompute,
            isAvailable: true,
            authorization: .missing
        )
        let pccRunnable = ChatDonorFoundationModelRuntimeStatus(
            runtime: .privateCloudCompute,
            isAvailable: true,
            authorization: .granted
        )

        let options = ChatDonorFoundationModelPickerOption.options(from: [
            onDeviceDisabled,
            pccMissingEntitlement,
            pccRunnable
        ])

        XCTAssertEqual(options.map(\.id), ["system", "pcc", "pcc"])
        XCTAssertFalse(options[0].isEnabled)
        XCTAssertTrue(options[0].settingsActionRecommended)
        XCTAssertTrue(options[0].subtitle.contains("Apple Intelligence is disabled"))
        XCTAssertFalse(options[1].isEnabled)
        XCTAssertEqual(pccMissingEntitlement.reason, .missingEntitlement)
        XCTAssertTrue(options[1].subtitle.contains("not runnable in this process"))
        XCTAssertTrue(options[2].isEnabled)
        XCTAssertEqual(options[2].subtitle, "PCC: available")
        XCTAssertTrue(options[2].requiresNewSessionOnSelection)
    }

    func testFoundationModelConfigurationNormalizationMatchesDonorMotifs() {
        let createdAt = Date(timeIntervalSinceReferenceDate: 100)
        let modifiedAt = Date(timeIntervalSinceReferenceDate: 50)
        let configuration = ChatDonorFoundationModelSessionConfiguration(
            name: "Local test",
            prompt: "Explain",
            runtime: .onDevice,
            reasoningLevel: .deep,
            generationOptions: ChatDonorFoundationModelGenerationOptions(
                sampling: .topK(0, seed: 7),
                temperature: 7,
                maximumResponseTokens: -1
            ),
            selectedToolIDs: [" weather ", "weather", "", "calendar"],
            createdAt: createdAt,
            modifiedAt: modifiedAt
        )

        XCTAssertEqual(configuration.reasoningLevel, .none)
        XCTAssertEqual(configuration.selectedToolIDs, ["weather", "calendar"])
        XCTAssertEqual(configuration.modifiedAt, createdAt)
        XCTAssertEqual(configuration.generationOptions.sampling, .topK(1, seed: 7))
        XCTAssertEqual(configuration.generationOptions.temperature, 2)
        XCTAssertNil(configuration.generationOptions.maximumResponseTokens)

        let pcc = ChatDonorFoundationModelSessionConfiguration(
            name: "PCC test",
            prompt: "Explain",
            runtime: .privateCloudCompute,
            reasoningLevel: .moderate,
            generationOptions: ChatDonorFoundationModelGenerationOptions(
                sampling: .topP(.infinity, seed: nil),
                temperature: -.infinity,
                maximumResponseTokens: 256
            )
        )

        XCTAssertEqual(pcc.reasoningLevel, .moderate)
        XCTAssertEqual(pcc.generationOptions.sampling, .topP(0.9, seed: nil))
        XCTAssertNil(pcc.generationOptions.temperature)
        XCTAssertEqual(pcc.generationOptions.maximumResponseTokens, 256)
    }

    func testFoundationModelGenerationOptionsPresentationAndCodable() throws {
        let topP = ChatDonorFoundationModelGenerationOptions(
            sampling: .topP(0.345, seed: 123),
            temperature: 0.2,
            maximumResponseTokens: 1024
        )

        XCTAssertEqual(topP.samplingDescription, "Top-P 0.35 - Seed 123")
        XCTAssertEqual(topP.temperatureDescription, "0.20")
        XCTAssertEqual(topP.maximumResponseTokensDescription, "1024")

        let defaults = ChatDonorFoundationModelGenerationOptions()
        XCTAssertEqual(defaults.samplingDescription, "System Default")
        XCTAssertEqual(defaults.temperatureDescription, "System Default")
        XCTAssertEqual(defaults.maximumResponseTokensDescription, "System Default")

        let data = try JSONEncoder().encode(topP)
        let decoded = try JSONDecoder().decode(ChatDonorFoundationModelGenerationOptions.self, from: data)
        XCTAssertEqual(decoded, topP)
    }

    func testFoundationModelStructuredRunRequestValidationAndSummaryRows() throws {
        let configuration = ChatDonorFoundationModelSessionConfiguration(
            name: "Structured recipe",
            prompt: "Return a JSON recipe",
            runtime: .privateCloudCompute,
            reasoningLevel: .light,
            generationOptions: ChatDonorFoundationModelGenerationOptions(
                sampling: .greedy,
                temperature: 0,
                maximumResponseTokens: 300
            )
        )
        let request = ChatDonorFoundationModelRunRequest(
            configuration: configuration,
            outputMode: .structured(schemaName: "Recipe", schemaSummary: "title and ingredients")
        )

        XCTAssertTrue(request.validationFailures.isEmpty)
        XCTAssertTrue(request.outputMode.isStructured)
        XCTAssertEqual(
            request.runSummaryRows.map(\.label),
            ["Runtime", "Model", "Reasoning", "Sampling", "Temperature", "Maximum response tokens", "Output"]
        )
        XCTAssertEqual(request.runSummaryRows.last?.value, "Structured: Recipe")

        let invalid = ChatDonorFoundationModelRunRequest(
            configuration: ChatDonorFoundationModelSessionConfiguration(name: "", prompt: " "),
            outputMode: .structured(schemaName: " ", schemaSummary: "")
        )
        XCTAssertEqual(invalid.validationFailures, [.emptyPrompt, .emptyStructuredSchemaName])

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(ChatDonorFoundationModelRunRequest.self, from: data)
        XCTAssertEqual(decoded, request)
    }

    func testAgentCloneVisibleOntologyChromePreservesReachableControls() throws {
        let contract = try XCTUnwrap(
            ChatDonorContractCatalog.swiftChat20260625.first {
                $0.id == "agent-clone.visible-ontology-chrome"
            }
        )

        XCTAssertEqual(contract.status, .adaptedWithTests)
        XCTAssertTrue(contract.destinationSeams.contains(.visibleShell))
        XCTAssertTrue(contract.destinationSeams.contains(.providerPicker))
        XCTAssertTrue(contract.destinationSeams.contains(.settingsSurface))
        XCTAssertTrue(contract.destinationSeams.contains(.sidePanel))
        XCTAssertTrue(contract.proof.visualReadbackRequired)

        let content = try sourceContents("LocalPackages/AgentClone/Sources/AgentClone/Views/ContentView/ContentView.swift")
        XCTAssertTrue(content.contains("EpistemosChatChromeBar("))
        XCTAssertTrue(content.contains("private struct EpistemosChatChromeBar"))
        XCTAssertTrue(content.contains("Text(\"Epistemos\")"))
        XCTAssertTrue(content.contains("viewModel.resolvedLLMConfig(for: selectedTab)"))
        XCTAssertTrue(content.contains("showSettings = true"))
        XCTAssertTrue(content.contains("showHistory = true"))
        XCTAssertTrue(content.contains("showNewTabSheet = true"))
        XCTAssertTrue(content.contains("showSearch.toggle()"))
        XCTAssertTrue(content.contains("showControlPanel.toggle()"))
        XCTAssertTrue(content.contains(".overlay(alignment: .leading)"))
        XCTAssertTrue(content.contains(".transition(.move(edge: .leading).combined(with: .opacity))"))
        XCTAssertTrue(content.contains(".frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)"))
        XCTAssertTrue(content.contains("sidebar.left"))
        XCTAssertFalse(content.contains("sidebar.right"))
        XCTAssertTrue(content.contains("plus.message"))
        XCTAssertTrue(content.contains("magnifyingglass"))
        XCTAssertTrue(content.contains("clock.arrow.circlepath"))
        XCTAssertTrue(content.contains("gearshape"))
        XCTAssertTrue(content.contains("Text(\"Context\")"))

        let services = try sourceContents("LocalPackages/AgentClone/Sources/AgentClone/Views/Header/ServicesPopover.swift")
        XCTAssertTrue(services.contains("Text(\"User Helper\")"))
        XCTAssertTrue(services.contains("Text(\"Privileged Helper\")"))
        XCTAssertFalse(services.contains("Text(\"Daemon Service\")"))

        let header = try sourceContents("LocalPackages/AgentClone/Sources/AgentClone/Views/Header/HeaderSectionView.swift")
        XCTAssertTrue(header.contains("Text(\"User\")"))
        XCTAssertTrue(header.contains("Text(\"Privileged\")"))
        XCTAssertTrue(header.contains(".help(\"User helper:"))
        XCTAssertTrue(header.contains(".help(\"Privileged helper:"))
        XCTAssertFalse(header.contains("Text(\"Daemon\")"))
        XCTAssertFalse(header.contains(".accessibilityLabel(\"Daemon\")"))

        let input = try sourceContents("LocalPackages/AgentClone/Sources/AgentClone/Views/Input/InputSectionView.swift")
        XCTAssertTrue(input.contains("modelSettingsButton"))
        XCTAssertTrue(input.contains("SettingsView(viewModel: viewModel)"))
        XCTAssertTrue(input.contains("compactToolsMenu"))
        XCTAssertTrue(input.contains("Label(\"Attach screenshot\", systemImage: \"camera\")"))
        XCTAssertTrue(input.contains("viewModel.pasteImageFromClipboard()"))
        XCTAssertTrue(input.contains("systemImage: viewModel.isListening ? \"mic.fill\" : \"mic\""))
        XCTAssertTrue(input.contains("systemImage: viewModel.isHotwordListening ? \"waveform.circle.fill\" : \"waveform.circle\""))

        let skin = try sourceContents("LocalPackages/AgentClone/Sources/AgentClone/EpistemosReskin.swift")
        XCTAssertTrue(skin.contains(".system(size: size, weight: weight, design: .monospaced)"))
        XCTAssertTrue(skin.contains(".system(size: size, weight: .semibold, design: .monospaced)"))
    }

    func testAgentCloneStartMessageBarOntologyRemovesDonorHints() throws {
        let contract = try XCTUnwrap(
            ChatDonorContractCatalog.swiftChat20260625.first {
                $0.id == "agent-clone.start-message-bar-ontology"
            }
        )

        XCTAssertEqual(contract.status, .adaptedWithTests)
        XCTAssertTrue(contract.destinationSeams.contains(.visibleShell))
        XCTAssertTrue(contract.destinationSeams.contains(.composer))
        XCTAssertTrue(contract.destinationSeams.contains(.providerPicker))
        XCTAssertTrue(contract.proof.visualReadbackRequired)

        let content = try sourceContents("LocalPackages/AgentClone/Sources/AgentClone/Views/ContentView/ContentView.swift")
        XCTAssertTrue(content.contains("private struct ChatStartSurface"))
        XCTAssertTrue(content.contains("Text(\"epistemos\")"))
        XCTAssertTrue(content.contains("InputSectionView("))
        XCTAssertTrue(content.contains(".frame(width: chatWidth)"))
        XCTAssertTrue(content.contains("!Self.hasConversationContent(activityText)"))
        XCTAssertTrue(content.contains("private static func hasConversationContent(_ activityText: String) -> Bool"))
        XCTAssertTrue(content.contains("private static func strippingActivityTimestamp(from line: String) -> String"))
        XCTAssertTrue(content.contains("private static func isBootstrapStatusLine(_ line: String) -> Bool"))
        XCTAssertTrue(content.contains("Advanced helpers unavailable — Epistemos runs in-process."))
        XCTAssertFalse(content.contains("Background agent: unavailable"))
        XCTAssertTrue(content.contains("line.hasPrefix(\"⚙️ Ollama:\") && line.hasSuffix(\"pre-warmed\")"))
        XCTAssertFalse(content.contains("Text(\"tab agents\")"))
        XCTAssertFalse(content.contains("Text(\"cmd+p commands\")"))
        XCTAssertFalse(content.contains("Text(\"esc stop\")"))
        XCTAssertFalse(content.contains("Text(\"Tip\")"))
        XCTAssertFalse(content.contains("Advanced controls live in the side panel."))
        XCTAssertFalse(content.contains(".tracking(1)"))

        let input = try sourceContents("LocalPackages/AgentClone/Sources/AgentClone/Views/Input/InputSectionView.swift")
        XCTAssertTrue(input.contains("private func placeholder(for tab: ScriptTab?) -> String"))
        XCTAssertTrue(input.contains("Message Epistemos..."))
        XCTAssertTrue(input.contains("Message recipient..."))
        XCTAssertTrue(input.contains("Message \\(tab.scriptName)..."))
        XCTAssertTrue(input.contains("TextField(placeholder(for: nil)"))
        XCTAssertTrue(input.contains("placeholder(for: tab)"))
        XCTAssertTrue(input.contains("modelSettingsButton"))
        XCTAssertTrue(input.contains("compactToolsMenu"))
        XCTAssertTrue(input.contains("SettingsView(viewModel: viewModel)"))
    }

    func testChatModeKeepsAgentCloneFoundationAndRejectsOldBackendRoute() throws {
        let contract = try XCTUnwrap(
            ChatDonorContractCatalog.swiftChat20260625.first {
                $0.id == "agent-clone.chatview2-route-ontology"
            }
        )

        XCTAssertEqual(contract.status, .adaptedWithTests)
        XCTAssertTrue(contract.sourcePaths.contains("Epistemos/App/RootView.swift"))
        XCTAssertTrue(contract.sourcePaths.contains("Epistemos/Views/AgentFusion/AgentCloneAppContextSnapshot.swift"))
        XCTAssertTrue(contract.sourcePaths.contains("Epistemos/Views/AgentFusion/AgentPortalContextSnapshot.swift"))
        XCTAssertTrue(contract.sourcePaths.contains("Epistemos/Views/AgentFusion/AgentPortalRouteRequest.swift"))
        XCTAssertTrue(contract.sourcePaths.contains("Epistemos/State/AgentChatState.swift"))
        XCTAssertTrue(contract.sourcePaths.contains("Epistemos/Views/Graph/GraphWorkspaceContainer.swift"))
        XCTAssertTrue(contract.sourcePaths.contains("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift"))
        XCTAssertTrue(contract.sourcePaths.contains("Epistemos/Views/AgentFusion/AgentCompactPortalView.swift"))
        XCTAssertTrue(contract.sourcePaths.contains("Epistemos/App/UtilityWindowManager.swift"))
        XCTAssertTrue(contract.sourcePaths.contains("Epistemos/App/EpistemosApp.swift"))
        XCTAssertTrue(contract.sourcePaths.contains("EpistemosTests/AgentCloneAppContextSnapshotTests.swift"))
        XCTAssertTrue(contract.sourcePaths.contains("Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift"))
        XCTAssertTrue(contract.sourcePaths.contains("LocalPackages/AgentClone/Sources/AgentClone/Views/ContentView/ContentView.swift"))
        XCTAssertTrue(contract.sourcePaths.contains("LocalPackages/AgentClone/Sources/AgentClone/Services/LLMProviderSetup.swift"))
        XCTAssertTrue(contract.sourcePaths.contains("LocalPackages/AgentClone/Sources/AgentClone/Models/ToolNames.swift"))
        XCTAssertTrue(contract.sourcePaths.contains("LocalPackages/AgentClone/Sources/AgentClone/MCP/MCPService.swift"))
        XCTAssertTrue(contract.destinationSeams.contains(.visibleShell))
        XCTAssertTrue(contract.destinationSeams.contains(.transcriptRenderer))
        XCTAssertTrue(contract.destinationSeams.contains(.composer))
        XCTAssertTrue(contract.destinationSeams.contains(.providerPicker))
        XCTAssertTrue(contract.destinationSeams.contains(.settingsSurface))
        XCTAssertTrue(contract.destinationSeams.contains(.sidePanel))
        XCTAssertTrue(contract.destinationSeams.contains(.modelUX))
        XCTAssertTrue(contract.destinationSeams.contains(.recentsBridge))
        XCTAssertTrue(contract.destinationSeams.contains(.toolRegistry))
        XCTAssertTrue(contract.destinationSeams.contains(.mcpBridge))
        XCTAssertFalse(contract.proof.visualReadbackRequired)
        XCTAssertFalse(contract.proof.endpointProofRequired)

        let root = try sourceContents("Epistemos/App/RootView.swift")
        let snapshot = try sourceContents("Epistemos/Views/AgentFusion/AgentCloneAppContextSnapshot.swift")
        let portal = try sourceContents("Epistemos/Views/AgentFusion/AgentPortalContextSnapshot.swift")
        let routeRequest = try sourceContents("Epistemos/Views/AgentFusion/AgentPortalRouteRequest.swift")
        let agentChatState = try sourceContents("Epistemos/State/AgentChatState.swift")
        let host = try sourceContents("Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift")
        let compactPortal = try sourceContents("Epistemos/Views/AgentFusion/AgentCompactPortalView.swift")
        let utilityWindows = try sourceContents("Epistemos/App/UtilityWindowManager.swift")
        let appCommands = try sourceContents("Epistemos/App/EpistemosApp.swift")
        let graphWorkspace = try sourceContents("Epistemos/Views/Graph/GraphWorkspaceContainer.swift")
        let noteWorkspace = try sourceContents("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let chatTypes = try sourceContents("Epistemos/Models/ChatTypes.swift")
        let currentAccessPlan = try sourceContents("Epistemos/Views/Chat/ComposerCurrentAccessPlan.swift")
        XCTAssertTrue(root.contains("@State private var workspaceMode: WorkspaceModeKind = WorkspaceModeSelection.current()"))
        XCTAssertTrue(root.contains("@ViewBuilder private var chatModeSurface: some View"))
        XCTAssertTrue(root.contains("AgentCloneChatHostSurface("))
        XCTAssertTrue(root.contains("private var agentCloneContextSnapshot: AgentCloneAppContextSnapshot"))
        XCTAssertTrue(root.contains("context: agentCloneContextSnapshot"))
        XCTAssertTrue(root.contains("let _ = AgentClone.AgentSkin.configure("))
        XCTAssertTrue(snapshot.contains("struct AgentCloneAppContextSnapshot: Codable, Equatable, Sendable"))
        XCTAssertTrue(snapshot.contains(#"Self.normalized(appName) ?? "Epistemos""#))
        XCTAssertTrue(snapshot.contains(#"Self.normalized(modeLabel) ?? "Act""#))
        XCTAssertTrue(snapshot.contains("var workspacePath: String?"))
        XCTAssertTrue(snapshot.contains("var appSupportPath: String?"))
        XCTAssertTrue(snapshot.contains("var portalContext: AgentPortalContextSnapshot"))
        XCTAssertTrue(snapshot.contains("var bridgePresentation: String"))
        XCTAssertTrue(snapshot.contains("var modelVisibleSummary: String"))
        XCTAssertTrue(snapshot.contains("var modelVisibleJSON: String"))
        XCTAssertTrue(snapshot.contains("private struct ModelVisiblePayload: Codable, Equatable, Sendable"))
        XCTAssertTrue(snapshot.contains("encoder.outputFormatting = [.sortedKeys]"))
        XCTAssertFalse(snapshot.contains("appSupportPath: appSupportPath"))
        XCTAssertTrue(portal.contains("struct AgentPortalContextSnapshot: Codable, Equatable, Sendable"))
        XCTAssertTrue(portal.contains("case landing"))
        XCTAssertTrue(portal.contains("case mini"))
        XCTAssertTrue(portal.contains("case note"))
        XCTAssertTrue(portal.contains("case graph"))
        XCTAssertTrue(portal.contains("static func mini("))
        XCTAssertTrue(portal.contains("static func note("))
        XCTAssertTrue(portal.contains("static func graph("))
        XCTAssertTrue(portal.contains("selectedText: String? = nil"))
        XCTAssertTrue(portal.contains("selectedNodeIds: [String] = []"))
        XCTAssertTrue(portal.contains("selectedEdgeIds: [String] = []"))
        XCTAssertTrue(portal.contains("neighborhoodSummary: String? = nil"))
        XCTAssertTrue(portal.contains("struct ActionDescriptor: Codable, Equatable, Sendable"))
        XCTAssertTrue(portal.contains("var additionalContextAttachments: [ContextAttachment]"))
        XCTAssertTrue(portal.contains("func withAdditionalContextAttachments(_ attachments: [ContextAttachment])"))
        XCTAssertTrue(portal.contains("var contextAttachments: [ContextAttachment]"))
        XCTAssertTrue(portal.contains("var actionDescriptors: [ActionDescriptor]"))
        XCTAssertTrue(portal.contains("func agentClonePromptEnvelope("))
        XCTAssertTrue(portal.contains("Use this Epistemos portal context. Preserve the user's request as the task"))
        XCTAssertTrue(portal.contains("private func agentClonePromptContextLines(capabilityLines: [String]) -> [String]"))
        XCTAssertTrue(portal.contains("private static let actionCatalog: [ActionDescriptor]"))
        XCTAssertTrue(portal.contains("lines.append(\"approved actions: \\(descriptors.map(\\.id).prefix(8).joined(separator: \",\"))\")"))
        XCTAssertTrue(portal.contains("action \\(descriptor.id):"))
        XCTAssertTrue(portal.contains("id: \"app-context.snapshot\""))
        XCTAssertTrue(portal.contains("id: \"vault.search\""))
        XCTAssertTrue(portal.contains("id: \"note.create\""))
        XCTAssertTrue(portal.contains("id: \"note.update\""))
        XCTAssertTrue(portal.contains("id: \"note.delete.with-approval\""))
        XCTAssertTrue(portal.contains("id: \"selected-text.rewrite.with-approval\""))
        XCTAssertTrue(portal.contains("id: \"graph.mutate.with-approval\""))
        XCTAssertTrue(portal.contains("resourceURI: \"epistemos://note/delete\""))
        XCTAssertTrue(portal.contains("resourceURI: \"epistemos://graph/mutate\""))
        XCTAssertTrue(portal.contains("requiresApproval: true"))
        XCTAssertTrue(portal.contains("mutatesAppState: true"))
        XCTAssertTrue(portal.contains("kind: .graph"))
        XCTAssertTrue(portal.contains("resourceURI: \"epistemos://graph/context\""))
        XCTAssertTrue(portal.contains("\"graph.mutate.with-approval\""))
        XCTAssertTrue(portal.contains("parts.append(\"selectedText: \\(selectedText)\")"))
        XCTAssertTrue(portal.contains("parts.append(\"graphNodes: \\(graph.selectedNodeIds.joined(separator: \",\"))\")"))
        XCTAssertTrue(portal.contains("for attachment in additionalContextAttachments where !attachments.contains(where: { $0.id == attachment.id })"))
        XCTAssertTrue(routeRequest.contains("enum AgentPortalRouteRequest"))
        XCTAssertTrue(routeRequest.contains("static let portalContextUserInfoKey"))
        XCTAssertTrue(routeRequest.contains("static func post(_ portalContext: AgentPortalContextSnapshot)"))
        XCTAssertTrue(routeRequest.contains("name: .openAgentPortal"))
        XCTAssertTrue(routeRequest.contains("static let openAgentPortal"))
        XCTAssertTrue(root.contains(".onReceive(NotificationCenter.default.publisher(for: .openAgentPortal))"))
        XCTAssertTrue(root.contains("AgentPortalRouteRequest.portalContext(from: notification)"))
        XCTAssertTrue(root.contains("WorkspaceModeSelection.select(.act)"))
        XCTAssertTrue(root.contains("agentChat.startNewSession(portalContext: portalContext)"))
        XCTAssertTrue(agentChatState.contains("struct AgentPortalSessionSummary: Identifiable, Codable, Equatable, Sendable"))
        XCTAssertTrue(agentChatState.contains("var recentPortalSessions: [AgentPortalSessionSummary] = []"))
        XCTAssertTrue(agentChatState.contains("private static let maxRecentPortalSessions = 12"))
        XCTAssertTrue(agentChatState.contains("recordActivePortalSession(promptPreview: query)"))
        XCTAssertTrue(agentChatState.contains("recordActivePortalSession()"))
        XCTAssertTrue(agentChatState.contains("func activatePortalSession(_ summary: AgentPortalSessionSummary)"))
        XCTAssertTrue(agentChatState.contains("promoteRecentPortalSession(_ summary: AgentPortalSessionSummary)"))
        XCTAssertTrue(agentChatState.contains("This intentionally does not fake transcript persistence"))
        XCTAssertTrue(agentChatState.contains("activePortalContext = portalContext"))
        XCTAssertTrue(compactPortal.contains("struct AgentCompactPortalView: View"))
        XCTAssertTrue(compactPortal.contains("AgentPortalContextSnapshot.mini("))
        XCTAssertTrue(compactPortal.contains("vaultRootPath: vaultSync.vaultURL?.path"))
        XCTAssertTrue(compactPortal.contains("workspacePath: FileManager.default.homeDirectoryForCurrentUser.path"))
        XCTAssertTrue(compactPortal.contains("agentChat.startNewSession(portalContext: portalContext)"))
        XCTAssertTrue(compactPortal.contains("agentChat.submitAgentQuery(trimmed, portalContext: portalContext)"))
        XCTAssertTrue(compactPortal.contains("activateRecentPortalSession(_ summary: AgentPortalSessionSummary)"))
        XCTAssertTrue(compactPortal.contains("agentChat.activatePortalSession(summary)"))
        XCTAssertTrue(compactPortal.contains("AgentCloneBridge.updateHostContext("))
        XCTAssertTrue(compactPortal.contains("workspaceRootPath: FileManager.default.homeDirectoryForCurrentUser.path"))
        XCTAssertTrue(compactPortal.contains("AgentCloneBridge.submitPrompt(portalContext.agentClonePromptEnvelope(userPrompt: trimmed))"))
        XCTAssertTrue(compactPortal.contains("AgentPortalRouteRequest.post(portalContext)"))
        XCTAssertTrue(compactPortal.contains("agentChat.recentPortalSessions.prefix(4)"))
        XCTAssertTrue(compactPortal.contains("recentDetail(_ summary: AgentPortalSessionSummary)"))
        XCTAssertTrue(compactPortal.contains("compactContextBar"))
        XCTAssertTrue(compactPortal.contains("compactActionChips"))
        XCTAssertTrue(compactPortal.contains("compactResolvedPortalContext"))
        XCTAssertTrue(compactPortal.contains("compactSubmissionPortalContext"))
        XCTAssertTrue(compactPortal.contains("portalContext.promptPreview = promptText"))
        XCTAssertTrue(compactPortal.contains("compactAppContextSnapshotText"))
        XCTAssertTrue(compactPortal.contains("appendCompactAppContextSnapshotIntent()"))
        XCTAssertTrue(compactPortal.contains("compactActionDescriptors"))
        XCTAssertTrue(compactPortal.contains("ForEach(compactActionDescriptors, id: \\.id)"))
        XCTAssertTrue(compactPortal.contains("appendCompactActionIntent(_ action: AgentPortalContextSnapshot.ActionDescriptor)"))
        XCTAssertTrue(compactPortal.contains("compactActionHelp(_ action: AgentPortalContextSnapshot.ActionDescriptor)"))
        XCTAssertTrue(compactPortal.contains("compactActionSystemImage(_ action: AgentPortalContextSnapshot.ActionDescriptor)"))
        XCTAssertTrue(compactPortal.contains("Use this Epistemos compact portal context:"))
        XCTAssertTrue(compactPortal.contains("approved actions: \\(compactApprovedActionChips.joined(separator: \",\"))"))
        XCTAssertFalse(compactPortal.contains("MiniChat"))
        XCTAssertFalse(compactPortal.contains("ChatCoordinator"))
        XCTAssertTrue(utilityWindows.contains("case agent"))
        XCTAssertTrue(utilityWindows.contains("AgentCompactPortalView()"))
        XCTAssertFalse(utilityWindows.contains("MiniChatWindowController"))
        XCTAssertTrue(appCommands.contains("UtilityWindowManager.shared.show(.agent)"))
        XCTAssertTrue(graphWorkspace.contains("graphAgentPortalButton"))
        XCTAssertTrue(graphWorkspace.contains("openGraphAgentPortal()"))
        XCTAssertTrue(graphWorkspace.contains("AgentPortalContextSnapshot.graph("))
        XCTAssertTrue(graphWorkspace.contains("vaultRootPath: vaultSync.vaultURL?.path"))
        XCTAssertTrue(graphWorkspace.contains("workspacePath: FileManager.default.homeDirectoryForCurrentUser.path"))
        XCTAssertTrue(graphWorkspace.contains("selectedNodeIds: graphPortalSelectedNodeIds"))
        XCTAssertTrue(graphWorkspace.contains("selectedEdgeIds: graphPortalSelectedEdgeIds"))
        XCTAssertTrue(graphWorkspace.contains("neighborhoodSummary: graphPortalNeighborhoodSummary"))
        XCTAssertTrue(noteWorkspace.contains("case agentPortal"))
        XCTAssertTrue(noteWorkspace.contains("\"Open in Agent\""))
        XCTAssertTrue(noteWorkspace.contains("openNoteAgentPortal()"))
        XCTAssertTrue(noteWorkspace.contains("AgentPortalContextSnapshot.note("))
        XCTAssertTrue(noteWorkspace.contains("vaultRootPath: vaultSync.vaultURL?.path"))
        XCTAssertTrue(noteWorkspace.contains("workspacePath: FileManager.default.homeDirectoryForCurrentUser.path"))
        XCTAssertTrue(noteWorkspace.contains("selectedText: currentEditorSelectedText()"))
        XCTAssertTrue(noteWorkspace.contains("AgentPortalRouteRequest.post(portalContext)"))
        XCTAssertFalse(graphWorkspace.contains("GraphChatRequest"))
        XCTAssertFalse(noteWorkspace.contains("NoteChatState"))
        XCTAssertFalse(noteWorkspace.contains("NoteChatSidebar"))
        XCTAssertTrue(chatTypes.contains("case graph"))
        XCTAssertTrue(chatTypes.contains("case .graph: \"point.3.connected.trianglepath.dotted\""))
        XCTAssertTrue(currentAccessPlan.contains("case .graph:"))
        XCTAssertTrue(currentAccessPlan.contains("Read selected graph context"))
        XCTAssertFalse(portal.contains("ChatCoordinator"))
        XCTAssertTrue(host.contains("AgentClone.ContentView()"))
        XCTAssertTrue(host.contains("let context: AgentCloneAppContextSnapshot"))
        XCTAssertTrue(host.contains("sessionRail"))
        XCTAssertTrue(host.contains("contextRail"))
        XCTAssertTrue(host.contains("context.appName"))
        XCTAssertTrue(host.contains("context.modeLabel"))
        XCTAssertTrue(host.contains("context.presentation"))
        XCTAssertTrue(host.contains("context.portalContext"))
        XCTAssertTrue(host.contains("context.modelVisibleSummary"))
        XCTAssertTrue(host.contains("@Environment(AgentChatState.self) private var agentChat"))
        XCTAssertTrue(host.contains("agentChat.recentPortalSessions.prefix(6)"))
        XCTAssertTrue(host.contains("recentPortalSessionDetail(_ summary: AgentPortalSessionSummary)"))
        XCTAssertTrue(host.contains("recentPortalSessionMeta(_ summary: AgentPortalSessionSummary)"))
        XCTAssertTrue(host.contains("recentPortalMessageCountLabel(_ count: Int)"))
        XCTAssertTrue(host.contains("@Environment(InferenceState.self) private var inference"))
        XCTAssertTrue(host.contains("@Environment(AgentCommandCenterState.self) private var agentCommandCenter"))
        XCTAssertTrue(host.contains("@Environment(ChatApprovalQueue.self) private var chatApprovalQueue"))
        XCTAssertTrue(host.contains("@Environment(VaultSyncService.self) private var vaultSync"))
        XCTAssertTrue(host.contains("@Environment(\\.modelContext) private var modelContext"))
        XCTAssertTrue(host.contains("@Environment(\\.openSettings) private var openSettings"))
        XCTAssertTrue(host.contains("@AppStorage(MainChatOperatingModePreference.defaultsKey)"))
        XCTAssertTrue(host.contains("static let toolbarMinHeight: CGFloat = 50"))
        XCTAssertTrue(host.contains("AgentFusionRailRow(title: \"Current\", detail: bridgeAgentStatusLabel, systemImage: bridgeAgentStatusSymbol)"))
        XCTAssertTrue(host.contains("AgentFusionRailRow(title: \"Runtime\", detail: \"native agent\""))
        XCTAssertTrue(host.contains("AgentFusionRailRow(title: \"Source\", detail: \"App context\""))
        XCTAssertTrue(host.contains("railSectionTitle(\"Portal Context\")"))
        XCTAssertTrue(host.contains("private var bridgeResolvedPortalContext: AgentPortalContextSnapshot"))
        XCTAssertTrue(host.contains("private var shouldShowBridgePortalContextSection: Bool"))
        XCTAssertTrue(host.contains("private var bridgePortalContextSummary: String"))
        XCTAssertTrue(host.contains("private func bridgeNoteContextSummary(_ note: AgentPortalContextSnapshot.NoteContext) -> String"))
        XCTAssertTrue(host.contains("private func bridgeNoteSelectionSummary(_ note: AgentPortalContextSnapshot.NoteContext) -> String"))
        XCTAssertTrue(host.contains("private func bridgeGraphContextSummary(_ graph: AgentPortalContextSnapshot.GraphContext) -> String"))
        XCTAssertTrue(host.contains("private func bridgeGraphNeighborhoodSummary(_ graph: AgentPortalContextSnapshot.GraphContext) -> String"))
        XCTAssertTrue(host.contains("private var bridgeAdditionalAttachmentSummary: String"))
        XCTAssertTrue(host.contains("AgentFusionRailRow(title: \"Note\", detail: bridgeNoteContextSummary(note)"))
        XCTAssertTrue(host.contains("AgentFusionRailRow(title: \"Selection\", detail: bridgeNoteSelectionSummary(note)"))
        XCTAssertTrue(host.contains("AgentFusionRailRow(title: \"Graph\", detail: bridgeGraphContextSummary(graph)"))
        XCTAssertTrue(host.contains("AgentFusionRailRow(title: \"Neighborhood\", detail: bridgeGraphNeighborhoodSummary(graph)"))
        XCTAssertTrue(host.contains("AgentFusionRailRow(title: \"Attached\", detail: bridgeAdditionalAttachmentSummary"))
        XCTAssertTrue(host.contains("private func clippedInline(_ value: String, limit: Int) -> String"))
        XCTAssertTrue(host.contains("railSectionTitle(\"Capabilities\")"))
        XCTAssertTrue(host.contains("AgentFusionRailRow(title: \"Tools\", detail: bridgeToolCapabilitySummary"))
        XCTAssertTrue(host.contains("AgentFusionRailRow(title: \"Skills\", detail: bridgeSkillCapabilitySummary"))
        XCTAssertTrue(host.contains("AgentFusionRailRow(title: \"Commands\", detail: bridgeCommandCapabilitySummary"))
        XCTAssertTrue(host.contains("AgentFusionRailRow(title: \"MCP\", detail: bridgeMCPCapabilitySummary"))
        XCTAssertTrue(host.contains("private var bridgeToolCapabilitySummary: String"))
        XCTAssertTrue(host.contains("private var bridgeSkillCapabilitySummary: String"))
        XCTAssertTrue(host.contains("private var bridgeCommandCapabilitySummary: String"))
        XCTAssertTrue(host.contains("private var bridgeMCPCapabilitySummary: String"))
        XCTAssertTrue(host.contains(".background(theme.chatSurface.opacity(0.94))"))
        XCTAssertFalse(host.contains("Swift agent foundation"))
        XCTAssertFalse(host.contains("Swift agent fusion"))
        XCTAssertFalse(host.contains("Epistemos bridge"))
        XCTAssertFalse(host.contains("AgentClone foundation"))
        XCTAssertFalse(host.contains("AgentClone bridge"))
        XCTAssertFalse(host.contains("Backend\", detail:"))
        XCTAssertFalse(host.contains("AgentClone foundation"))
        XCTAssertFalse(host.contains("AgentClone bridge"))
        XCTAssertTrue(host.contains("@State private var showSessionRail = false"))
        XCTAssertTrue(host.contains("@State private var showContextRail = false"))
        XCTAssertTrue(host.contains("@State private var showCompactSessionRail = false"))
        XCTAssertTrue(host.contains("@State private var showCompactContextRail = false"))
        XCTAssertTrue(host.contains("@State private var showBridgeRuntimePicker = false"))
        XCTAssertTrue(host.contains("@State private var showBridgeSlashMenu = false"))
        XCTAssertTrue(host.contains("@State private var bridgeSlashFilter = \"\""))
        XCTAssertTrue(host.contains("@State private var selectedBridgeSlashItem: ComposerSlashCommandItem?"))
        XCTAssertTrue(host.contains("@State private var showBridgeMentionDropdown = false"))
        XCTAssertTrue(host.contains("@State private var bridgeMentionFilter = \"\""))
        XCTAssertTrue(host.contains("@State private var bridgeReferenceSearch = ComposerReferenceSearchState()"))
        XCTAssertTrue(host.contains("@State private var bridgeContextAttachments: [ContextAttachment] = []"))
        XCTAssertTrue(host.contains("@State private var bridgePromptText = \"\""))
        XCTAssertTrue(host.contains("@State private var mirroredAgentCloneMessages: [AgentCloneMirroredMessage] = []"))
        XCTAssertTrue(host.contains("@State private var mirrorTask: Task<Void, Never>?"))
        XCTAssertTrue(host.contains("private enum AgentFusionChatLayout"))
        XCTAssertTrue(host.contains("static let toolbarMinHeight: CGFloat = 50"))
        XCTAssertTrue(host.contains("static let messageColumnMaxWidth: CGFloat = 760"))
        XCTAssertTrue(host.contains("static let composerMaxWidth: CGFloat = 860"))
        XCTAssertTrue(host.contains("static let transcriptSpacing: CGFloat = 28"))
        XCTAssertTrue(host.contains("static let userBubbleLeadingReserve: CGFloat = 200"))
        XCTAssertTrue(host.contains("chatHostToolbar(compact: compact)"))
        XCTAssertTrue(host.contains("agentCloneFoundationMount"))
        XCTAssertTrue(host.contains("bridgeConversationCanvas(compact: compact)"))
        XCTAssertTrue(host.contains(".opacity(0.001)"))
        XCTAssertTrue(host.contains(".allowsHitTesting(false)"))
        XCTAssertTrue(host.contains(".accessibilityHidden(true)"))
        XCTAssertTrue(host.contains("private func chatHostToolbar(compact: Bool) -> some View"))
        XCTAssertTrue(host.contains("Text(bridgeAgentStatusLabel)"))
        XCTAssertTrue(host.contains("private var bridgeAgentStatusLabel: String"))
        XCTAssertTrue(host.contains("private var bridgeAgentStatusSymbol: String"))
        XCTAssertTrue(host.contains("if bridgePendingApproval != nil"))
        XCTAssertTrue(host.contains("return \"approval\""))
        XCTAssertTrue(host.contains("return \"running\""))
        XCTAssertTrue(host.contains("return \"thinking\""))
        XCTAssertTrue(host.contains("return \"live\""))
        XCTAssertTrue(host.contains("return \"session ready\""))
        XCTAssertTrue(host.contains("AgentFusionRailRow(title: \"Current\", detail: bridgeAgentStatusLabel, systemImage: bridgeAgentStatusSymbol)"))
        XCTAssertTrue(host.contains("sessionControlButton(compact: compact)"))
        XCTAssertTrue(host.contains("modelContextButton(compact: compact)"))
        XCTAssertTrue(host.contains("Text(\"session\")"))
        XCTAssertTrue(host.contains("Text(\"model\")"))
        XCTAssertTrue(host.contains("Image(systemName: \"arrow.up.right\")"))
        XCTAssertTrue(host.contains(".help(\"Model picker\")"))
        XCTAssertTrue(host.contains("showBridgeRuntimePicker.toggle()"))
        XCTAssertTrue(host.contains("railControlButtons(compact: compact)"))
        XCTAssertTrue(host.contains("toggleSessionRail(compact: compact)"))
        XCTAssertTrue(host.contains("toggleContextRail(compact: compact)"))
        XCTAssertTrue(host.contains("shouldShowBridgeEmptyLandingMark"))
        XCTAssertTrue(host.contains("bridgeEmptyLandingMark(compact: compact)"))
        XCTAssertTrue(host.contains("private func bridgeEmptyLandingMark(compact: Bool) -> some View"))
        XCTAssertTrue(host.contains("private var bridgeActiveRecentPortalSession: AgentPortalSessionSummary?"))
        XCTAssertTrue(host.contains("private var shouldShowBridgeSessionResumeMark: Bool"))
        XCTAssertTrue(host.contains("private func bridgeSessionResumeMark("))
        XCTAssertTrue(host.contains("if let summary = bridgeActiveRecentPortalSession"))
        XCTAssertTrue(host.contains("shouldShowBridgeSessionResumeMark"))
        XCTAssertTrue(host.contains("bridgeSessionResumeMark(summary, compact: compact)"))
        XCTAssertTrue(host.contains("let contextLine = recentPortalSessionContextLine(summary, compact: compact)"))
        XCTAssertTrue(host.contains("MotionTitle("))
        XCTAssertTrue(host.contains("text: context.appName"))
        XCTAssertTrue(host.contains("text: \"Session ready\""))
        XCTAssertTrue(host.contains("Label(\"Continue\", systemImage: \"arrow.turn.down.left\")"))
        XCTAssertTrue(host.contains("bridgePromptFocused = true"))
        XCTAssertTrue(host.contains("Label(\"Context\", systemImage: \"sidebar.right\")"))
        XCTAssertTrue(host.contains("toggleContextRail(compact: compact)"))
        XCTAssertTrue(host.contains("summary.messageCount > 0 || summary.promptPreview != nil"))
        XCTAssertTrue(host.contains("Text(context.appName)"))
        XCTAssertTrue(host.contains("private var bridgeEmptyLandingSubtitle: String"))
        XCTAssertTrue(host.contains("!agentChat.hasMessages"))
        XCTAssertTrue(host.contains("!agentChat.isStreaming"))
        XCTAssertTrue(host.contains("!agentChat.isAgentExecuting"))
        XCTAssertTrue(host.contains("bridgeComposerDock(compact: compact)"))
        XCTAssertTrue(host.contains("bridgeTranscriptRunway(compact: compact)"))
        XCTAssertTrue(host.contains("private func activateRecentPortalSession(_ summary: AgentPortalSessionSummary)"))
        XCTAssertTrue(host.contains("agentChat.activatePortalSession(summary)"))
        XCTAssertTrue(host.contains("AgentFusionRecentSessionRow("))
        XCTAssertTrue(host.contains("meta: recentPortalSessionMeta(summary)"))
        XCTAssertTrue(host.contains("isActive: summary.id == agentChat.activeSessionId"))
        XCTAssertTrue(host.contains("private func recentPortalSessionContextLine("))
        XCTAssertTrue(host.contains("let portalContext = summary.portalContext"))
        XCTAssertTrue(host.contains("if let note = portalContext.note"))
        XCTAssertTrue(host.contains("if let graph = portalContext.graph"))
        XCTAssertTrue(host.contains("portalContext.additionalContextAttachments"))
        XCTAssertTrue(host.contains("portalContext.approvedActions"))
        XCTAssertTrue(host.contains("private struct AgentFusionRecentSessionRow: View"))
        XCTAssertTrue(host.contains("Text(\"active\")"))
        XCTAssertTrue(host.contains("count == 1 ? \"1 message\" : \"\\(count) messages\""))
        XCTAssertTrue(host.contains(".help(\"Activate portal context\")"))
        XCTAssertTrue(host.contains("private func bridgeComposerDock(compact: Bool) -> some View"))
        XCTAssertTrue(host.contains("private func bridgeTranscriptRunway(compact: Bool) -> some View"))
        XCTAssertTrue(host.contains("LazyVStack(alignment: .leading, spacing: AgentFusionChatLayout.transcriptSpacing)"))
        XCTAssertTrue(host.contains(".frame(maxWidth: compact ? .infinity : AgentFusionChatLayout.messageColumnMaxWidth)"))
        XCTAssertTrue(host.contains(".frame(maxWidth: compact ? .infinity : AgentFusionChatLayout.composerMaxWidth)"))
        XCTAssertTrue(host.contains("bridgeComposerContextBar"))
        XCTAssertTrue(host.contains("private var bridgeComposerContextBar: some View"))
        XCTAssertTrue(host.contains("Text(\"Read + Search vault\")"))
        XCTAssertTrue(host.contains(".padding(.top, AgentFusionChatLayout.composerControlRowTopPadding)"))
        XCTAssertTrue(host.contains("InlineRuntimePickerPanel("))
        XCTAssertTrue(host.contains("operatingMode: bridgeOperatingModeBinding"))
        XCTAssertTrue(host.contains("onOpenSettings: { openSettings() }"))
        XCTAssertTrue(host.contains("ComposerMicButton { transcript in"))
        XCTAssertTrue(host.contains("appendBridgeVoiceTranscript(transcript)"))
        XCTAssertTrue(host.contains("private var bridgeSelectedOperatingMode: EpistemosOperatingMode"))
        XCTAssertTrue(host.contains("MainChatOperatingModePreference.sanitize("))
        XCTAssertTrue(host.contains("private var bridgeOperatingModeBinding: Binding<EpistemosOperatingMode>"))
        XCTAssertTrue(host.contains("private var bridgeRuntimeTierLabel: String"))
        XCTAssertTrue(host.contains("SlashCommandPopover("))
        XCTAssertTrue(host.contains("items: supportedBridgeSlashItems"))
        XCTAssertTrue(host.contains("applyBridgeSlashItem"))
        XCTAssertTrue(host.contains("ComposerReferencePopover("))
        XCTAssertTrue(host.contains("attachBridgeMentionReference"))
        XCTAssertTrue(host.contains("bridgeContextAttachmentChips"))
        XCTAssertTrue(host.contains("ComposerReferenceHelpers.contextAttachment("))
        XCTAssertTrue(host.contains("ComposerReferenceHelpers.allNotesAttachment"))
        XCTAssertTrue(host.contains("bridgePortalActionChips"))
        XCTAssertTrue(host.contains("private var bridgePortalActionChips: some View"))
        XCTAssertTrue(host.contains("railSectionTitle(\"Portal Actions\")"))
        XCTAssertTrue(host.contains("ForEach(bridgeActionDescriptors, id: \\.id)"))
        XCTAssertTrue(host.contains("bridgeActionDescriptorDetail(action)"))
        XCTAssertTrue(host.contains("private var bridgeActionDescriptors: [AgentPortalContextSnapshot.ActionDescriptor]"))
        XCTAssertTrue(host.contains("private var bridgeApprovedActionChips: [String]"))
        XCTAssertTrue(host.contains("appendBridgeActionIntent(action)"))
        XCTAssertTrue(host.contains("private func appendBridgeActionIntent(_ action: AgentPortalContextSnapshot.ActionDescriptor)"))
        XCTAssertTrue(host.contains("Request native approval before changing app state."))
        XCTAssertTrue(host.contains("private func bridgeActionHelp(_ action: AgentPortalContextSnapshot.ActionDescriptor) -> String"))
        XCTAssertTrue(host.contains("private func bridgeActionChipFill(_ action: AgentPortalContextSnapshot.ActionDescriptor) -> Color"))
        XCTAssertTrue(host.contains("private func bridgeActionSystemImage(_ action: AgentPortalContextSnapshot.ActionDescriptor) -> String"))
        XCTAssertTrue(host.contains("private var bridgePortalContext: AgentPortalContextSnapshot"))
        XCTAssertTrue(host.contains("bridgeResolvedPortalContext.withAdditionalContextAttachments(bridgeContextAttachments)"))
        XCTAssertTrue(host.contains("portalContext.promptPreview = bridgePromptText"))
        XCTAssertTrue(host.contains("portalContext = portalContext.withSessionId(sessionId)"))
        XCTAssertTrue(host.contains("TextField(\"Ask anything... Type @ for notes or chats\", text: $bridgePromptText, axis: .vertical)"))
        XCTAssertTrue(host.contains("Button(action: submitBridgePromptFromDock)"))
        XCTAssertTrue(host.contains("let portalContext = bridgePortalContext"))
        XCTAssertTrue(host.contains("agentChat.submitAgentQuery(trimmed, portalContext: portalContext)"))
        XCTAssertTrue(host.contains("syncBridgeHostContext(portalContext: agentChat.activePortalContext ?? portalContext)"))
        XCTAssertTrue(host.contains("bridgeAgentClonePromptCapabilityLines"))
        XCTAssertTrue(host.contains("AgentCloneBridge.submitPrompt(portalContext.agentClonePromptEnvelope("))
        XCTAssertTrue(host.contains("capabilityLines: bridgeAgentClonePromptCapabilityLines"))
        XCTAssertTrue(host.contains("private func syncBridgeHostContext(portalContext: AgentPortalContextSnapshot? = nil)"))
        XCTAssertTrue(host.contains("presentation: portalContext?.bridgePresentation"))
        XCTAssertTrue(host.contains("AgentCloneBridge.updateHostContext(AgentCloneHostContext("))
        XCTAssertTrue(host.contains("Array(agentChat.messages.suffix(4))"))
        XCTAssertTrue(host.contains("agentChat.streamingText"))
        XCTAssertTrue(host.contains("message.effectiveText"))
        XCTAssertTrue(host.contains("bridgeUserTranscriptRow(message)"))
        XCTAssertTrue(host.contains("bridgeAssistantTranscriptRow(message)"))
        XCTAssertTrue(host.contains("bridgeErrorTranscriptRow(message)"))
        XCTAssertTrue(host.contains("let failedToolResults = bridgeFailedToolResults(from: message.contentBlocks)"))
        XCTAssertTrue(host.contains("ForEach(failedToolResults) { failure in"))
        XCTAssertTrue(host.contains("bridgeToolFailureResultRow(failure)"))
        XCTAssertTrue(host.contains("private func bridgeFailedToolResults(from blocks: [MessageContentBlock]?) -> [AgentFusionToolFailureSummary]"))
        XCTAssertTrue(host.contains("case .toolResult(let toolUseId, let content, let isError) where isError:"))
        XCTAssertTrue(host.contains("private func bridgeToolFailureResultRow(_ failure: AgentFusionToolFailureSummary) -> some View"))
        XCTAssertTrue(host.contains("Text(\"tool failed\")"))
        XCTAssertTrue(host.contains("private struct AgentFusionToolFailureSummary: Identifiable, Equatable, Sendable"))
        XCTAssertTrue(host.contains("let errorTone = bridgeErrorTone(for: message.errorKind)"))
        XCTAssertTrue(host.contains("private func bridgeErrorTone("))
        XCTAssertTrue(host.contains("for kind: UserFacingChatErrorKind?"))
        XCTAssertTrue(host.contains("Text(errorTone.recoveryHint)"))
        XCTAssertTrue(host.contains("case .authFailure:"))
        XCTAssertTrue(host.contains("case .rateLimited:"))
        XCTAssertTrue(host.contains("case .providerUnreachable:"))
        XCTAssertTrue(host.contains("case .timedOut:"))
        XCTAssertTrue(host.contains("case .contextOverflow:"))
        XCTAssertTrue(host.contains("case .modelNotReady:"))
        XCTAssertTrue(host.contains("case .cancelled:"))
        XCTAssertTrue(host.contains("return (\"stopped\", \"The turn was stopped before completion.\""))
        XCTAssertFalse(host.contains("Text(\"error\")"))
        XCTAssertTrue(host.contains("TaggedMarkdownTextView("))
        XCTAssertTrue(host.contains("typographyRole: .user"))
        XCTAssertTrue(host.contains("typographyRole: .assistant"))
        XCTAssertTrue(host.contains("AssistantResponseChrome {"))
        XCTAssertTrue(host.contains("foregroundOverride: theme.userBubbleText"))
        XCTAssertTrue(host.contains("foregroundOverride: theme.assistantBubbleForeground"))
        XCTAssertTrue(host.contains(".background(theme.userBubbleBg, in: RoundedRectangle(cornerRadius: 15))"))
        XCTAssertTrue(host.contains("UserFacingModelOutput.finalVisibleText(from: message.effectiveText)"))
        XCTAssertFalse(host.contains("bridgeRuntimeStatus"))
        XCTAssertFalse(host.contains("Text(\"transcript\")"))
        XCTAssertFalse(host.contains("transcriptTextFont(for:"))
        XCTAssertTrue(host.contains("ForEach(mirroredAgentCloneMessages.suffix(3))"))
        XCTAssertTrue(host.contains("bridgeMirroredRuntimeRow(message)"))
        XCTAssertTrue(host.contains("if agentChat.isAgentExecuting"))
        XCTAssertTrue(host.contains("bridgeActiveToolRow("))
        XCTAssertTrue(host.contains("name: agentChat.activeToolName"))
        XCTAssertTrue(host.contains("inputJson: agentChat.activeToolInputJson"))
        XCTAssertTrue(host.contains("private func bridgeActiveToolRow(name: String?, inputJson: String?) -> some View"))
        XCTAssertTrue(host.contains("ToolActivityNarrator.surface(name: resolvedToolName)"))
        XCTAssertTrue(host.contains("ToolActivityNarrator.phrase(name: resolvedToolName, inputJson: inputJson)"))
        XCTAssertTrue(host.contains("Text(\"running\")"))
        XCTAssertTrue(host.contains("if let pendingApproval = bridgePendingApproval"))
        XCTAssertTrue(host.contains("bridgePendingApprovalRow(pendingApproval)"))
        XCTAssertTrue(host.contains("private var bridgePendingApproval: ApprovalModalView.PendingApproval?"))
        XCTAssertTrue(host.contains("chatApprovalQueue.pendingApproval"))
        XCTAssertTrue(host.contains("return approval.sessionId == activeSessionId ? approval : nil"))
        XCTAssertTrue(host.contains("private func bridgePendingApprovalRow(_ approval: ApprovalModalView.PendingApproval) -> some View"))
        XCTAssertTrue(host.contains("Text(\"approval\")"))
        XCTAssertTrue(host.contains("private func bridgeApprovalDecisionButton("))
        XCTAssertTrue(host.contains("chatApprovalQueue.resolve(approval, decision: decision)"))
        XCTAssertTrue(host.contains("private func bridgeApprovalDetail(_ approval: ApprovalModalView.PendingApproval) -> String"))
        XCTAssertTrue(host.contains("private struct AgentCloneMirroredMessage: Identifiable, Equatable, Sendable"))
        XCTAssertTrue(host.contains("private enum AgentCloneSessionMirror"))
        XCTAssertTrue(host.contains("private static let maxMirroredFileBytes = 1_048_576"))
        XCTAssertTrue(host.contains("mirrorTask = Task { @MainActor in"))
        XCTAssertTrue(host.contains("Task.detached(priority: .utility)"))
        XCTAssertTrue(host.contains("for _ in 0..<120"))
        XCTAssertTrue(host.contains("await AgentCloneSessionMirror.snapshot("))
        XCTAssertTrue(host.contains("modifiedAt >= startDate"))
        XCTAssertTrue(host.contains(".appendingPathComponent(\"sessions\", isDirectory: true)"))
        XCTAssertTrue(host.contains("$0.pathExtension == \"jsonl\""))
        XCTAssertTrue(host.contains("$0.byteCount <= maxMirroredFileBytes"))
        XCTAssertTrue(host.contains("startNewBridgeSession()"))
        XCTAssertTrue(host.contains("syncBridgeHostContext()"))
        XCTAssertTrue(host.contains("compact && showCompactSessionRail"))
        XCTAssertTrue(host.contains("compact && showCompactContextRail"))
        XCTAssertFalse(host.contains(".ultraThinMaterial"))
        XCTAssertFalse(host.contains(".shadow(color:"))
        XCTAssertFalse(host.contains("theme.card.opacity(0.64)"))
        XCTAssertFalse(host.contains("theme.card.opacity(0.7)"))
        XCTAssertFalse(host.contains("simulated"))
        XCTAssertFalse(host.contains("fake response"))
        XCTAssertFalse(host.contains("Overseer"))
        XCTAssertFalse(host.contains("Execution Plan"))
        XCTAssertFalse(host.contains("ChatCoordinator"))
        XCTAssertFalse(root.contains("ChatRouteView()"))
        XCTAssertTrue(root.contains("if workspaceMode == .work {"))
        XCTAssertTrue(root.contains("chatModeSurface.transition(.blurFade())"))

        XCTAssertFalse(sourcePathExists("Epistemos/Chat/ChatRouteView.swift"))
        XCTAssertFalse(sourcePathExists("Epistemos/Chat/ChatSurfaceCoordinator.swift"))
        XCTAssertFalse(sourcePathExists("Epistemos/Chat/ChatViewModel.swift"))
        XCTAssertFalse(sourcePathExists("Epistemos/Chat/EpistemosChatEngineProvider.swift"))
        XCTAssertFalse(root.contains("ChatView("))
        XCTAssertFalse(root.contains("MiniChat"))
    }

    func testAgentCloneRouteDocumentationMatchesDirectRouteTruth() throws {
        let index = try sourceContents("docs/donor-contracts/swift-chat/INDEX.md")
        let provenance = try sourceContents("docs/donor-contracts/swift-chat/agent-clone/provenance.json")
        let status = try sourceContents("docs/WORK_CANON_STATUS_2026_06_25.md")
        let handoff = try sourceContents("docs/handoffs/ACT_AGENTCLONE_MASTER_GOAL_PROMPT_2026_06_25.md")

        XCTAssertTrue(index.contains("Rejected historical route experiment"))
        XCTAssertTrue(index.contains("Rejected historical panel experiment"))
        XCTAssertTrue(index.contains("Rejected historical transcript experiment"))
        XCTAssertFalse(index.contains("Historical/current-reference"))

        XCTAssertTrue(provenance.contains("current RootView mounts AgentCloneChatHostSurface for Chat/Act"))
        XCTAssertTrue(provenance.contains("AgentCloneChatHostSurface embeds AgentClone.ContentView()"))
        XCTAssertTrue(provenance.contains("AgentCloneBridge.submitPrompt(portalContext.agentClonePromptEnvelope"))
        XCTAssertTrue(provenance.contains("old Epistemos local-chat backend must not return"))
        XCTAssertTrue(provenance.contains("RootView must not mount ChatRouteView() as the direct Chat surface"))
        XCTAssertTrue(provenance.contains("ChatView2BrainPanel was rejected"))
        XCTAssertTrue(provenance.contains("ChatView2TranscriptBubble was rejected"))
        XCTAssertFalse(provenance.contains("serializes ActOsaurusPromptRequest"))
        XCTAssertFalse(provenance.contains("RootView no longer mounts AgentClone.ContentView"))
        XCTAssertFalse(provenance.contains("RootView.chatModeSurface mounts ChatRouteView()"))
        XCTAssertFalse(provenance.contains("pending current verification"))
        XCTAssertFalse(provenance.contains("pending current visual readback"))

        XCTAssertTrue(status.contains("future loops do not revive `ChatRouteView`"))
        XCTAssertTrue(handoff.contains("Do not restore\n  `ChatRouteView`"))
        XCTAssertTrue(handoff.contains("The live route must remain\n  an AgentClone-backed Epistemos host shell"))
    }

    func testStandardChatRejectsOverseerDiagnosticsAsPrimaryPanel() throws {
        let contract = try XCTUnwrap(
            ChatDonorContractCatalog.swiftChat20260625.first {
                $0.id == "agent-clone.chatview2-brain-panel-parity"
            }
        )

        XCTAssertEqual(contract.status, .blocked)
        XCTAssertTrue(contract.sourcePaths.contains("LocalPackages/AgentClone/Sources/AgentClone/Services/LLMProviderSetup.swift"))
        XCTAssertTrue(contract.sourcePaths.contains("LocalPackages/AgentClone/Sources/AgentClone/Models/ToolNames.swift"))
        XCTAssertTrue(contract.sourcePaths.contains("LocalPackages/AgentClone/Sources/AgentClone/MCP/MCPService.swift"))
        XCTAssertTrue(contract.destinationSeams.contains(.sidePanel))
        XCTAssertTrue(contract.destinationSeams.contains(.toolRegistry))
        XCTAssertTrue(contract.destinationSeams.contains(.mcpBridge))
        XCTAssertTrue(contract.destinationSeams.contains(.settingsSurface))
        XCTAssertTrue(contract.destinationSeams.contains(.modelUX))
        XCTAssertTrue(contract.destinationSeams.contains(.observability))
        XCTAssertTrue(contract.threading.runtimeWorkOffMainActor)
        XCTAssertFalse(contract.proof.visualReadbackRequired)
        XCTAssertFalse(contract.proof.endpointProofRequired)

        XCTAssertFalse(sourcePathExists("Epistemos/Chat/ChatRouteView.swift"))
        XCTAssertFalse(sourcePathExists("Epistemos/Chat/ChatSurfaceCoordinator.swift"))
        XCTAssertFalse(sourcePathExists("Epistemos/Chat/ChatTranscript.swift"))
        XCTAssertFalse(sourcePathExists("Epistemos/Chat/EpistemosInProcessProvider.swift"))
        XCTAssertFalse(sourcePathExists("Epistemos/Views/Chat/ChatView.swift"))
        XCTAssertFalse(sourcePathExists("Epistemos/Views/Chat/ChatSidebarView.swift"))

        let host = try sourceContents("Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift")
        XCTAssertTrue(host.contains("@State private var showSessionRail = false"))
        XCTAssertTrue(host.contains("@State private var showContextRail = false"))
        XCTAssertTrue(host.contains("@State private var bridgePromptText = \"\""))
        XCTAssertTrue(host.contains("@State private var showBridgeRuntimePicker = false"))
        XCTAssertTrue(host.contains("@State private var showBridgeSlashMenu = false"))
        XCTAssertTrue(host.contains("@State private var showBridgeMentionDropdown = false"))
        XCTAssertTrue(host.contains("@State private var bridgeContextAttachments: [ContextAttachment] = []"))
        XCTAssertTrue(host.contains("@Environment(AgentCommandCenterState.self) private var agentCommandCenter"))
        XCTAssertTrue(host.contains("@Environment(ChatApprovalQueue.self) private var chatApprovalQueue"))
        XCTAssertTrue(host.contains("@Environment(VaultSyncService.self) private var vaultSync"))
        XCTAssertTrue(host.contains("@Environment(InferenceState.self) private var inference"))
        XCTAssertTrue(host.contains("@AppStorage(MainChatOperatingModePreference.defaultsKey)"))
        XCTAssertTrue(host.contains("@State private var mirroredAgentCloneMessages: [AgentCloneMirroredMessage] = []"))
        XCTAssertTrue(host.contains("@State private var mirrorTask: Task<Void, Never>?"))
        XCTAssertTrue(host.contains("chatHostToolbar(compact: compact)"))
        XCTAssertTrue(host.contains("private func chatHostToolbar(compact: Bool) -> some View"))
        XCTAssertTrue(host.contains("Text(context.appName)"))
        XCTAssertTrue(host.contains("Text(bridgeAgentStatusLabel)"))
        XCTAssertTrue(host.contains("sessionControlButton(compact: compact)"))
        XCTAssertTrue(host.contains("Text(\"session\")"))
        XCTAssertTrue(host.contains("private var bridgeVisibleSessionId: String?"))
        XCTAssertTrue(host.contains("agentChat.activeSessionId ?? context.portalContext.sessionId"))
        XCTAssertTrue(host.contains("clippedSession(bridgeVisibleSessionId)"))
        XCTAssertTrue(host.contains("toggleSessionRail(compact: compact)"))
        XCTAssertTrue(host.contains("Text(\"model\")"))
        XCTAssertTrue(host.contains("Image(systemName: \"arrow.up.right\")"))
        XCTAssertTrue(host.contains("showBridgeRuntimePicker.toggle()"))
        XCTAssertTrue(host.contains("toggleContextRail(compact: compact)"))
        XCTAssertTrue(host.contains("railControlButtons(compact: compact)"))
        XCTAssertTrue(host.contains("bridgeComposerDock(compact: compact)"))
        XCTAssertTrue(host.contains("bridgeTranscriptRunway(compact: compact)"))
        XCTAssertTrue(host.contains("InlineRuntimePickerPanel("))
        XCTAssertTrue(host.contains("operatingMode: bridgeOperatingModeBinding"))
        XCTAssertTrue(host.contains("ComposerMicButton { transcript in"))
        XCTAssertTrue(host.contains("appendBridgeVoiceTranscript(transcript)"))
        XCTAssertTrue(host.contains("showBridgeRuntimePicker = false"))
        XCTAssertTrue(host.contains("SlashCommandPopover("))
        XCTAssertTrue(host.contains("ComposerReferencePopover("))
        XCTAssertTrue(host.contains("bridgeContextAttachmentChips"))
        XCTAssertTrue(host.contains("bridgeComposerContextBar"))
        XCTAssertTrue(host.contains("Text(\"Read + Search vault\")"))
        XCTAssertTrue(host.contains("toggleBridgeAllNotesContext()"))
        XCTAssertTrue(host.contains("bridgePortalActionChips"))
        XCTAssertTrue(host.contains("bridgeActionDescriptors"))
        XCTAssertTrue(host.contains("railSectionTitle(\"Portal Actions\")"))
        XCTAssertTrue(host.contains("bridgeActionDescriptorDetail(action)"))
        XCTAssertTrue(host.contains("bridgeApprovedActionChips"))
        XCTAssertTrue(host.contains("appendBridgeActionIntent(action)"))
        XCTAssertTrue(host.contains("bridgeActionSystemImage(action)"))
        XCTAssertTrue(host.contains("bridgeActionHelp(action)"))
        XCTAssertTrue(host.contains("bridgeResolvedPortalContext.withAdditionalContextAttachments(bridgeContextAttachments)"))
        XCTAssertTrue(host.contains("portalContext.promptPreview = bridgePromptText"))
        XCTAssertTrue(host.contains("portalContext = portalContext.withSessionId(sessionId)"))
        XCTAssertTrue(host.contains("TextField(\"Ask anything... Type @ for notes or chats\", text: $bridgePromptText, axis: .vertical)"))
        XCTAssertTrue(host.contains("agentChat.startNewSession(portalContext: portalContext)"))
        XCTAssertTrue(host.contains("agentChat.submitAgentQuery(trimmed, portalContext: portalContext)"))
        XCTAssertTrue(host.contains("syncBridgeHostContext(portalContext: agentChat.activePortalContext ?? portalContext)"))
        XCTAssertTrue(host.contains("bridgeAgentClonePromptCapabilityLines"))
        XCTAssertTrue(host.contains("AgentCloneBridge.submitPrompt(portalContext.agentClonePromptEnvelope("))
        XCTAssertTrue(host.contains("capabilityLines: bridgeAgentClonePromptCapabilityLines"))
        XCTAssertTrue(host.contains("presentation: portalContext?.bridgePresentation"))
        XCTAssertTrue(host.contains("AgentCloneBridge.updateHostContext(AgentCloneHostContext("))
        XCTAssertTrue(host.contains("Array(agentChat.messages.suffix(4))"))
        XCTAssertTrue(host.contains("agentChat.streamingText"))
        XCTAssertTrue(host.contains("message.effectiveText"))
        XCTAssertTrue(host.contains("private enum AgentFusionChatLayout"))
        XCTAssertTrue(host.contains("LazyVStack(alignment: .leading, spacing: AgentFusionChatLayout.transcriptSpacing)"))
        XCTAssertTrue(host.contains(".frame(maxWidth: compact ? .infinity : AgentFusionChatLayout.messageColumnMaxWidth)"))
        XCTAssertTrue(host.contains(".frame(maxWidth: compact ? .infinity : AgentFusionChatLayout.composerMaxWidth)"))
        XCTAssertTrue(host.contains("AgentFusionRailRow(title: \"Current\", detail: bridgeAgentStatusLabel, systemImage: bridgeAgentStatusSymbol)"))
        XCTAssertTrue(host.contains("AgentFusionRailRow(title: \"Runtime\", detail: \"native agent\""))
        XCTAssertTrue(host.contains("AgentFusionRailRow(title: \"Session\", detail: clippedSession(bridgeVisibleSessionId), systemImage: \"number\")"))
        XCTAssertTrue(host.contains("AgentFusionRailRow(title: \"Source\", detail: \"App context\""))
        XCTAssertTrue(host.contains("Label(\"Use Context\", systemImage: \"doc.badge.gearshape\")"))
        XCTAssertTrue(host.contains("appendBridgeAppContextSnapshotIntent()"))
        XCTAssertTrue(host.contains("private var bridgeAppContextSnapshotText: String"))
        XCTAssertTrue(host.contains("Use this Epistemos app context snapshot:"))
        XCTAssertTrue(host.contains("railSectionTitle(\"Portal Context\")"))
        XCTAssertTrue(host.contains("bridgeResolvedPortalContext.note"))
        XCTAssertTrue(host.contains("bridgeResolvedPortalContext.graph"))
        XCTAssertTrue(host.contains("bridgeResolvedPortalContext.additionalContextAttachments"))
        XCTAssertTrue(host.contains("bridgePortalContextSummary"))
        XCTAssertTrue(host.contains("bridgeNoteContextSummary(note)"))
        XCTAssertTrue(host.contains("bridgeNoteSelectionSummary(note)"))
        XCTAssertTrue(host.contains("bridgeGraphContextSummary(graph)"))
        XCTAssertTrue(host.contains("bridgeGraphNeighborhoodSummary(graph)"))
        XCTAssertTrue(host.contains("bridgeAdditionalAttachmentSummary"))
        XCTAssertTrue(host.contains("railSectionTitle(\"Capabilities\")"))
        XCTAssertTrue(host.contains("AgentFusionRailRow(title: \"Tools\", detail: bridgeToolCapabilitySummary"))
        XCTAssertTrue(host.contains("AgentFusionRailRow(title: \"Skills\", detail: bridgeSkillCapabilitySummary"))
        XCTAssertTrue(host.contains("AgentFusionRailRow(title: \"Commands\", detail: bridgeCommandCapabilitySummary"))
        XCTAssertTrue(host.contains("AgentFusionRailRow(title: \"MCP\", detail: bridgeMCPCapabilitySummary"))
        XCTAssertTrue(host.contains("AgentFusionRecentSessionRow("))
        XCTAssertTrue(host.contains("meta: recentPortalSessionMeta(summary)"))
        XCTAssertTrue(host.contains("isActive: summary.id == agentChat.activeSessionId"))
        XCTAssertTrue(host.contains("private struct AgentFusionRecentSessionRow: View"))
        XCTAssertTrue(host.contains("bridgeSessionResumeMark(summary, compact: compact)"))
        XCTAssertTrue(host.contains("summary.messageCount > 0 || summary.promptPreview != nil"))
        XCTAssertTrue(host.contains("text: \"Session ready\""))
        XCTAssertFalse(host.contains("Swift agent foundation"))
        XCTAssertFalse(host.contains("Swift agent fusion"))
        XCTAssertFalse(host.contains("Epistemos bridge"))
        XCTAssertFalse(host.contains("Backend\", detail:"))
        XCTAssertTrue(host.contains("bridgeUserTranscriptRow(message)"))
        XCTAssertTrue(host.contains("bridgeAssistantTranscriptRow(message)"))
        XCTAssertTrue(host.contains("bridgeFailedToolResults(from: message.contentBlocks)"))
        XCTAssertTrue(host.contains("bridgeToolFailureResultRow(failure)"))
        XCTAssertTrue(host.contains("AgentFusionToolFailureSummary"))
        XCTAssertTrue(host.contains("case .toolResult(let toolUseId, let content, let isError) where isError:"))
        XCTAssertTrue(host.contains("AssistantResponseChrome {"))
        XCTAssertTrue(host.contains("TaggedMarkdownTextView("))
        XCTAssertTrue(host.contains("typographyRole: .assistant"))
        XCTAssertTrue(host.contains("typographyRole: .user"))
        XCTAssertFalse(host.contains("Text(\"transcript\")"))
        XCTAssertFalse(host.contains("bridgeRuntimeStatus"))
        XCTAssertFalse(host.contains("transcriptTextFont(for:"))
        XCTAssertTrue(host.contains("ForEach(mirroredAgentCloneMessages.suffix(3))"))
        XCTAssertTrue(host.contains("bridgeMirroredRuntimeRow(message)"))
        XCTAssertTrue(host.contains("if agentChat.isAgentExecuting"))
        XCTAssertTrue(host.contains("bridgeActiveToolRow("))
        XCTAssertTrue(host.contains("ToolActivityNarrator.phrase(name: resolvedToolName, inputJson: inputJson)"))
        XCTAssertTrue(host.contains("bridgePendingApprovalRow(pendingApproval)"))
        XCTAssertTrue(host.contains("chatApprovalQueue.resolve(approval, decision: decision)"))
        XCTAssertTrue(host.contains("private enum AgentCloneSessionMirror"))
        XCTAssertTrue(host.contains("mirrorTask = Task { @MainActor in"))
        XCTAssertTrue(host.contains("Task.detached(priority: .utility)"))
        XCTAssertTrue(host.contains("private static let maxMirroredFileBytes = 1_048_576"))
        XCTAssertTrue(host.contains("modifiedAt >= startDate"))
        XCTAssertTrue(host.contains(".appendingPathComponent(\"sessions\", isDirectory: true)"))
        XCTAssertTrue(host.contains("$0.pathExtension == \"jsonl\""))
        XCTAssertTrue(host.contains("$0.byteCount <= maxMirroredFileBytes"))
        XCTAssertTrue(host.contains("title: \"Model\""))
        XCTAssertTrue(host.contains("AgentFusionRailRow(title: \"Vault\""))
        XCTAssertTrue(host.contains("AgentFusionRailRow(title: \"Actions\""))
        XCTAssertFalse(host.contains("@State private var showContextRail = true"))
        XCTAssertFalse(host.contains(".ultraThinMaterial"))
        XCTAssertFalse(host.contains("simulated"))
        XCTAssertFalse(host.contains("fake response"))
        XCTAssertFalse(host.contains("ROUTING"))
        XCTAssertFalse(host.contains("REQUEST"))
        XCTAssertFalse(host.contains("Execution Plan"))
        XCTAssertFalse(host.contains("Overseer"))
    }

    func testOldMessageBubbleReferenceTargetsAgentCloneNotOldBackendRoute() throws {
        let contract = try XCTUnwrap(
            ChatDonorContractCatalog.swiftChat20260625.first {
                $0.id == "agent-clone.chatview2-transcript-bubble-parity"
            }
        )

        XCTAssertEqual(contract.status, .blocked)
        XCTAssertTrue(contract.sourcePaths.contains("LocalPackages/AgentClone/Sources/AgentClone/Views/Output/MessagesView.swift"))
        XCTAssertTrue(contract.sourcePaths.contains("LocalPackages/AgentClone/Sources/AgentClone/Models/ChatModels.swift"))
        XCTAssertTrue(contract.destinationSeams.contains(.transcriptRenderer))
        XCTAssertTrue(contract.destinationSeams.contains(.visibleShell))
        XCTAssertTrue(contract.destinationSeams.contains(.recentsBridge))
        XCTAssertTrue(contract.destinationSeams.contains(.observability))
        XCTAssertTrue(contract.threading.runtimeWorkOffMainActor)
        XCTAssertFalse(contract.proof.visualReadbackRequired)
        XCTAssertFalse(contract.proof.endpointProofRequired)

        XCTAssertFalse(sourcePathExists("Epistemos/Chat/ChatRouteView.swift"))
        XCTAssertFalse(sourcePathExists("Epistemos/Chat/ChatTranscript.swift"))
        XCTAssertFalse(sourcePathExists("Epistemos/Chat/ChatViewModel.swift"))
        XCTAssertFalse(sourcePathExists("Epistemos/Views/Chat/AssistantInlineTranscriptView.swift"))
        XCTAssertFalse(sourcePathExists("Epistemos/Views/Chat/MessageBubble.swift"))

        let agentContent = try sourceContents("LocalPackages/AgentClone/Sources/AgentClone/Views/ContentView/ContentView.swift")
        XCTAssertTrue(agentContent.contains("transcriptStack("))
        XCTAssertTrue(agentContent.contains("InputSectionView("))
    }

    func testAgentCloneMessageBarLayoutMatchesEpistemosComposerRhythm() throws {
        let contract = try XCTUnwrap(
            ChatDonorContractCatalog.swiftChat20260625.first {
                $0.id == "agent-clone.message-bar-layout-parity"
            }
        )

        XCTAssertEqual(contract.status, .adaptedWithTests)
        XCTAssertTrue(contract.destinationSeams.contains(.composer))
        XCTAssertTrue(contract.destinationSeams.contains(.visibleShell))
        XCTAssertTrue(contract.destinationSeams.contains(.providerPicker))
        XCTAssertTrue(contract.proof.visualReadbackRequired)
        XCTAssertFalse(contract.proof.endpointProofRequired)
        XCTAssertTrue(
            contract.proof.commands.contains {
                $0.contains("swift build --package-path /tmp/AgentCloneVisualHost")
            }
        )

        let input = try sourceContents("LocalPackages/AgentClone/Sources/AgentClone/Views/Input/InputSectionView.swift")
        XCTAssertTrue(input.contains("private enum EpistemosMessageBarLayout"))
        XCTAssertTrue(input.contains("static let maxWidth: CGFloat = 620"))
        XCTAssertTrue(input.contains("static let horizontalPadding: CGFloat = 11"))
        XCTAssertTrue(input.contains("static let topPadding: CGFloat = 9"))
        XCTAssertTrue(input.contains("static let bottomPadding: CGFloat = 7"))
        XCTAssertTrue(input.contains("static let controlRowSpacing: CGFloat = 4"))
        XCTAssertTrue(input.contains("static let controlRowTopPadding: CGFloat = 6"))
        XCTAssertTrue(input.contains(".frame(maxWidth: EpistemosMessageBarLayout.maxWidth)"))
        XCTAssertTrue(input.contains(".frame(maxWidth: .infinity, alignment: .center)"))
        XCTAssertTrue(input.contains("VStack(alignment: .leading, spacing: 0)"))
        XCTAssertTrue(input.contains("HStack(spacing: EpistemosMessageBarLayout.controlRowSpacing)"))
        XCTAssertTrue(input.contains(".padding(.top, EpistemosMessageBarLayout.controlRowTopPadding)"))
        XCTAssertTrue(input.contains(".padding(.horizontal, EpistemosMessageBarLayout.horizontalPadding)"))
        XCTAssertTrue(input.contains(".padding(.top, EpistemosMessageBarLayout.topPadding)"))
        XCTAssertTrue(input.contains(".padding(.bottom, EpistemosMessageBarLayout.bottomPadding)"))

        XCTAssertTrue(input.contains("modelSettingsButton"))
        XCTAssertTrue(input.contains("SettingsView(viewModel: viewModel)"))
        XCTAssertTrue(input.contains("viewModel.captureScreenshot()"))
        XCTAssertTrue(input.contains("viewModel.pasteImageFromClipboard()"))
        XCTAssertTrue(input.contains("viewModel.toggleDictation()"))
        XCTAssertTrue(input.contains("viewModel.toggleHotwordListening()"))
        XCTAssertTrue(input.contains("Image(systemName: isBusy ? \"stop.fill\" : \"xmark\")"))
        XCTAssertTrue(input.contains("Image(systemName: \"arrow.up\")"))

        let content = try sourceContents("LocalPackages/AgentClone/Sources/AgentClone/Views/ContentView/ContentView.swift")
        XCTAssertGreaterThanOrEqual(content.components(separatedBy: "InputSectionView(").count - 1, 2)
        XCTAssertTrue(content.contains("ChatStartSurface("))
        XCTAssertTrue(content.contains("transcriptStack("))

        let root = try sourceContents("Epistemos/App/RootView.swift")
        let host = try sourceContents("Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift")
        XCTAssertTrue(root.contains("@ViewBuilder private var chatModeSurface: some View"))
        XCTAssertTrue(root.contains("AgentCloneChatHostSurface("))
        XCTAssertTrue(root.contains("context: agentCloneContextSnapshot"))
        XCTAssertTrue(host.contains("AgentClone.ContentView()"))
        XCTAssertTrue(root.contains("let _ = AgentClone.AgentSkin.configure("))
        XCTAssertFalse(root.contains("ChatRouteView()"))

        XCTAssertFalse(sourcePathExists("Epistemos/Chat/ChatRouteView.swift"))
        XCTAssertFalse(sourcePathExists("Epistemos/Views/Chat/ChatInputBar.swift"))
        XCTAssertFalse(sourcePathExists("Epistemos/Views/MiniChat/MiniChatView.swift"))
    }

    func testAgentCloneCapabilityManifestCoversProviderStack() {
        let expectedProviders: Set<String> = [
            "claude",
            "openAI",
            "codex",
            "deepSeek",
            "huggingFace",
            "zAI",
            "bigModel",
            "miniMax",
            "openRouter",
            "qwen",
            "gemini",
            "grok",
            "mistral",
            "codestral",
            "vibe",
            "ollama",
            "localOllama",
            "vLLM",
            "lmStudio",
            "foundationModel"
        ]

        XCTAssertEqual(Set(ChatDonorAgentCloneCapabilityManifest.providerIDs), expectedProviders)
        XCTAssertEqual(ChatDonorAgentCloneCapabilityManifest.providerCapabilities.count, expectedProviders.count)
        XCTAssertTrue(ChatDonorAgentCloneCapabilityManifest.providerCapabilities.allSatisfy(\.mustPreserve))
    }

    func testAgentCloneCapabilityManifestCoversToolsSurfacesAndRisk() {
        let expectedTools: Set<String> = [
            "task_complete",
            "list_native_tools",
            "web_search",
            "project_folder",
            "conversation",
            "send_message",
            "agent_script",
            "plan_mode",
            "index",
            "git",
            "batch_commands",
            "batch_tools",
            "file_manager",
            "xcode",
            "run_shell_script",
            "apple_script",
            "accessibility",
            "javascript",
            "execute_agent_command",
            "execute_daemon_command",
            "safari",
            "selenium",
            "memory",
            "skill",
            "spawn_agent",
            "tell_agent",
            "ask_user",
            "fetch"
        ]
        let expectedSurfaces: Set<String> = [
            "mcp",
            "sessions-history-recents",
            "settings",
            "permissions-approval",
            "rollback",
            "usage",
            "automation",
            "messages"
        ]

        XCTAssertEqual(Set(ChatDonorAgentCloneCapabilityManifest.toolNames), expectedTools)
        XCTAssertEqual(Set(ChatDonorAgentCloneCapabilityManifest.surfaceCapabilities.compactMap(\.nativeName)), expectedSurfaces)
        XCTAssertEqual(Set(ChatDonorAgentCloneCapabilityManifest.toolGroupCapabilities.compactMap(\.nativeName)), [
            "Core",
            "Work",
            "Code",
            "Auto",
            "User",
            "Root",
            "Sub-agents",
            "Experimental"
        ])
        XCTAssertEqual(ChatDonorAgentCloneCapabilityManifest.validationFailures, [:])
        XCTAssertEqual(ChatDonorAgentCloneCapabilityManifest.dependencyRiskCapabilities.map(\.id), [
            "agentclone.risk.closed-agent-packages"
        ])
        XCTAssertTrue(ChatDonorAgentCloneCapabilityManifest.allCapabilities.allSatisfy(\.requiresOwnerApprovalBeforeRemoval))
    }

    func testAgentCloneCapabilityManifestSourceAnchorsExistAndContainMarkers() throws {
        let repoRootURL = repositoryRootURL()
        var sourceCache: [String: String] = [:]

        for capability in ChatDonorAgentCloneCapabilityManifest.allCapabilities {
            for anchor in capability.sourceAnchors {
                let url = URL(fileURLWithPath: anchor.path, relativeTo: repoRootURL).standardizedFileURL
                XCTAssertTrue(
                    FileManager.default.fileExists(atPath: url.path),
                    "\(capability.id) source path missing: \(anchor.path)"
                )
                let contents: String
                if let cached = sourceCache[anchor.path] {
                    contents = cached
                } else {
                    contents = try String(contentsOf: url, encoding: .utf8)
                    sourceCache[anchor.path] = contents
                }

                for marker in anchor.requiredMarkers {
                    XCTAssertTrue(
                        contents.contains(marker),
                        "\(capability.id) missing marker '\(marker)' in \(anchor.path)"
                    )
                }
            }
        }
    }

    func testDeletedEpistemosChatBackendCannotDriveSwiftChat() throws {
        let contract = try XCTUnwrap(
            ChatDonorContractCatalog.swiftChat20260625.first {
                $0.id == "swarm.in-process-chat-substrate"
            }
        )

        XCTAssertEqual(contract.status, .blocked)
        XCTAssertFalse(sourcePathExists("Epistemos/Chat/EpistemosInProcessProvider.swift"))
        XCTAssertFalse(sourcePathExists("Epistemos/Chat/EpistemosChatSession.swift"))
        XCTAssertFalse(sourcePathExists("Epistemos/Chat/EpistemosChatAgentFactory.swift"))
        XCTAssertFalse(sourcePathExists("Epistemos/Chat/ChatTranscript.swift"))
        XCTAssertFalse(sourcePathExists("Epistemos/Chat/ChatViewModel.swift"))
        XCTAssertFalse(sourcePathExists("Epistemos/Chat/EpistemosChatEngineProvider.swift"))

        let bootstrap = try sourceContents("Epistemos/App/AppBootstrap.swift")
        XCTAssertFalse(bootstrap.contains("ChatSurfaceCoordinator("))
        XCTAssertFalse(bootstrap.contains("EpistemosChatEngineProvider.make("))

        let environment = try sourceContents("Epistemos/App/AppEnvironment.swift")
        XCTAssertFalse(environment.contains("chatSurfaceCoordinator"))
        XCTAssertFalse(environment.contains("ChatSurfaceEnvironment"))
    }

    func testLegacyNativeChatFamilyAndOsaurusAreDeleted() throws {
        let deletedPaths = [
            "Epistemos/App/ChatCoordinator.swift",
            "Epistemos/App/ChatCoordinator+EidosCitationGate.swift",
            "Epistemos/State/ChatState.swift",
            "Epistemos/State/NoteChatState.swift",
            "Epistemos/State/DialogueChatState.swift",
            "Epistemos/Views/Chat/ChatView.swift",
            "Epistemos/Views/Chat/ChatInputBar.swift",
            "Epistemos/Views/Chat/ChatSidebarView.swift",
            "Epistemos/Views/Chat/AnswerPacketBadge.swift",
            "Epistemos/Views/Chat/AssistantInlineTranscriptView.swift",
            "Epistemos/Views/Chat/BTMView.swift",
            "Epistemos/Views/Chat/ChatBrainPickerMenu.swift",
            "Epistemos/Views/Chat/ContextWindowIndicator.swift",
            "Epistemos/Views/Chat/ContextWindowCompactBadge.swift",
            "Epistemos/Views/Chat/DiffPreviewView.swift",
            "Epistemos/Views/Chat/EditorSkillChips.swift",
            "Epistemos/Views/Chat/EidosRetrievedSection.swift",
            "Epistemos/Views/Chat/LiveActivityStrip.swift",
            "Epistemos/Views/Chat/MessageBubble.swift",
            "Epistemos/Views/Chat/ProcessDisclosureViews.swift",
            "Epistemos/Views/Chat/ThinkingPopoverView.swift",
            "Epistemos/Views/Chat/ThinkingTrailView.swift",
            "Epistemos/Views/Chat/TodoSnapshotCard.swift",
            "Epistemos/Views/Chat/VRMLabelView.swift",
            "Epistemos/Views/Chat/VaultRecallProvenanceCard.swift",
            "Epistemos/Views/MiniChat/MiniChatView.swift",
            "Epistemos/Views/MiniChat/MiniChatWindowController.swift",
            "Epistemos/Views/Notes/NoteChatSidebar.swift",
            "Epistemos/Views/Notes/CodeAskBar.swift",
            "Epistemos/Graph/Workspace/GraphChatRequest.swift",
            "Epistemos/Vault/ChatTranscriptVaultWriter.swift",
            "Epistemos/ActOsaurus",
            "Epistemos/Vendor/Osaurus",
            "LocalPackages/osaurus"
        ]

        for path in deletedPaths {
            XCTAssertFalse(sourcePathExists(path), "Legacy chat/Osaurus path should be deleted: \(path)")
        }

        let root = try sourceContents("Epistemos/App/RootView.swift")
        XCTAssertFalse(root.contains("ChatView("))
        XCTAssertFalse(root.contains("MiniChat"))
        XCTAssertFalse(root.contains("ChatRouteView"))
        XCTAssertFalse(root.contains("import OsaurusCore"))
        XCTAssertFalse(root.contains("EpistemosOsaurusChatHost("))
        XCTAssertFalse(root.contains("ActEpistemosChatSurface("))
        XCTAssertFalse(root.contains(".submitActOsaurusPrompt"))
        XCTAssertFalse(root.contains("ActOsaurusPromptRequest"))

        let bootstrap = try sourceContents("Epistemos/App/AppBootstrap.swift")
        XCTAssertFalse(bootstrap.contains("ChatCoordinator"))
        XCTAssertFalse(bootstrap.contains("NoteChatState"))
        XCTAssertFalse(bootstrap.contains("DialogueChatState"))
        XCTAssertFalse(bootstrap.contains("Osaurus"))

        let vaultSync = try sourceContents("Epistemos/Sync/VaultSyncService.swift")
        XCTAssertFalse(vaultSync.contains("AppBootstrap.shared?.chatState"))

        let notesSidebar = try sourceContents("Epistemos/Views/Notes/NotesSidebar.swift")
        XCTAssertFalse(notesSidebar.contains("case summarize("))
        XCTAssertFalse(notesSidebar.contains("case deepDive("))
        XCTAssertFalse(notesSidebar.contains("loadedNoteIds"))
        XCTAssertFalse(notesSidebar.contains("submitQuery("))

        let localizedStrings = try sourceContents("Epistemos/Resources/Localizable.xcstrings")
        XCTAssertFalse(localizedStrings.contains("MiniChat"))
        XCTAssertFalse(localizedStrings.contains("Open Mini Chat"))
        XCTAssertFalse(localizedStrings.contains("NoteChatSidebar"))
        XCTAssertFalse(localizedStrings.contains("Chat Transcripts"))

        let bannedMountedTokens = [
            "ChatCoordinator",
            "ChatSurfaceCoordinator",
            "ChatRouteView",
            "DialogueChatState",
            "NoteChat",
            "noteChat",
            "NoteChatState",
            "GraphChatRequest",
            "ChatTranscriptVaultWriter",
            "ContextWindowIndicator",
            "DiffPreviewView",
            "EditorSkillChips",
            "TodoSnapshotCard",
            "NoteChatSidebar",
            "MiniChat",
            "miniChat",
            "ActOsaurus",
            "EpistemosOsaurus",
            "OsaurusCore",
            "submitActOsaurus",
            "ActOsaurusPromptRequest",
        ]
        for path in appSwiftSourcePathsForDeletedChatScan() {
            let contents = try sourceContents(path)
            for token in bannedMountedTokens {
                XCTAssertFalse(contents.contains(token), "\(token) should not remain in \(path)")
            }
        }
    }

    func testMOHAWKTrainingAssetsDoNotTeachDeletedNativeChatSurfaces() throws {
        let bannedTrainingTokens = [
            "ChatCoordinator",
            "ChatRouteView",
            "ChatSurfaceCoordinator",
            "DialogueChatState",
            "NoteChat",
            "noteChat",
            "NoteChatState",
            "NoteChatSidebar",
            "GraphChatRequest",
            "GraphChat",
            "MiniChat",
            "ChatView.swift",
            "ChatInputBar.swift",
            "ChatSidebarView.swift",
            "Epistemos/App/ChatCoordinator.swift",
            "Epistemos/State/ChatState.swift",
            "Epistemos/State/DialogueChatState.swift",
            "Epistemos/State/NoteChatState.swift",
            "Epistemos/Views/MiniChat/",
            "Epistemos/Views/Notes/NoteChatSidebar.swift",
            "Epistemos/Graph/Workspace/GraphChatRequest.swift",
            "ActOsaurus",
            "EpistemosOsaurus",
            "Osaurus",
            "AgentBlueprint",
            "SystemG",
        ]

        let paths = mohawkTrainingAssetPathsForDeletedChatScan()
        XCTAssertFalse(paths.isEmpty)
        for path in paths {
            let contents = try sourceContents(path)
            for token in bannedTrainingTokens {
                XCTAssertFalse(contents.contains(token), "\(token) should not remain in \(path)")
            }
        }

        let generator = try sourceContents("Epistemos/KnowledgeFusion/MOHAWK/generate_epistemos_training_data.py")
        XCTAssertTrue(generator.contains("AgentPortalContextSnapshot"))
        XCTAssertTrue(generator.contains("note_agent_portal"))
    }

    func testAgentChatStateKeepsStreamingSupportWithoutRestoringDeletedChatState() throws {
        XCTAssertFalse(sourcePathExists("Epistemos/State/ChatState.swift"))
        XCTAssertFalse(sourcePathExists("Epistemos/State/NoteChatState.swift"))
        XCTAssertFalse(sourcePathExists("Epistemos/State/DialogueChatState.swift"))
        XCTAssertTrue(sourcePathExists("Epistemos/State/AgentStreamingSupport.swift"))

        let support = try sourceContents("Epistemos/State/AgentStreamingSupport.swift")
        XCTAssertTrue(support.contains("enum StreamingReasoningTraceBuffer"))
        XCTAssertTrue(support.contains("static let postAnswerDisplaySeparator"))
        XCTAssertTrue(support.contains("final class DisplayPacedTextBuffer"))
        XCTAssertTrue(support.contains("func reset(releaseCapacity: Bool = false)"))

        let agentChatState = try sourceContents("Epistemos/State/AgentChatState.swift")
        XCTAssertTrue(agentChatState.contains("private lazy var streamBuffer = DisplayPacedTextBuffer"))
        XCTAssertTrue(agentChatState.contains("StreamingReasoningTraceBuffer.append("))
        XCTAssertTrue(agentChatState.contains("struct AgentPortalSessionSummary: Identifiable, Codable, Equatable, Sendable"))
        XCTAssertTrue(agentChatState.contains("var activePortalContext: AgentPortalContextSnapshot?"))
        XCTAssertTrue(agentChatState.contains("var recentPortalSessions: [AgentPortalSessionSummary] = []"))
        XCTAssertTrue(agentChatState.contains("private static let maxRecentPortalSessions = 12"))
        XCTAssertTrue(agentChatState.contains("private func recordActivePortalSession(promptPreview: String? = nil)"))
        XCTAssertTrue(agentChatState.contains("recentPortalSessions.removeAll { $0.id == sessionId }"))
        XCTAssertTrue(agentChatState.contains("recentPortalSessions.insert(summary, at: 0)"))
        XCTAssertFalse(agentChatState.contains("ChatCoordinator.inferAuthorship"))
    }

    func testLegacyNativeAgentBlueprintSystemGAndCompanionRoutingAreDeleted() throws {
        let deletedPaths = [
            "Epistemos/LocalAgent/AgentBlueprint.swift",
            "Epistemos/SystemG",
            "Epistemos/Views/Settings/AgentBlueprintSettingsView.swift",
            "Epistemos/Views/Settings/SystemGHealthRow.swift",
            "Epistemos/Views/Chat/AgentRunTimelineView.swift",
        ]

        for path in deletedPaths {
            XCTAssertFalse(sourcePathExists(path), "Legacy native agent path should be deleted: \(path)")
        }

        let localizedStrings = try sourceContents("Epistemos/Resources/Localizable.xcstrings")
        XCTAssertFalse(localizedStrings.contains("AgentBlueprint"))
        XCTAssertFalse(localizedStrings.contains("SystemG"))
        XCTAssertFalse(localizedStrings.contains("System G"))
        XCTAssertFalse(localizedStrings.contains("Run (System G)"))

        let companionCreation = try sourceContents("Epistemos/Views/Landing/Farm/CompanionCreationFlow.swift")
        XCTAssertFalse(companionCreation.contains("availableBrains"))
        XCTAssertFalse(companionCreation.contains("availableTools"))
        XCTAssertFalse(companionCreation.contains("selectedToolNames"))
        XCTAssertFalse(companionCreation.contains("Provider + model"))
        XCTAssertFalse(companionCreation.contains("Tools + guardrails"))

        let landing = try sourceContents("Epistemos/Views/Landing/LandingView.swift")
        XCTAssertFalse(landing.contains("applyLandingAgentRuntimePreference"))
        XCTAssertFalse(landing.contains("selectedModelRoutingID"))

        let bootstrap = try sourceContents("Epistemos/App/AppBootstrap.swift")
        XCTAssertFalse(bootstrap.contains("activeCompanionInstructionProvider"))
        XCTAssertFalse(bootstrap.contains("RealSystemGRunSeam"))
        XCTAssertFalse(bootstrap.contains("SystemGRunSeamRegistry"))

        let pipeline = try sourceContents("Epistemos/Engine/PipelineService.swift")
        XCTAssertFalse(pipeline.contains("activeCompanionInstructionProvider"))
        XCTAssertFalse(pipeline.contains("activeCompanionSystemInstruction"))

        let root = try sourceContents("Epistemos/App/RootView.swift")
        XCTAssertFalse(root.contains("CompanionState.self"))
        XCTAssertFalse(root.contains("No agent (base)"))
        XCTAssertTrue(root.contains("not mounted as an in-chat runtime switcher"))

        let bannedMountedTokens = [
            "AgentBlueprint",
            "SystemG",
            "System G",
            "AgentMissionPacket",
            "SystemGAgentEvent",
            "SystemGRunSeam",
            "SystemGBridge",
            "SystemGFlags",
            "RealSystemGRunSeam",
        ]
        for path in appSwiftSourcePathsForDeletedChatScan() {
            let contents = try sourceContents(path)
            for token in bannedMountedTokens {
                XCTAssertFalse(contents.contains(token), "\(token) should not remain in \(path)")
            }
        }
    }

    func testProjectMetadataDoesNotMountDeletedNativeChatOrOsaurus() throws {
        let metadataFiles = [
            "project.yml",
            "Epistemos.xcodeproj/project.pbxproj",
            "Epistemos.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved",
        ]
        let bannedMetadataTokens = [
            "ChatCoordinator",
            "ChatRouteView",
            "ChatSurfaceCoordinator",
            "ChatView.swift",
            "ChatInputBar.swift",
            "ChatSidebarView.swift",
            "DialogueChatState",
            "NoteChatState",
            "NoteChatSidebar",
            "GraphChatRequest",
            "MiniChat",
            "MiniChatView",
            "MiniChatWindowController",
            "ActOsaurus",
            "EpistemosOsaurus",
            "Osaurus",
            "osaurus",
            "LocalPackages/osaurus",
            "AgentBlueprint",
            "SystemG",
        ]

        for path in metadataFiles {
            let contents = try sourceContents(path)
            for token in bannedMetadataTokens {
                XCTAssertFalse(contents.contains(token), "\(token) should not remain in project metadata \(path)")
            }
        }
    }

    func testActLandingRoutesDirectlyToAgentCloneFoundationWithoutOsaurusBridge() throws {
        let app = try sourceContents("Epistemos/App/EpistemosApp.swift")
        let root = try sourceContents("Epistemos/App/RootView.swift")
        let host = try sourceContents("Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift")
        let snapshot = try sourceContents("Epistemos/Views/AgentFusion/AgentCloneAppContextSnapshot.swift")
        let portal = try sourceContents("Epistemos/Views/AgentFusion/AgentPortalContextSnapshot.swift")
        let routeRequest = try sourceContents("Epistemos/Views/AgentFusion/AgentPortalRouteRequest.swift")
        let agentChatState = try sourceContents("Epistemos/State/AgentChatState.swift")
        let compactPortal = try sourceContents("Epistemos/Views/AgentFusion/AgentCompactPortalView.swift")
        let landing = try sourceContents("Epistemos/Views/Landing/LandingView.swift")
        let utilityWindows = try sourceContents("Epistemos/App/UtilityWindowManager.swift")
        let chatTypes = try sourceContents("Epistemos/Models/ChatTypes.swift")
        let graphWorkspace = try sourceContents("Epistemos/Views/Graph/GraphWorkspaceContainer.swift")
        let noteWorkspace = try sourceContents("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let workspaceModeSelection = try sourceContents("Epistemos/Views/Landing/WorkspaceModeSelection.swift")
        let graph = try sourceContents("Epistemos/Views/Graph/HologramSearchSidebar.swift")
        let agentBridge = try sourceContents("LocalPackages/AgentClone/Sources/AgentClone/EpistemosAgentBridge.swift")
        let agentContent = try sourceContents("LocalPackages/AgentClone/Sources/AgentClone/Views/ContentView/ContentView.swift")
        let agentHostContext = try sourceContents("LocalPackages/AgentClone/Sources/AgentClone/AgentViewModel/Core/HostContext.swift")
        let sessionStore = try sourceContents("LocalPackages/AgentClone/Sources/AgentClone/Services/SessionStore.swift")
        let taskUtilities = try sourceContents("LocalPackages/AgentClone/Sources/AgentClone/AgentViewModel/TaskUtilities/TaskUtilities.swift")
        let taskExecution = try sourceContents("LocalPackages/AgentClone/Sources/AgentClone/AgentViewModel/TaskExecution/TaskExecution.swift")
        let tabLLMServices = try sourceContents("LocalPackages/AgentClone/Sources/AgentClone/AgentViewModel/TabTask/LLMServices.swift")

        XCTAssertFalse(app.contains("submitActOsaurusPrompt"))
        XCTAssertFalse(app.contains("openActOsaurusSession"))
        XCTAssertFalse(app.contains("showActOsaurusSettings"))
        XCTAssertFalse(app.contains("ActOsaurusPromptRequest"))

        XCTAssertFalse(root.contains(".submitActOsaurusPrompt"))
        XCTAssertFalse(root.contains(".openActOsaurusSession"))
        XCTAssertFalse(root.contains(".showActOsaurusSettings"))
        XCTAssertFalse(root.contains("agentClonePromptText(for: request, prompt: prompt)"))
        XCTAssertFalse(root.contains("ActOsaurusPromptRequest"))
        XCTAssertTrue(root.contains("onSyncHostContext: syncAgentCloneHostContext"))
        XCTAssertTrue(host.contains(".onAppear {"))
        XCTAssertTrue(host.contains("onSyncHostContext()"))
        XCTAssertTrue(host.contains("agentCommandCenter.refreshSkillCatalog()"))
        XCTAssertTrue(root.contains("AgentCloneBridge.updateHostContext("))
        XCTAssertTrue(root.contains("AgentCloneHostContext("))
        XCTAssertTrue(root.contains("private var agentCloneContextSnapshot: AgentCloneAppContextSnapshot"))
        XCTAssertTrue(root.contains("AgentCloneAppContextSnapshot("))
        XCTAssertTrue(root.contains("context: agentCloneContextSnapshot"))
        XCTAssertTrue(snapshot.contains("struct AgentCloneAppContextSnapshot: Codable, Equatable, Sendable"))
        XCTAssertTrue(snapshot.contains("static func defaultAppSupportPath(appName: String) -> String"))
        XCTAssertTrue(snapshot.contains("var portalContext: AgentPortalContextSnapshot"))
        XCTAssertTrue(portal.contains("struct AgentPortalContextSnapshot: Codable, Equatable, Sendable"))
        XCTAssertTrue(portal.contains("case landing"))
        XCTAssertTrue(portal.contains("case mini"))
        XCTAssertTrue(portal.contains("case note"))
        XCTAssertTrue(portal.contains("case graph"))
        XCTAssertTrue(portal.contains("static func mini("))
        XCTAssertTrue(portal.contains("static func note("))
        XCTAssertTrue(portal.contains("static func graph("))
        XCTAssertTrue(portal.contains("struct ActionDescriptor: Codable, Equatable, Sendable"))
        XCTAssertTrue(portal.contains("var actionDescriptors: [ActionDescriptor]"))
        XCTAssertTrue(portal.contains("id: \"app-context.snapshot\""))
        XCTAssertTrue(portal.contains("id: \"note.delete.with-approval\""))
        XCTAssertTrue(portal.contains("id: \"graph.mutate.with-approval\""))
        XCTAssertTrue(portal.contains("kind: .graph"))
        XCTAssertTrue(portal.contains("resourceURI: \"epistemos://graph/context\""))
        XCTAssertTrue(portal.contains("\"graph.mutate.with-approval\""))
        XCTAssertTrue(portal.contains("var contextAttachments: [ContextAttachment]"))
        XCTAssertTrue(routeRequest.contains("NotificationCenter.default.post("))
        XCTAssertTrue(routeRequest.contains("static let openAgentPortal"))
        XCTAssertTrue(root.contains(".onReceive(NotificationCenter.default.publisher(for: .openAgentPortal))"))
        XCTAssertTrue(root.contains("agentChat.startNewSession(portalContext: portalContext)"))
        XCTAssertTrue(agentChatState.contains("struct AgentPortalSessionSummary: Identifiable, Codable, Equatable, Sendable"))
        XCTAssertTrue(agentChatState.contains("var recentPortalSessions: [AgentPortalSessionSummary] = []"))
        XCTAssertTrue(agentChatState.contains("private static let maxRecentPortalSessions = 12"))
        XCTAssertTrue(agentChatState.contains("recordActivePortalSession(promptPreview: query)"))
        XCTAssertTrue(agentChatState.contains("recordActivePortalSession()"))
        XCTAssertTrue(agentChatState.contains("func activatePortalSession(_ summary: AgentPortalSessionSummary)"))
        XCTAssertTrue(agentChatState.contains("promoteRecentPortalSession(_ summary: AgentPortalSessionSummary)"))
        XCTAssertTrue(host.contains("agentChat.recentPortalSessions.prefix(6)"))
        XCTAssertTrue(host.contains("shouldShowBridgeEmptyLandingMark"))
        XCTAssertTrue(host.contains("bridgeEmptyLandingMark(compact: compact)"))
        XCTAssertTrue(host.contains("Text(context.appName)"))
        XCTAssertTrue(host.contains("agentCloneFoundationMount"))
        XCTAssertTrue(host.contains("bridgeConversationCanvas(compact: compact)"))
        XCTAssertTrue(host.contains(".opacity(0.001)"))
        XCTAssertTrue(host.contains(".allowsHitTesting(false)"))
        XCTAssertTrue(host.contains("agentChat.activatePortalSession(summary)"))
        XCTAssertTrue(compactPortal.contains("AgentPortalContextSnapshot.mini("))
        XCTAssertTrue(compactPortal.contains("AgentCloneBridge.submitPrompt(portalContext.agentClonePromptEnvelope(userPrompt: trimmed))"))
        XCTAssertTrue(compactPortal.contains("AgentPortalRouteRequest.post(portalContext)"))
        XCTAssertTrue(compactPortal.contains("agentChat.recentPortalSessions.prefix(4)"))
        XCTAssertTrue(compactPortal.contains("agentChat.activatePortalSession(summary)"))
        XCTAssertTrue(compactPortal.contains("compactContextBar"))
        XCTAssertTrue(compactPortal.contains("compactActionChips"))
        XCTAssertTrue(compactPortal.contains("compactSubmissionPortalContext"))
        XCTAssertTrue(compactPortal.contains("appendCompactAppContextSnapshotIntent()"))
        XCTAssertTrue(compactPortal.contains("compactActionDescriptors"))
        XCTAssertTrue(compactPortal.contains("appendCompactActionIntent(_ action: AgentPortalContextSnapshot.ActionDescriptor)"))
        XCTAssertTrue(compactPortal.contains("compactActionHelp(_ action: AgentPortalContextSnapshot.ActionDescriptor)"))
        XCTAssertTrue(compactPortal.contains("Use this Epistemos compact portal context:"))
        XCTAssertTrue(utilityWindows.contains("case agent"))
        XCTAssertTrue(utilityWindows.contains("AgentCompactPortalView()"))
        XCTAssertTrue(graphWorkspace.contains("AgentPortalContextSnapshot.graph("))
        XCTAssertTrue(noteWorkspace.contains("AgentPortalContextSnapshot.note("))
        XCTAssertTrue(noteWorkspace.contains("AgentPortalRouteRequest.post(portalContext)"))
        XCTAssertTrue(chatTypes.contains("case graph"))
        XCTAssertFalse(portal.contains("ChatState"))
        XCTAssertFalse(portal.contains("ChatCoordinator"))
        XCTAssertFalse(compactPortal.contains("MiniChat"))
        XCTAssertFalse(compactPortal.contains("ChatCoordinator"))
        XCTAssertFalse(graphWorkspace.contains("GraphChatRequest"))
        XCTAssertFalse(noteWorkspace.contains("NoteChatState"))
        XCTAssertFalse(noteWorkspace.contains("NoteChatSidebar"))
        XCTAssertTrue(snapshot.contains("var vaultPath: String?"))
        XCTAssertTrue(snapshot.contains("var modelVisibleJSON: String"))
        XCTAssertFalse(snapshot.contains("appSupportPath: appSupportPath"))
        XCTAssertTrue(snapshot.contains(#"presentation: String = "main""#))
        XCTAssertTrue(host.contains("let context: AgentCloneAppContextSnapshot"))
        XCTAssertTrue(host.contains("context.modelVisibleSummary"))
        XCTAssertTrue(host.contains("context.vaultPath"))
        XCTAssertTrue(host.contains("context.workspacePath"))
        XCTAssertTrue(root.contains("workspacePath: Self.workWorkspaceURL.path"))
        XCTAssertTrue(root.contains("vaultPath: vaultSync.vaultURL?.path"))
        XCTAssertTrue(root.contains("private static var agentCloneSupportURL"))
        XCTAssertTrue(root.contains("AgentCloneAppContextSnapshot.defaultAppSupportPath("))
        XCTAssertTrue(root.contains("appSupportPath: Self.agentCloneSupportURL.path"))
        XCTAssertTrue(root.contains("modeLabel: workspaceMode.defaultLabel"))
        XCTAssertTrue(root.contains("portalContext: agentChat.activePortalContext"))
        XCTAssertTrue(root.contains("let snapshot = agentCloneContextSnapshot"))
        XCTAssertTrue(root.contains("workspaceRootPath: snapshot.workspacePath"))
        XCTAssertTrue(root.contains("vaultRootPath: snapshot.vaultPath"))
        XCTAssertTrue(root.contains("appSupportRootPath: snapshot.appSupportPath"))
        XCTAssertTrue(root.contains("mode: snapshot.modeLabel"))
        XCTAssertTrue(root.contains("presentation: snapshot.bridgePresentation"))
        XCTAssertTrue(root.contains("guard workspaceMode != .work else { return }"))
        XCTAssertTrue(root.contains("WorkspaceModeSelection.didSelectNotification"))
        XCTAssertTrue(root.contains("WorkspaceModeSelection.selectedModeUserInfoKey"))
        XCTAssertTrue(root.contains("workspaceMode = candidate"))
        XCTAssertTrue(root.contains("if candidate != .work {\n                syncAgentCloneHostContext()"))

        XCTAssertTrue(landing.contains("@Environment(AgentChatState.self)"))
        XCTAssertTrue(landing.contains("import AgentClone"))
        XCTAssertTrue(landing.contains("WorkspaceModeSelection.select(.act)"))
        XCTAssertTrue(landing.contains("AgentPortalContextSnapshot.landing("))
        XCTAssertTrue(landing.contains("agentChat.startNewSession(portalContext: portalContext)"))
        XCTAssertTrue(landing.contains("agentChat.submitAgentQuery(trimmed, portalContext: portalContext)"))
        XCTAssertFalse(landing.contains("agentChat.submitAgentQuery(trimmed)\n"))
        XCTAssertTrue(landing.contains("AgentCloneBridge.updateHostContext(AgentCloneHostContext("))
        XCTAssertTrue(landing.contains("AgentCloneAppContextSnapshot.defaultAppSupportPath("))
        XCTAssertTrue(landing.contains("presentation: agentChat.activePortalContext?.bridgePresentation"))
        XCTAssertTrue(landing.contains("AgentCloneBridge.submitPrompt(portalContext.agentClonePromptEnvelope(userPrompt: trimmed))"))
        XCTAssertFalse(landing.contains("if isActSearchPage {\n            AgentCloneBridge.submitPrompt(trimmed)"))
        XCTAssertFalse(landing.contains("submitActOsaurusPrompt"))
        XCTAssertFalse(landing.contains("ActOsaurusPromptRequest"))
        XCTAssertFalse(landing.contains("showActOsaurusSettings"))
        XCTAssertTrue(graph.contains("old graph-chat"))
        XCTAssertFalse(graph.contains("name: .submitActOsaurusPrompt"))
        XCTAssertTrue(workspaceModeSelection.contains("didSelectNotification"))
        XCTAssertTrue(workspaceModeSelection.contains("selectedModeUserInfoKey"))
        XCTAssertTrue(workspaceModeSelection.contains(#"Notification.Name("epistemos.workspace.mode.didSelect")"#))
        XCTAssertTrue(workspaceModeSelection.contains("NotificationCenter.default.post("))
        XCTAssertTrue(workspaceModeSelection.contains("object: defaults"))
        XCTAssertTrue(workspaceModeSelection.contains("userInfo: [selectedModeUserInfoKey: mode.rawValue]"))

        XCTAssertTrue(agentBridge.contains("public enum AgentCloneBridge"))
        XCTAssertTrue(agentBridge.contains("public struct AgentCloneHostContext"))
        XCTAssertTrue(agentBridge.contains("public var appSupportRootPath: String?"))
        XCTAssertTrue(agentBridge.contains("public var presentation: String?"))
        XCTAssertTrue(agentBridge.contains("Notification.Name(\"epistemos.agentclone.submitPrompt\")"))
        XCTAssertTrue(agentBridge.contains("Notification.Name(\"epistemos.agentclone.hostContext\")"))
        XCTAssertTrue(agentBridge.contains("currentHostContext"))
        XCTAssertTrue(agentBridge.contains("AgentClonePendingPrompt"))
        XCTAssertTrue(agentBridge.contains("AgentClonePendingPromptStore"))
        XCTAssertTrue(agentBridge.contains("pendingPromptStore"))
        XCTAssertTrue(agentBridge.contains("@discardableResult"))
        XCTAssertTrue(agentBridge.contains("public static func submitPrompt(_ prompt: String) -> UUID"))
        XCTAssertTrue(agentBridge.contains("promptIDUserInfoKey"))
        XCTAssertTrue(agentBridge.contains("markPromptConsumed(id: UUID)"))
        XCTAssertTrue(agentBridge.contains("drainPendingPrompts() -> [AgentClonePendingPrompt]"))
        XCTAssertTrue(agentBridge.contains("updateHostContext(_ context: AgentCloneHostContext)"))
        XCTAssertTrue(agentBridge.contains(#"parts.append("vault: \(vaultRootPath)")"#))
        XCTAssertTrue(agentBridge.contains(#"parts.append("workspace: \(workspaceRootPath)")"#))
        XCTAssertTrue(agentBridge.contains(#"parts.append("surface: \(presentation)")"#))
        XCTAssertTrue(agentBridge.contains("vaultRootPath ?? workspaceRootPath"))
        XCTAssertFalse(agentBridge.contains("} else if let workspaceRootPath {"))
        XCTAssertTrue(agentContent.contains("AgentCloneBridge.submitPromptNotification"))
        XCTAssertTrue(agentContent.contains("AgentCloneBridge.hostContextNotification"))
        XCTAssertTrue(agentContent.contains("private func submitBridgePrompt"))
        XCTAssertTrue(agentContent.contains("drainPendingBridgePrompts()"))
        XCTAssertTrue(agentContent.contains("AgentCloneBridge.markPromptConsumed(id: promptID)"))
        XCTAssertTrue(agentContent.contains("AgentCloneBridge.drainPendingPrompts()"))
        XCTAssertTrue(agentContent.contains("submitBridgePromptText(pendingPrompt.text)"))
        XCTAssertTrue(agentContent.contains("private func applyBridgeHostContext"))
        XCTAssertTrue(agentContent.contains("private func applyCurrentHostContext"))
        XCTAssertTrue(agentContent.contains("applyCurrentHostContext()\n            drainPendingBridgePrompts()"))
        XCTAssertTrue(agentContent.contains("viewModel.applyEpistemosHostContext(context)"))
        XCTAssertTrue(agentContent.contains("EpistemosHostContextRow(summary: viewModel.epistemosHostContextSummary)"))
        XCTAssertTrue(agentContent.contains("Text(\"Epistemos context\")"))
        XCTAssertTrue(agentContent.contains("viewModel.runTabTask(tab: tab)"))
        XCTAssertTrue(agentContent.contains("viewModel.run()"))
        XCTAssertFalse(agentContent.contains("if !tab.isLLMRunning {\n                viewModel.runTabTask(tab: tab)"))
        XCTAssertFalse(agentContent.contains("if !viewModel.isRunning {\n            viewModel.run()"))
        XCTAssertTrue(agentHostContext.contains("func applyEpistemosHostContext(_ context: AgentCloneHostContext)"))
        XCTAssertTrue(agentHostContext.contains("epistemosHostContextSummary = context.summary"))
        XCTAssertTrue(agentHostContext.contains("SessionStore.shared.applyEpistemosHostContext(context)"))
        XCTAssertTrue(agentHostContext.contains("context.preferredProjectFolder"))
        XCTAssertTrue(agentHostContext.contains("epistemos.agentclone.lastAppliedHostProjectFolder"))
        XCTAssertTrue(agentHostContext.contains("currentFolder == lastHostFolder"))
        XCTAssertTrue(agentHostContext.contains("RecentFoldersService.shared.addFolder(resolvedFolder)"))
        XCTAssertTrue(sessionStore.contains("func applyEpistemosHostContext(_ context: AgentCloneHostContext)"))
        XCTAssertTrue(sessionStore.contains("context.appSupportRootPath"))
        XCTAssertTrue(sessionStore.contains(#"appendingPathComponent("sessions", isDirectory: true)"#))
        XCTAssertTrue(sessionStore.contains("legacySessionsDir"))
        XCTAssertTrue(sessionStore.contains(#"Documents/AgentScript/sessions"#))
        XCTAssertTrue(sessionStore.contains("importLegacySessionsIfNeeded()"))
        XCTAssertTrue(sessionStore.contains("migrateSessionIfNeeded(from: url)"))
        XCTAssertTrue(taskUtilities.contains("hostContextSummary: String = \"\""))
        XCTAssertTrue(taskUtilities.contains("[Epistemos context: \\(trimmedHostContext)]"))
        XCTAssertTrue(taskExecution.contains("hostContextSummary: epistemosHostContextSummary"))
        XCTAssertTrue(tabLLMServices.contains("hostContextSummary: epistemosHostContextSummary"))
    }

    func testAgentCloneForegroundDirectoriesHideDonorRuntimeNames() throws {
        let foregroundFiles = agentCloneForegroundSwiftSourcePaths()
        XCTAssertFalse(foregroundFiles.isEmpty)

        let forbiddenForegroundLiteralPattern =
            #""(?:[^"\\\n]|\\.)*(Agent!|AgentClone|Agent Question|User Agent|Background Agents|Daemon|OpenCode|Goose|Osaurus)(?:[^"\\\n]|\\.)*""#
        for path in foregroundFiles {
            let contents = try sourceContents(path)
            XCTAssertNil(
                contents.range(of: forbiddenForegroundLiteralPattern, options: .regularExpression),
                "\(path) has a donor/runtime name in a quoted foreground literal"
            )
        }
    }

    func testAgentCloneHelpResourcesUseEpistemosForegroundNames() throws {
        let helpFiles = agentCloneHelpHTMLSourcePaths()
        XCTAssertFalse(helpFiles.isEmpty)

        let forbiddenHelpText = [
            "Agent!",
            "Agent Help",
            "Agent Scripts",
            "Privileged Daemon",
            "Settings → Daemon",
            "Launch Daemon",
            "User Agent",
            "Background Agents",
            "Agent Question",
            "OpenCode",
            "Goose",
            "Osaurus",
        ]

        for path in helpFiles {
            let contents = try sourceContents(path)
            for token in forbiddenHelpText {
                XCTAssertFalse(contents.contains(token), "\(path) contains stale help token \(token)")
            }
        }
    }

    func testAgentCloneProtectedRuntimeContractsStayDonorCompatible() throws {
        let systemPrompt = try sourceContents("LocalPackages/AgentClone/Sources/AgentClone/Services/SystemPromptService.swift")
        let keychain = try sourceContents("LocalPackages/AgentClone/Sources/AgentClone/Services/KeychainService.swift")
        let scriptService = try sourceContents("LocalPackages/AgentClone/Sources/AgentClone/Services/ScriptService.swift")
        let scriptExecution = try sourceContents("LocalPackages/AgentClone/Sources/AgentClone/Services/ScriptService+Execution.swift")
        let shellSafety = try sourceContents("LocalPackages/AgentClone/Sources/AgentClone/Services/ShellSafetyService.swift")
        let helperService = try sourceContents("LocalPackages/AgentClone/Sources/AgentClone/Services/HelperService.swift")
        let viewModel = try sourceContents("LocalPackages/AgentClone/Sources/AgentClone/AgentViewModel/Core/AgentViewModel.swift")
        let setup = try sourceContents("LocalPackages/AgentClone/Sources/AgentClone/AgentViewModel/TaskExecution/Setup.swift")
        let bridge = try sourceContents("LocalPackages/AgentClone/Sources/AgentClone/EpistemosAgentBridge.swift")

        XCTAssertTrue(systemPrompt.contains(#"private static let versionPrefix = "// Agent! v""#))
        XCTAssertTrue(systemPrompt.contains(#"private static let customPrefix = "// Agent! custom v""#))
        XCTAssertTrue(systemPrompt.contains(#"private static let readOnlyPrefix = "// Agent! READ ONLY v""#))
        XCTAssertTrue(systemPrompt.contains(#"Documents/AgentScript/system"#))

        XCTAssertTrue(keychain.contains(#"kSecAttrService as String: "Agent!""#))
        XCTAssertTrue(keychain.contains(#"private static let claudeAPIKey = "agent.claudeAPIKey""#))
        XCTAssertTrue(keychain.contains(#"private static let openRouterAPIKey = "com.agent.openrouter-api-key""#))

        XCTAssertTrue(scriptService.contains(#"https://github.com/macOS26/AgentScripts.git"#))
        XCTAssertTrue(scriptService.contains(#"Documents/AgentScript/agents"#))
        XCTAssertTrue(scriptExecution.contains(#"env["AGENT_PROJECT_FOLDER"] = cwdPath"#))
        XCTAssertTrue(viewModel.contains(#"forKey: "agentProjectFolder""#))

        XCTAssertTrue(shellSafety.contains("case rootDaemon"))
        XCTAssertTrue(helperService.contains("enum SafeSMAppServiceDaemon"))
        XCTAssertTrue(bridge.contains(#"Notification.Name("epistemos.agentclone.submitPrompt")"#))
        XCTAssertTrue(bridge.contains(#"Notification.Name("epistemos.agentclone.hostContext")"#))

        XCTAssertTrue(setup.contains("ClaudeService"))
        XCTAssertTrue(setup.contains("CodexService"))
        XCTAssertTrue(setup.contains("OpenAICompatibleService"))
        XCTAssertTrue(setup.contains("OllamaService"))
        XCTAssertTrue(setup.contains("FoundationModelService"))
    }

    private func repositoryRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func sourceContents(_ path: String) throws -> String {
        let url = URL(fileURLWithPath: path, relativeTo: repositoryRootURL()).standardizedFileURL
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "Source path missing: \(path)")
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func sourcePathExists(_ path: String) -> Bool {
        let url = URL(fileURLWithPath: path, relativeTo: repositoryRootURL()).standardizedFileURL
        return FileManager.default.fileExists(atPath: url.path)
    }

    private func agentCloneForegroundSwiftSourcePaths() -> [String] {
        let roots = [
            "LocalPackages/AgentClone/Sources/AgentClone/Views",
            "LocalPackages/AgentClone/Sources/AgentClone/DependencyChecker",
        ]
        let repositoryRoot = repositoryRootURL()
        let fileManager = FileManager.default
        var paths = roots.flatMap { root -> [String] in
            let rootURL = URL(fileURLWithPath: root, relativeTo: repositoryRoot).standardizedFileURL
            guard let enumerator = fileManager.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                return []
            }
            return enumerator.compactMap { item in
                guard let url = item as? URL, url.pathExtension == "swift" else {
                    return nil
                }
                let path = url.standardizedFileURL.path
                return String(path.dropFirst(repositoryRoot.path.count + 1))
            }
        }
        paths.append("LocalPackages/AgentClone/Sources/AgentClone/AgentApp.swift")
        return paths.sorted()
    }

    private func agentCloneHelpHTMLSourcePaths() -> [String] {
        let root = "LocalPackages/AgentClone/Sources/AgentClone/Resources/Agent.help/Contents/Resources/en.lproj"
        let repositoryRoot = repositoryRootURL()
        let rootURL = URL(fileURLWithPath: root, relativeTo: repositoryRoot).standardizedFileURL
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return enumerator.compactMap { item in
            guard let url = item as? URL, url.pathExtension == "html" else {
                return nil
            }
            let path = url.standardizedFileURL.path
            return String(path.dropFirst(repositoryRoot.path.count + 1))
        }.sorted()
    }

    private func appSwiftSourcePathsForDeletedChatScan() -> [String] {
        let roots = [
            "Epistemos/App",
            "Epistemos/Bridge",
            "Epistemos/Engine",
            "Epistemos/Graph",
            "Epistemos/LocalAgent",
            "Epistemos/Models",
            "Epistemos/State",
            "Epistemos/Views",
        ]
        let repositoryRoot = repositoryRootURL()
        let fileManager = FileManager.default
        return roots.flatMap { root -> [String] in
            let rootURL = URL(fileURLWithPath: root, relativeTo: repositoryRoot).standardizedFileURL
            guard let enumerator = fileManager.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                return []
            }
            return enumerator.compactMap { item in
                guard let url = item as? URL, url.pathExtension == "swift" else {
                    return nil
                }
                let path = url.standardizedFileURL.path
                return String(path.dropFirst(repositoryRoot.path.count + 1))
            }
        }
    }

    private func mohawkTrainingAssetPathsForDeletedChatScan() -> [String] {
        let root = "Epistemos/KnowledgeFusion/MOHAWK"
        let repositoryRoot = repositoryRootURL()
        let rootURL = URL(fileURLWithPath: root, relativeTo: repositoryRoot).standardizedFileURL
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let allowedExtensions = Set(["py", "json", "jsonl"])
        return enumerator.compactMap { item in
            guard let url = item as? URL, allowedExtensions.contains(url.pathExtension) else {
                return nil
            }
            let path = url.standardizedFileURL.path
            return String(path.dropFirst(repositoryRoot.path.count + 1))
        }.sorted()
    }

    private struct AgentKitMCPTestInput: Codable, Equatable, Sendable {
        var message: String
    }

    private enum AgentKitErgonomicsTestError: Error, Sendable {
        case transient
        case permanent
    }

    private actor SwiftAIModelRecorder {
        private var flags: [Bool] = []
        private var prompts: [String] = []

        func record(prompt: String, allowTools: Bool) {
            prompts.append(prompt)
            flags.append(allowTools)
        }

        var allowToolsFlags: [Bool] {
            flags
        }
    }
}
