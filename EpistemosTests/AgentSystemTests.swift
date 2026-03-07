import Testing
import Foundation
@testable import Epistemos

// MARK: - Agent Types Tests

@Suite("AgentID")
struct AgentIDTests {

    @Test("All agent IDs have display names")
    func displayNames() {
        for id in AgentID.allCases {
            #expect(!id.displayName.isEmpty)
        }
    }

    @Test("All agent IDs have icon names")
    func iconNames() {
        for id in AgentID.allCases {
            #expect(!id.iconName.isEmpty)
        }
    }

    @Test("Agent IDs are unique raw values")
    func uniqueRawValues() {
        let values = AgentID.allCases.map(\.rawValue)
        #expect(Set(values).count == values.count)
    }

    @Test("Four agents exist")
    func agentCount() {
        #expect(AgentID.allCases.count == 4)
    }
}

// MARK: - Agent Status Tests

@Suite("AgentStatus")
struct AgentStatusTests {

    @Test("Idle is not active")
    func idleInactive() {
        #expect(!AgentStatus.idle.isActive)
    }

    @Test("Thinking is active")
    func thinkingActive() {
        #expect(AgentStatus.thinking.isActive)
    }

    @Test("Working is active")
    func workingActive() {
        #expect(AgentStatus.working(task: "test").isActive)
    }

    @Test("WaitingForApproval is not active")
    func waitingNotActive() {
        #expect(!AgentStatus.waitingForApproval(action: "test").isActive)
    }

    @Test("Error is not active")
    func errorNotActive() {
        #expect(!AgentStatus.error("test").isActive)
    }

    @Test("Labels are non-empty")
    func labelsExist() {
        let statuses: [AgentStatus] = [
            .idle, .thinking, .working(task: "x"),
            .waitingForApproval(action: "y"), .error("z")
        ]
        for status in statuses {
            #expect(!status.label.isEmpty)
        }
    }
}

// MARK: - Trust Level Tests

@Suite("TrustLevel")
struct TrustLevelTests {

    @Test("Ordering: sandbox < standard < elevated")
    func ordering() {
        #expect(TrustLevel.sandbox < TrustLevel.standard)
        #expect(TrustLevel.standard < TrustLevel.elevated)
        #expect(TrustLevel.sandbox < TrustLevel.elevated)
    }

    @Test("Equal trust levels are not less than each other")
    func equality() {
        #expect(!(TrustLevel.standard < TrustLevel.standard))
    }
}

// MARK: - Agent Task Tests

@Suite("AgentTask")
struct AgentTaskTests {

    @Test("Task has unique ID")
    func uniqueId() {
        let t1 = AgentTask(from: .triage, to: .builder, instruction: "test")
        let t2 = AgentTask(from: .triage, to: .builder, instruction: "test")
        #expect(t1.id != t2.id)
    }

    @Test("Task preserves properties")
    func properties() {
        let task = AgentTask(from: .triage, to: .writer, instruction: "write", context: "ctx")
        #expect(task.from == .triage)
        #expect(task.to == .writer)
        #expect(task.instruction == "write")
        #expect(task.context == "ctx")
    }
}

// MARK: - MessageBus Tests

@Suite("MessageBus")
struct MessageBusTests {

    @Test("Publish delivers to targeted subscriber")
    func targetedDelivery() async {
        let bus = MessageBus()
        let stream = await bus.subscribe(for: .builder)
        let task = AgentTask(from: .triage, to: .builder, instruction: "build it")

        await bus.publish(.taskAssignment(from: .triage, to: .builder, task: task))

        var received: MessageBus.Message?
        for await msg in stream {
            received = msg
            break
        }

        #expect(received != nil)
    }

    @Test("Agent only receives messages targeted to it or broadcasts")
    func filtering() async {
        let bus = MessageBus()
        let writerStream = await bus.subscribe(for: .writer)

        // Send message targeted to builder — writer should NOT get it
        let task = AgentTask(from: .triage, to: .builder, instruction: "build")
        await bus.publish(.taskAssignment(from: .triage, to: .builder, task: task))

        // Send broadcast (insight with nil target) — writer SHOULD get it
        await bus.publish(.insight(from: .librarian, relevantTo: nil, content: "broadcast"))

        var received: MessageBus.Message?
        for await msg in writerStream {
            received = msg
            break
        }

        if case .insight(_, _, let content) = received {
            #expect(content == "broadcast")
        } else {
            #expect(Bool(false), "Expected broadcast insight, got \(String(describing: received))")
        }
    }

