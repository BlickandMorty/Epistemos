import Foundation
import Testing
@testable import Epistemos

@MainActor
private final class DriverChannelAgentEventSink {
    private(set) var events: [AgentProvenanceEvent] = []

    func append(_ event: AgentProvenanceEvent) -> Bool {
        events.append(event)
        return true
    }
}

@Suite("Control Plane Surfaces")
struct ControlPlaneSurfaceTests {
    @MainActor
    @Test("channel registry defaults to iMessage and exposes every built-in channel")
    func channelRegistryDefaultsToIMessageAndExposesBuiltInChannels() {
        let suiteName = "ChannelRegistryDefaults-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let registry = ChannelRegistryState(userDefaults: defaults)

        #expect(registry.driverChannel == .imessage)
        #expect(Set(registry.channels.map(\.id)) == Set(ChannelIdentity.allCases))
        #expect(registry.configuration(for: .imessage).isEnabled)
        #expect(registry.configuration(for: .telegram).threadLocator.defaultRecipient.isEmpty)
    }

    @MainActor
    @Test("channel registry builds outbound payloads from stored defaults")
    func channelRegistryBuildsOutboundPayloadsFromStoredDefaults() throws {
        let suiteName = "ChannelRegistryPayloads-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let registry = ChannelRegistryState(userDefaults: defaults)
        registry.update(.telegram) { config in
            config.threadLocator.defaultRecipient = "123456"
        }
        registry.update(.email) { config in
            config.threadLocator.defaultRecipient = "ops@example.com"
            config.threadLocator.defaultSubject = "Operator Digest"
        }

        let telegramToolCall = try registry.makeSendToolCall(for: .telegram, message: "hello")
        let telegramPayload = try #require(jsonObject(from: telegramToolCall.inputJson))
        #expect(telegramToolCall.toolName == "send_message")
        #expect(telegramPayload["platform"] as? String == "telegram")
        #expect(telegramPayload["target"] as? String == "123456")

        let emailToolCall = try registry.makeSendToolCall(for: .email, message: "status")
        let emailPayload = try #require(jsonObject(from: emailToolCall.inputJson))
        #expect(emailPayload["platform"] as? String == "email")
        #expect(emailPayload["to"] as? String == "ops@example.com")
        #expect(emailPayload["subject"] as? String == "Operator Digest")
    }

