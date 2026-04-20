import AppKit
import Darwin.Mach
import Foundation
import Testing
@testable import Epistemos

@MainActor
private final class LocalRuntimeSmokeMockLLMClient: LLMClientProtocol {
    func generate(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String {
        "mock-generate"
    }

    func stream(prompt: String, systemPrompt: String?, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield("mock-stream")
            continuation.finish()
        }
    }

    func testConnection() async -> ConnectionTestResult {
        ConnectionTestResult(success: true, message: "ok")
    }

    func configSnapshot() -> LLMSnapshot {
        LLMSnapshot(
            provider: .localMLX,
            model: LocalTextModelID.qwen35_4B4Bit.rawValue,
            reasoningMode: .fast
        )
    }
}

enum LocalRuntimeSmokeSupport {
    struct LiveValidationBlockedError: LocalizedError {
        let reason: String
        let underlyingDescription: String

        var errorDescription: String? {
            "Live validation blocked: \(reason)"
        }

        var recoverySuggestion: String? {
            underlyingDescription
        }
    }

    nonisolated static func liveValidationBlockerReason(for error: any Error) -> String? {
        let description = error.localizedDescription
        let lowered = description.lowercased()
        let isHTTP429 = description.contains("Response error (Status 429)")
            || lowered.contains("<h1>429</h1>")
        let isRateLimit = lowered.contains("rate limit")

        guard isHTTP429 || isRateLimit else { return nil }
        return "Hugging Face rate-limited the live model download; rerun once download quota recovers."
    }

    static func supportedReleaseModelIDs(
        snapshot: LocalHardwareCapabilitySnapshot = .current
    ) -> [LocalTextModelID] {
        LocalModelCatalog.textDescriptors
            .compactMap { LocalTextModelID(rawValue: $0.id) }
            .filter(\.isReleaseValidatedForInteractiveChat)
            .filter { snapshot.supports(textModelID: $0.rawValue) }
            .sorted { lhs, rhs in
                if lhs.minimumRecommendedMemoryGB == rhs.minimumRecommendedMemoryGB {
                    return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
                }
                return lhs.minimumRecommendedMemoryGB < rhs.minimumRecommendedMemoryGB
            }
    }

    static func selectedReleaseSweepModelIDs(
        snapshot: LocalHardwareCapabilitySnapshot = .current,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        overrideFileURL: URL = URL(fileURLWithPath: "/tmp/epi-local-model-sweep-models.txt")
    ) -> [LocalTextModelID] {
        guard let rawOverride = environment["EPI_LOCAL_MODEL_SWEEP_MODELS"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !rawOverride.isEmpty else {
            guard let fileOverride = try? String(contentsOf: overrideFileURL, encoding: .utf8),
                  !fileOverride.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return supportedReleaseModelIDs(snapshot: snapshot)
            }
            return requestedReleaseSweepModelIDs(from: fileOverride, snapshot: snapshot)
        }

        return requestedReleaseSweepModelIDs(from: rawOverride, snapshot: snapshot)
    }

    private static func requestedReleaseSweepModelIDs(
        from rawOverride: String,
        snapshot: LocalHardwareCapabilitySnapshot
    ) -> [LocalTextModelID] {
        let requested = rawOverride
            .split(whereSeparator: { $0 == "," || $0 == "\n" })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .compactMap(LocalTextModelID.init(rawValue:))
            .filter { snapshot.supports(textModelID: $0.rawValue) }
            .filter { LocalModelCatalog.descriptor(for: $0.rawValue) != nil }

        return requested.isEmpty ? supportedReleaseModelIDs(snapshot: snapshot) : requested
    }

