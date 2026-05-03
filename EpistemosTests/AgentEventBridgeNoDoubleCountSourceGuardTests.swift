import Testing

/// Locks the post-PR43 bridge invariant: AgentEvents are emitted at tool or
/// bridge execution boundaries, not inside transport, parser, router, or Swift
/// policy surfaces that would double-count the same action.
@Suite("AgentEvent Bridge No-Double-Count Source Guards")
struct AgentEventBridgeNoDoubleCountSourceGuardTests {
    private static let noInstrumentFiles: [(path: String, reason: String)] = [
        (
            "Epistemos/Bridge/ChunkedMCPFraming.swift",
            "transport framing belongs below MCPBridge policy and tool-call events"
        ),
        (
            "Epistemos/Bridge/CoTStreamInterceptor.swift",
            "thinking-token parsing is cognition telemetry, not a tool action"
        ),
        (
            "Epistemos/Bridge/StreamingDelegate.swift",
            "the delegate is a router; downstream bridges own the event rows"
        ),
        (
            "Epistemos/Bridge/ToolTierBridge.swift",
            "Rust agent_core executes the tool and emits the FFI-backed events"
        ),
    ]

    private static let forbiddenDirectRecordingMarkers = [
        "AgentToolProvenanceRecorder(",
        "AgentToolProvenanceRecorder.",
        "recordToolEvent(",
        "AgentProvenanceEvent(",
    ]

    @Test("no-instrument bridge files do not directly record AgentEvents")
    func noInstrumentBridgeFilesDoNotDirectlyRecordAgentEvents() throws {
        for file in Self.noInstrumentFiles {
            let source = try loadMirroredSourceTextFile(file.path)

            for marker in Self.forbiddenDirectRecordingMarkers {
                #expect(
                    !source.contains(marker),
                    "\(file.path) must not contain \(marker); \(file.reason)"
                )
            }
        }
    }

    @Test("StreamingDelegate stays a thin router to specialized bridge callbacks")
    func streamingDelegateStaysThinRouterToSpecializedBridgeCallbacks() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Bridge/StreamingDelegate.swift")

        #expect(source.contains("executeComputerAction(actionJson: String) -> String"))
        #expect(source.contains("askUserQuestion(questionJson: String) -> String"))
        #expect(source.contains("perceiveApp(appName: String, depth: String) -> String"))
        #expect(source.contains("interactWithApp(actionJson: String) -> String"))
        #expect(source.contains("manageSsmState(actionJson: String) -> String"))
        #expect(!source.contains("recordToolEvent("))
        #expect(!source.contains("AgentToolProvenanceRecorder("))
    }

    @Test("ChunkedMCPFraming stays transport-only")
    func chunkedMCPFramingStaysTransportOnly() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Bridge/ChunkedMCPFraming.swift")

        #expect(source.contains("Content-Length"))
        #expect(source.contains("feedAndResolve"))
        #expect(source.contains("ShmReference"))
        #expect(source.contains("resolveShmReferenceIfNeeded"))
        #expect(!source.contains("recordToolEvent("))
        #expect(!source.contains("AgentToolProvenanceRecorder("))
    }

    @Test("CoTStreamInterceptor stays token parser, not tool timeline emitter")
    func cotStreamInterceptorStaysTokenParserNotToolTimelineEmitter() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Bridge/CoTStreamInterceptor.swift")

        #expect(source.contains("TokenClassification"))
        #expect(source.contains("thinkBlockComplete"))
        #expect(source.contains("responseToken"))
        #expect(source.contains("CoTTextInterceptor"))
        #expect(!source.contains("recordToolEvent("))
        #expect(!source.contains("AgentToolProvenanceRecorder("))
    }

    @Test("ToolTierBridge keeps Swift side as policy and executor bridge only")
    func toolTierBridgeKeepsSwiftSideAsPolicyAndExecutorBridgeOnly() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Bridge/ToolTierBridge.swift")

        #expect(source.contains("ToolSurfacePolicy"))
        #expect(source.contains("toolExecutor() -> LocalAgentToolExecutor"))
        #expect(source.contains("executeToolCallBridged"))
        #expect(source.contains("executeToolCall("))
        #expect(!source.contains("recordToolEvent("))
        #expect(!source.contains("AgentToolProvenanceRecorder("))
    }
}
