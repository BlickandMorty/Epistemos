import Foundation

public enum ChatDonorSwiftAIAgentOutput: Codable, Hashable, Sendable {
    case text(String)
    case functionCalls([String])
    case structured(ChatDonorMCPValue)
    case image(Data)
    case audio(Data)

    public var displayText: String? {
        switch self {
        case .text(let text):
            text
        case .functionCalls(let calls):
            calls.joined(separator: "||")
        case .structured(let value):
            Self.encodedJSON(value)
        case .image:
            "AI generated image"
        case .audio:
            "AI generated audio"
        }
    }

    public var textValue: String? {
        if case .text(let text) = self { text } else { nil }
    }

    public var functionCallValues: [String] {
        if case .functionCalls(let calls) = self { calls } else { [] }
    }

    private static func encodedJSON(_ value: ChatDonorMCPValue) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(value),
              let text = String(data: data, encoding: .utf8) else {
            return "\(value)"
        }
        return text
    }
}

public struct ChatDonorSwiftAIAgentOutputBatch: Codable, Hashable, Sendable {
    public var outputs: [ChatDonorSwiftAIAgentOutput]

    public init(_ outputs: [ChatDonorSwiftAIAgentOutput] = []) {
        self.outputs = outputs
    }

    public var firstText: String? {
        allTexts.first
    }

    public var allTexts: [String] {
        outputs.compactMap(\.textValue)
    }

    public var allFunctionCalls: [String] {
        outputs.flatMap(\.functionCallValues)
    }

    public var allStructuredValues: [ChatDonorMCPValue] {
        outputs.compactMap {
            if case .structured(let value) = $0 { value } else { nil }
        }
    }

    public var normalizedTranscriptText: String {
        outputs.compactMap(\.displayText).joined(separator: "\n")
    }

    public var parsedToolCalls: [ChatDonorSwiftAIToolCall] {
        allFunctionCalls.compactMap(ChatDonorSwiftAIToolCall.init(jsonString:))
    }
}

public struct ChatDonorSwiftAIToolCall: Codable, Hashable, Sendable {
    public var name: String
    public var arguments: [String: ChatDonorMCPValue]

    public init(name: String, arguments: [String: ChatDonorMCPValue] = [:]) {
        self.name = name
        self.arguments = arguments
    }

    public init?(jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(DecodedToolCall.self, from: data),
              !decoded.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        self.name = decoded.name
        self.arguments = decoded.args
    }

    public var argumentsJSON: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(arguments),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    private struct DecodedToolCall: Decodable {
        var name: String
        var args: [String: ChatDonorMCPValue]
    }
}

public struct ChatDonorSwiftAIAgentConfiguration: Codable, Hashable, Sendable {
    public var maxToolIterations: Int
    public var toolExecutionDelayNanoseconds: UInt64

    public init(
        maxToolIterations: Int = 5,
        toolExecutionDelayNanoseconds: UInt64 = 1_500_000_000
    ) {
        self.maxToolIterations = max(1, maxToolIterations)
        self.toolExecutionDelayNanoseconds = toolExecutionDelayNanoseconds
    }

    public static let `default` = ChatDonorSwiftAIAgentConfiguration()
}

public enum ChatDonorSwiftAIAgentLoopTermination: String, Codable, Hashable, Sendable {
    case completed
    case maxIterationsReached = "max-iterations-reached"
}

public struct ChatDonorSwiftAIAgentLoopReceipt: Codable, Hashable, Sendable {
    public var iterations: Int
    public var toolCallCounts: [Int]
    public var finalNoToolsCallMade: Bool
    public var termination: ChatDonorSwiftAIAgentLoopTermination
    public var finalPrompt: String

    public init(
        iterations: Int,
        toolCallCounts: [Int],
        finalNoToolsCallMade: Bool,
        termination: ChatDonorSwiftAIAgentLoopTermination,
        finalPrompt: String
    ) {
        self.iterations = iterations
        self.toolCallCounts = toolCallCounts
        self.finalNoToolsCallMade = finalNoToolsCallMade
        self.termination = termination
        self.finalPrompt = finalPrompt
    }
}

public enum ChatDonorSwiftAIAgentLoopResult: Sendable {
    case completed(outputs: [ChatDonorSwiftAIAgentOutput], receipt: ChatDonorSwiftAIAgentLoopReceipt)
    case maxIterationsReached(
        lastOutputs: [ChatDonorSwiftAIAgentOutput],
        finalOutputs: [ChatDonorSwiftAIAgentOutput],
        receipt: ChatDonorSwiftAIAgentLoopReceipt
    )

    public var receipt: ChatDonorSwiftAIAgentLoopReceipt {
        switch self {
        case .completed(_, let receipt):
            receipt
        case .maxIterationsReached(_, _, let receipt):
            receipt
        }
    }
}

public struct ChatDonorSwiftAIAgentLoopRunner: Sendable {
    public var configuration: ChatDonorSwiftAIAgentConfiguration
    public var stopToolCallInstruction: String