    @MainActor
    static func runLiveQwen35Smoke() async throws {
        let bootstrap = try await preparedBootstrap(for: LocalTextModelID.qwen35_4B4Bit.rawValue)

        let llm = LocalRuntimeSmokeMockLLMClient()
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
        let bootstrap = try await preparedBootstrap(for: LocalTextModelID.qwen35_4B4Bit.rawValue)
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
    static func preparedBootstrap(for modelID: String) async throws -> AppBootstrap {
        let bootstrap = AppBootstrap()
        _ = try await verifyLiveInstall(modelID: modelID, bootstrap: bootstrap)

        bootstrap.inferenceState.appleIntelligenceAvailable = false
        bootstrap.inferenceState.routingMode = .auto
        bootstrap.inferenceState.preferredLocalTextModelID = modelID
        bootstrap.inferenceState.setPreferredChatModelSelection(.localMLX(modelID))
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

    @MainActor
    static func verifyLiveInstall(
        modelID: String,
        bootstrap: AppBootstrap
    ) async throws -> LocalModelInstallRecord {
        if bootstrap.localModelManager.installRecords[modelID] == nil {
            print("LOCAL_MODEL_INSTALL_SMOKE install \(modelID)")
            do {
                try await bootstrap.localModelManager.install(modelID: modelID)
            } catch {
                if let blockerReason = liveValidationBlockerReason(for: error) {
                    print("LOCAL_MODEL_INSTALL_SMOKE blocked model=\(modelID) reason=\(blockerReason)")
                    throw LiveValidationBlockedError(
                        reason: blockerReason,
                        underlyingDescription: error.localizedDescription
                    )
                }
                throw error
            }
        } else {
            print("LOCAL_MODEL_INSTALL_SMOKE already-installed \(modelID)")
        }

        bootstrap.localModelManager.refreshFromDisk()

        let descriptor = try #require(LocalModelCatalog.descriptor(for: modelID))
        let record = try #require(bootstrap.localModelManager.installRecords[modelID])
        let activeDirectory = bootstrap.localModelManager.paths.activeDirectory(for: descriptor)

        #expect(record.activeDirectoryURL == activeDirectory)
        #expect(record.revision == descriptor.revision)
        #expect(FileManager.default.fileExists(atPath: activeDirectory.path))
        #expect(FileManager.default.fileExists(atPath: activeDirectory.appendingPathComponent("config.json").path))
        let hasTokenizer = [
            "tokenizer.json",
            "tokenizer.model",
            "vocab.json",
        ].contains { name in
            FileManager.default.fileExists(atPath: activeDirectory.appendingPathComponent(name).path)
        }
        #expect(hasTokenizer)

        let safetensorFiles = try FileManager.default.contentsOfDirectory(at: activeDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "safetensors" }
        #expect(!safetensorFiles.isEmpty)
        #expect(bootstrap.inferenceState.installedLocalTextModelIDs.contains(modelID))

        let manifestData = try Data(contentsOf: bootstrap.localModelManager.paths.manifestURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(LocalModelInstallManifest.self, from: manifestData)
        #expect(manifest.records.contains { $0.modelID == modelID })

        let probe = try await bootstrap.localLLMClient.generate(
            prompt: "Reply with exactly: OK",
            systemPrompt: nil,
            maxTokens: 16,
            reasoningMode: .fast,
            modelID: modelID
        )
        #expect(!probe.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        print(
            "LOCAL_MODEL_INSTALL_SMOKE ready model=\(modelID) size=\(record.sizeBytes) files=\(safetensorFiles.count)"
        )
        return record
    }

    @MainActor
    static func verifyLiveSSMStateRoundTrip(
        modelID: String,
        bootstrap: AppBootstrap
    ) async throws {
        bootstrap.localModelManager.refreshFromDisk()
        guard bootstrap.localModelManager.installRecords[modelID] != nil else {
            print("LOCAL_SSM_SMOKE skipped model=\(modelID) reason=preinstalled model required")
            return
        }

        try await withTimedMainActorBridge(seconds: 180) {
            try await performLiveSSMStateRoundTrip(
                modelID: modelID,
                bootstrap: bootstrap
            )
        }
    }

    @MainActor
    private static func performLiveSSMStateRoundTrip(
        modelID: String,
        bootstrap: AppBootstrap
    ) async throws {
        _ = try await verifyLiveInstall(modelID: modelID, bootstrap: bootstrap)
        await bootstrap.localInferenceService.unload()

        let previousEnabled = bootstrap.epistemosConfig.ssmStatePersistenceEnabled
        let previousAutoSave = bootstrap.epistemosConfig.ssmAutoSaveOnTurnEnd
        defer {
            bootstrap.epistemosConfig.ssmStatePersistenceEnabled = previousEnabled
            bootstrap.epistemosConfig.ssmAutoSaveOnTurnEnd = previousAutoSave
            bootstrap.ssmStateService.activate(enabled: previousEnabled)
        }

        bootstrap.epistemosConfig.ssmStatePersistenceEnabled = true
        bootstrap.epistemosConfig.ssmAutoSaveOnTurnEnd = true
        bootstrap.ssmStateService.activate(enabled: true)
        await bootstrap.localInferenceService.setSsmStateService(bootstrap.ssmStateService)

        let vaultRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: vaultRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: vaultRoot) }

        let sessionID = UUID().uuidString
        await bootstrap.localInferenceService.setActiveSessionID(sessionID)
        await bootstrap.localInferenceService.setActiveVaultRoot(vaultRoot)

        let firstReply = try await bootstrap.localLLMClient.generate(
            prompt: "Reply with one short sentence about why recurrent state helps long sessions.",
            systemPrompt: "Be brief and direct.",
            maxTokens: 48,
            reasoningMode: .fast,
            modelID: modelID
        )
        #expect(!firstReply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(bootstrap.ssmStateService.lastSaveDurationMS > 0)

        let firstSavedState = try #require(
            bootstrap.ssmStateService.findLatestState(modelId: modelID, sessionId: sessionID)
        )
        #expect(FileManager.default.fileExists(atPath: firstSavedState.path))
        #expect(firstSavedState.pathExtension == "safetensors")