    @Test("UI subscriber receives all messages")
    func uiReceivesAll() async {
        let bus = MessageBus()
        let uiStream = await bus.subscribeAll()

        await bus.publish(.statusUpdate(from: .triage, status: .thinking))

        var received: MessageBus.Message?
        for await msg in uiStream {
            received = msg
            break
        }

        #expect(received != nil)
    }

    @Test("Activity buffer stores recent messages")
    func activityBuffer() async {
        let bus = MessageBus()

        await bus.publish(.activityLog(from: .triage, action: "test", detail: "detail"))
        await bus.publish(.activityLog(from: .builder, action: "build", detail: "stuff"))

        let recent = await bus.recentActivity()
        #expect(recent.count == 2)
    }

    @Test("Activity buffer caps at 100")
    func activityCap() async {
        let bus = MessageBus()

        for i in 0..<150 {
            await bus.publish(.activityLog(from: .triage, action: "test\(i)", detail: ""))
        }

        let recent = await bus.recentActivity()
        #expect(recent.count == 100)
    }

    @Test("Filter activity by agent")
    func activityByAgent() async {
        let bus = MessageBus()

        await bus.publish(.activityLog(from: .triage, action: "t", detail: ""))
        await bus.publish(.activityLog(from: .builder, action: "b", detail: ""))
        await bus.publish(.activityLog(from: .triage, action: "t2", detail: ""))

        let triageActivity = await bus.recentActivity(for: .triage)
        #expect(triageActivity.count == 2)
    }

    @Test("Clear activity empties buffer")
    func clearActivity() async {
        let bus = MessageBus()

        await bus.publish(.activityLog(from: .triage, action: "test", detail: ""))
        await bus.clearActivity()

        let recent = await bus.recentActivity()
        #expect(recent.isEmpty)
    }

    @Test("Message sender returns correct agent")
    func messageSender() {
        let msg = MessageBus.Message.statusUpdate(from: .librarian, status: .idle)
        #expect(msg.sender == .librarian)
    }

    @Test("Message targetAgent returns correct target")
    func messageTarget() {
        let task = AgentTask(from: .triage, to: .writer, instruction: "")
        let msg = MessageBus.Message.taskAssignment(from: .triage, to: .writer, task: task)
        #expect(msg.targetAgent == .writer)
    }

    @Test("Broadcast message has nil target")
    func broadcastTarget() {
        let msg = MessageBus.Message.statusUpdate(from: .triage, status: .idle)
        #expect(msg.targetAgent == nil)
    }
}

// MARK: - Triage Classification Tests

@Suite("TriageAgent Classification")
struct TriageClassificationTests {

    @Test("Parses DIRECT response")
    func parseDirect() {
        #expect(TriageAgent.parseClassification("DIRECT") == .direct)
        #expect(TriageAgent.parseClassification("  direct  ") == .direct)
    }

    @Test("Parses LIBRARIAN response")
    func parseLibrarian() {
        #expect(TriageAgent.parseClassification("LIBRARIAN") == .librarian)
        #expect(TriageAgent.parseClassification("-> LIBRARIAN") == .librarian)
    }

    @Test("Parses WRITER response")
    func parseWriter() {
        #expect(TriageAgent.parseClassification("WRITER") == .writer)
    }

    @Test("Parses BUILDER response")
    func parseBuilder() {
        #expect(TriageAgent.parseClassification("BUILDER") == .builder)
    }

    @Test("Parses LEARNING_POOL response")
    func parseLearningPool() {
        #expect(TriageAgent.parseClassification("LEARNING_POOL") == .learningPool)
        #expect(TriageAgent.parseClassification("LEARNING") == .learningPool)
    }

    @Test("Unknown response defaults to direct")
    func parseUnknown() {
        #expect(TriageAgent.parseClassification("???") == .direct)
        #expect(TriageAgent.parseClassification("") == .direct)
    }

