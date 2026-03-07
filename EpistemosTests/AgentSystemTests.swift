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