        let resumedBootstrap = AppBootstrap()
        _ = try await verifyLiveInstall(modelID: modelID, bootstrap: resumedBootstrap)
        await resumedBootstrap.localInferenceService.unload()

        let resumedPreviousEnabled = resumedBootstrap.epistemosConfig.ssmStatePersistenceEnabled
        let resumedPreviousAutoSave = resumedBootstrap.epistemosConfig.ssmAutoSaveOnTurnEnd
        defer {
            resumedBootstrap.epistemosConfig.ssmStatePersistenceEnabled = resumedPreviousEnabled
            resumedBootstrap.epistemosConfig.ssmAutoSaveOnTurnEnd = resumedPreviousAutoSave
            resumedBootstrap.ssmStateService.activate(enabled: resumedPreviousEnabled)
        }

        resumedBootstrap.epistemosConfig.ssmStatePersistenceEnabled = true
        resumedBootstrap.epistemosConfig.ssmAutoSaveOnTurnEnd = true
        resumedBootstrap.ssmStateService.activate(enabled: true)
        await resumedBootstrap.localInferenceService.setSsmStateService(
            resumedBootstrap.ssmStateService
        )
        await resumedBootstrap.localInferenceService.setActiveSessionID(sessionID)
        await resumedBootstrap.localInferenceService.setActiveVaultRoot(vaultRoot)

        let resumedReply = try await resumedBootstrap.localLLMClient.generate(
            prompt: "Continue with one short sentence.",
            systemPrompt: "Be brief and direct.",
            maxTokens: 48,
            reasoningMode: .fast,
            modelID: modelID
        )
        #expect(!resumedReply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(resumedBootstrap.ssmStateService.lastLoadDurationMS > 0)
        #expect(resumedBootstrap.ssmStateService.currentSessionStateId == sessionID)

