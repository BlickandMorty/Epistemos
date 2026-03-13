import Testing
@testable import Epistemos

@Suite("TriageService")
struct TriageServiceTests {

    // MARK: - isRefusalResponse

    @Test("empty string is a refusal")
    func emptyRefusal() {
        #expect(TriageService.isRefusalResponse(""))
    }

    @Test("whitespace-only string is a refusal")
    func whitespaceRefusal() {
        #expect(TriageService.isRefusalResponse("   \n  "))
    }

    @Test("generic AI refusal detected")
    func genericRefusal() {
        #expect(TriageService.isRefusalResponse("I can't help with that request."))
        #expect(TriageService.isRefusalResponse("I cannot assist with this topic."))
        #expect(TriageService.isRefusalResponse("As an AI, I don't have the ability to do that."))
    }

    @Test("Apple Intelligence refusal detected")
    func appleRefusal() {
        #expect(TriageService.isRefusalResponse("As a language model created by Apple, I am unable to assist with that."))
        #expect(TriageService.isRefusalResponse("Beyond my remit to provide that kind of analysis."))
    }

    @Test("legitimate response is not a refusal")
    func legitimateResponse() {
        #expect(!TriageService.isRefusalResponse("Aspirin is a nonsteroidal anti-inflammatory drug (NSAID)."))
        #expect(!TriageService.isRefusalResponse("The key insight here is that quantum entanglement does not allow faster-than-light communication."))
    }

    @Test("refusal buried after 500 chars is not detected")
    func buriedRefusal() {
        let longPrefix = String(repeating: "This is valid content. ", count: 30)
        let text = longPrefix + "I can't help with that."
        #expect(!TriageService.isRefusalResponse(text))
    }

    // MARK: - isTruncatedResponse

    @Test("short response is truncated")
    func shortTruncated() {
        #expect(TriageService.isTruncatedResponse("Yes"))
        #expect(TriageService.isTruncatedResponse("I think"))
    }

    @Test("response ending without punctuation is truncated")
    func noPunctuationTruncated() {
        let text = "This is a response that ends abruptly without any terminal punctuation and keeps going on"
        #expect(TriageService.isTruncatedResponse(text))
    }

    @Test("response ending with period is not truncated")
    func periodNotTruncated() {
        #expect(!TriageService.isTruncatedResponse("This is a complete response with a proper ending."))
    }

    @Test("response ending with list marker is not truncated")
    func listNotTruncated() {
        #expect(!TriageService.isTruncatedResponse("Here are the key points:\n- First important item"))
    }

    @Test("response ending with code block is not truncated")
    func codeBlockNotTruncated() {
        #expect(!TriageService.isTruncatedResponse("Here is the code:\n```"))
    }

    // MARK: - shouldFallbackToAPI

    @Test("combines refusal and truncation checks")
    func fallbackCombined() {
        #expect(TriageService.shouldFallbackToAPI(""))           // refusal
        #expect(TriageService.shouldFallbackToAPI("I can't help")) // refusal
        #expect(TriageService.shouldFallbackToAPI("Short"))       // truncated
        #expect(!TriageService.shouldFallbackToAPI("This is a perfectly valid response that should not trigger any fallback."))
    }

    // MARK: - NotesOperation complexity

    @Test("operations have correct complexity ordering")
    func complexityOrdering() {
        #expect(NotesOperation.grammarFix.baseComplexity < NotesOperation.summarize.baseComplexity)
        #expect(NotesOperation.summarize.baseComplexity <= NotesOperation.ask(query: "test").baseComplexity)
        #expect(NotesOperation.ask(query: "test").baseComplexity < NotesOperation.rewrite.baseComplexity)
        #expect(NotesOperation.rewrite.baseComplexity < NotesOperation.continueWriting.baseComplexity)
        #expect(NotesOperation.ask(query: "test").baseComplexity < NotesOperation.outline.baseComplexity)
        #expect(NotesOperation.outline.baseComplexity < NotesOperation.expand.baseComplexity)
        #expect(NotesOperation.expand.baseComplexity < NotesOperation.analyze.baseComplexity)
        #expect(NotesOperation.analyze.baseComplexity < NotesOperation.learn.baseComplexity)
    }

    @Test("all operations have display names")
    func operationDisplayNames() {
        #expect(!NotesOperation.grammarFix.displayName.isEmpty)
        #expect(!NotesOperation.summarize.displayName.isEmpty)
        #expect(!NotesOperation.learn.displayName.isEmpty)
    }