    @Test("Classification prompt contains user input")
    func promptContainsInput() {
        let prompt = TriageAgent.classificationPrompt(for: "test query")
        #expect(prompt.contains("test query"))
    }

    @Test("Classification prompt contains all categories")
    func promptCategories() {
        let prompt = TriageAgent.classificationPrompt(for: "x")
        #expect(prompt.contains("DIRECT"))
        #expect(prompt.contains("LIBRARIAN"))
        #expect(prompt.contains("WRITER"))
        #expect(prompt.contains("BUILDER"))
        #expect(prompt.contains("LEARNING_POOL"))
    }
}

// MARK: - Triage Keyword Fallback Tests

@Suite("TriageAgent Keyword Fallback")
struct TriageKeywordFallbackTests {

    private func makeAgent() -> TriageAgent {
        TriageAgent(messageBus: MessageBus(), mlxClient: nil)
    }

    @Test("Code-related query routes to builder")
    func builderKeywords() async {
        let agent = makeAgent()
        let result = await agent.classify("write me a swift function")
        #expect(result == .builder)
    }

    @Test("Writing query routes to writer")
    func writerKeywords() async {
        let agent = makeAgent()
        let result = await agent.classify("rewrite this paragraph")
        #expect(result == .writer)
    }

    @Test("Note query routes to librarian")
    func librarianKeywords() async {
        let agent = makeAgent()
        let result = await agent.classify("find my notes about physics")
        #expect(result == .librarian)
    }

    @Test("Research query routes to learning pool")
    func poolKeywords() async {
        let agent = makeAgent()
        let result = await agent.classify("what is the latest research on AI")
        #expect(result == .learningPool)
    }

    @Test("Greeting defaults to direct")
    func directFallback() async {
        let agent = makeAgent()
        let result = await agent.classify("hello there")
        #expect(result == .direct)
    }
}

// MARK: - Triage Classification Enum

@Suite("TriageClassification")
struct TriageClassificationEnumTests {

    @Test("All raw values are non-empty")
    func rawValues() {
        let all: [TriageClassification] = [.direct, .librarian, .writer, .builder, .learningPool]
        for c in all {
            #expect(!c.rawValue.isEmpty)
        }
    }
}

// MARK: - LibrarianAgent Tests

@Suite("LibrarianAgent")
struct LibrarianAgentTests {

    private func makeAgent() -> LibrarianAgent {
        LibrarianAgent(messageBus: MessageBus())
    }

    @Test("Has correct ID")
    func agentId() {
        let agent = makeAgent()
        #expect(agent.id == .librarian)
    }

    @Test("Starts idle")
    func startsIdle() {
        let agent = makeAgent()
        #expect(agent.status == .idle)
    }

    @Test("Default trust level is standard")
    func defaultTrust() {
        let agent = makeAgent()
        #expect(agent.trustLevel == .standard)
    }

    @Test("Handles task and returns to idle")
    func handleTask() async {
        let agent = makeAgent()
        let task = AgentTask(from: .triage, to: .librarian, instruction: "find notes about Swift")
        await agent.handleTask(task)
        #expect(agent.status == .idle)
    }

    @Test("Handles mention and returns response")
    func handleMention() async {
        let agent = makeAgent()
        let response = await agent.handleMention(from: .writer, context: "", request: "find citations")
        #expect(response.contains("Librarian"))
        #expect(agent.status == .idle)
    }

    @Test("Cancel resets to idle")
    func cancelResets() {
        let agent = makeAgent()
        agent.cancel()
        #expect(agent.status == .idle)
    }
}

// MARK: - WriterAgent Tests

@Suite("WriterAgent")
struct WriterAgentTests {

    private func makeAgent() -> WriterAgent {
        WriterAgent(messageBus: MessageBus())
    }

    @Test("Has correct ID")
    func agentId() {
        let agent = makeAgent()
        #expect(agent.id == .writer)
    }

    @Test("Starts idle")
    func startsIdle() {
        let agent = makeAgent()
        #expect(agent.status == .idle)
    }

    @Test("Default trust level is standard")
    func defaultTrust() {
        let agent = makeAgent()
        #expect(agent.trustLevel == .standard)
    }

    @Test("Handles task and returns to idle")
    func handleTask() async {
        let agent = makeAgent()
        let task = AgentTask(from: .triage, to: .writer, instruction: "rewrite this paragraph")
        await agent.handleTask(task)
        #expect(agent.status == .idle)
    }

