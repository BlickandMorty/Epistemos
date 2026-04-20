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
                usesANE: false,
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
                usesANE: false,
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
                usesANE: false,
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

    @MainActor
    @Test("dual brain only reports active with a dedicated ANE backend")
    func dualBrainRequiresDedicatedANEBackend() {
        let hardwareTier = HardwareTierManager(tier: .pro32, aneAvailable: true, metalGPUAvailable: true)
        let deviceAgent = DeviceAgentService(hardwareTier: hardwareTier)
        let router = DualBrainRouter(hardwareTier: hardwareTier, deviceAgent: deviceAgent)

        deviceAgent.setBackend(
            StubDeviceBackend(
                name: "SharedGPU",
                usesANE: false,
                output: #"{"selector":"//AXButton","action":"AXPress","confidence":0.9}"#
            )
        )
        #expect(!router.isDualBrainActive)

        deviceAgent.setBackend(
            StubDeviceBackend(
                name: "DedicatedANE",
                usesANE: true,
                output: #"{"selector":"//AXButton","action":"AXPress","confidence":0.9}"#
            )
        )
        #expect(router.isDualBrainActive)
    }
}

@Suite("iMessage Driver Routing")
struct IMessageDriverServiceRoutingTests {
    @MainActor
    @Test("default contact model uses an agent-capable local preset")
    func defaultContactModelUsesAgentCapableLocalPreset() throws {
        #expect(IMessageDriverService.defaultContactModel == "qwen-4b")
        let defaultModelID = try #require(
            IMessageDriverService.localTextModelID(forShortName: IMessageDriverService.defaultContactModel)
        )
        #expect(defaultModelID.canActAsAgent)
    }

    @MainActor
    @Test("local dispatch plan does not fall back to cloud for missing local clients")
    func localDispatchPlanDoesNotFallbackToCloud() {
        #expect(
            IMessageDriverService.localDispatchPlan(
                for: .qwen35_4B4Bit,
                hasLocalClient: false
            ) == .unavailable
        )
        #expect(
            IMessageDriverService.localDispatchPlan(
                for: .qwen35_2B4Bit,
                hasLocalClient: true
            ) == .agentLoop
        )
        #expect(
            IMessageDriverService.localDispatchPlan(
                for: .qwen35_4B4Bit,
                hasLocalClient: true
            ) == .agentLoop
        )
    }

    @MainActor
    @Test("suggested model options derive the multi-model example from installed agent-capable locals")
    func suggestedModelOptionsUseInstalledAgentCapableExample() {
        let options = IMessageDriverService.suggestedModelOptions(
            installedLocalModelIDs: [
                LocalTextModelID.qwen35_2B4Bit.rawValue,
                LocalTextModelID.qwen35_4B4Bit.rawValue,
            ],
            configuredCloudProviders: [.anthropic, .google]
        )

        #expect(options.contains("qwen-4b"))
        #expect(options.contains("claude-sonnet-4-6"))
        #expect(options.contains("gemini-pro"))
        #expect(options.contains("qwen-4b,claude-sonnet-4-6"))
        #expect(!options.contains("qwen-2b,claude-sonnet-4-6"))
    }

    @MainActor
    @Test("new local short-name aliases resolve to the intended runtime models")
    func localShortNameAliasesResolveToExpectedModels() {
        #expect(IMessageDriverService.localTextModelID(forShortName: "qwen3.6-35b") == .qwen36_35BA3B4Bit)
        #expect(IMessageDriverService.localTextModelID(forShortName: "bonsai-4b") == .bonsai4B2Bit)
        #expect(IMessageDriverService.localTextModelID(forShortName: "bonsai-8b") == .bonsai8B2Bit)
        #expect(IMessageDriverService.localTextModelID(forShortName: "gemma-26b-a4b") == .gemma4_27BA4B4Bit)
    }

    @MainActor
    @Test("reply rate limiter blocks the sixty-first auto-reply inside one hour and clears after pruning old sends")
    func replyRateLimiterBlocksBurstAndPrunesOldEntries() {
        let now = Date(timeIntervalSince1970: 1_712_708_800)
        let window = (0..<IMessageDriverService.perContactHourlyReplyLimit).map { offset in
            now.addingTimeInterval(TimeInterval(-offset))
        }

        #expect(
            IMessageDriverService.isReplyRateLimited(
                existingReplyTimestamps: window,
                now: now
            )
        )

        let oldTimestamps = window + [now.addingTimeInterval(-3700)]
        let pruned = IMessageDriverService.prunedReplyTimestamps(
            oldTimestamps,
            now: now
        )
        #expect(pruned.count == IMessageDriverService.perContactHourlyReplyLimit)
        #expect(
            IMessageDriverService.isReplyRateLimited(
                existingReplyTimestamps: Array(pruned.dropFirst()),
                now: now
            ) == false
        )
    }

    @MainActor
    @Test("driver channel messages prefer provider message ids for dedup")
    func driverChannelMessagesPreferProviderMessageIDsForDedup() {
        let message = DriverChannelMessage(
            channelID: "imessage",
            messageID: "42",
            conversationID: "88",
            senderID: "+15551234567",
            text: "hello",
            unix: 1_712_708_800
        )
        #expect(message.dedupKey == "imessage:42")
    }

    @MainActor
    @Test("driver channel messages fall back to conversation sender timestamp when ids are missing")
    func driverChannelMessagesFallbackToConversationSenderTimestamp() {
        let message = DriverChannelMessage(
            channelID: "imessage",
            messageID: nil,
            conversationID: "88",
            senderID: "+15551234567",
            text: "hello",
            unix: 1_712_708_800
        )
        #expect(message.dedupKey == "imessage:88:+15551234567:1712708800")
    }

    @MainActor
    @Test("iMessage unread parser preserves message and chat identifiers")
    func iMessageUnreadParserPreservesMessageAndChatIdentifiers() {
        let json = """
        {
          "messages": [
            {
              "message_id": 42,
              "text": "hey there",
              "unix": 1712708800,
              "handle": "+15551234567",
              "chat_id": 88
            }
          ]
        }
        """

        let messages = IMessageChannelAdapter.parseUnreadMessages(from: json)
        #expect(messages.count == 1)
        #expect(messages.first?.messageID == "42")
        #expect(messages.first?.conversationID == "88")
        #expect(messages.first?.senderID == "+15551234567")
        #expect(messages.first?.dedupKey == "imessage:42")
    }

    @MainActor
    @Test("telegram adapter builds a send_message call with chat target")
    func telegramAdapterBuildsSendMessageCall() throws {
        let adapter = TelegramChannelAdapter()
        let toolCall = try adapter.makeSendToolCall(message: "hello", recipientID: "123456")
        let payload = try #require(jsonObject(from: toolCall.inputJson))

        #expect(toolCall.toolName == "send_message")
        #expect(payload["platform"] as? String == "telegram")
        #expect(payload["message"] as? String == "hello")
        #expect(payload["target"] as? String == "123456")
    }

    @MainActor
    @Test("slack adapter routes webhook recipients without fabricating a target")
    func slackAdapterRoutesWebhookRecipients() throws {
        let adapter = SlackChannelAdapter()
        let webhookURL = "https://hooks.slack.com/services/test"
        let toolCall = try adapter.makeSendToolCall(message: "hello", recipientID: webhookURL)
        let payload = try #require(jsonObject(from: toolCall.inputJson))

        #expect(toolCall.toolName == "send_message")
        #expect(payload["platform"] as? String == "slack")
        #expect(payload["message"] as? String == "hello")
        #expect(payload["webhook_url"] as? String == webhookURL)
        #expect(payload["target"] == nil)
    }

    @MainActor
    @Test("discord adapter routes webhook recipients without fabricating a target")
    func discordAdapterRoutesWebhookRecipients() throws {
        let adapter = DiscordChannelAdapter()
        let webhookURL = "https://discord.com/api/webhooks/test"
        let toolCall = try adapter.makeSendToolCall(message: "hello", recipientID: webhookURL)
        let payload = try #require(jsonObject(from: toolCall.inputJson))

        #expect(toolCall.toolName == "send_message")
        #expect(payload["platform"] as? String == "discord")
        #expect(payload["message"] as? String == "hello")
        #expect(payload["webhook_url"] as? String == webhookURL)
        #expect(payload["target"] == nil)
    }

    @MainActor
    @Test("whatsapp adapter builds a send_message call with phone target")
    func whatsappAdapterBuildsSendMessageCall() throws {
        let adapter = WhatsAppChannelAdapter()
        let toolCall = try adapter.makeSendToolCall(message: "hello", recipientID: "+15551234567")
        let payload = try #require(jsonObject(from: toolCall.inputJson))

        #expect(toolCall.toolName == "send_message")
        #expect(payload["platform"] as? String == "whatsapp")
        #expect(payload["message"] as? String == "hello")
        #expect(payload["target"] as? String == "+15551234567")
    }

    @MainActor
    @Test("signal adapter preserves multi-recipient routing in target")
    func signalAdapterPreservesMultiRecipientRouting() throws {
        let adapter = SignalChannelAdapter()
        let toolCall = try adapter.makeSendToolCall(
            message: "hello",
            recipientID: "+15551234567,+15557654321"
        )
        let payload = try #require(jsonObject(from: toolCall.inputJson))

        #expect(toolCall.toolName == "send_message")
        #expect(payload["platform"] as? String == "signal")
        #expect(payload["message"] as? String == "hello")
        #expect(payload["target"] as? String == "+15551234567,+15557654321")
    }

    @MainActor
    @Test("email adapter adds the subject required by send_message")
    func emailAdapterAddsRequiredSubject() throws {
        let adapter = EmailChannelAdapter(subject: "Epistemos Reply")
        let toolCall = try adapter.makeSendToolCall(
            message: "hello",
            recipientID: "friend@example.com"
        )
        let payload = try #require(jsonObject(from: toolCall.inputJson))

        #expect(toolCall.toolName == "send_message")
        #expect(payload["platform"] as? String == "email")
        #expect(payload["message"] as? String == "hello")
        #expect(payload["to"] as? String == "friend@example.com")
        #expect(payload["subject"] as? String == "Epistemos Reply")
    }

    @MainActor
    @Test("send-only channel adapters fail fast on unread polling")
    func sendOnlyChannelAdaptersFailFastOnUnreadPolling() async {
        await #expect(throws: DriverChannelError.self) {
            _ = try await TelegramChannelAdapter().fetchUnreadMessages(vaultPath: "/tmp/test", limit: 5)
        }
        await #expect(throws: DriverChannelError.self) {
            _ = try await SlackChannelAdapter().fetchUnreadMessages(vaultPath: "/tmp/test", limit: 5)
        }
        await #expect(throws: DriverChannelError.self) {
            _ = try await DiscordChannelAdapter().fetchUnreadMessages(vaultPath: "/tmp/test", limit: 5)
        }
        await #expect(throws: DriverChannelError.self) {
            _ = try await WhatsAppChannelAdapter().fetchUnreadMessages(vaultPath: "/tmp/test", limit: 5)
        }
        await #expect(throws: DriverChannelError.self) {
            _ = try await SignalChannelAdapter().fetchUnreadMessages(vaultPath: "/tmp/test", limit: 5)
        }
        await #expect(throws: DriverChannelError.self) {
            _ = try await EmailChannelAdapter().fetchUnreadMessages(vaultPath: "/tmp/test", limit: 5)
        }
    }

    @MainActor
    @Test("partner context query prefers the current line when it has signal")
    func partnerContextQueryPrefersCurrentLine() {
        let body = """
        alpha
        investigate weighted graph recall here
        omega
        """
        let offset = (body as NSString).range(of: "weighted").location
        #expect(
            AIPartnerService.partnerQuery(
                in: body,
                cursorOffset: offset,
                fallbackTitle: "Fallback"
            ) == "investigate weighted graph recall here"
        )
    }

    @MainActor
    @Test("partner context line counting clamps offsets to the note buffer")
    func partnerContextLineCountingClampsOffsets() {
        let body = "one\ntwo\nthree"
        #expect(AIPartnerService.safeCursorOffset(in: body, cursorOffset: 999) == (body as NSString).length)
        #expect(AIPartnerService.cursorLine(in: body, cursorOffset: -20) == 1)
        #expect(AIPartnerService.cursorLine(in: body, cursorOffset: 999) == 3)
    }

    private func jsonObject(from json: String) -> [String: Any]? {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object
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
        let steeringHintsJSON: String?
    }

    var generateRequests: [GenerateRequest] = []
    var generateResult: String = ""

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
        generateRequests.append(
            GenerateRequest(
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens,
                reasoningMode: reasoningMode,
                modelID: modelID,
                steeringHintsJSON: steeringHintsJSON
            )
        )
        return generateResult
    }

    func stream(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        modelID: String?,
        steeringHintsJSON: String?
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
    let usesANE: Bool
    let output: String

    func generate(prompt: String, systemPrompt: String, maxTokens: Int) async throws -> String {
        _ = prompt
        _ = systemPrompt
        _ = maxTokens
        return output
    }
}
