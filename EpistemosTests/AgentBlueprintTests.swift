import Foundation
import Testing
@testable import Epistemos

@Suite("AgentBlueprint mission packet")
struct AgentBlueprintTests {
    @Test("MissionPacket normalizes identity, tools, scope, and approval mode")
    func missionPacketNormalizesFields() {
        let draft = AgentBlueprintDraft(
            name: "  Research Assistant  ",
            role: "  Local synthesis agent  ",
            objective: "  Build an evidence-backed note.  ",
            model: .autoConstellation,
            toolNames: ["vault.search", "note.create", "vault.search", "  "],
            scope: .currentVault,
            approvalMode: .approveOncePerSession
        )

        let packet = draft.missionPacket(
            id: "mission-test",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        #expect(packet.blueprintName == "Research Assistant")
        #expect(packet.role == "Local synthesis agent")
        #expect(packet.objective == "Build an evidence-backed note.")
        #expect(packet.toolNames == ["note.create", "vault.search"])
        #expect(packet.scope == .currentVault)
        #expect(packet.approvalMode == .approveOncePerSession)
    }

    @Test("MissionPacket command text carries runtime queue fields")
    func missionPacketCommandTextCarriesRuntimeFields() {
        let packet = AgentBlueprintDraft(
            name: "Research Assistant",
            role: "Research",
            objective: "Synthesize local evidence.",
            model: .local(
                modelID: LocalTextModelID.qwen3_8B4Bit.rawValue,
                displayName: LocalTextModelID.qwen3_8B4Bit.displayName
            ),
            toolNames: ["vault.search", "note.create"],
            scope: .allNotes,
            approvalMode: .autoReadOnly
        ).missionPacket(id: "mission-queue", createdAt: Date(timeIntervalSince1970: 1))

        let text = packet.commandCenterQuery
        #expect(text.contains("AgentBlueprint MissionPacket"))
        #expect(text.contains("mission_packet_id: mission-queue"))
        #expect(text.contains("model: local:\(LocalTextModelID.qwen3_8B4Bit.rawValue)"))
        #expect(text.contains("model_badges: HONEST, LOCAL, Qwen XML, STRICT-GRAMMAR"))
        #expect(text.contains("execution_policy: local_only"))
        #expect(text.contains("cloud_escalation: disabled"))
        #expect(text.contains("strict_grammar: enabled"))
        #expect(text.contains("grammar_profile: qwen_xml"))
        #expect(text.contains("artifact_contract: note_artifact_and_answer_packet"))
        #expect(text.contains("scope: all_notes"))
        #expect(text.contains("approval_mode: auto_read_only"))
        #expect(text.contains("tools: note.create, vault.search"))
        #expect(text.contains("objective:\nSynthesize local evidence."))
    }

    @Test("MissionPacket command text yields run metadata without objective text")
    func missionPacketCommandTextYieldsRunMetadataWithoutObjectiveText() {
        let packet = AgentBlueprintDraft(
            name: "Research Assistant",
            role: "Research",
            objective: "Synthesize local evidence with private wording.",
            model: .autoConstellation,
            toolNames: ["vault.search", "note.create"],
            scope: .currentVault,
            approvalMode: .approveOncePerSession
        ).missionPacket(id: "mission-runtime", createdAt: Date(timeIntervalSince1970: 1))

        let metadata = AgentMissionPacket.runtimeMetadata(
            fromCommandCenterQuery: packet.commandCenterQuery
        )

        #expect(metadata["agent_blueprint"] == "true")
        #expect(metadata["mission_packet_id"] == "mission-runtime")
        #expect(metadata["agent_blueprint_name"] == "Research Assistant")
        #expect(metadata["agent_blueprint_model"] == "auto_constellation")
        #expect(metadata["agent_blueprint_model_badges"] == "HONEST, LOCAL-FIRST, ROUTER, STRICT-GRAMMAR")
        #expect(metadata["agent_blueprint_execution_policy"] == "local_only")
        #expect(metadata["agent_blueprint_cloud_escalation"] == "disabled")
        #expect(metadata["agent_blueprint_cloud_guard"] == "zero_cloud_required")
        #expect(metadata["agent_blueprint_network_policy"] == "local_runtime_only")
        #expect(metadata["agent_blueprint_strict_grammar"] == "enabled")
        #expect(metadata["agent_blueprint_grammar_profile"] == "router_native_strict")
        #expect(metadata["agent_blueprint_artifact_contract"] == "note_artifact_and_answer_packet")
        #expect(metadata["agent_blueprint_scope"] == "current_vault")
        #expect(metadata["agent_blueprint_approval_mode"] == "approve_once_per_session")
        #expect(metadata["agent_blueprint_tools"] == "note.create, vault.search")
        #expect(!metadata.values.contains { $0.contains("private wording") })
        #expect(AgentMissionPacket.runtimeMetadata(fromCommandCenterQuery: "ordinary prompt").isEmpty)

        #expect(packet.runtimeContractFields.contains(.init(
            label: "Cloud guard",
            value: "zero_cloud_required",
            tone: .good
        )))
        #expect(packet.runtimeContractFields.contains(.init(
            label: "Network",
            value: "local_runtime_only",
            tone: .good
        )))
        #expect(packet.runtimeContractFields.contains(.init(
            label: "Artifact",
            value: AgentMissionPacket.artifactContract,
            tone: .good
        )))
    }

    @Test("MissionPacket local-only runtime contract blocks hidden cloud fallback")
    func missionPacketLocalOnlyRuntimeContractBlocksHiddenCloudFallback() throws {
        let packet = AgentBlueprintDraft(
            name: "Research Assistant",
            role: "Research",
            objective: "Synthesize local evidence.",
            model: .autoConstellation,
            toolNames: ["vault.search", "note.create"],
            scope: .currentVault,
            approvalMode: .approveOncePerSession
        ).missionPacket(id: "mission-local-only", createdAt: Date(timeIntervalSince1970: 1))
        let metadata = AgentMissionPacket.runtimeMetadata(
            fromCommandCenterQuery: packet.commandCenterQuery
        )

        #expect(AgentMissionPacket.requiresLocalOnlyRuntime(metadata: metadata))
        #expect(throws: AgentRuntimeError.self) {
            try ChatCoordinator.validateMissionPacketRuntimeContract(
                metadata: metadata,
                resolvedRuntime: .cloud(provider: "openai", displayName: "OpenAI")
            )
        }
        try ChatCoordinator.validateMissionPacketRuntimeContract(
            metadata: metadata,
            resolvedRuntime: .local(modelId: "mlx-community/Qwen3-8B-4bit", displayName: "Qwen 3 8B")
        )

        let cloudPacket = AgentBlueprintDraft(
            name: "Cloud Research",
            role: "Research",
            objective: "Use explicit cloud escalation.",
            model: .cloud(provider: "openai", displayName: "OpenAI"),
            toolNames: ["vault.search"],
            scope: .currentVault,
            approvalMode: .askEveryTool
        ).missionPacket(id: "mission-cloud", createdAt: Date(timeIntervalSince1970: 2))
        let cloudMetadata = AgentMissionPacket.runtimeMetadata(
            fromCommandCenterQuery: cloudPacket.commandCenterQuery
        )
        #expect(AgentMissionPacket.allowsExplicitCloudEscalation(metadata: cloudMetadata))
        #expect(cloudPacket.runtimeContractFields.contains(.init(
            label: "Cloud guard",
            value: "explicit_cloud_allowed",
            tone: .warning
        )))
        #expect(cloudPacket.runtimeContractFields.contains(.init(
            label: "Network",
            value: "user_selected_cloud",
            tone: .warning
        )))
        try ChatCoordinator.validateMissionPacketRuntimeContract(
            metadata: cloudMetadata,
            resolvedRuntime: .cloud(provider: "openai", displayName: "OpenAI")
        )
    }

    @Test("Model choices expose honest runtime badges")
    func modelChoicesExposeRuntimeBadges() {
        let autoTitles = AgentBlueprintModelChoice.autoConstellation.badges.map(\.title)
        #expect(autoTitles == ["HONEST", "LOCAL-FIRST", "ROUTER", "STRICT-GRAMMAR"])
        #expect(!AgentBlueprintModelChoice.autoConstellation.requiresExplicitBrainOverride)

        let local = AgentBlueprintModelChoice.local(
            modelID: LocalTextModelID.qwen3_8B4Bit.rawValue,
            displayName: LocalTextModelID.qwen3_8B4Bit.displayName
        )
        #expect(local.badges.first == .init(title: "HONEST", tone: .good))
        #expect(local.badges.map(\.title).contains("LOCAL"))
        #expect(local.badges.map(\.title).contains("Qwen XML"))
        #expect(local.strictGrammarStatus == "enabled")
        #expect(local.requiresExplicitBrainOverride)

        let mistral = AgentBlueprintModelChoice.local(
            modelID: LocalTextModelID.mistralSmall31_24B4Bit.rawValue,
            displayName: "Mistral Small"
        )
        #expect(mistral.badges.first == .init(title: "EXPERIMENTAL", tone: .warning))
        #expect(mistral.badges.contains(.init(title: "Mistral Small", tone: .neutral)))
        #expect(mistral.strictGrammarStatus == "soft_guidance")

        let devstral = AgentBlueprintModelChoice.local(
            modelID: LocalTextModelID.devstralSmall2505_4Bit.rawValue,
            displayName: "Devstral Small"
        )
        #expect(devstral.badges.first == .init(title: "EXPERIMENTAL", tone: .warning))
        #expect(devstral.badges.contains(.init(title: "SOFT-GUIDED", tone: .warning)))
        #expect(devstral.strictGrammarStatus == "soft_guidance")

        let smol = AgentBlueprintModelChoice.local(
            modelID: LocalTextModelID.smolLM3_3B4Bit.rawValue,
            displayName: "SmolLM3"
        )
        #expect(smol.badges.first == .init(title: "OFF", tone: .disabled))
        #expect(smol.badges.contains(.init(title: "NO-TOOLS", tone: .disabled)))
        #expect(smol.strictGrammarStatus == "no_tools")

        let cloud = AgentBlueprintModelChoice.cloud(provider: "openai", displayName: "OpenAI")
        #expect(cloud.badgeLine == "HONEST, CLOUD, ESCALATION")
        #expect(cloud.badges.contains(.init(title: "CLOUD", tone: .warning)))
        #expect(cloud.executionPolicy == "cloud_escalation_explicit")
        #expect(cloud.cloudEscalation == "explicit_model_selection")
        #expect(cloud.requiresExplicitBrainOverride)

        let appleTitles = AgentBlueprintModelChoice.appleIntelligence.badges.map(\.title)
        #expect(appleTitles.contains("OFF"))
        #expect(appleTitles.contains("NO-TOOLS"))
        #expect(AgentBlueprintModelChoice.appleIntelligence.requiresExplicitBrainOverride)
    }

    @Test("Brain resolver replays the MissionPacket model contract")
    func brainResolverReplaysMissionPacketModelContract() {
        let qwen = ACCBrainSelection.local(
            modelId: "mlx-community/Qwen3-8B-4bit",
            displayName: "Qwen 3 8B",
            supportsThinking: true,
            supportsVision: false,
            supportsTools: true
        )
        let deepSeek = ACCBrainSelection.local(
            modelId: "mlx-community/DeepSeek-Coder-V2-Lite-Instruct-4bit",
            displayName: "DeepSeek-Coder",
            supportsThinking: true,
            supportsVision: false,
            supportsTools: true
        )
        let openAI = ACCBrainSelection.cloud(provider: .openAI)
        let brains: [ACCBrainSelection] = [
            deepSeek,
            openAI,
            .appleIntelligence,
            qwen,
        ]

        #expect(AgentBlueprintBrainResolver.brainSelection(
            for: .autoConstellation,
            availableBrains: brains
        ) == nil)
        #expect(AgentBlueprintBrainResolver.brainSelection(
            for: .local(modelID: "mlx-community/Qwen3-8B-4bit", displayName: "Qwen 3 8B"),
            availableBrains: brains
        ) == qwen)
        #expect(AgentBlueprintBrainResolver.brainSelection(
            for: .cloud(provider: "openai", displayName: "OpenAI"),
            availableBrains: brains
        ) == openAI)
        #expect(AgentBlueprintBrainResolver.brainSelection(
            for: .appleIntelligence,
            availableBrains: brains
        ) == .appleIntelligence)
        #expect(AgentBlueprintBrainResolver.brainSelection(
            for: .local(modelID: "missing-model", displayName: "Missing"),
            availableBrains: brains
        ) == nil)
    }

    @Test("Run store persists bounded replayable mission packets")
    func runStorePersistsBoundedReplayableMissionPackets() throws {
        let suiteName = "AgentBlueprintRunStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = AgentBlueprintDraft(
            name: "Research Assistant",
            role: "Research",
            objective: "First packet.",
            model: .autoConstellation,
            toolNames: ["vault.search"],
            scope: .currentVault,
            approvalMode: .approveOncePerSession
        ).missionPacket(id: "mission-first", createdAt: Date(timeIntervalSince1970: 10))

        let second = AgentBlueprintDraft(
            name: "Coder",
            role: "Code review",
            objective: "Second packet.",
            model: .local(modelID: "mlx-community/DeepSeek-Coder-V2-Lite-Instruct-4bit", displayName: "DeepSeek-Coder"),
            toolNames: ["workspace.search"],
            scope: .currentWorkspace,
            approvalMode: .askEveryTool
        ).missionPacket(id: "mission-second", createdAt: Date(timeIntervalSince1970: 20))

        AgentBlueprintRunStore.record(
            first,
            queuedAt: Date(timeIntervalSince1970: 100),
            defaults: defaults,
            limit: 2
        )
        AgentBlueprintRunStore.record(
            second,
            queuedAt: Date(timeIntervalSince1970: 200),
            defaults: defaults,
            limit: 2
        )
        AgentBlueprintRunStore.record(
            first,
            queuedAt: Date(timeIntervalSince1970: 300),
            defaults: defaults,
            limit: 2
        )

        let records = AgentBlueprintRunStore.load(defaults: defaults, limit: 2)
        #expect(records.map(\.id) == ["mission-first", "mission-second"])
        #expect(records.first?.packet.commandCenterQuery.contains("mission_packet_id: mission-first") == true)
        #expect(records.first?.packet.commandCenterQuery.contains("model_badges: HONEST, LOCAL-FIRST, ROUTER, STRICT-GRAMMAR") == true)

        AgentBlueprintRunStore.clear(defaults: defaults)
        #expect(AgentBlueprintRunStore.load(defaults: defaults).isEmpty)
    }

    @Test("Run records resolve latest RunEventLog replay snapshot")
    func runRecordsResolveLatestRunEventLogReplaySnapshot() throws {
        let packet = AgentBlueprintDraft(
            name: "Research Assistant",
            role: "Research",
            objective: "Replay the latest run.",
            model: .autoConstellation,
            toolNames: ["vault.search", "note.create"],
            scope: .currentVault,
            approvalMode: .approveOncePerSession
        ).missionPacket(id: "mission-replay", createdAt: Date(timeIntervalSince1970: 10))
        let record = AgentBlueprintRunRecord(
            packet: packet,
            queuedAt: Date(timeIntervalSince1970: 20)
        )
        let olderRun = AgentProvenanceEvent(
            eventID: "older-start",
            runID: "run-old",
            sequence: 0,
            kind: .runStarted,
            actor: .agent(id: "agent", modelID: "qwen-local"),
            occurredAtMs: 1_000,
            metadata: ["mission_packet_id": packet.id]
        )
        let latestStart = AgentProvenanceEvent(
            eventID: "latest-start",
            runID: "run-newer",
            sequence: 0,
            kind: .runStarted,
            actor: .agent(id: "agent", modelID: "qwen-local"),
            occurredAtMs: 2_000,
            metadata: ["mission_packet_id": packet.id]
        )
        let latestComplete = AgentProvenanceEvent(
            eventID: "latest-complete",
            runID: "run-newer",
            sequence: 1,
            kind: .runCompleted,
            actor: .agent(id: "agent", modelID: "qwen-local"),
            occurredAtMs: 3_000,
            metadata: [
                "mission_packet_id": packet.id,
                "answer_packet_id": "packet-123"
            ]
        )
        let unrelated = AgentProvenanceEvent(
            eventID: "unrelated",
            runID: "run-other",
            sequence: 0,
            kind: .runStarted,
            actor: .agent(id: "agent", modelID: "qwen-local"),
            occurredAtMs: 4_000,
            metadata: ["mission_packet_id": "other-mission"]
        )

        let snapshot = try #require(record.replaySnapshot(from: [
            unrelated,
            latestComplete,
            olderRun,
            latestStart,
        ]))

        #expect(snapshot.runID == "run-newer")
        #expect(snapshot.shortRunID == "run-newer")
        #expect(snapshot.eventCount == 2)
        #expect(snapshot.latestEventKind == AgentProvenanceEventKind.runCompleted.rawValue)
        #expect(snapshot.answerPacketId == "packet-123")
        #expect(snapshot.replayStatus == .missingPacket)
        #expect(snapshot.summary == "2 events · missing packet")
        #expect(record.replaySnapshot(from: [unrelated]) == nil)
    }

    @Test("Minimal AgentBlueprint run emits replayable AnswerPacket evidence into chat row")
    @MainActor
    func minimalAgentBlueprintRunEmitsReplayableAnswerPacketEvidenceIntoChatRow() async throws {
        await AnswerPacketEmitter.shared.resetForTesting()

        let packet = AgentBlueprintDraft(
            name: "Research Assistant",
            role: "Research",
            objective: "Summarize the replay witness.",
            model: .autoConstellation,
            toolNames: ["vault.search"],
            scope: .currentVault,
            approvalMode: .autoReadOnly
        ).missionPacket(id: "mission-e2e-replay", createdAt: Date(timeIntervalSince1970: 10))
        let record = AgentBlueprintRunRecord(
            packet: packet,
            queuedAt: Date(timeIntervalSince1970: 11)
        )

        let log = try await RealSystemGRunSeam().run(mission: packet)
        let answerPacket = try #require(await AnswerPacketEmitter.shared.recentPackets().last)
        let events = try AgentBlueprintRunEventProjector.events(
            packet: packet,
            log: log,
            answerPacket: answerPacket
        )

        let snapshot = try #require(record.replaySnapshot(
            from: events,
            packets: [answerPacket]
        ))
        #expect(snapshot.runID == log.missionId)
        #expect(snapshot.answerPacketId == answerPacket.id)
        #expect(snapshot.replayStatus == .verified)
        #expect(snapshot.summary == "3 events · replay verified")

        let chat = AgentChatState()
        chat.submitAgentQuery(packet.objective)
        chat.startStreaming()
        chat.appendStreamingText(try RunEventLogReplayProjection.answerText(from: log))
        chat.completeProcessing(
            mode: .local,
            resolvedModelLabel: "System G",
            answerPacketId: answerPacket.id
        )

        let assistant = try #require(chat.messages.last)
        #expect(assistant.role == .assistant)
        #expect(assistant.answerPacketId == answerPacket.id)
        #expect(assistant.content == "Summarize the replay witness.")

        let timeline = AgentRunTimelineItem.replayItems(from: events)
        #expect(timeline.map(\.title) == ["Plan", "Summary", "Output"])
        #expect(timeline.last?.detail.contains(answerPacket.id) == true)
    }

    @Test("RunEventLog replay snapshot exposes AnswerPacket display fields")
    func runEventLogReplaySnapshotExposesAnswerPacketDisplayFields() throws {
        let packet = AgentBlueprintDraft(
            name: "Research Assistant",
            role: "Research",
            objective: "Replay visible packet fields.",
            model: .autoConstellation,
            toolNames: ["vault.search"],
            scope: .currentVault,
            approvalMode: .autoReadOnly
        ).missionPacket(id: "mission-visible-replay", createdAt: Date(timeIntervalSince1970: 30))
        let record = AgentBlueprintRunRecord(
            packet: packet,
            queuedAt: Date(timeIntervalSince1970: 31)
        )
        var log = RunEventLog(missionId: "run-visible-replay")
        log.append(.planStart(turnId: "turn-visible", plan: "show replay proof"))
        log.append(.tokenChunk(turnId: "turn-visible", text: "Visible replay proof."))
        log.append(.complete(turnId: "turn-visible", answerPacketId: "packet-visible-replay"))

        let answerPacket = AnswerPacket(
            id: "packet-visible-replay",
            claims: [
                Claim(
                    id: "claim-visible-replay",
                    text: "Replay proof is visible.",
                    status: .active,
                    createdAtMs: 30_000,
                    kind: .empirical
                )
            ],
            residencySignals: [.neutral],
            uiLabel: .verified,
            attentionMode: .dynamic,
            interruptBucket: .high,
            witnessedStateRef: "run_event_log:run-visible-replay;answer_packet:packet-visible-replay;events:3",
            mutationEnvelopeRef: "run_event_log:run-visible-replay"
        )

        let events = try AgentBlueprintRunEventProjector.events(
            packet: packet,
            log: log,
            answerPacket: answerPacket
        )
        let snapshot = try #require(record.replaySnapshot(
            from: events,
            packets: [answerPacket]
        ))

        #expect(snapshot.replayStatus == .verified)
        #expect(snapshot.answerPacketUILabel == VRMLabel.verified.rawValue)
        #expect(snapshot.answerPacketAttentionMode == AttentionMode.dynamic.rawValue)
        #expect(snapshot.answerPacketInterruptBucket == InterruptBucket.high.rawValue)
        #expect(snapshot.answerPacketReplayDetail == "verified · dynamic · high")
    }

    @Test("RunEventLog replay status fails explicit instead of promoting missing or invalid evidence")
    func runEventLogReplayStatusFailsExplicitInsteadOfPromotingMissingOrInvalidEvidence() throws {
        let packet = AgentBlueprintDraft(
            name: "Research Assistant",
            role: "Research",
            objective: "Check replay status.",
            model: .autoConstellation,
            toolNames: ["vault.search"],
            scope: .currentVault,
            approvalMode: .autoReadOnly
        ).missionPacket(id: "mission-status", createdAt: Date(timeIntervalSince1970: 20))
        let record = AgentBlueprintRunRecord(
            packet: packet,
            queuedAt: Date(timeIntervalSince1970: 21)
        )
        let completion = AgentProvenanceEvent(
            eventID: "status-complete",
            runID: "run-status",
            sequence: 1,
            kind: .runCompleted,
            actor: .agent(id: "system_g", modelID: "auto_constellation"),
            occurredAtMs: 21_001,
            metadata: [
                "mission_packet_id": packet.id,
                "answer_packet_id": "packet-status"
            ]
        )
        let invalidPacket = AnswerPacket(
            id: "packet-status",
            claims: [],
            uiLabel: .verified,
            witnessedStateRef: "run_event_log:other-run",
            mutationEnvelopeRef: "packet-status"
        )

        let missingPacket = try #require(record.replaySnapshot(from: [completion], packets: []))
        #expect(missingPacket.replayStatus == .missingPacket)
        #expect(missingPacket.summary == "1 events · missing packet")

        let invalidProof = try #require(record.replaySnapshot(
            from: [completion],
            packets: [invalidPacket]
        ))
        #expect(invalidProof.replayStatus == .invalidProof)
        #expect(invalidProof.summary == "1 events · invalid proof")
    }
}