    @Test("Handles mention and returns response")
    func handleMention() async {
        let agent = makeAgent()
        let response = await agent.handleMention(from: .librarian, context: "", request: "improve prose")
        #expect(response.contains("Writer"))
        #expect(agent.status == .idle)
    }

    @Test("Cancel resets to idle")
    func cancelResets() {
        let agent = makeAgent()
        agent.cancel()
        #expect(agent.status == .idle)
    }
}

// MARK: - BuilderAgent Tests

@Suite("BuilderAgent")
struct BuilderAgentTests {

    private func makeAgent() -> BuilderAgent {
        BuilderAgent(messageBus: MessageBus())
    }

    @Test("Has correct ID")
    func agentId() {
        let agent = makeAgent()
        #expect(agent.id == .builder)
    }

    @Test("Starts idle")
    func startsIdle() {
        let agent = makeAgent()
        #expect(agent.status == .idle)
    }

    @Test("Default trust level is sandbox")
    func defaultTrust() {
        let agent = makeAgent()
        #expect(agent.trustLevel == .sandbox)
    }

    @Test("Handles task and returns to idle")
    func handleTask() async {
        let agent = makeAgent()
        let task = AgentTask(from: .triage, to: .builder, instruction: "write a parser")
        await agent.handleTask(task)
        #expect(agent.status == .idle)
    }

    @Test("Handles mention and returns response")
    func handleMention() async {
        let agent = makeAgent()
        let response = await agent.handleMention(from: .triage, context: "", request: "build an API")
        #expect(response.contains("Builder"))
        #expect(agent.status == .idle)
    }

    @Test("Cancel resets to idle")
    func cancelResets() {
        let agent = makeAgent()
        agent.cancel()
        #expect(agent.status == .idle)
    }

    @Test("Trust level can be elevated")
    func trustElevation() {
        let agent = makeAgent()
        #expect(agent.trustLevel == .sandbox)
        agent.trustLevel = .elevated
        #expect(agent.trustLevel == .elevated)
    }
}

// MARK: - LearningPoolState Tests

@Suite("LearningPoolState")
struct LearningPoolStateTests {

    @Test("Default search mode is balanced")
    func defaultMode() {
        let state = LearningPoolState()
        #expect(state.searchMode == .balanced)
    }

    @Test("Search modes have correct iteration limits")
    func iterationLimits() {
        #expect(LearningPoolState.SearchMode.speed.maxIterations == 2)
        #expect(LearningPoolState.SearchMode.balanced.maxIterations == 6)
        #expect(LearningPoolState.SearchMode.quality.maxIterations == 25)
    }

    @Test("All search modes have display names")
    func displayNames() {
        for mode in LearningPoolState.SearchMode.allCases {
            #expect(!mode.displayName.isEmpty)
        }
    }

    @Test("Default source config enables all sources")
    func defaultSources() {
        let config = LearningPoolState.SourceConfig()
        #expect(config.web)
        #expect(config.academic)
        #expect(config.notes)
    }

    @Test("Adding results caps at 50")
    func resultCap() {
        let state = LearningPoolState()
        for i in 0..<60 {
            state.addResult(LearningPoolState.PoolSearchResult(
                id: "\(i)", query: "q\(i)", answer: "a", sources: [], timestamp: Date()
            ))
        }
        #expect(state.recentSearches.count == 50)
    }

    @Test("Most recent result is first")
    func recentFirst() {
        let state = LearningPoolState()
        state.addResult(LearningPoolState.PoolSearchResult(
            id: "1", query: "first", answer: "", sources: [], timestamp: Date()
        ))
        state.addResult(LearningPoolState.PoolSearchResult(
            id: "2", query: "second", answer: "", sources: [], timestamp: Date()
        ))
        #expect(state.recentSearches.first?.query == "second")
    }

    @Test("Clear history empties results")
    func clearHistory() {
        let state = LearningPoolState()
        state.addResult(LearningPoolState.PoolSearchResult(
            id: "1", query: "test", answer: "", sources: [], timestamp: Date()
        ))
        state.clearHistory()
        #expect(state.recentSearches.isEmpty)
    }

