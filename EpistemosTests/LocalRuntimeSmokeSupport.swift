import Darwin.Mach
import Testing
@testable import Epistemos

enum LocalRuntimeSmokeSupport {
    @MainActor
    static func runLiveQwen35Smoke() async throws {
        let bootstrap = try await makePreparedBootstrap()

        let llm = TriageIntegrationMockLLMClient()
        let triage = TriageService(
            inference: bootstrap.inferenceState,
            localLLMService: bootstrap.localLLMClient
        )

        await bootstrap.localInferenceService.unload()

        let autoPrompt = "Compare Bayesian and evidential decision theory in two short paragraphs."
        let autoDecision = triage.triageGeneral(
            operation: .chatResponse(query: autoPrompt),
            contentLength: autoPrompt.count
        )
        #expect(autoDecision == .localMLX)
        let autoOutput = try await triage.generateGeneral(
            prompt: autoPrompt,
            systemPrompt: "Be concise, accurate, and direct.",
            operation: .chatResponse(query: autoPrompt),
            contentLength: autoPrompt.count
        )
        #expect(!autoOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        let coldProfile = await bootstrap.localInferenceService.profilingSnapshot()
        #expect(coldProfile?.coldLoad == true)

        bootstrap.inferenceState.routingMode = .localOnly
        let localPrompt = "Explain the main cause of tides in under 80 words."
        let localDecision = triage.triageGeneral(
            operation: .chatResponse(query: localPrompt),
            contentLength: localPrompt.count
        )
        #expect(localDecision == .localMLX)
        let localOutput = try await triage.generateGeneral(
            prompt: localPrompt,
            systemPrompt: "Answer briefly and clearly.",
            operation: .chatResponse(query: localPrompt),
            contentLength: localPrompt.count
        )
        #expect(!localOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        let warmProfile = await bootstrap.localInferenceService.profilingSnapshot()
        #expect(warmProfile?.coldLoad == false)

        let cappedPrompt = """
        Write a numbered list from 1 to 10 naming distinct epistemology concepts.
        Each item must be a short sentence, not just a phrase.
        """
        let cappedOutput = try await bootstrap.localLLMClient.generate(
            prompt: cappedPrompt,
            systemPrompt: "Answer with a clean numbered list and finish the list completely.",
            maxTokens: 32,
            reasoningMode: .fast
        )
        let cappedProfile = await bootstrap.localInferenceService.profilingSnapshot()
        #expect(!cappedOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(!(cappedOutput.contains("[Local response reached the current generation limit before finishing.]")))
        #expect((cappedProfile?.continuationCount ?? 0) == 0)
        #expect(cappedProfile?.stopReason == "stop" || cappedProfile?.stopReason == "length")

        let rawThinkingOutcome = await collect(
            bootstrap.localLLMClient.stream(
                prompt: "Explain briefly why ice floats on water.",
                systemPrompt: "Think through density and hydrogen bonding first, then answer.",
                maxTokens: 256,
                reasoningMode: .thinking
            )
        )
        if let error = rawThinkingOutcome.error {
            throw error
        }
        let rawThinkingText = rawThinkingOutcome.tokens.joined()
        #expect(!rawThinkingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        let pipelineState = PipelineState()
        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: llm,
            triageService: triage,
            inference: bootstrap.inferenceState,
            eventBus: EventBus()
        )

        var visibleText = ""
        for try await event in pipeline.run(
            query: "Explain why ice floats on water. Think through it first, then give the answer.",
            mode: .api
        ) {
            if case .textDelta(let delta) = event {
                visibleText += delta
            }
        }
        #expect(!visibleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        await bootstrap.localInferenceService.unload()
        try? await Task.sleep(for: .milliseconds(250))

        let baselineMemory = currentMemoryUsage()
        await bootstrap.graphState.loadGraph(container: bootstrap.modelContainer)
        let graphLoadedMemory = currentMemoryUsage()

        bootstrap.inferenceState.routingMode = .localOnly

        let noteChat = NoteChatState(pageId: "local-qwen35-live-smoke")
        noteChat.noteBodyProvider = {
            String(repeating: "Bayesian updating, coherentism, and note synthesis. ", count: 1_200)
        }
        noteChat.submitQuery(
            "Summarize the note's main disagreement in five bullets.",
            triageService: triage
        )

        var peakMemory = graphLoadedMemory
        let deadline = Date().addingTimeInterval(120)
        while noteChat.isStreaming && Date() < deadline {
            peakMemory = max(peakMemory, currentMemoryUsage())
            try? await Task.sleep(for: .milliseconds(100))
        }
        noteChat.stopStreaming()