    public init(
        configuration: ChatDonorSwiftAIAgentConfiguration = .default,
        stopToolCallInstruction: String = "All tool calls succeeded. If no more tools are needed, return no functions to call."
    ) {
        self.configuration = configuration
        self.stopToolCallInstruction = stopToolCallInstruction
    }

    public func run(
        prompt: String,
        model: @Sendable (_ prompt: String, _ allowTools: Bool) async throws -> [ChatDonorSwiftAIAgentOutput],
        executeTools: @Sendable ([ChatDonorSwiftAIToolCall]) async throws -> [ChatDonorSwiftAIAgentOutput],
        sleep: @Sendable (UInt64) async throws -> Void = { nanoseconds in
            guard nanoseconds > 0 else { return }
            try await Task.sleep(nanoseconds: nanoseconds)
        }
    ) async throws -> ChatDonorSwiftAIAgentLoopResult {
        var currentPrompt = prompt
        var lastOutputs: [ChatDonorSwiftAIAgentOutput] = []
        var toolCallCounts: [Int] = []

        for iteration in 1...configuration.maxToolIterations {
            let outputs = try await model(currentPrompt, true)
            let batch = ChatDonorSwiftAIAgentOutputBatch(outputs)
            let toolCalls = batch.parsedToolCalls

            guard !toolCalls.isEmpty else {
                return .completed(outputs: outputs, receipt: ChatDonorSwiftAIAgentLoopReceipt(
                    iterations: iteration,
                    toolCallCounts: toolCallCounts,
                    finalNoToolsCallMade: false,
                    termination: .completed,
                    finalPrompt: currentPrompt
                ))
            }

            lastOutputs = outputs
            toolCallCounts.append(toolCalls.count)
            let toolOutputs = try await executeTools(toolCalls)
            currentPrompt = nextPrompt(
                originalPrompt: prompt,
                previousOutputs: outputs,
                toolOutputs: toolOutputs
            )
            try await sleep(configuration.toolExecutionDelayNanoseconds)
        }

        let finalOutputs = try await model(currentPrompt, false)
        return .maxIterationsReached(
            lastOutputs: lastOutputs,
            finalOutputs: finalOutputs,
            receipt: ChatDonorSwiftAIAgentLoopReceipt(
                iterations: configuration.maxToolIterations,
                toolCallCounts: toolCallCounts,
                finalNoToolsCallMade: true,
                termination: .maxIterationsReached,
                finalPrompt: currentPrompt
            )
        )
    }

    public func nextPrompt(
        originalPrompt: String,
        previousOutputs: [ChatDonorSwiftAIAgentOutput],
        toolOutputs: [ChatDonorSwiftAIAgentOutput]
    ) -> String {
        let previousText = ChatDonorSwiftAIAgentOutputBatch(previousOutputs).allTexts.joined(separator: "\n")
        let toolText = ChatDonorSwiftAIAgentOutputBatch(toolOutputs).allTexts.joined(separator: "\n")
        return """
        \(originalPrompt)
        <previous_llm_response>
        \(previousText)
        </previous_llm_response>
        <tool_execution_results>
        \(toolText)
        </tool_execution_results>
        \(stopToolCallInstruction)
        """
    }
}

public indirect enum ChatDonorSwiftAIWorkflowStep: Codable, Hashable, Sendable {
    case single(agentID: String)
    case sequence([ChatDonorSwiftAIWorkflowStep])
    case parallel([ChatDonorSwiftAIWorkflowStep])
    case conditional(requiredText: String, ChatDonorSwiftAIWorkflowStep)

    public func run(
        prompt: String,
        invoke: @escaping @Sendable (_ agentID: String, _ prompt: String) async throws -> [ChatDonorSwiftAIAgentOutput]
    ) async throws -> [ChatDonorSwiftAIAgentOutput] {
        switch self {
        case .single(let agentID):
            return try await invoke(agentID, prompt)

        case .sequence(let steps):
            var current = [ChatDonorSwiftAIAgentOutput.text(prompt)]
            for step in steps {
                let nextPrompt = ChatDonorSwiftAIAgentOutputBatch(current).allTexts.joined(separator: ",")
                current = try await step.run(prompt: nextPrompt, invoke: invoke)
            }
            return current

        case .parallel(let steps):
            return try await withThrowingTaskGroup(of: [ChatDonorSwiftAIAgentOutput].self) { group in
                for step in steps {
                    group.addTask {
                        try await step.run(prompt: prompt, invoke: invoke)
                    }
                }
                var outputs: [ChatDonorSwiftAIAgentOutput] = []
                for try await result in group {
                    outputs.append(contentsOf: result)
                }
                return outputs
            }

        case .conditional(let requiredText, let step):
            guard prompt.contains(requiredText) else { return [] }
            return try await step.run(prompt: prompt, invoke: invoke)
        }
    }
}