    @Test("Error can be set and cleared")
    func errorHandling() {
        let state = LearningPoolState()
        #expect(state.error == nil)
        state.setError("test error")
        #expect(state.error == "test error")
        state.setError(nil)
        #expect(state.error == nil)
    }

    @Test("Not searching by default")
    func notSearching() {
        let state = LearningPoolState()
        #expect(!state.isSearching)
        #expect(state.currentQuery.isEmpty)
    }
}

// MARK: - AgentNPCState Tests

@Suite("AgentNPCState")
struct AgentNPCStateTests {

    @Test("Glow colors are unique per agent")
    func uniqueGlowColors() {
        let colors = AgentID.allCases.map { AgentNPCState(agentId: $0).glowColor }
        for i in 0..<colors.count {
            for j in (i + 1)..<colors.count {
                #expect(colors[i] != colors[j])
            }
        }
    }

    @Test("Starts idle with zero position")
    func startsIdle() {
        let npc = AgentNPCState(agentId: .librarian)
        #expect(npc.animState == .idle)
        #expect(npc.position == .zero)
        #expect(npc.targetNodeId == nil)
        #expect(npc.trailPoints.isEmpty)
    }

    @Test("Attach sets target and increases glow")
    func attachBehavior() {
        let npc = AgentNPCState(agentId: .writer)
        let baseGlow = npc.glowIntensity
        npc.attachTo(nodeId: "node-1", at: .init(1, 2, 3))
        #expect(npc.targetNodeId == "node-1")
        #expect(npc.glowIntensity > baseGlow)
        #expect(npc.animState == .attached(angle: 0))
    }

    @Test("Working increases glow further")
    func workingGlow() {
        let npc = AgentNPCState(agentId: .builder)
        npc.startWorking()
        #expect(npc.glowIntensity == 0.8)
    }

    @Test("Return to idle clears state")
    func returnToIdle() {
        let npc = AgentNPCState(agentId: .triage)
        npc.attachTo(nodeId: "x", at: .init(1, 0, 0))
        npc.startWorking()
        npc.returnToIdle()
        #expect(npc.animState == .idle)
        #expect(npc.targetNodeId == nil)
        #expect(npc.glowIntensity == 0.3)
        #expect(npc.trailPoints.isEmpty)
    }
}

// MARK: - AgentEngine Integration Tests

@Suite("AgentEngine Integration")
struct AgentEngineIntegrationTests {

    @Test("Engine registers and retrieves agents")
    func registerRetrieve() {
        let engine = AgentEngine()
        let librarian = LibrarianAgent(messageBus: engine.messageBus)
        engine.register(librarian)

        #expect(engine.agent(for: .librarian) != nil)
        #expect(engine.agent(for: .builder) == nil)
    }

    @Test("Engine tracks statuses for all registered agents")
    func statusTracking() {
        let engine = AgentEngine()
        engine.register(LibrarianAgent(messageBus: engine.messageBus))
        engine.register(WriterAgent(messageBus: engine.messageBus))
        engine.register(BuilderAgent(messageBus: engine.messageBus))

        #expect(engine.status(for: .librarian) == .idle)
        #expect(engine.status(for: .writer) == .idle)
        #expect(engine.status(for: .builder) == .idle)
    }

    @Test("Engine starts and stops")
    func startStop() {
        let engine = AgentEngine()
        engine.register(LibrarianAgent(messageBus: engine.messageBus))

        #expect(!engine.isRunning)
        engine.start()
        #expect(engine.isRunning)
        engine.stop()
        #expect(!engine.isRunning)
    }

    @Test("Active agents list is empty when all idle")
    func activeAgentsEmpty() {
        let engine = AgentEngine()
        engine.register(LibrarianAgent(messageBus: engine.messageBus))
        engine.register(WriterAgent(messageBus: engine.messageBus))

        #expect(engine.activeAgents.isEmpty)
    }

    @Test("Unregistered agent returns idle status")
    func unregisteredStatus() {
        let engine = AgentEngine()
        #expect(engine.status(for: .triage) == .idle)
    }
}

// MARK: - VoiceEngine Tests

@Suite("VoiceEngine")
struct VoiceEngineTests {

