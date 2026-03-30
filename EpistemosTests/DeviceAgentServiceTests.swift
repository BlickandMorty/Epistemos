import Testing
@testable import Epistemos

@Suite("Device Agent Service")
struct DeviceAgentServiceTests {
    @MainActor
    @Test("shared GPU backend uses the local agent loop for agent-capable local models")
    func sharedGPUBackendUsesTheLocalAgentLoopForAgentCapableLocalModels() async throws {
        let localClient = RecordingDeviceLocalLLMClient()
        localClient.generateResult = #"{"selector":"//AXButton[@AXTitle='Run']","action":"AXPress","confidence":0.91}"#

        let inference = InferenceState()
        let triage = TriageService(inference: inference, localLLMService: localClient)
        let backend = SharedGPUBackend(
            triageService: triage,
            localModelClient: localClient,
            constrainedDecoding: nil,
            activeModelID: { LocalTextModelID.qwen35_4B4Bit.rawValue }
        )

        let result = try await backend.generate(
            prompt: "AX Tree (JSON): {\"elements\":[]}",
            systemPrompt: "Return ONLY valid JSON.",
            maxTokens: 256
        )

        #expect(result.contains("\"selector\""))
        #expect(localClient.generateRequests.count == 1)
        #expect(localClient.generateRequests[0].prompt.contains("<|im_start|>system"))
        #expect(localClient.generateRequests[0].prompt.contains("No tools are available for this turn."))
        #expect(localClient.generateRequests[0].prompt.contains("Return ONLY valid JSON."))
        #expect(localClient.generateRequests[0].prompt.contains("AX Tree (JSON): {\"elements\":[]}"))
        #expect(localClient.generateRequests[0].systemPrompt == nil)
    }

    @MainActor
    @Test("shared GPU backend falls back to raw local generation for weak local models")
    func sharedGPUBackendFallsBackToRawLocalGenerationForWeakLocalModels() async throws {
        let localClient = RecordingDeviceLocalLLMClient()
        localClient.generateResult = #"{"selector":"fallback","action":"AXPress","confidence":0.52}"#

        let inference = InferenceState()
        let triage = TriageService(inference: inference, localLLMService: localClient)
        let backend = SharedGPUBackend(
            triageService: triage,
            localModelClient: localClient,
            constrainedDecoding: nil,
            activeModelID: { LocalTextModelID.qwen35_2B4Bit.rawValue }
        )

        let result = try await backend.generate(
            prompt: "AX Tree (JSON): {\"elements\":[1]}",
            systemPrompt: "Return ONLY valid JSON.",
            maxTokens: 128
        )

        #expect(result.contains("\"selector\":\"fallback\""))
        #expect(localClient.generateRequests.count == 1)
        #expect(localClient.generateRequests[0].prompt == "AX Tree (JSON): {\"elements\":[1]}")
        #expect(localClient.generateRequests[0].systemPrompt?.contains("Return ONLY valid JSON.") == true)
    }

    @MainActor
    @Test("resolve UI action returns backend metadata for successful results")
    func resolveUIActionReturnsBackendMetadataForSuccessfulResults() async throws {
        let service = DeviceAgentService(hardwareTier: HardwareTierManager())
        service.setBackend(
            StubDeviceBackend(
                name: "StubGPU",
                output: #"{"selector":"//AXButton[@AXTitle='Run']","action":"AXPress","confidence":0.94}"#
            )
        )

        let result = try await service.resolveUIAction(
            axTreeJson: #"{"elements":[{"role":"AXButton","title":"Run"}]}"#,
            userIntent: "Press Run."
        )

        #expect(result.selector == "//AXButton[@AXTitle='Run']")
        #expect(result.backendName == "StubGPU")
        #expect(!result.requiresEscalation)
    }

    @MainActor
    @Test("resolve UI action escalates low-confidence model output")
    func resolveUIActionEscalatesLowConfidenceModelOutput() async {
        let service = DeviceAgentService(hardwareTier: HardwareTierManager())
        service.setBackend(
            StubDeviceBackend(
                name: "StubGPU",
                output: #"{"selector":"//AXButton[@AXTitle='Run']","action":"AXPress","confidence":0.41}"#
            )
        )

        await #expect(throws: DeviceAgentError.self) {
            try await service.resolveUIAction(
                axTreeJson: #"{"elements":[{"role":"AXButton","title":"Run"}]}"#,
                userIntent: "Press Run."
            )
        }
    }

    @MainActor
    @Test("resolve UI action rejects missing selectors")
    func resolveUIActionRejectsMissingSelectors() async {
        let service = DeviceAgentService(hardwareTier: HardwareTierManager())
        service.setBackend(
            StubDeviceBackend(
                name: "StubGPU",
                output: #"{"action":"AXPress","confidence":0.95}"#
            )
        )

        await #expect(throws: DeviceAgentError.self) {
            try await service.resolveUIAction(
                axTreeJson: #"{"elements":[{"role":"AXButton","title":"Run"}]}"#,
                userIntent: "Press Run."
            )
        }
    }
}

@MainActor
private final class RecordingDeviceLocalLLMClient: LocalConfigurableLLMClient {
    struct GenerateRequest: Equatable {
        let prompt: String
        let systemPrompt: String?
        let maxTokens: Int
        let reasoningMode: LocalReasoningMode
        let modelID: String?
    }

    var generateRequests: [GenerateRequest] = []
    var generateResult: String = ""

    func generate(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String {
        try await generate(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            reasoningMode: .fast,
            modelID: nil
        )
    }

    func stream(prompt: String, systemPrompt: String?, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        stream(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            reasoningMode: .fast,
            modelID: nil
        )
    }

    func generate(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        modelID: String?
    ) async throws -> String {
        generateRequests.append(
            GenerateRequest(
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens,
                reasoningMode: reasoningMode,
                modelID: modelID
            )
        )
        return generateResult
    }

    func stream(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        modelID: String?
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func testConnection() async -> ConnectionTestResult {
        ConnectionTestResult(success: true, message: "ok")
    }

    func configSnapshot() -> LLMSnapshot {
        LLMSnapshot(provider: .localMLX, model: "", reasoningMode: .fast)
    }
}

private struct StubDeviceBackend: DeviceInferenceBackend {
    let name: String
    let usesANE: Bool = false
    let output: String

    func generate(prompt: String, systemPrompt: String, maxTokens: Int) async throws -> String {
        _ = prompt
        _ = systemPrompt
        _ = maxTokens
        return output
    }
}