    // MARK: - GeneralOperation complexity

    @Test("apiOnly always has max complexity")
    func apiOnlyMaxComplexity() {
        #expect(GeneralOperation.apiOnly.baseComplexity == 1.0)
    }

    @Test("general operations have display names")
    func generalDisplayNames() {
        #expect(!GeneralOperation.chatResponse(query: "test").displayName.isEmpty)
        #expect(!GeneralOperation.epistemicLens.displayName.isEmpty)
        #expect(!GeneralOperation.brainstorm.displayName.isEmpty)
        #expect(!GeneralOperation.apiOnly.displayName.isEmpty)
    }

    // MARK: - TriageDecision

    @Test("decision labels and icons are non-empty")
    func decisionLabels() {
        #expect(!TriageDecision.appleIntelligence.label.isEmpty)
        #expect(!TriageDecision.apiProvider.label.isEmpty)
        #expect(!TriageDecision.appleIntelligence.icon.isEmpty)
        #expect(!TriageDecision.apiProvider.icon.isEmpty)
    }

    @Test("isOnDevice matches enum case")
    func isOnDevice() {
        #expect(TriageDecision.appleIntelligence.isOnDevice)
        #expect(!TriageDecision.apiProvider.isOnDevice)
    }
}

@MainActor
final class TriageIntegrationMockLLMClient: LLMClientProtocol {
    var generateCalls: [(prompt: String, systemPrompt: String?, maxTokens: Int)] = []
    var streamCalls: [(prompt: String, systemPrompt: String?, maxTokens: Int)] = []

    var generateResult: Result<String, Error> = .success("mock-generate")
    var streamTokens: [String] = ["mock-stream"]
    var streamError: (any Error)?

    func generate(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String {
        generateCalls.append((prompt, systemPrompt, maxTokens))
        switch generateResult {
        case .success(let output):
            return output
        case .failure(let error):
            throw error
        }
    }

    func stream(prompt: String, systemPrompt: String?, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        streamCalls.append((prompt, systemPrompt, maxTokens))
        let tokens = streamTokens
        let error = streamError

        return AsyncThrowingStream { continuation in
            Task {
                for token in tokens {
                    continuation.yield(token)
                }
                if let error {
                    continuation.finish(throwing: error)
                } else {
                    continuation.finish()
                }
            }
        }
    }

    func testConnection() async -> ConnectionTestResult {
        ConnectionTestResult(success: true, message: "ok")
    }

    func configSnapshot() -> LLMSnapshot {
        LLMSnapshot(provider: .anthropic, apiKey: "test-key", model: "test-model", ollamaBaseUrl: "http://localhost:11434")
    }

    func enrichmentSnapshot() -> LLMSnapshot { configSnapshot() }
}

@Suite("TriageService Integration")
struct TriageServiceIntegrationTests {

    // MARK: - Notes Routing

    @Test("notes triage prefers on-device for simple transforms when Apple AI is available")
    @MainActor func notesSimpleOperationsUseOnDevice() {
        let triage = makeService(apiProvider: .anthropic, apiKey: "key", appleAvailable: true)

        #expect(triage.triage(operation: .grammarFix, contentLength: 240) == .appleIntelligence)
        #expect(triage.triage(operation: .summarize, contentLength: 240) == .appleIntelligence)
        #expect(triage.triage(operation: .rewrite, contentLength: 240) == .appleIntelligence)
        #expect(
            triage.triage(
                operation: .ask(query: "Summarize the core point of this note."),
                contentLength: 240
            ) == .appleIntelligence
        )
    }