    @Test("Initial state is stopped")
    @MainActor func initialState() {
        let engine = VoiceEngine()
        #expect(engine.state == .stopped)
        #expect(!engine.isReady)
        #expect(!engine.readModeEnabled)
    }

    @Test("Start transitions to ready")
    @MainActor func startTransition() async {
        let engine = VoiceEngine()
        await engine.start()
        #expect(engine.state == .ready)
        #expect(engine.isReady)
    }

    @Test("Stop transitions to stopped")
    @MainActor func stopTransition() async {
        let engine = VoiceEngine()
        await engine.start()
        engine.stop()
        #expect(engine.state == .stopped)
        #expect(!engine.isReady)
    }

    @Test("Start when already started is no-op")
    @MainActor func doubleStart() async {
        let engine = VoiceEngine()
        await engine.start()
        await engine.start()
        #expect(engine.state == .ready)
    }

    @Test("Voice configs initialized for all agents")
    @MainActor func voiceConfigsInitialized() {
        let engine = VoiceEngine()
        for agent in AgentID.allCases {
            let config = engine.voiceConfigs[agent]
            #expect(config != nil)
            #expect(config?.enabled == false)
            #expect(config?.referenceAudioPath == nil)
        }
    }

    @Test("Set voice enabled")
    @MainActor func setVoiceEnabled() {
        let engine = VoiceEngine()
        engine.setVoiceEnabled(true, for: .librarian)
        #expect(engine.voiceConfigs[.librarian]?.enabled == true)
        #expect(engine.voiceConfigs[.writer]?.enabled == false)
    }

    @Test("Set reference audio path")
    @MainActor func setReferenceAudio() {
        let engine = VoiceEngine()
        engine.setReferenceAudio("/path/to/voice.wav", for: .writer)
        #expect(engine.voiceConfigs[.writer]?.referenceAudioPath == "/path/to/voice.wav")
    }

    @Test("Speak requires ready state")
    @MainActor func speakRequiresReady() async {
        let engine = VoiceEngine()
        engine.setVoiceEnabled(true, for: .triage)
        await engine.speak("Hello", as: .triage)
        #expect(engine.state == .stopped)
    }

    @Test("Speak requires voice enabled")
    @MainActor func speakRequiresEnabled() async {
        let engine = VoiceEngine()
        await engine.start()
        await engine.speak("Hello", as: .triage)
        #expect(engine.state == .ready)
    }

    @Test("Speak completes and returns to ready")
    @MainActor func speakCompletesReady() async {
        let engine = VoiceEngine()
        await engine.start()
        engine.setVoiceEnabled(true, for: .librarian)
        await engine.speak("Test speech", as: .librarian)
        #expect(engine.state == .ready)
    }
}

// MARK: - Working Memory Tests

@Suite("WorkingMemory")
struct WorkingMemoryTests {

    @Test("Initial state is empty")
    @MainActor func initialState() {
        let wm = WorkingMemory(agentId: .triage)
        #expect(wm.entries.isEmpty)
        #expect(wm.currentTokens == 0)
        #expect(wm.compactionCount == 0)
        #expect(wm.utilization == 0)
    }

    @Test("Append adds entries")
    @MainActor func appendEntries() {
        let wm = WorkingMemory(agentId: .librarian)
        wm.append("Hello world", role: .user)
        #expect(wm.entries.count == 1)
        #expect(wm.entries[0].role == .user)
        #expect(wm.currentTokens > 0)
    }

    @Test("Utilization calculation")
    @MainActor func utilization() {
        let wm = WorkingMemory(agentId: .writer, maxTokens: 100)
        wm.append(String(repeating: "x", count: 280), role: .user)
        // 280 chars / 4 = 70 tokens → 70% utilization
        #expect(wm.utilization >= 0.69)
        #expect(wm.utilization <= 0.71)
    }

    @Test("Compaction triggers at 70% threshold")
    @MainActor func compactionTriggers() {
        let wm = WorkingMemory(agentId: .builder, maxTokens: 40)
        // Each entry ~7 tokens (28 chars / 4). At 40 max, threshold is 28 tokens (~4 entries).
        for _ in 0..<6 {
            wm.append(String(repeating: "abcdefg ", count: 4), role: .user)
        }
        #expect(wm.compactionCount > 0)
        // After compaction, should have fewer entries than we added
        #expect(wm.entries.count < 6)
    }

