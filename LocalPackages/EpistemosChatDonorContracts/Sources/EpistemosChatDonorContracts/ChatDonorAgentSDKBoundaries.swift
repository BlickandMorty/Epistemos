import Foundation

public enum ChatDonorAgentSDKParameterType: String, Codable, Hashable, Sendable {
    case string
    case number
    case boolean
    case array
    case object

    public var jsonType: String { rawValue }
}

public struct ChatDonorAgentSDKToolParameter: Codable, Hashable, Sendable {
    public var name: String
    public var description: String
    public var type: ChatDonorAgentSDKParameterType
    public var required: Bool

    public init(
        name: String,
        description: String,
        type: ChatDonorAgentSDKParameterType,
        required: Bool = true
    ) {
        self.name = name
        self.description = description
        self.type = type
        self.required = required
    }
}

public enum ChatDonorAgentSDKToolAvailability: Codable, Hashable, Sendable {
    case always
    case disabled
    case requiresAllCapabilities([String])
    case requiresAnyCapability([String])

    public func isEnabled(enabledCapabilities: Set<String>) -> Bool {
        switch self {
        case .always:
            true
        case .disabled:
            false
        case .requiresAllCapabilities(let required):
            Set(required).isSubset(of: enabledCapabilities)
        case .requiresAnyCapability(let candidates):
            !enabledCapabilities.isDisjoint(with: candidates)
        }
    }
}

public struct ChatDonorAgentSDKRunContext: Codable, Hashable, Sendable {
    public var sessionID: String
    public var enabledCapabilities: Set<String>
    public var metadata: [String: String]
    public var usage: ChatDonorAgentSDKUsage

    public init(
        sessionID: String,
        enabledCapabilities: Set<String> = [],
        metadata: [String: String] = [:],
        usage: ChatDonorAgentSDKUsage = ChatDonorAgentSDKUsage()
    ) {
        self.sessionID = sessionID
        self.enabledCapabilities = enabledCapabilities
        self.metadata = metadata
        self.usage = usage
    }
}

public struct ChatDonorAgentSDKToolDescriptor: Codable, Hashable, Sendable {
    public var name: String
    public var description: String
    public var parameters: [ChatDonorAgentSDKToolParameter]
    public var availability: ChatDonorAgentSDKToolAvailability

    public init(
        name: String,
        description: String,
        parameters: [ChatDonorAgentSDKToolParameter] = [],
        availability: ChatDonorAgentSDKToolAvailability = .always
    ) {
        self.name = name
        self.description = description
        self.parameters = parameters
        self.availability = availability
    }

    public func isEnabled(for context: ChatDonorAgentSDKRunContext) -> Bool {
        availability.isEnabled(enabledCapabilities: context.enabledCapabilities)
    }

    public var requiredParameterNames: [String] {
        parameters.filter(\.required).map(\.name)
    }
}

public enum ChatDonorAgentSDKGuardrailScope: String, Codable, Hashable, Sendable {
    case input
    case output
}

public enum ChatDonorAgentSDKGuardrailRule: Codable, Hashable, Sendable {
    case maxCharacters(Int)
    case blockSubstring(String, caseSensitive: Bool = false)
    case requireSubstring(String, caseSensitive: Bool = false)

    public func evaluate(
        _ text: String,
        scope: ChatDonorAgentSDKGuardrailScope
    ) -> ChatDonorAgentSDKGuardrailDecision {
        switch self {
        case .maxCharacters(let maxCharacters):
            guard text.count <= maxCharacters else {
                return .rejected(
                    scope: scope,
                    reason: "\(scope.rawValue) exceeds \(maxCharacters) characters"
                )
            }
            return .allowed(text, scope: scope)

        case .blockSubstring(let needle, let caseSensitive):
            let found = Self.contains(needle, in: text, caseSensitive: caseSensitive)
            guard !found else {
                return .rejected(
                    scope: scope,
                    reason: "\(scope.rawValue) contains blocked content"
                )
            }
            return .allowed(text, scope: scope)

        case .requireSubstring(let needle, let caseSensitive):
            let found = Self.contains(needle, in: text, caseSensitive: caseSensitive)
            guard found else {
                return .rejected(
                    scope: scope,
                    reason: "\(scope.rawValue) is missing required content"
                )
            }
            return .allowed(text, scope: scope)
        }
    }

    private static func contains(_ needle: String, in haystack: String, caseSensitive: Bool) -> Bool {
        guard !needle.isEmpty else { return true }
        if caseSensitive {
            return haystack.contains(needle)
        }
        return haystack.localizedCaseInsensitiveContains(needle)
    }
}

public struct ChatDonorAgentSDKGuardrailDecision: Codable, Hashable, Sendable {
    public var allowed: Bool
    public var scope: ChatDonorAgentSDKGuardrailScope
    public var text: String?
    public var reason: String?

