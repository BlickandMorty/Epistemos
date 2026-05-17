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
            model: .local(modelID: "mlx-community/Qwen3-8B-4bit", displayName: "Qwen 3 8B"),
            toolNames: ["vault.search", "note.create"],
            scope: .allNotes,
            approvalMode: .autoReadOnly
        ).missionPacket(id: "mission-queue", createdAt: Date(timeIntervalSince1970: 1))

        let text = packet.commandCenterQuery
        #expect(text.contains("AgentBlueprint MissionPacket"))
        #expect(text.contains("mission_packet_id: mission-queue"))
        #expect(text.contains("model: local:mlx-community/Qwen3-8B-4bit"))
        #expect(text.contains("model_badges: HONEST, LOCAL, Qwen XML, STRICT-GRAMMAR"))
        #expect(text.contains("scope: all_notes"))
        #expect(text.contains("approval_mode: auto_read_only"))
        #expect(text.contains("tools: note.create, vault.search"))
        #expect(text.contains("objective:\nSynthesize local evidence."))
    }

    @Test("Model choices expose honest runtime badges")
    func modelChoicesExposeRuntimeBadges() {
        let autoTitles = AgentBlueprintModelChoice.autoConstellation.badges.map(\.title)
        #expect(autoTitles == ["HONEST", "LOCAL-FIRST", "ROUTER", "STRICT-GRAMMAR"])

        let local = AgentBlueprintModelChoice.local(
            modelID: "mlx-community/DeepSeek-Coder-V2-Lite-Instruct-4bit",
            displayName: "DeepSeek-Coder"
        )
        #expect(local.badges.map(\.title).contains("LOCAL"))
        #expect(local.badges.map(\.title).contains("DeepSeek-Coder"))
        #expect(local.badges.map(\.tone).contains(.good))

        let cloud = AgentBlueprintModelChoice.cloud(provider: "openai", displayName: "OpenAI")
        #expect(cloud.badgeLine == "HONEST, CLOUD, ESCALATION")
        #expect(cloud.badges.contains(.init(title: "CLOUD", tone: .warning)))

        let appleTitles = AgentBlueprintModelChoice.appleIntelligence.badges.map(\.title)
        #expect(appleTitles.contains("EXPERIMENTAL"))
        #expect(appleTitles.contains("NO-TOOLS"))
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
}