    @Test("notes triage routes complex operations to cloud when key is configured")
    @MainActor func notesComplexOperationsUseCloud() {
        let triage = makeService(apiProvider: .anthropic, apiKey: "key", appleAvailable: true)

        #expect(triage.triage(operation: .continueWriting, contentLength: 100) == .apiProvider)
        #expect(
            triage.triage(
                operation: .ask(
                    query: "Compare the causal relationship between Bayesian updating, coherence, and evidential decision theory across conflicting studies."
                ),
                contentLength: 100
            ) == .apiProvider
        )
        #expect(triage.triage(operation: .outline, contentLength: 100) == .apiProvider)
        #expect(triage.triage(operation: .expand, contentLength: 100) == .apiProvider)
        #expect(triage.triage(operation: .analyze, contentLength: 100) == .apiProvider)
        #expect(triage.triage(operation: .learn, contentLength: 100) == .apiProvider)
    }

    @Test("notes triage force-routes to on-device when selected provider key is missing")
    @MainActor func notesNoSelectedProviderKeyForcesOnDevice() {
        // OpenAI is selected and empty; Anthropic key is irrelevant for selected-provider routing.
        let triage = makeService(apiProvider: .openai, apiKey: "", appleAvailable: true, otherProviderKey: "anthropic-key")

        #expect(triage.triage(operation: .learn, contentLength: 12000) == .appleIntelligence)
    }

    @Test("notes triage routes to cloud when Apple AI is unavailable")
    @MainActor func notesAppleUnavailableUsesCloud() {
        let triage = makeService(apiProvider: .anthropic, apiKey: "key", appleAvailable: false)

        #expect(triage.triage(operation: .grammarFix, contentLength: 100) == .apiProvider)
    }

    @Test("direct triage calls do not mutate lastDecision state")
    @MainActor func triageCallsDoNotMutateLastDecision() {
        let triage = makeService(apiProvider: .anthropic, apiKey: "key", appleAvailable: true)

        _ = triage.triage(operation: .grammarFix, contentLength: 50)
        _ = triage.triageGeneral(operation: .brainstorm, contentLength: 50)
        #expect(triage.lastDecision == nil)
    }

    // MARK: - General Routing

    @Test("general triage sends brainstorm to on-device when Apple AI is available")
    @MainActor func generalBrainstormUsesOnDevice() {
        let triage = makeService(apiProvider: .anthropic, apiKey: "key", appleAvailable: true)
        #expect(triage.triageGeneral(operation: .brainstorm, contentLength: 500) == .appleIntelligence)
    }

    @Test("general triage routes higher-complexity operations to cloud")
    @MainActor func generalComplexUsesCloud() {
        let triage = makeService(apiProvider: .anthropic, apiKey: "key", appleAvailable: true)

        #expect(triage.triageGeneral(operation: .chatResponse(query: "What is Bayesian updating?"), contentLength: 100) == .apiProvider)
        #expect(triage.triageGeneral(operation: .epistemicLens, contentLength: 100) == .apiProvider)
        #expect(triage.triageGeneral(operation: .apiOnly, contentLength: 100) == .apiProvider)
    }

    @Test("general triage force-routes to on-device when selected provider key is missing")
    @MainActor func generalNoSelectedProviderKeyForcesOnDevice() {
        let triage = makeService(apiProvider: .google, apiKey: "", appleAvailable: true)
        #expect(triage.triageGeneral(operation: .apiOnly, contentLength: 10000) == .appleIntelligence)
    }

    @Test("general triage routes to cloud when Apple AI is unavailable")
    @MainActor func generalAppleUnavailableUsesCloud() {
        let triage = makeService(apiProvider: .anthropic, apiKey: "key", appleAvailable: false)
        #expect(triage.triageGeneral(operation: .brainstorm, contentLength: 100) == .apiProvider)
    }

    // MARK: - Notes Generate/Stream Integration

    @Test("notes generate uses cloud path and records maxTokens default")
    @MainActor func notesGenerateUsesCloudPath() async throws {
        let mock = TriageIntegrationMockLLMClient()
        mock.generateResult = .success("cloud-response")
        let triage = makeService(apiProvider: .anthropic, apiKey: "key", appleAvailable: false, llm: mock)

        let output = try await triage.generate(
            prompt: "Prompt A",
            systemPrompt: "System A",
            operation: .analyze,
            contentLength: 1800
        )

        #expect(output == "cloud-response")
        #expect(triage.lastDecision == .apiProvider)
        #expect(mock.generateCalls.count == 1)
        #expect(mock.streamCalls.isEmpty)
        #expect(mock.generateCalls[0].prompt == "Prompt A")
        #expect(mock.generateCalls[0].systemPrompt == "System A")
        #expect(mock.generateCalls[0].maxTokens == 4096)
    }

    @Test("notes generate propagates cloud errors")
    @MainActor func notesGeneratePropagatesCloudError() async {
        let mock = TriageIntegrationMockLLMClient()
        mock.generateResult = .failure(LLMError.apiError(statusCode: 500, body: "boom"))
        let triage = makeService(apiProvider: .anthropic, apiKey: "key", appleAvailable: false, llm: mock)

        do {
            _ = try await triage.generate(
                prompt: "Prompt B",
                systemPrompt: nil,
                operation: .learn,
                contentLength: 2400
            )
            Issue.record("Expected generate to throw")
        } catch let error as LLMError {
            if case .apiError(let code, _) = error {
                #expect(code == 500)
            } else {
                Issue.record("Expected .apiError case")
            }
        } catch {
            Issue.record("Expected LLMError, got \(type(of: error))")
        }

        #expect(triage.lastDecision == .apiProvider)
        #expect(mock.generateCalls.count == 1)
    }

    @Test("notes stream uses cloud path and yields all chunks")
    @MainActor func notesStreamUsesCloudPath() async {
        let mock = TriageIntegrationMockLLMClient()
        mock.streamTokens = ["alpha", " ", "beta"]
        let triage = makeService(apiProvider: .anthropic, apiKey: "key", appleAvailable: false, llm: mock)

        let stream = triage.stream(
            prompt: "Prompt C",
            systemPrompt: "System C",
            operation: .expand,
            contentLength: 900
        )
        #expect(triage.lastDecision == .apiProvider)

        let outcome = await collect(stream)
        #expect(outcome.tokens == ["alpha", " ", "beta"])
        if let error = outcome.error {
            Issue.record("Unexpected stream error: \(error)")
        }

        #expect(mock.streamCalls.count == 1)
        #expect(mock.generateCalls.isEmpty)
        #expect(mock.streamCalls[0].prompt == "Prompt C")
        #expect(mock.streamCalls[0].systemPrompt == "System C")
        #expect(mock.streamCalls[0].maxTokens == 0)
    }

    @Test("notes stream propagates cloud stream errors after partial output")
    @MainActor func notesStreamPropagatesCloudError() async {
        let mock = TriageIntegrationMockLLMClient()
        mock.streamTokens = ["partial"]
        mock.streamError = LLMError.apiError(statusCode: 503, body: "unavailable")
        let triage = makeService(apiProvider: .anthropic, apiKey: "key", appleAvailable: false, llm: mock)

        let stream = triage.stream(
            prompt: "Prompt D",
            systemPrompt: nil,
            operation: .analyze,
            contentLength: 1200
        )
        let outcome = await collect(stream)

        #expect(outcome.tokens == ["partial"])
        guard let error = outcome.error as? LLMError else {
            Issue.record("Expected LLMError from stream")
            return
        }
        if case .apiError(let code, _) = error {
            #expect(code == 503)
        } else {
            Issue.record("Expected .apiError case")
        }
        #expect(triage.lastDecision == .apiProvider)
    }

    // MARK: - General Generate/Stream Integration

    @Test("general generate apiOnly uses cloud path")
    @MainActor func generalGenerateApiOnlyUsesCloudPath() async throws {
        let mock = TriageIntegrationMockLLMClient()
        mock.generateResult = .success("general-cloud")
        let triage = makeService(apiProvider: .anthropic, apiKey: "key", appleAvailable: false, llm: mock)

        let output = try await triage.generateGeneral(
            prompt: "General prompt",
            systemPrompt: "General system",
            operation: .apiOnly,
            contentLength: 100
        )

        #expect(output == "general-cloud")
        #expect(triage.lastDecision == .apiProvider)
        #expect(mock.generateCalls.count == 1)
        #expect(mock.generateCalls[0].maxTokens == 4096)
    }

    @Test("general generate chat response uses cloud path when Apple AI is unavailable")
    @MainActor func generalGenerateChatResponseUsesCloudPath() async throws {
        let mock = TriageIntegrationMockLLMClient()
        mock.generateResult = .success("chat-cloud")
        let triage = makeService(apiProvider: .anthropic, apiKey: "key", appleAvailable: false, llm: mock)

        let output = try await triage.generateGeneral(
            prompt: "Explain epistemology",
            operation: .chatResponse(query: "Explain epistemology"),
            contentLength: 300
        )

        #expect(output == "chat-cloud")
        #expect(mock.generateCalls.count == 1)
        #expect(triage.lastDecision == .apiProvider)
    }

    @Test("general generate propagates non-auth cloud errors")
    @MainActor func generalGeneratePropagatesNonAuthError() async {
        let mock = TriageIntegrationMockLLMClient()
        mock.generateResult = .failure(LLMError.apiError(statusCode: 400, body: "bad request"))
        let triage = makeService(apiProvider: .anthropic, apiKey: "key", appleAvailable: false, llm: mock)

        do {
            _ = try await triage.generateGeneral(
                prompt: "General prompt 2",
                operation: .apiOnly,
                contentLength: 500
            )
            Issue.record("Expected generateGeneral to throw")
        } catch let error as LLMError {
            if case .apiError(let code, _) = error {
                #expect(code == 400)
            } else {
                Issue.record("Expected .apiError case")
            }
        } catch {
            Issue.record("Expected LLMError, got \(type(of: error))")
        }

        #expect(triage.lastDecision == .apiProvider)
    }

    @Test("general stream uses cloud path and yields all chunks")
    @MainActor func generalStreamUsesCloudPath() async {
        let mock = TriageIntegrationMockLLMClient()
        mock.streamTokens = ["x", "y", "z"]
        let triage = makeService(apiProvider: .anthropic, apiKey: "key", appleAvailable: false, llm: mock)

        let stream = triage.streamGeneral(
            prompt: "General stream prompt",
            operation: .epistemicLens,
            contentLength: 600
        )
        let outcome = await collect(stream)

        #expect(outcome.tokens == ["x", "y", "z"])
        if let error = outcome.error {
            Issue.record("Unexpected streamGeneral error: \(error)")
        }
        #expect(mock.streamCalls.count == 1)
        #expect(triage.lastDecision == .apiProvider)
    }

    @Test("general stream propagates non-auth cloud stream errors")
    @MainActor func generalStreamPropagatesNonAuthError() async {
        let mock = TriageIntegrationMockLLMClient()
        mock.streamTokens = ["chunk"]
        mock.streamError = LLMError.apiError(statusCode: 500, body: "server")
        let triage = makeService(apiProvider: .anthropic, apiKey: "key", appleAvailable: false, llm: mock)

        let stream = triage.streamGeneral(
            prompt: "General stream prompt 2",
            operation: .chatResponse(query: "What is coherentism?"),
            contentLength: 500
        )
        let outcome = await collect(stream)

        #expect(outcome.tokens == ["chunk"])
        guard let error = outcome.error as? LLMError else {
            Issue.record("Expected LLMError from streamGeneral")
            return
        }
        if case .apiError(let code, _) = error {
            #expect(code == 500)
        } else {
            Issue.record("Expected .apiError case")
        }
        #expect(triage.lastDecision == .apiProvider)
    }

    // MARK: - Heuristic Edge Cases

    @Test("refusal detection is case-insensitive and prefix-bounded")
    func refusalCaseInsensitivityAndPrefixWindow() {
        #expect(TriageService.isRefusalResponse("I CANNOT ASSIST WITH THIS REQUEST."))

        let longPrefix = String(repeating: "valid-content ", count: 45) // >500 chars
        let buried = longPrefix + "I cannot assist with this request."
        #expect(!TriageService.isRefusalResponse(buried))
    }

    @Test("truncation detection accepts terminal bracket and quote")
    func truncationTerminalCharactersAccepted() {
        #expect(!TriageService.isTruncatedResponse("The quoted sentence is complete.'"))
        #expect(!TriageService.isTruncatedResponse("The bracketed citation is complete.]"))
    }

    @Test("fallback check stays false for complete, substantive prose")
    func fallbackFalseForCompleteResponse() {
        let text = """
        This answer includes sufficient detail, clear reasoning, and a proper ending.
        It should not be classified as a refusal or a truncation artifact.
        """
        #expect(!TriageService.shouldFallbackToAPI(text))
    }

    // MARK: - Helpers

    @MainActor
    private func makeService(
        apiProvider: LLMProviderType,
        apiKey: String,
        appleAvailable: Bool,
        otherProviderKey: String = "",
        llm: TriageIntegrationMockLLMClient = TriageIntegrationMockLLMClient()
    ) -> TriageService {
        let inference = InferenceState()
        inference.apiProvider = apiProvider
        inference.anthropicKey = ""
        inference.openaiKey = ""
        inference.googleKey = ""
        inference.kimiKey = ""
        inference.appleIntelligenceAvailable = appleAvailable

        switch apiProvider {
        case .anthropic: inference.anthropicKey = apiKey
        case .openai: inference.openaiKey = apiKey
        case .google: inference.googleKey = apiKey
        case .kimi: inference.kimiKey = apiKey
        case .ollama, .appleIntelligence: break
        }

        if !otherProviderKey.isEmpty {
            inference.anthropicKey = otherProviderKey
        }

        return TriageService(inference: inference, llmService: llm)
    }

    private func collect(_ stream: AsyncThrowingStream<String, Error>) async -> (tokens: [String], error: (any Error)?) {
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
}