    public init(
        allowed: Bool,
        scope: ChatDonorAgentSDKGuardrailScope,
        text: String? = nil,
        reason: String? = nil
    ) {
        self.allowed = allowed
        self.scope = scope
        self.text = text
        self.reason = reason
    }

    public static func allowed(
        _ text: String,
        scope: ChatDonorAgentSDKGuardrailScope = .input
    ) -> ChatDonorAgentSDKGuardrailDecision {
        ChatDonorAgentSDKGuardrailDecision(
            allowed: true,
            scope: scope,
            text: text
        )
    }

    public static func rejected(
        scope: ChatDonorAgentSDKGuardrailScope,
        reason: String
    ) -> ChatDonorAgentSDKGuardrailDecision {
        ChatDonorAgentSDKGuardrailDecision(
            allowed: false,
            scope: scope,
            reason: reason
        )
    }
}

public struct ChatDonorAgentSDKGuardrailPipeline: Codable, Hashable, Sendable {
    public var scope: ChatDonorAgentSDKGuardrailScope
    public var rules: [ChatDonorAgentSDKGuardrailRule]

    public init(
        scope: ChatDonorAgentSDKGuardrailScope,
        rules: [ChatDonorAgentSDKGuardrailRule] = []
    ) {
        self.scope = scope
        self.rules = rules
    }

    public func validate(_ text: String) -> ChatDonorAgentSDKGuardrailDecision {
        for rule in rules {
            let decision = rule.evaluate(text, scope: scope)
            guard decision.allowed else { return decision }
        }
        return .allowed(text, scope: scope)
    }
}

public struct ChatDonorAgentSDKHandoffRule: Codable, Hashable, Sendable {
    public var targetAgentName: String
    public var keywords: [String]
    public var caseSensitive: Bool

    public init(
        targetAgentName: String,
        keywords: [String],
        caseSensitive: Bool = false
    ) {
        self.targetAgentName = targetAgentName
        self.keywords = keywords
        self.caseSensitive = caseSensitive
    }

    public func shouldHandoff(input: String) -> Bool {
        let searchInput = caseSensitive ? input : input.lowercased()
        return keywords.contains { keyword in
            guard !keyword.isEmpty else { return false }
            let searchKeyword = caseSensitive ? keyword : keyword.lowercased()
            return searchInput.contains(searchKeyword)
        }
    }

    public func decision(for input: String) -> ChatDonorAgentSDKHandoffDecision? {
        guard shouldHandoff(input: input) else { return nil }
        return ChatDonorAgentSDKHandoffDecision(
            targetAgentName: targetAgentName,
            input: input,
            matchedKeywords: keywords.filter { keyword in
                guard !keyword.isEmpty else { return false }
                let searchInput = caseSensitive ? input : input.lowercased()
                let searchKeyword = caseSensitive ? keyword : keyword.lowercased()
                return searchInput.contains(searchKeyword)
            }
        )
    }
}

public struct ChatDonorAgentSDKHandoffDecision: Codable, Hashable, Sendable {
    public var targetAgentName: String
    public var input: String
    public var matchedKeywords: [String]

    public init(targetAgentName: String, input: String, matchedKeywords: [String]) {
        self.targetAgentName = targetAgentName
        self.input = input
        self.matchedKeywords = matchedKeywords
    }
}

public enum ChatDonorAgentSDKToolUseBehavior: Codable, Hashable, Sendable {
    case runLLMAgain
    case stopOnFirstTool
    case stopAtTools(Set<String>)

    public func finalOutput(from toolResults: [ChatDonorAgentSDKToolCallResult]) -> String? {
        guard !toolResults.isEmpty else { return nil }
        switch self {
        case .runLLMAgain:
            return nil
        case .stopOnFirstTool:
            return toolResults.first?.output
        case .stopAtTools(let names):
            return toolResults.first { names.contains($0.name) }?.output
        }
    }
}

public struct ChatDonorAgentSDKToolCallResult: Codable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var output: String

    public init(id: String, name: String, output: String) {
        self.id = id
        self.name = name
        self.output = output
    }
}

public struct ChatDonorAgentSDKModelSettings: Codable, Hashable, Sendable {
    public enum ToolChoice: Codable, Hashable, Sendable {
        case auto
        case required
        case none
        case named(String)
    }

    public enum ReasoningEffort: String, Codable, Hashable, Sendable {
        case minimal
        case low
        case medium
        case high
    }

    public var modelName: String
    public var temperature: Double?
    public var topP: Double?
    public var maxTokens: Int?
    public var toolChoice: ToolChoice?
    public var parallelToolCalls: Bool?
    public var reasoningEffort: ReasoningEffort?