public struct ChatDonorSwiftAISubTask: Codable, Hashable, Sendable {
    public var name: String
    public var details: String
    public var condition: String?
    public var runSubTasksInParallel: Bool?
    public var tools: [String]
    public var temperature: Double

    public init(
        name: String,
        details: String,
        condition: String? = nil,
        runSubTasksInParallel: Bool? = nil,
        tools: [String] = [],
        temperature: Double = 0.7
    ) {
        self.name = name
        self.details = details
        self.condition = condition
        self.runSubTasksInParallel = runSubTasksInParallel
        self.tools = tools
        self.temperature = temperature
    }
}

public struct ChatDonorSwiftAIGoalPlan: Codable, Hashable, Sendable {
    public var name: String
    public var details: String
    public var condition: String?
    public var runSubTasksInParallel: Bool
    public var subTasks: [ChatDonorSwiftAISubTask]

    public init(
        name: String,
        details: String,
        condition: String? = nil,
        runSubTasksInParallel: Bool = false,
        subTasks: [ChatDonorSwiftAISubTask] = []
    ) {
        self.name = name
        self.details = details
        self.condition = condition
        self.runSubTasksInParallel = runSubTasksInParallel
        self.subTasks = subTasks
    }

    public var agentSetup: String {
        guard !subTasks.isEmpty else { return "Single agent task execution" }
        let descriptions = subTasks.enumerated().map { index, task in
            """
            <agent \(index + 1)>
            Name: \(task.name)
            Task: \(task.details)
            Tools: \(task.tools.isEmpty ? "none" : task.tools.joined(separator: ", "))
            Temperature: \(task.temperature)
            </agent \(index + 1)>
            """
        }.joined(separator: "\n")

        return """
        Collaborative execution with \(subTasks.count) specialized agents:
        \(descriptions)

        Execution mode: \(runSubTasksInParallel ? "Parallel" : "Sequential")
        """
    }

    public func validationFailures() -> [ChatDonorSwiftAIGoalPlanFailure] {
        var failures: [ChatDonorSwiftAIGoalPlanFailure] = []
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            failures.append(.emptyName)
        }
        if details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            failures.append(.emptyDetails)
        }
        if subTasks.isEmpty {
            failures.append(.noSubtasks)
        }
        for task in subTasks {
            if task.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                failures.append(.emptySubtaskName)
            }
            if task.details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                failures.append(.emptySubtaskDetails)
            }
            if task.temperature < 0 || task.temperature > 2 {
                failures.append(.temperatureOutOfRange(task.name))
            }
        }
        return failures
    }

    public func workflowStep(configuration: ChatDonorSwiftAIGoalConfiguration = .init()) -> ChatDonorSwiftAIWorkflowStep? {
        guard validationFailures().filter({ $0.isFatal }).isEmpty else { return nil }
        let steps = subTasks.map { ChatDonorSwiftAIWorkflowStep.single(agentID: $0.name) }
        if runSubTasksInParallel && configuration.enableParallelExecution {
            return .parallel(steps)
        }
        return .sequence(steps)
    }
}

public enum ChatDonorSwiftAIGoalPlanFailure: Codable, Hashable, Sendable {
    case emptyName
    case emptyDetails
    case noSubtasks
    case emptySubtaskName
    case emptySubtaskDetails
    case temperatureOutOfRange(String)

    public var isFatal: Bool {
        switch self {
        case .temperatureOutOfRange:
            false
        case .emptyName, .emptyDetails, .noSubtasks, .emptySubtaskName, .emptySubtaskDetails:
            true
        }
    }
}

public struct ChatDonorSwiftAIGoalConfiguration: Codable, Hashable, Sendable {
    public var maxClarificationRounds: Int
    public var defaultTemperature: Double
    public var enableParallelExecution: Bool

    public init(
        maxClarificationRounds: Int = 3,
        defaultTemperature: Double = 0.7,
        enableParallelExecution: Bool = true
    ) {
        self.maxClarificationRounds = max(0, maxClarificationRounds)
        self.defaultTemperature = min(max(defaultTemperature, 0), 2)
        self.enableParallelExecution = enableParallelExecution
    }
}

public enum ChatDonorSwiftAIGoalState: String, Codable, Hashable, Sendable {
    case idle
    case clarifying
    case planning
    case executing
    case completed
    case failed
}

public struct ChatDonorSwiftAIGoalReceipt: Codable, Hashable, Sendable {
    public var goal: String
    public var states: [ChatDonorSwiftAIGoalState]
    public var clarificationQuestions: [String]
    public var planFailures: [ChatDonorSwiftAIGoalPlanFailure]
    public var finalOutputCount: Int

    public init(
        goal: String,
        states: [ChatDonorSwiftAIGoalState],
        clarificationQuestions: [String] = [],
        planFailures: [ChatDonorSwiftAIGoalPlanFailure] = [],
        finalOutputCount: Int = 0
    ) {
        self.goal = goal
        self.states = states
        self.clarificationQuestions = clarificationQuestions
        self.planFailures = planFailures
        self.finalOutputCount = finalOutputCount
    }
}