    @Test("Todo context is nil when empty")
    @MainActor func todoContextEmpty() {
        let wm = WorkingMemory(agentId: .triage)
        #expect(wm.todoContext == nil)
    }

    @Test("Todo context formats correctly")
    @MainActor func todoContextFormatted() {
        let wm = WorkingMemory(agentId: .triage)
        wm.currentTodos = ["Find related notes", "Summarize findings"]
        let context = wm.todoContext
        #expect(context != nil)
        #expect(context!.contains("1. Find related notes"))
        #expect(context!.contains("2. Summarize findings"))
    }

    @Test("Clear resets everything")
    @MainActor func clearResets() {
        let wm = WorkingMemory(agentId: .librarian)
        wm.append("test", role: .user)
        wm.currentTodos = ["task"]
        wm.clear()
        #expect(wm.entries.isEmpty)
        #expect(wm.currentTokens == 0)
        #expect(wm.currentTodos.isEmpty)
    }
}

// MARK: - Episodic Memory Tests

@Suite("EpisodicMemory")
struct EpisodicMemoryTests {

    @Test("Initial state is empty")
    @MainActor func initialState() {
        let em = EpisodicMemory()
        #expect(em.episodes.isEmpty)
    }

    @Test("Record episode adds entry")
    @MainActor func recordEpisode() {
        let em = EpisodicMemory()
        em.recordEpisode(agentId: .librarian, sessionId: "s1", summary: "Organized notes")
        #expect(em.episodes.count == 1)
        #expect(em.episodes[0].agentId == AgentID.librarian.rawValue)
    }

    @Test("Recent episodes filters by agent")
    @MainActor func recentEpisodesFiltered() {
        let em = EpisodicMemory()
        em.recordEpisode(agentId: .librarian, sessionId: "s1", summary: "Lib work")
        em.recordEpisode(agentId: .writer, sessionId: "s2", summary: "Write work")
        em.recordEpisode(agentId: .librarian, sessionId: "s3", summary: "More lib work")

        let libEpisodes = em.recentEpisodes(for: .librarian)
        #expect(libEpisodes.count == 2)
        #expect(libEpisodes.allSatisfy { $0.agentId == AgentID.librarian.rawValue })
    }

    @Test("Context summary returns nil when empty")
    @MainActor func contextSummaryEmpty() {
        let em = EpisodicMemory()
        #expect(em.contextSummary(for: .triage) == nil)
    }

    @Test("Context summary formats correctly")
    @MainActor func contextSummaryFormatted() {
        let em = EpisodicMemory()
        em.recordEpisode(agentId: .writer, sessionId: "s1", summary: "Drafted essay", keyDecisions: ["Used narrative style"])
        let summary = em.contextSummary(for: .writer)
        #expect(summary != nil)
        #expect(summary!.contains("Drafted essay"))
        #expect(summary!.contains("narrative style"))
    }
}

// MARK: - Semantic Memory Tests

@Suite("SemanticMemory")
struct SemanticMemoryTests {

    @Test("Initial state is not ready")
    @MainActor func initialState() {
        let sm = SemanticMemory()
        #expect(!sm.isIndexReady)
        #expect(sm.entryCount == 0)
    }

    @Test("Initialize marks as ready")
    @MainActor func initialize() async {
        let sm = SemanticMemory()
        await sm.initialize()
        #expect(sm.isIndexReady)
    }

    @Test("Index increments count")
    @MainActor func indexIncrements() async {
        let sm = SemanticMemory()
        await sm.index(content: "test", sourceId: nil, sourceType: "note")
        #expect(sm.entryCount == 1)
        await sm.index(content: "test2", sourceId: "n1", sourceType: "note")
        #expect(sm.entryCount == 2)
    }

    @Test("Search returns empty in scaffold mode")
    @MainActor func searchEmpty() async {
        let sm = SemanticMemory()
        await sm.initialize()
        let results = await sm.search(query: "test")
        #expect(results.isEmpty)
    }
}

// MARK: - Agent Memory Service Tests

@Suite("AgentMemoryService")
struct AgentMemoryServiceTests {