        #expect(noteChat.error == nil)
        #expect(!noteChat.responseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        let completedMemory = currentMemoryUsage()
        await bootstrap.localInferenceService.unload()
        try? await Task.sleep(for: .seconds(1))
        let unloadedMemory = currentMemoryUsage()

        print(
            """
            LOCAL_QWEN35_SMOKE memory baseline=\(formattedMemory(baselineMemory)) \
            graph=\(formattedMemory(graphLoadedMemory)) \
            peak=\(formattedMemory(peakMemory)) \
            completed=\(formattedMemory(completedMemory)) \
            unloaded=\(formattedMemory(unloadedMemory)) \
            graphNodes=\(bootstrap.graphState.store.nodeCount)
            """
        )
    }

    @MainActor
    static func runLiveQwen35MemoryProfile() async throws {
        let bootstrap = try await makePreparedBootstrap()
        let triage = TriageService(
            inference: bootstrap.inferenceState,
            localLLMService: bootstrap.localLLMClient
        )

        await bootstrap.localInferenceService.unload()
        try? await Task.sleep(for: .milliseconds(250))

        let baselineMemory = currentMemoryUsage()
        await bootstrap.graphState.loadGraph(container: bootstrap.modelContainer)
        let graphLoadedMemory = currentMemoryUsage()

        bootstrap.inferenceState.routingMode = .localOnly

        let noteChat = NoteChatState(pageId: "local-qwen35-memory-profile")
        noteChat.noteBodyProvider = {
            String(repeating: "Bayesian updating, coherentism, and note synthesis. ", count: 1_200)
        }
        noteChat.submitQuery(
            "Summarize the note's main disagreement in five bullets.",
            triageService: triage
        )

        var peakMemory = graphLoadedMemory
        let deadline = Date().addingTimeInterval(90)
        while noteChat.isStreaming && Date() < deadline {
            peakMemory = max(peakMemory, currentMemoryUsage())
            try? await Task.sleep(for: .milliseconds(100))
        }
        noteChat.stopStreaming()

        #expect(noteChat.error == nil)
        #expect(!noteChat.responseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        let completedMemory = currentMemoryUsage()
        await bootstrap.localInferenceService.unload()
        try? await Task.sleep(for: .seconds(1))
        let unloadedMemory = currentMemoryUsage()

        print(
            """
            LOCAL_QWEN35_SMOKE memory baseline=\(formattedMemory(baselineMemory)) \
            graph=\(formattedMemory(graphLoadedMemory)) \
            peak=\(formattedMemory(peakMemory)) \
            completed=\(formattedMemory(completedMemory)) \
            unloaded=\(formattedMemory(unloadedMemory)) \
            graphNodes=\(bootstrap.graphState.store.nodeCount)
            """
        )
    }

    static func collect(_ stream: AsyncThrowingStream<String, Error>) async -> (tokens: [String], error: (any Error)?) {
        var tokens: [String] = []
        do {
            for try await token in stream {
                tokens.append(token)
            }
            return (tokens, nil)
        } catch {
            return (tokens, error)
        }
    }

    private static func currentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return info.resident_size
    }

    private static func formattedMemory(_ bytes: UInt64) -> String {
        let megabytes = Double(bytes) / 1024 / 1024
        return String(format: "%.2f MB", megabytes)
    }

    @MainActor
    private static func makePreparedBootstrap() async throws -> AppBootstrap {
        let bootstrap = AppBootstrap()
        let modelID = LocalTextModelID.qwen35_4B4Bit.rawValue

        if bootstrap.localModelManager.installRecords[modelID] == nil {
            print("LOCAL_QWEN35_SMOKE install \(modelID)")
            try await bootstrap.localModelManager.install(modelID: modelID)
        } else {
            print("LOCAL_QWEN35_SMOKE already-installed \(modelID)")
        }

        bootstrap.inferenceState.appleIntelligenceAvailable = false
        bootstrap.inferenceState.routingMode = .auto
        bootstrap.inferenceState.preferredLocalTextModelID = modelID
        let nominalConditions = LocalRuntimeConditions(
            lowPowerModeEnabled: false,
            appActive: true,
            thermalState: .nominal
        )
        bootstrap.inferenceState.setLocalRuntimeConditions(nominalConditions)
        bootstrap.localModelManager.refreshFromDisk()
        await bootstrap.localInferenceService.updateRuntimeConditions(nominalConditions)

        #expect(bootstrap.localModelManager.installRecords[modelID] != nil)
        #expect(bootstrap.inferenceState.effectiveLocalTextModelID == modelID)
        return bootstrap
    }
}