    @MainActor
    @Test("driver channel executor records successful tool provenance")
    func driverChannelExecutorRecordsSuccessfulToolProvenance() async throws {
        let sink = DriverChannelAgentEventSink()
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 777 },
            persist: { event in sink.append(event) }
        )
        let toolCall = try DriverChannelToolCall(
            toolName: "send_message",
            payload: [
                "platform": "telegram",
                "target": "123456",
                "message": "hello",
            ]
        )

        let output = try await DriverChannelToolExecutor.execute(
            toolCall,
            vaultPath: "/tmp/epistemos-channel-vault",
            tier: "agent",
            channelID: "telegram",
            toolRunner: { vaultPath, tier, toolName, inputJson in
                #expect(vaultPath == "/tmp/epistemos-channel-vault")
                #expect(tier == "agent")
                #expect(toolName == "send_message")
                #expect(inputJson.contains("\"platform\":\"telegram\""))
                return DriverChannelToolExecutionResult(
                    success: true,
                    outputJson: #"{"delivered":true}"#,
                    error: nil
                )
            },
            agentProvenanceRecorder: recorder
        )

        #expect(output == #"{"delivered":true}"#)
        #expect(sink.events.map(\.kind) == [.toolCallRequested, .toolCallStarted, .toolCallCompleted])
        #expect(Set(sink.events.map(\.runID)).count == 1)
        #expect(sink.events.first?.runID.hasPrefix("driver-channel-telegram-") == true)
        #expect(sink.events.allSatisfy { $0.tool?.toolCallID == "driver-channel-tool:1" })
        #expect(sink.events.allSatisfy { $0.tool?.toolName == "send_message" })
        #expect(sink.events.allSatisfy { $0.metadata["source"] == "driver_channel_tool_executor" })
        #expect(sink.events.allSatisfy { $0.metadata["surface"] == "driver_channel" })
        #expect(sink.events.allSatisfy { $0.metadata["channel"] == "telegram" })
        #expect(sink.events.last?.tool?.status == .completed)
        #expect(sink.events.last?.tool?.resultJSON?.contains("delivered") == true)
    }

    @MainActor
    @Test("driver channel executor records failed tool provenance")
    func driverChannelExecutorRecordsFailedToolProvenance() async throws {
        let sink = DriverChannelAgentEventSink()
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 778 },
            persist: { event in sink.append(event) }
        )
        let toolCall = try DriverChannelToolCall(
            toolName: "send_message",
            payload: [
                "platform": "telegram",
                "target": "123456",
                "message": "hello",
            ]
        )

        await #expect(throws: DriverChannelError.self) {
            try await DriverChannelToolExecutor.execute(
                toolCall,
                vaultPath: "/tmp/epistemos-channel-vault",
                tier: "agent",
                channelID: "telegram",
                toolRunner: { _, _, _, _ in
                    DriverChannelToolExecutionResult(
                        success: false,
                        outputJson: #"{"delivered":false}"#,
                        error: "relay offline"
                    )
                },
                agentProvenanceRecorder: recorder
            )
        }

        #expect(sink.events.map(\.kind) == [.toolCallRequested, .toolCallStarted, .toolCallFailed])
        #expect(sink.events.last?.tool?.status == .failed)
        #expect(sink.events.last?.tool?.errorMessage?.contains("relay offline") == true)
        #expect(sink.events.last?.tool?.resultJSON?.contains("delivered") == true)
    }

    @MainActor
    @Test("remote relay pairing upgrades a channel into an inbound driver option")
    func remoteRelayPairingUpgradesAChannelIntoAnInboundDriverOption() {
        let suiteName = "ChannelRegistryRelay-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let registry = ChannelRegistryState(userDefaults: defaults)
        registry.update(.telegram) { config in
            config.pairingState = .remoteRelay
            config.pairingMetadata = ChannelPairingMetadata(
                relayEndpoint: "https://relay.example.com",
                relayCredential: "secret",
                senderIdentity: "Mac mini",
                enableNativeFallback: false,
                keepAliveOnLaunch: false
            )
        }

        #expect(registry.driverChannelOptions.map(\.id).contains(.telegram))

        let adapter = registry.makeAdapter(for: .telegram)
        #expect(adapter.capabilities.contains(.inboundPolling))
        #expect(adapter.capabilities.contains(.threadHistory))
        #expect(adapter.capabilities.contains(.auditTrail))
    }

    @MainActor
    @Test("remote relay email adapters preserve worker delivery metadata")
    func remoteRelayEmailAdaptersPreserveWorkerDeliveryMetadata() throws {
        let suiteName = "ChannelRegistryRelayEmail-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let registry = ChannelRegistryState(userDefaults: defaults)
        registry.update(.email) { config in
            config.displayName = "Ops Mailbox"
            config.threadLocator.defaultRecipient = "ops@example.com"
            config.threadLocator.defaultSubject = "Operator Digest"
            config.pairingState = .remoteRelay
            config.pairingMetadata = ChannelPairingMetadata(
                relayEndpoint: "https://relay.example.com",
                relayCredential: "secret",
                senderIdentity: "Mac mini",
                enableNativeFallback: false,
                keepAliveOnLaunch: false
            )
        }

        let adapter = try #require(registry.makeAdapter(for: .email) as? RemoteRelayChannelAdapter)

        #expect(adapter.deliveryMetadata["subject"] == "Operator Digest")
        #expect(adapter.deliveryMetadata["display_target"] == "Ops Mailbox")
    }

    @MainActor
    @Test("remote relay webhook adapters use safe display targets")
    func remoteRelayWebhookAdaptersUseSafeDisplayTargets() throws {
        let suiteName = "ChannelRegistryRelaySlack-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let registry = ChannelRegistryState(userDefaults: defaults)
        registry.update(.slack) { config in
            config.displayName = "Ops Alerts"
            config.threadLocator.defaultRecipient = "https://hooks.slack.com/services/T/B/C"
            config.pairingState = .remoteRelay
            config.pairingMetadata = ChannelPairingMetadata(
                relayEndpoint: "https://relay.example.com",
                relayCredential: "secret",
                senderIdentity: "Mac mini",
                enableNativeFallback: false,
                keepAliveOnLaunch: false
            )
        }

        let adapter = try #require(registry.makeAdapter(for: .slack) as? RemoteRelayChannelAdapter)

        #expect(adapter.deliveryMetadata["display_target"] == "Ops Alerts")
    }

    @Test("session browser extracts summary sections and a searchable corpus")
    func sessionBrowserExtractsSummarySectionsAndSearchableCorpus() {
        let markdown = """
        # Summary

        ## Key Decisions
        Make iMessage the flagship channel.

        ## Open Questions
        How should Slack pairing be approved?
        """
        let transcriptLines = [
            #"{"content":"Slack webhook pairing is ready."}"#,
            #"{"content":"Signal remains outbound-only for now."}"#,
        ]

        let sections = SessionBrowser.extractSummarySections(from: markdown)
        let corpus = SessionBrowser.searchCorpus(summary: markdown, transcriptLines: transcriptLines)

        #expect(sections.map(\.title) == ["Key Decisions", "Open Questions"])
        #expect(corpus.localizedCaseInsensitiveContains("flagship channel"))
        #expect(corpus.localizedCaseInsensitiveContains("Slack webhook pairing is ready"))
        #expect(corpus.localizedCaseInsensitiveContains("Signal remains outbound-only"))
    }

    @Test("agent session lineage store links follow-up runs to the previous chat session")
    func agentSessionLineageStoreLinksFollowUpRuns() throws {
        let suiteName = "AgentSessionLineage-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let firstFolder = root.appendingPathComponent("sess-1", isDirectory: true)
        let secondFolder = root.appendingPathComponent("sess-2", isDirectory: true)
        try fileManager.createDirectory(at: firstFolder, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: secondFolder, withIntermediateDirectories: true)
        try writeSessionMetadata(at: firstFolder, sessionID: "sess-1")
        try writeSessionMetadata(at: secondFolder, sessionID: "sess-2")

        let store = AgentSessionLineageStore(userDefaults: defaults)

        let firstMetadata = try store.recordCompletedSession(
            sessionID: "sess-1",
            chatThreadID: "chat-main",
            sessionFolderPath: firstFolder.path
        )
        #expect(firstMetadata.parentSessionID == nil)
        #expect(store.parentSessionID(forChatThread: "chat-main") == "sess-1")

        let secondMetadata = try store.recordCompletedSession(
            sessionID: "sess-2",
            chatThreadID: "chat-main",
            sessionFolderPath: secondFolder.path
        )
        #expect(secondMetadata.parentSessionID == "sess-1")

        let persisted = try #require(jsonObject(at: secondFolder.appendingPathComponent("session.json")))
        #expect(persisted["parent_session_id"] as? String == "sess-1")
        #expect(persisted["chat_thread_id"] as? String == "chat-main")
        #expect(persisted["tags"] as? [String] == ["smoke", "lineage"])
        #expect((persisted["token_count"] as? [String: Int])?["input"] == 0)
    }

    @Test("todo snapshot decodes tool input through typed schema")
    func todoSnapshotDecodesToolInputThroughTypedSchema() throws {
        let json = """
        {
          "action": "merge",
          "todos": [
            {
              "id": "one",
              "content": "Read trace payloads",
              "active_form": "Reading trace payloads",
              "status": "in_progress"
            },
            {
              "id": "two",
              "content": "Ship typed decoder",
              "active_form": "",
              "status": "completed"
            },
            {
              "id": "empty-content",
              "content": "   ",
              "status": "pending"
            }
          ]
        }
        """

        let snapshot = try #require(TodoSnapshot.fromToolInput(json))
        #expect(snapshot.items.count == 2)
        #expect(snapshot.inProgressItem?.id == "one")
        #expect(snapshot.completedCount == 1)
        #expect(snapshot.items[1].activeForm == "Ship typed decoder")
    }

    @Test("skill trace heuristic reads typed trace rows and emits typed proposal")
    func skillTraceHeuristicReadsTypedTraceRowsAndEmitsTypedProposal() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sessionFolder = root
            .appendingPathComponent("sessions", isDirectory: true)
            .appendingPathComponent("2026-04-10_release-audit", isDirectory: true)
        try fileManager.createDirectory(at: sessionFolder, withIntermediateDirectories: true)
        try writeSessionMetadata(at: sessionFolder, sessionID: "release-audit")

        let trace = """
        [
          {
            "name": "release-audit",
            "input_summary": "audit pass",
            "output_summary": "first failure",
            "outcome": "failed",
            "duration_ms": 12
          },
          {
            "name": "release-audit",
            "input_summary": "audit pass",
            "output_summary": "second failure",
            "outcome": "failed",
            "duration_ms": 18.5
          },
          {
            "name": "release-audit",
            "input_summary": "audit pass",
            "output_summary": "third failure",
            "outcome": "failed",
            "duration_ms": 21
          }
        ]
        """
        try trace.write(to: sessionFolder.appendingPathComponent("trace.json"), atomically: true, encoding: .utf8)

        let patternJSON = try analyzeSkillTracesLocal(vaultPath: root.path, skillName: "release-audit")
        let pattern = try #require(jsonObject(from: patternJSON))
        #expect(pattern["traceCount"] as? Int == 3)
        #expect(pattern["failureCount"] as? Int == 3)
        #expect(pattern["averageDurationMs"] as? Double == (12.0 + 18.5 + 21.0) / 3.0)

        let proposalJSON = try proposeSkillMutationHeuristic(skillContent: "", tracePatternJson: patternJSON)
        let proposal = try #require(jsonObject(from: proposalJSON))
        #expect(proposal["mutation_type"] as? String == "instruction_tightening")
        #expect((proposal["reasoning"] as? String)?.contains("3 failing traces") == true)
    }

    @Test("iMessage adapter parses chat summaries for operator thread continuity")
    func iMessageAdapterParsesChatSummariesForOperatorThreadContinuity() {
        let json = """
        {
          "chats": [
            {
              "chat_id": 88,
              "display_name": "Alice",
              "identifier": "+15551234567",
              "archived": false,
              "last_activity_unix": 1712708800
            }
          ]
        }
        """

        let threads = IMessageChannelAdapter.parseThreads(from: json)

        #expect(threads.count == 1)
        #expect(threads.first?.conversationID == "88")
        #expect(threads.first?.title == "Alice")
        #expect(threads.first?.subtitle == "+15551234567")
        #expect(threads.first?.isArchived == false)
        #expect(threads.first?.lastActivityUnix == 1712708800)
    }

    @Test("remote relay parser normalizes generic inbox payloads")
    func remoteRelayParserNormalizesGenericInboxPayloads() {
        let json = """
        {
          "messages": [
            {
              "message_id": "abc123",
              "conversation_id": "thread-42",
              "sender_id": "alice",
              "text": "Need a status update",
              "unix": 1712708800,
              "from_me": false
            }
          ],
          "threads": [
            {
              "conversation_id": "thread-42",
              "title": "Alice",
              "subtitle": "@alice",
              "last_activity_unix": 1712708800,
              "archived": false
            }
          ]
        }
        """

        let messages = RemoteRelayChannelAdapter.parseUnreadMessages(from: json, channelID: "telegram")
        let threads = RemoteRelayChannelAdapter.parseThreads(from: json)
        let audit = RemoteRelayChannelAdapter.parseAuditEntries(from: json)

        #expect(messages.count == 1)
        #expect(messages.first?.channelID == "telegram")
        #expect(messages.first?.messageID == "abc123")
        #expect(messages.first?.conversationID == "thread-42")
        #expect(messages.first?.senderID == "alice")
        #expect(threads.count == 1)
        #expect(threads.first?.title == "Alice")
        #expect(audit.count == 1)
        #expect(audit.first?.isFromMe == false)
    }

    @Test("fallback adapter emits telemetry when the relay path fails and native fallback takes over")
    func fallbackAdapterEmitsTelemetryWhenPrimaryFails() async throws {
        let sent = LockIsolated<[String]>([])
        let telemetry = LockIsolated<[DriverChannelFallbackEvent]>([])
        let adapter = FallbackDriverChannelAdapter(
            primary: StubDriverChannelAdapter(
                channelID: "imessage",
                displayName: "Relay",
                sendError: DriverChannelError.toolCallFailed(channelID: "imessage", reason: "relay offline")
            ),
            fallback: StubDriverChannelAdapter(
                channelID: "imessage",
                displayName: "Native",
                sentMessages: sent
            ),
            onFallback: { event in
                telemetry.withValue { $0.append(event) }
            }
        )

        try await adapter.send(message: "hello", to: "+15551234567", vaultPath: "/tmp/vault")

        #expect(sent.value == ["hello"])
        #expect(telemetry.value.count == 1)
        #expect(telemetry.value[0].channelID == "imessage")
        #expect(telemetry.value[0].operation == .send)
        #expect(telemetry.value[0].primaryDisplayName == "Relay")
        #expect(telemetry.value[0].fallbackDisplayName == "Native")
        #expect(telemetry.value[0].errorDescription.contains("relay offline"))
    }

    @Test("channel route contact parser preserves shared sender overrides")
    func channelRouteContactParserPreservesSharedSenderOverrides() {
        let payload: [String: Any] = [
            "channel_id": "telegram",
            "handle": "alice",
            "display_name": "Alice",
            "model": "claude-sonnet-4-6",
            "tool_tier": "agent",
            "prompt_mode": "research",
            "allowed": true,
            "auto_reply": true,
            "auto_approve": true,
            "notes": "VIP operator"
        ]

        let contact = ChannelRouteContact.fromToolPayload(payload, defaultChannelID: .telegram)

        #expect(contact?.channelIdentity == .telegram)
        #expect(contact?.handle == "alice")
        #expect(contact?.displayName == "Alice")
        #expect(contact?.model == "claude-sonnet-4-6")
        #expect(contact?.toolTier == "agent")
        #expect(contact?.promptMode == "research")
        #expect(contact?.allowed == true)
        #expect(contact?.autoReply == true)
        #expect(contact?.autoApprove == true)
        #expect(contact?.notes == "VIP operator")
    }

    @Test("channel route contact parser defaults legacy iMessage payloads to iMessage")
    func channelRouteContactParserDefaultsLegacyIMessagePayloadsToIMessage() {
        let payload: [String: Any] = [
            "handle": "+15551234567",
            "display_name": "Alice",
            "model": "qwen-4b",
            "tool_tier": "chat_pro",
            "prompt_mode": "general",
            "allowed": true,
            "auto_reply": true,
            "auto_approve": false
        ]

        let contact = ChannelRouteContact.fromToolPayload(payload, defaultChannelID: .imessage)

        #expect(contact?.channelIdentity == .imessage)
        #expect(contact?.id == "imessage:+15551234567")
    }

    @Test("approval policy store loads lists and recent approval history from the vault")
    func approvalPolicyStoreLoadsListsAndRecentApprovalHistoryFromTheVault() throws {
        let fileManager = FileManager.default
        let vaultRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let hiddenRoot = vaultRoot.appendingPathComponent(".epistemos", isDirectory: true)
        let sessionsRoot = vaultRoot.appendingPathComponent("sessions", isDirectory: true)
        let sessionFolder = sessionsRoot.appendingPathComponent("2026-04-10_abcd1234", isDirectory: true)
        try fileManager.createDirectory(at: hiddenRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: sessionFolder, withIntermediateDirectories: true)

        let listsData = try JSONSerialization.data(withJSONObject: [
            "allowlist": ["git status", "cargo test"],
            "blocklist": ["rm -rf"],
            "last_modified": 1_712_708_800,
        ], options: [.prettyPrinted, .sortedKeys])
        try listsData.write(to: hiddenRoot.appendingPathComponent("approval_lists.json"))

        let traceEvents: [[String: Any]] = [
            [
                "timestamp": "2026-04-10T12:01:00Z",
                "kind": "approval",
                "name": "bash_execute",
                "input_summary": "{\"command\":\"git push\"}",
                "output_summary": "File modification operation",
                "outcome": "approved",
            ],
            [
                "timestamp": "2026-04-10T12:02:00Z",
                "kind": "approval",
                "name": "bash_execute",
                "input_summary": "{\"command\":\"rm -rf build\"}",
                "output_summary": "Command matches permanent blocklist",
                "outcome": "denied",
            ],
        ]
        let traceData = try JSONSerialization.data(withJSONObject: traceEvents, options: [.prettyPrinted, .sortedKeys])
        try traceData.write(to: sessionFolder.appendingPathComponent("trace.json"))

        let snapshot = try AgentApprovalPolicyStore.loadSnapshot(vaultPath: vaultRoot.path)
        let history = AgentApprovalPolicyStore.loadHistory(vaultPath: vaultRoot.path, limit: 8)

        #expect(snapshot.allowlist.map(\.pattern) == ["cargo test", "git status"])
        #expect(snapshot.blocklist.map(\.pattern) == ["rm -rf"])
        #expect(history.count == 2)
        #expect(history.first?.outcome == .denied)
        #expect(history.first?.toolName == "bash_execute")
        #expect(history.first?.reason == "Command matches permanent blocklist")
    }

    @Test("skill discovery catalog scans local roots and parses frontmatter")
    func skillDiscoveryCatalogScansLocalRootsAndParsesFrontmatter() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let bundledSkill = root
            .appendingPathComponent(".agents", isDirectory: true)
            .appendingPathComponent("skills", isDirectory: true)
            .appendingPathComponent("release-audit", isDirectory: true)
        let codexSkill = root
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("skills", isDirectory: true)
            .appendingPathComponent("checks", isDirectory: true)

        try fileManager.createDirectory(at: bundledSkill, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: codexSkill, withIntermediateDirectories: true)
        try writeSkill(
            at: bundledSkill.appendingPathComponent("SKILL.md"),
            name: "release-audit",
            description: "Audit the app before release.",
            category: "quality",
            tags: ["release", "audit"]
        )
        try writeSkill(
            at: codexSkill.appendingPathComponent("SKILL.md"),
            name: "checks",
            description: "Run targeted checks.",
            category: "testing",
            tags: ["tests"]
        )

        let entries = SkillDiscoveryCatalog.discoverSkillEntries(
            inRoots: [
                SkillDiscoveryRoot(
                    url: root.appendingPathComponent(".agents/skills", isDirectory: true),
                    source: .bundled
                ),
                SkillDiscoveryRoot(
                    url: root.appendingPathComponent(".codex/skills", isDirectory: true),
                    source: .codex
                ),
            ],
            fileManager: fileManager
        )

        #expect(entries.count == 2)
        #expect(entries.map(\.identifier) == ["checks", "release-audit"])
        #expect(entries.first(where: { $0.identifier == "checks" })?.category == "testing")
        #expect(entries.first(where: { $0.identifier == "release-audit" })?.tags == ["release", "audit"])
    }

    @Test("skill authoring draft builds managed create payload with normalized metadata")
    func skillAuthoringDraftBuildsManagedCreatePayloadWithNormalizedMetadata() throws {
        let draft = SkillAuthoringDraft(
            title: "Release Audit",
            description: "Audit the app before release.",
            category: "Quality / Release",
            tagsText: "release, audit, release",
            instructionSheet: """
            Use this skill when the user asks for a ship/no-ship call.

            1. Check logs first.
            2. Run the focused verification slice before making claims.
            """
        )

        #expect(draft.identifier == "release-audit")
        #expect(draft.normalizedCategory == "quality-release")
        #expect(draft.tags == ["release", "audit"])

        let payload = try draft.createPayload()
        #expect(payload["action"] as? String == "create")
        #expect(payload["name"] as? String == "release-audit")

        let content = try #require(payload["content"] as? String)
        #expect(content.contains("name: \"release-audit\""))
        #expect(content.contains("description: \"Audit the app before release.\""))
        #expect(content.contains("category: \"quality-release\""))
        #expect(content.contains("tags: [\"release\", \"audit\"]"))
        #expect(content.contains("## Instruction Sheet"))
    }

    @Test("skill authoring draft emits discovery-compatible skill markdown")
    func skillAuthoringDraftEmitsDiscoveryCompatibleSkillMarkdown() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let draft = SkillAuthoringDraft(
            title: "Source Synthesizer",
            description: "Merge notes into one research memo.",
            category: "Research",
            tagsText: "research, synthesis",
            instructionSheet: """
            Keep the output concise and source-grounded.
            """
        )

        let skillURL = root
            .appendingPathComponent("skills", isDirectory: true)
            .appendingPathComponent(draft.identifier, isDirectory: true)
            .appendingPathComponent("SKILL.md")
        try fileManager.createDirectory(at: skillURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try draft.skillMarkdown().write(to: skillURL, atomically: true, encoding: .utf8)

        let entries = SkillDiscoveryCatalog.discoverSkillEntries(
            inRoots: [
                SkillDiscoveryRoot(
                    url: root.appendingPathComponent("skills", isDirectory: true),
                    source: .bundled
                ),
            ],
            fileManager: fileManager
        )

        #expect(entries.count == 1)
        #expect(entries.first?.identifier == "source-synthesizer")
        #expect(entries.first?.category == "research")
        #expect(entries.first?.tags == ["research", "synthesis"])
        #expect(entries.first?.description == "Merge notes into one research memo.")
    }
}