    @Test("Working memory exists for all agents")
    @MainActor func workingMemoryForAll() {
        let service = AgentMemoryService()
        for agent in AgentID.allCases {
            let wm = service.workingMemory(for: agent)
            #expect(wm.agentId == agent)
        }
    }

    @Test("Retrieve returns combined context")
    @MainActor func retrieveCombined() async {
        let service = AgentMemoryService()
        let wm = service.workingMemory(for: .librarian)
        wm.currentTodos = ["Find notes on AI"]
        service.episodicMemory.recordEpisode(agentId: .librarian, sessionId: "s1", summary: "Previous research")

        let context = await service.retrieve(query: "AI research", for: .librarian)
        #expect(context.contains("Find notes on AI"))
        #expect(context.contains("Previous research"))
    }

    @Test("Start initializes semantic memory")
    @MainActor func startInitializes() async {
        let service = AgentMemoryService()
        await service.start()
        #expect(service.semanticMemory.isIndexReady)
    }
}

// MARK: - Agent Notification Service Tests

@Suite("AgentNotificationService")
struct AgentNotificationServiceTests {

    @Test("Configs initialized for all agents")
    @MainActor func configsInitialized() {
        let service = AgentNotificationService()
        for agent in AgentID.allCases {
            let config = service.configs[agent]
            #expect(config != nil)
            #expect(config?.macOSEnabled == true)
            #expect(config?.inAppEnabled == true)
            #expect(config?.voiceEnabled == false)
        }
    }

    @Test("Badges start at zero")
    @MainActor func badgesZero() {
        let service = AgentNotificationService()
        for agent in AgentID.allCases {
            #expect(service.badges[agent] == 0)
        }
        #expect(service.totalBadgeCount() == 0)
    }

    @Test("In-app badge increments on notify")
    @MainActor func badgeIncrements() async {
        let service = AgentNotificationService()
        // Disable macOS notifications (no authorization in tests)
        service.setMacOSEnabled(false, for: .librarian)
        await service.notify(agent: .librarian, category: .taskComplete, title: "Done", body: "Task finished")
        #expect(service.badges[.librarian] == 1)
        #expect(service.totalBadgeCount() == 1)
    }

    @Test("Clear badge resets to zero")
    @MainActor func clearBadge() async {
        let service = AgentNotificationService()
        service.setMacOSEnabled(false, for: .writer)
        await service.notify(agent: .writer, category: .proactiveInsight, title: "Found", body: "Connection")
        service.clearBadge(for: .writer)
        #expect(service.badges[.writer] == 0)
    }

    @Test("Clear all badges")
    @MainActor func clearAllBadges() async {
        let service = AgentNotificationService()
        for agent in AgentID.allCases {
            service.setMacOSEnabled(false, for: agent)
        }
        await service.notify(agent: .librarian, category: .taskComplete, title: "T", body: "B")
        await service.notify(agent: .writer, category: .taskComplete, title: "T", body: "B")
        service.clearAllBadges()
        #expect(service.totalBadgeCount() == 0)
    }

    @Test("Disabled category skips notification")
    @MainActor func disabledCategory() async {
        let service = AgentNotificationService()
        service.setMacOSEnabled(false, for: .builder)
        service.setCategoryEnabled(.error, enabled: false, for: .builder)
        await service.notify(agent: .builder, category: .error, title: "Err", body: "Failed")
        #expect(service.badges[.builder] == 0)
    }

    @Test("Config toggles persist")
    @MainActor func configToggles() {
        let service = AgentNotificationService()
        service.setMacOSEnabled(false, for: .triage)
        service.setInAppEnabled(false, for: .triage)
        service.setVoiceEnabled(true, for: .triage)
        #expect(service.configs[.triage]?.macOSEnabled == false)
        #expect(service.configs[.triage]?.inAppEnabled == false)
        #expect(service.configs[.triage]?.voiceEnabled == true)
    }

    @Test("Disabled in-app skips badge")
    @MainActor func disabledInApp() async {
        let service = AgentNotificationService()
        service.setMacOSEnabled(false, for: .librarian)
        service.setInAppEnabled(false, for: .librarian)
        await service.notify(agent: .librarian, category: .taskComplete, title: "T", body: "B")
        #expect(service.badges[.librarian] == 0)
    }
}