    public init(
        modelName: String = "gpt-4.1",
        temperature: Double? = nil,
        topP: Double? = nil,
        maxTokens: Int? = nil,
        toolChoice: ToolChoice? = nil,
        parallelToolCalls: Bool? = nil,
        reasoningEffort: ReasoningEffort? = nil
    ) {
        self.modelName = modelName
        self.temperature = temperature
        self.topP = topP
        self.maxTokens = maxTokens
        self.toolChoice = toolChoice
        self.parallelToolCalls = parallelToolCalls
        self.reasoningEffort = reasoningEffort
    }
}

public struct ChatDonorAgentSDKUsage: Codable, Hashable, Sendable {
    public var requests: Int
    public var inputTokens: Int
    public var outputTokens: Int
    public var totalTokens: Int

    public init(
        requests: Int = 0,
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        totalTokens: Int = 0
    ) {
        self.requests = max(0, requests)
        self.inputTokens = max(0, inputTokens)
        self.outputTokens = max(0, outputTokens)
        self.totalTokens = max(0, totalTokens)
    }

    public mutating func record(inputTokens: Int, outputTokens: Int, totalTokens: Int? = nil) {
        requests = Self.saturatingAdd(requests, 1)
        let boundedInputTokens = max(0, inputTokens)
        let boundedOutputTokens = max(0, outputTokens)
        self.inputTokens = Self.saturatingAdd(self.inputTokens, boundedInputTokens)
        self.outputTokens = Self.saturatingAdd(self.outputTokens, boundedOutputTokens)
        self.totalTokens = Self.saturatingAdd(
            self.totalTokens,
            max(0, totalTokens ?? Self.saturatingAdd(boundedInputTokens, boundedOutputTokens))
        )
    }

    public mutating func merge(_ other: ChatDonorAgentSDKUsage) {
        requests = Self.saturatingAdd(requests, other.requests)
        inputTokens = Self.saturatingAdd(inputTokens, other.inputTokens)
        outputTokens = Self.saturatingAdd(outputTokens, other.outputTokens)
        totalTokens = Self.saturatingAdd(totalTokens, other.totalTokens)
    }

    public func merged(with other: ChatDonorAgentSDKUsage) -> ChatDonorAgentSDKUsage {
        var copy = self
        copy.merge(other)
        return copy
    }

    private static func saturatingAdd(_ first: Int, _ second: Int) -> Int {
        let result = first.addingReportingOverflow(second)
        return result.overflow ? Int.max : result.partialValue
    }
}

public struct ChatDonorAgentSDKAgentDescriptor: Codable, Hashable, Sendable {
    public var name: String
    public var instructions: String
    public var handoffDescription: String?
    public var tools: [ChatDonorAgentSDKToolDescriptor]
    public var inputGuardrails: [ChatDonorAgentSDKGuardrailRule]
    public var outputGuardrails: [ChatDonorAgentSDKGuardrailRule]
    public var handoffs: [ChatDonorAgentSDKHandoffRule]
    public var modelSettings: ChatDonorAgentSDKModelSettings
    public var toolUseBehavior: ChatDonorAgentSDKToolUseBehavior
    public var resetToolChoice: Bool

    public init(
        name: String,
        instructions: String,
        handoffDescription: String? = nil,
        tools: [ChatDonorAgentSDKToolDescriptor] = [],
        inputGuardrails: [ChatDonorAgentSDKGuardrailRule] = [],
        outputGuardrails: [ChatDonorAgentSDKGuardrailRule] = [],
        handoffs: [ChatDonorAgentSDKHandoffRule] = [],
        modelSettings: ChatDonorAgentSDKModelSettings = ChatDonorAgentSDKModelSettings(),
        toolUseBehavior: ChatDonorAgentSDKToolUseBehavior = .runLLMAgain,
        resetToolChoice: Bool = true
    ) {
        self.name = name
        self.instructions = instructions
        self.handoffDescription = handoffDescription
        self.tools = tools
        self.inputGuardrails = inputGuardrails
        self.outputGuardrails = outputGuardrails
        self.handoffs = handoffs
        self.modelSettings = modelSettings
        self.toolUseBehavior = toolUseBehavior
        self.resetToolChoice = resetToolChoice
    }

    public func enabledTools(for context: ChatDonorAgentSDKRunContext) -> [ChatDonorAgentSDKToolDescriptor] {
        tools.filter { $0.isEnabled(for: context) }
    }

    public func validateInput(_ input: String) -> ChatDonorAgentSDKGuardrailDecision {
        ChatDonorAgentSDKGuardrailPipeline(scope: .input, rules: inputGuardrails)
            .validate(input)
    }

    public func validateOutput(_ output: String) -> ChatDonorAgentSDKGuardrailDecision {
        ChatDonorAgentSDKGuardrailPipeline(scope: .output, rules: outputGuardrails)
            .validate(output)
    }

    public func handoffDecision(for input: String) -> ChatDonorAgentSDKHandoffDecision? {
        for handoff in handoffs {
            if let decision = handoff.decision(for: input) {
                return decision
            }
        }
        return nil
    }
}