private func jsonObject(from jsonString: String) -> [String: Any]? {
    guard let data = jsonString.data(using: .utf8) else {
        return nil
    }
    return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
}

private func jsonObject(at url: URL) -> [String: Any]? {
    guard let data = try? Data(contentsOf: url) else {
        return nil
    }
    return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
}

private func writeSessionMetadata(at folderURL: URL, sessionID: String) throws {
    let metadata: [String: Any] = [
        "id": sessionID,
        "model": "claude-sonnet",
        "provider": "anthropic",
        "started_at": "2026-04-10T00:00:00Z",
        "tags": ["smoke", "lineage"],
        "token_count": ["input": 0, "output": 0],
        "context_fill_pct": 0.0,
        "turn_count": 0,
        "status": "running",
    ]
    let data = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: folderURL.appendingPathComponent("session.json"))
}

private func writeSkill(
    at url: URL,
    name: String,
    description: String,
    category: String,
    tags: [String]
) throws {
    let content = """
    ---
    name: \(name)
    description: \(description)
    category: \(category)
    tags: [\(tags.map { "\"\($0)\"" }.joined(separator: ", "))]
    ---
    # \(name)

    Use this skill when the task matches \(name).
    """
    try content.write(to: url, atomically: true, encoding: .utf8)
}

private final class LockIsolated<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var storage: Value

    nonisolated init(_ value: Value) {
        self.storage = value
    }

    nonisolated var value: Value {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    nonisolated func withValue(_ body: (inout Value) -> Void) {
        lock.lock()
        body(&storage)
        lock.unlock()
    }
}

private struct StubDriverChannelAdapter: DriverChannelAdapting {
    let channelID: String
    let displayName: String
    var sendError: Error? = nil
    var sentMessages: LockIsolated<[String]>? = nil

    func fetchUnreadMessages(vaultPath: String, limit: Int) async throws -> [DriverChannelMessage] {
        []
    }

    func send(message: String, to recipientID: String, vaultPath: String) async throws {
        if let sendError {
            throw sendError
        }
        sentMessages?.withValue { $0.append(message) }
    }

    func listThreads(vaultPath: String, limit: Int) async throws -> [DriverChannelThreadSummary] {
        []
    }

    func recentAuditEntries(vaultPath: String, limit: Int) async throws -> [DriverChannelAuditEntry] {
        []
    }
}