        let resumedState = try #require(
            resumedBootstrap.ssmStateService.findLatestState(modelId: modelID, sessionId: sessionID)
        )
        #expect(FileManager.default.fileExists(atPath: resumedState.path))
        #expect(resumedState.pathExtension == "safetensors")

        print(
            "LOCAL_SSM_SMOKE ready model=\(modelID) session=\(sessionID) save_ms=\(bootstrap.ssmStateService.lastSaveDurationMS) load_ms=\(resumedBootstrap.ssmStateService.lastLoadDurationMS)"
        )
    }

    @MainActor
    static func verifyPickerVisibilityAndSelection(
        modelID: String,
        bootstrap: AppBootstrap
    ) throws {
        let descriptor = try #require(LocalModelCatalog.descriptor(for: modelID))

        #expect(bootstrap.localModelManager.textDescriptors.contains { $0.id == modelID })
        #expect(bootstrap.localModelManager.installRecords[modelID] != nil)
        #expect(bootstrap.inferenceState.hardwareCapabilitySnapshot.supports(descriptor: descriptor))

        bootstrap.inferenceState.setPreferredChatModelSelection(.localMLX(modelID))

        #expect(bootstrap.inferenceState.preferredChatModelSelection == .localMLX(modelID))
        #expect(bootstrap.inferenceState.activeLocalTextModelID == modelID)
        #expect(bootstrap.inferenceState.activeChatModelDisplayName == descriptor.displayName)
        #expect(bootstrap.inferenceState.availableOperatingModes.contains(.fast))

        if let model = LocalTextModelID(rawValue: modelID) {
            #expect(bootstrap.inferenceState.availableOperatingModes.contains(.thinking) == model.supportsThinkingMode)
            #expect(bootstrap.inferenceState.availableOperatingModes.contains(.agent) == model.supportsAgentMode)
        }
    }

    @MainActor
    static func verifyChatQuality(
        modelID: String,
        bootstrap: AppBootstrap
    ) async throws {
        let response = try await bootstrap.localLLMClient.generate(
            prompt: "Why does ice float on water? Answer in one short sentence.",
            systemPrompt: "Be concise, factual, and direct.",
            maxTokens: 96,
            reasoningMode: .fast,
            modelID: modelID
        )
        let final = normalizedVisibleText(from: response)
        let lowered = final.lowercased()

        #expect(!final.isEmpty)
        #expect(
            lowered.contains("density")
                || lowered.contains("less dense")
                || lowered.contains("dense")
        )

        print("LOCAL_MODEL_RELEASE_SWEEP quality model=\(modelID) answer=\(final.replacingOccurrences(of: "\n", with: " "))")
    }

    @MainActor
    static func verifyThinkingMode(
        modelID: String,
        bootstrap: AppBootstrap
    ) async throws {
        guard let model = LocalTextModelID(rawValue: modelID),
              model.supportsThinkingMode else {
            return
        }

        let response = try await bootstrap.localLLMClient.generate(
            prompt: "A library had 9 books, lent out 4, and got 2 back. How many books are there now? Answer with the number only.",
            systemPrompt: "Think it through first, then give only the final number.",
            maxTokens: 96,
            reasoningMode: .thinking,
            modelID: modelID
        )
        let final = normalizedVisibleText(from: response)

        #expect(!final.isEmpty)
        #expect(final.contains("7"))

        print("LOCAL_MODEL_RELEASE_SWEEP thinking model=\(modelID) final=\(final.replacingOccurrences(of: "\n", with: " "))")
    }

    @MainActor
    static func verifyLongContextSanity(
        modelID: String,
        bootstrap: AppBootstrap
    ) async throws {
        let sentinel = uniqueToken(prefix: "TAIL")
        let filler = String(
            repeating: "Context filler about epistemology, graph recall, and vault retrieval. ",
            count: 400
        )
        let prompt = """
        \(filler)

        Decoy code: IGNORE-THIS

        \(filler)

        Tail code: \(sentinel)
        Return the tail code exactly.
        """

        let response = try await bootstrap.localLLMClient.generate(
            prompt: prompt,
            systemPrompt: "Read carefully and return only the requested tail code.",
            maxTokens: 64,
            reasoningMode: .fast,
            modelID: modelID
        )
        let final = normalizedVisibleText(from: response).uppercased()

        #expect(final.contains(sentinel))

        print("LOCAL_MODEL_RELEASE_SWEEP context-window model=\(modelID) sentinel=\(sentinel)")
    }

    @MainActor
    static func verifyContextContract(
        modelID: String,
        bootstrap: AppBootstrap
    ) async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("local-release-context-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let fileSentinel = uniqueToken(prefix: "FILE")
        let noteSentinel = uniqueToken(prefix: "NOTE")
        let chatSentinel = uniqueToken(prefix: "CHAT")
        let fileURL = tempDirectory.appendingPathComponent("release-context.txt", isDirectory: false)
        try """
        Release sweep attachment memo.
        FILE_SENTINEL = \(fileSentinel)
        If asked for the file sentinel, return \(fileSentinel).
        """.write(to: fileURL, atomically: true, encoding: .utf8)

        let attachment = await FileAttachmentBuilder.build(from: fileURL)
        let fileContext = try #require(
            ChatCoordinator.buildFileAttachmentContext(from: [attachment], supportsVision: false)
        )

        let now = Date()
        let manifest = VaultManifest(
            vaultTitle: "Release Sweep",
            totalNoteCount: 1,
            isInventoryComplete: true,
            entries: [
                VaultManifest.ManifestEntry(
                    pageId: "release-note-id",
                    title: "Release Note",
                    tags: [],
                    folderName: "Audit",
                    wordCount: 12,
                    snippet: "Sentinel note",
                    updatedAt: now,
                    createdAt: now
                )
            ],
            recentBodies: [],
            generatedAt: now
        )
        let chatMessages = [
            AssistantMessage(role: .user, content: "Remember CHAT_SENTINEL = \(chatSentinel)"),
            AssistantMessage(role: .assistant, content: "Understood. CHAT_SENTINEL = \(chatSentinel)")
        ]

        let attachedContext = await ChatCoordinator.resolveAttachedContext(
            query: "Return the FILE, NOTE, and CHAT sentinels from the required context.",
            attachments: [
                ContextAttachment(kind: .note, targetId: "release-note-id", title: "Release Note", subtitle: "Audit"),
                ContextAttachment(kind: .chat, targetId: "release-chat-id", title: "Release Chat", subtitle: "Audit"),
            ],
            manifest: manifest,
            includeAllNotesContext: false,
            findNotesByTitle: { title in
                guard title == "Release Note" else { return [] }
                return [
                    VaultManifest.ManifestEntry(
                        pageId: "release-note-id",
                        title: "Release Note",
                        tags: [],
                        folderName: "Audit",
                        wordCount: 12,
                        snippet: "Sentinel note",
                        updatedAt: now,
                        createdAt: now
                    )
                ]
            },
            fetchNoteBodies: { ids in
                guard ids.contains("release-note-id") else { return [] }
                return [
                    VaultManifest.NoteBody(
                        pageId: "release-note-id",
                        title: "Release Note",
                        body: "NOTE_SENTINEL = \(noteSentinel)"
                    )
                ]
            },
            searchNoteIDs: { _ in [] },
            fetchChatMessages: { chatID in
                guard chatID == "release-chat-id" else { return [] }
                return chatMessages
            }
        )

        let mergedContext = [attachedContext.context, fileContext]
            .compactMap { section in
                guard let trimmed = section?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !trimmed.isEmpty else {
                    return nil
                }
                return trimmed
            }
            .joined(separator: "\n\n")

        let output = try await runPipelineQuery(
            bootstrap: bootstrap,
            query: "Return the exact FILE, NOTE, and CHAT sentinels from the required context in the format FILE=<value> NOTE=<value> CHAT=<value>.",
            notesContext: mergedContext
        ).uppercased()

        #expect(output.contains(fileSentinel))
        #expect(output.contains(noteSentinel))
        #expect(output.contains(chatSentinel))

        print("LOCAL_MODEL_RELEASE_SWEEP context model=\(modelID) file=\(fileSentinel) note=\(noteSentinel) chat=\(chatSentinel)")
    }

    @MainActor
    static func verifyVision(
        modelID: String,
        bootstrap: AppBootstrap
    ) async throws {
        guard let model = LocalTextModelID(rawValue: modelID),
              model.supportsVision else {
            return
        }

        let imageURL = try makeSolidColorPNG(color: .systemRed)
        defer { try? FileManager.default.removeItem(at: imageURL.deletingLastPathComponent()) }

        let attachment = await FileAttachmentBuilder.build(from: imageURL)
        let fileContext = try #require(
            ChatCoordinator.buildFileAttachmentContext(from: [attachment], supportsVision: true)
        )

        bootstrap.inferenceState.pendingImageURLs = [imageURL]
        defer { bootstrap.inferenceState.pendingImageURLs = [] }

        let output = try await runPipelineQuery(
            bootstrap: bootstrap,
            query: "The attached image is a solid color. Reply with the lowercase color only.",
            notesContext: fileContext
        ).lowercased()

        #expect(output.contains("red"))

        print("LOCAL_MODEL_RELEASE_SWEEP vision model=\(modelID) answer=\(output.replacingOccurrences(of: "\n", with: " "))")
    }

    @MainActor
    static func verifyAgentMode(
        modelID: String,
        bootstrap: AppBootstrap
    ) async throws {
        guard let model = LocalTextModelID(rawValue: modelID),
              model.canRunLocalAgentLoop else {
            return
        }

        let token = uniqueToken(prefix: "AGENT")
        let recorder = ReleaseSweepToolRecorder()
        let loop = LocalAgentLoop.liveLoop(
            using: bootstrap.localLLMClient,
            constrainedDecoding: bootstrap.constrainedDecoding,
            toolExecutor: { name, argumentsJson in
                await recorder.record(name: name, argumentsJson: argumentsJson)
                return LocalToolResult(
                    toolName: name,
                    resultJson: "{\"name\":\"release_probe\",\"content\":\"\(token)\"}",
                    isError: false
                )
            },
            modelID: modelID,
            defaultReasoningMode: .fast
        )

        let answer = try await loop.run(
            objective: "Call the release_probe tool exactly once. Then answer with the release token from the tool result and nothing else.",
            tools: [
                OmegaToolDefinition(
                    name: "release_probe",
                    agent: "notes",
                    description: "Returns the current release probe token.",
                    argumentsExample: #"{"request":"current"}"#,
                    schemaJson: #"{"type":"object","properties":{"request":{"type":"string"}},"required":["request"]}"#,
                    destructive: false,
                    requiresConfirmation: false
                )
            ],
            maxTurns: 3,
            onToken: { _ in }
        )

        let calls = await recorder.snapshot()
        let final = normalizedVisibleText(from: answer).uppercased()

        #expect(calls.count == 1)
        #expect(calls.first?.0 == "release_probe")
        #expect(final.contains(token))

        print("LOCAL_MODEL_RELEASE_SWEEP agent model=\(modelID) token=\(token)")
    }

    @MainActor
    private static func runPipelineQuery(
        bootstrap: AppBootstrap,
        query: String,
        notesContext: String?,
        operatingMode: EpistemosOperatingMode = .fast
    ) async throws -> String {
        let pipeline = PipelineService(
            pipelineState: PipelineState(),
            llmService: LocalRuntimeSmokeMockLLMClient(),
            triageService: bootstrap.triageService,
            inference: bootstrap.inferenceState,
            eventBus: EventBus()
        )

        var visibleText = ""
        var finalRawAnalysis: String?

        for try await event in pipeline.run(
            query: query,
            mode: .api,
            notesContext: notesContext,
            operatingMode: operatingMode
        ) {
            switch event {
            case .thinkingDelta:
                break
            case .textDelta(let delta):
                visibleText += delta
            case .completed(let dualMessage, _):
                finalRawAnalysis = dualMessage.rawAnalysis
            case .error(let message):
                throw LocalReleaseSweepError.pipelineFailure(message)
            }
        }

        let candidate = visibleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? normalizedVisibleText(from: finalRawAnalysis ?? "")
            : normalizedVisibleText(from: visibleText)
        return candidate
    }

    private static func normalizedVisibleText(from raw: String) -> String {
        UserFacingModelOutput.finalVisibleText(from: raw)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func uniqueToken(prefix: String) -> String {
        let suffix = UUID().uuidString
            .replacingOccurrences(of: "-", with: "")
            .prefix(10)
        return "\(prefix)-\(suffix)".uppercased()
    }

    @MainActor
    private static func makeSolidColorPNG(color: NSColor) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("local-release-vision-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("vision.png", isDirectory: false)

        guard let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 256,
            pixelsHigh: 256,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw LocalReleaseSweepError.imageEncodingFailed
        }

        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: representation) else {
            NSGraphicsContext.restoreGraphicsState()
            throw LocalReleaseSweepError.imageEncodingFailed
        }
        NSGraphicsContext.current = context
        color.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 256, height: 256)).fill()
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        guard let data = representation.representation(using: .png, properties: [:]) else {
            throw LocalReleaseSweepError.imageEncodingFailed
        }
        try data.write(to: url, options: .atomic)
        return url
    }
}

private actor ReleaseSweepToolRecorder {
    private var calls: [(String, String)] = []

    func record(name: String, argumentsJson: String) {
        calls.append((name, argumentsJson))
    }

    func snapshot() -> [(String, String)] {
        calls
    }
}

private enum LocalReleaseSweepError: LocalizedError {
    case pipelineFailure(String)
    case imageEncodingFailed

    var errorDescription: String? {
        switch self {
        case .pipelineFailure(let message):
            return message
        case .imageEncodingFailed:
            return "Failed to encode the temporary release-sweep vision image."
        }
    }
}
