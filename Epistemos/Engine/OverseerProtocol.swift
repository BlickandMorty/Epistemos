import Foundation

nonisolated enum OverseerProtocolVersion: String, Codable, Sendable, CaseIterable {
    case v1
}

nonisolated enum OverseerExecutionRoute: String, Codable, Sendable, Equatable {
    case localOnly = "local_only"
    case overseerLocalExecution = "overseer_local_execution"
    case managedAgentSession = "managed_agent_session"
}

nonisolated enum OverseerKVPolicyFlag: String, Codable, Sendable, Equatable, CaseIterable {
    case preserveSharedBase = "preserve_shared_base"
    case preserveAdapterCompatible = "preserve_adapter_compatible"
    case resetForDomainSwitch = "reset_for_domain_switch"
    case flushAll = "flush_all"
}

nonisolated enum OverseerToolPermissionMode: String, Codable, Sendable, Equatable, CaseIterable {
    case deny
    case ask
    case allow
}

nonisolated struct OverseerMaskPlan: Codable, Sendable, Equatable {
    let expertAllowlist: [String]
    let rationale: String?

    enum CodingKeys: String, CodingKey {
        case expertAllowlist = "expert_allowlist"
        case rationale
    }

    func normalized() -> OverseerMaskPlan {
        OverseerMaskPlan(
            expertAllowlist: Self.uniqueTrimmedStrings(expertAllowlist),
            rationale: Self.trimmedOrNil(rationale)
        )
    }
}

nonisolated struct OverseerLoRABlendCoefficient: Codable, Sendable, Equatable {
    let adapterID: String
    let coefficient: Double

    enum CodingKeys: String, CodingKey {
        case adapterID = "adapter_id"
        case coefficient
    }

    func normalized() -> OverseerLoRABlendCoefficient {
        OverseerLoRABlendCoefficient(
            adapterID: Self.trimmed(adapterID),
            coefficient: coefficient
        )
    }
}

nonisolated struct OverseerDepthBudget: Codable, Sendable, Equatable {
    let maxTurns: Int
    let maxReasoningSteps: Int
    let maxToolCalls: Int
    let maxOutputTokens: Int

    enum CodingKeys: String, CodingKey {
        case maxTurns = "max_turns"
        case maxReasoningSteps = "max_reasoning_steps"
        case maxToolCalls = "max_tool_calls"
        case maxOutputTokens = "max_output_tokens"
    }
}

nonisolated struct OverseerToolPermission: Codable, Sendable, Equatable {
    let toolName: String
    let mode: OverseerToolPermissionMode

    enum CodingKeys: String, CodingKey {
        case toolName = "tool_name"
        case mode
    }

    func normalized() -> OverseerToolPermission {
        OverseerToolPermission(
            toolName: Self.trimmed(toolName),
            mode: mode
        )
    }
}

nonisolated struct OverseerContextSummary: Codable, Sendable, Equatable {
    let summary: String
    let entityIDs: [String]
    let sourceSessionID: String?

    enum CodingKeys: String, CodingKey {
        case summary
        case entityIDs = "entity_ids"
        case sourceSessionID = "source_session_id"
    }

    func normalized() -> OverseerContextSummary {
        OverseerContextSummary(
            summary: Self.trimmed(summary),
            entityIDs: Self.uniqueTrimmedStrings(entityIDs),
            sourceSessionID: Self.trimmedOrNil(sourceSessionID)
        )
    }
}

nonisolated struct OverseerPlanV1: Codable, Sendable, Equatable {
    let version: OverseerProtocolVersion
    let route: OverseerExecutionRoute
    let maskPlan: OverseerMaskPlan
    let loraBlendCoefficients: [OverseerLoRABlendCoefficient]
    let kvPolicyFlag: OverseerKVPolicyFlag
    let depthBudget: OverseerDepthBudget
    let toolPermissions: [OverseerToolPermission]
    let contextSummary: OverseerContextSummary

    enum CodingKeys: String, CodingKey {
        case version
        case route
        case maskPlan = "mask_plan"
        case loraBlendCoefficients = "lora_blend_coefficients"
        case kvPolicyFlag = "kv_policy_flag"
        case depthBudget = "depth_budget"
        case toolPermissions = "tool_permissions"
        case contextSummary = "context_summary"
    }

    func normalized() -> OverseerPlanV1 {
        OverseerPlanV1(
            version: version,
            route: route,
            maskPlan: maskPlan.normalized(),
            loraBlendCoefficients: loraBlendCoefficients.map { $0.normalized() },
            kvPolicyFlag: kvPolicyFlag,
            depthBudget: depthBudget,
            toolPermissions: toolPermissions.map { $0.normalized() },
            contextSummary: contextSummary.normalized()
        )
    }

    func validated() throws -> OverseerPlanV1 {
        let plan = normalized()

        guard !plan.maskPlan.expertAllowlist.isEmpty else {
            throw OverseerProtocolError.emptyMaskPlan
        }

        for coefficient in plan.loraBlendCoefficients {
            guard !coefficient.adapterID.isEmpty else {
                throw OverseerProtocolError.emptyAdapterIdentifier
            }
            guard coefficient.coefficient.isFinite else {
                throw OverseerProtocolError.invalidBlendCoefficient(coefficient.adapterID, coefficient.coefficient)
            }
            guard coefficient.coefficient >= 0, coefficient.coefficient <= 1 else {
                throw OverseerProtocolError.invalidBlendCoefficient(coefficient.adapterID, coefficient.coefficient)
            }
        }

        let coefficientSum = plan.loraBlendCoefficients.reduce(0.0) { $0 + $1.coefficient }
        guard coefficientSum <= 1.000_001 else {
            throw OverseerProtocolError.blendCoefficientBudgetExceeded(coefficientSum)
        }

        guard plan.depthBudget.maxTurns > 0 else {
            throw OverseerProtocolError.invalidDepthBudget("max_turns must be greater than zero")
        }
        guard plan.depthBudget.maxReasoningSteps > 0 else {
            throw OverseerProtocolError.invalidDepthBudget("max_reasoning_steps must be greater than zero")
        }
        guard plan.depthBudget.maxToolCalls >= 0 else {
            throw OverseerProtocolError.invalidDepthBudget("max_tool_calls must be zero or greater")
        }
        guard plan.depthBudget.maxOutputTokens > 0 else {
            throw OverseerProtocolError.invalidDepthBudget("max_output_tokens must be greater than zero")
        }

        let toolNames = plan.toolPermissions.map(\.toolName)
        guard !toolNames.contains(where: \.isEmpty) else {
            throw OverseerProtocolError.emptyToolPermissionName
        }
        guard Set(toolNames).count == toolNames.count else {
            throw OverseerProtocolError.duplicateToolPermission
        }

        guard !plan.contextSummary.summary.isEmpty else {
            throw OverseerProtocolError.emptyContextSummary
        }

        return plan
    }

    func encodedJSON(prettyPrinted: Bool = true) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = prettyPrinted ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        let data = try encoder.encode(validated())
        guard let json = String(data: data, encoding: .utf8) else {
            throw OverseerProtocolError.encodingFailed
        }
        return json
    }

    func toSteeringHintsJSON() -> String? {
        let hints = BackendSteeringHints(
            maskPlan: BackendSteeringMaskPlan(
                expertAllowlist: maskPlan.expertAllowlist,
                blockSize: 128,
                rationale: maskPlan.rationale
            ),
            kvPolicyHint: kvPolicyFlag.rawValue,
            depthBudget: BackendSteeringDepthBudget(
                maxTurns: UInt32(depthBudget.maxTurns),
                maxReasoningSteps: UInt32(depthBudget.maxReasoningSteps),
                maxToolCalls: UInt32(depthBudget.maxToolCalls),
                maxOutputTokens: UInt32(depthBudget.maxOutputTokens)
            ),
            loraBlendCoefficients: loraBlendCoefficients.map {
                BackendSteeringLoRACoefficient(adapterID: $0.adapterID, coefficient: $0.coefficient)
            }
        )
        return hints.toJSON()
    }

    static func decode(json: String) throws -> OverseerPlanV1 {
        let decoder = JSONDecoder()
        return try decoder.decode(OverseerPlanV1.self, from: Data(json.utf8)).validated()
    }

    static let jsonSchema = CloudJSONSchema(
        name: "overseer_plan_v1",
        description: "Provider-agnostic control envelope for local expert masking, adapter blending, KV policy, and tool permissions.",
        schema: [
            "type": "object",
            "properties": [
                "version": [
                    "type": "string",
                    "enum": OverseerProtocolVersion.allCases.map(\.rawValue),
                ],
                "route": [
                    "type": "string",
                    "enum": [
                        OverseerExecutionRoute.localOnly.rawValue,
                        OverseerExecutionRoute.overseerLocalExecution.rawValue,
                        OverseerExecutionRoute.managedAgentSession.rawValue,
                    ],
                ],
                "mask_plan": [
                    "type": "object",
                    "properties": [
                        "expert_allowlist": [
                            "type": "array",
                            "items": ["type": "string"],
                        ],
                        "rationale": ["type": "string"],
                    ],
                    "required": ["expert_allowlist"],
                    "additionalProperties": false,
                ],
                "lora_blend_coefficients": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "adapter_id": ["type": "string"],
                            "coefficient": ["type": "number"],
                        ],
                        "required": ["adapter_id", "coefficient"],
                        "additionalProperties": false,
                    ],
                ],
                "kv_policy_flag": [
                    "type": "string",
                    "enum": OverseerKVPolicyFlag.allCases.map(\.rawValue),
                ],
                "depth_budget": [
                    "type": "object",
                    "properties": [
                        "max_turns": ["type": "integer"],
                        "max_reasoning_steps": ["type": "integer"],
                        "max_tool_calls": ["type": "integer"],
                        "max_output_tokens": ["type": "integer"],
                    ],
                    "required": ["max_turns", "max_reasoning_steps", "max_tool_calls", "max_output_tokens"],
                    "additionalProperties": false,
                ],
                "tool_permissions": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "tool_name": ["type": "string"],
                            "mode": [
                                "type": "string",
                                "enum": OverseerToolPermissionMode.allCases.map(\.rawValue),
                            ],
                        ],
                        "required": ["tool_name", "mode"],
                        "additionalProperties": false,
                    ],
                ],
                "context_summary": [
                    "type": "object",
                    "properties": [
                        "summary": ["type": "string"],
                        "entity_ids": [
                            "type": "array",
                            "items": ["type": "string"],
                        ],
                        "source_session_id": ["type": "string"],
                    ],
                    "required": ["summary", "entity_ids"],
                    "additionalProperties": false,
                ],
            ],
            "required": [
                "version",
                "route",
                "mask_plan",
                "lora_blend_coefficients",
                "kv_policy_flag",
                "depth_budget",
                "tool_permissions",
                "context_summary",
            ],
            "additionalProperties": false,
        ]
    )
}

nonisolated enum OverseerProtocolError: LocalizedError, Equatable {
    case emptyMaskPlan
    case emptyAdapterIdentifier
    case invalidBlendCoefficient(String, Double)
    case blendCoefficientBudgetExceeded(Double)
    case invalidDepthBudget(String)
    case emptyToolPermissionName
    case duplicateToolPermission
    case emptyContextSummary
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .emptyMaskPlan:
            return "mask_plan.expert_allowlist must contain at least one expert identifier."
        case .emptyAdapterIdentifier:
            return "LoRA blend entries need a non-empty adapter_id."
        case .invalidBlendCoefficient(let adapterID, let coefficient):
            return "LoRA blend coefficient for \(adapterID) must be finite and between 0 and 1. Received \(coefficient)."
        case .blendCoefficientBudgetExceeded(let sum):
            return "LoRA blend coefficients must not sum above 1.0. Received \(sum)."
        case .invalidDepthBudget(let reason):
            return "Invalid depth_budget: \(reason)"
        case .emptyToolPermissionName:
            return "tool_permissions entries need a non-empty tool_name."
        case .duplicateToolPermission:
            return "tool_permissions must not contain duplicate tool_name values."
        case .emptyContextSummary:
            return "context_summary.summary must not be empty."
        case .encodingFailed:
            return "Failed to encode Overseer plan JSON."
        }
    }
}

private extension OverseerMaskPlan {
    nonisolated static func uniqueTrimmedStrings(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        result.reserveCapacity(values.count)

        for value in values.map(Self.trimmed) where !value.isEmpty {
            if seen.insert(value).inserted {
                result.append(value)
            }
        }

        return result
    }

    nonisolated static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated static func trimmedOrNil(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

private extension OverseerLoRABlendCoefficient {
    nonisolated static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension OverseerToolPermission {
    nonisolated static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension OverseerContextSummary {
    nonisolated static func uniqueTrimmedStrings(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        result.reserveCapacity(values.count)

        for value in values.map(Self.trimmed) where !value.isEmpty {
            if seen.insert(value).inserted {
                result.append(value)
            }
        }

        return result
    }

    nonisolated static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated static func trimmedOrNil(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

@MainActor
final class OverseerComplexityRouter {
    struct ExecutionPlan: Sendable, Equatable {
        let route: OverseerExecutionRoute
        let localOperatingMode: EpistemosOperatingMode
        let plan: OverseerPlanV1
        let summary: String

        var forcesLocalExecution: Bool {
            route != .managedAgentSession
        }

        var allowsToolExecution: Bool {
            route == .overseerLocalExecution && !allowedToolNames.isEmpty && plan.depthBudget.maxToolCalls > 0
        }

        var allowedToolNames: Set<String> {
            Set(
                plan.toolPermissions
                    .filter { $0.mode == .allow || $0.mode == .ask }
                    .map(\.toolName)
            )
        }

        var steeringHintsJSON: String? {
            plan.toSteeringHintsJSON()
        }

        func additionalSystemPrompt() -> String {
            let json = (try? plan.encodedJSON(prettyPrinted: false)) ?? "{}"
            return """
            OVERSEER_PLAN_V1
            Route: \(route.rawValue)
            Summary: \(summary)
            Follow this execution plan exactly.
            Use only the tools explicitly listed in tool_permissions. If tool_permissions is empty, do not use tools.
            Treat any tool marked ask as requiring human approval before sensitive reads or writes.
            JSON:
            \(json)
            """
        }
    }

    private let inference: InferenceState

    init(inference: InferenceState) {
        self.inference = inference
    }

    func planForMainChat(
        query: String,
        contentLength: Int,
        operatingMode: EpistemosOperatingMode,
        hasExplicitContext: Bool,
        attachmentCount: Int,
        notesContext: String?,
        conversationHistory: String?
    ) -> ExecutionPlan {
        let analysis = QueryAnalyzer.analyze(query: query)
        let intent = inferredIntent(from: query, analysis: analysis, hasExplicitContext: hasExplicitContext)
        let route = selectedRoute(
            query: query,
            analysis: analysis,
            intent: intent,
            contentLength: contentLength,
            hasExplicitContext: hasExplicitContext,
            attachmentCount: attachmentCount
        )
        let localOperatingMode = selectedLocalOperatingMode(
            for: route,
            requestedMode: operatingMode,
            analysis: analysis,
            intent: intent
        )
        let plan = OverseerPlanV1(
            version: .v1,
            route: route,
            maskPlan: OverseerMaskPlan(
                expertAllowlist: expertAllowlist(for: route, intent: intent, hasExplicitContext: hasExplicitContext),
                rationale: rationale(for: route, intent: intent)
            ),
            loraBlendCoefficients: loraBlendCoefficients(for: intent),
            kvPolicyFlag: kvPolicyFlag(
                for: route,
                hasExplicitContext: hasExplicitContext,
                attachmentCount: attachmentCount
            ),
            depthBudget: depthBudget(for: route, analysis: analysis),
            toolPermissions: toolPermissions(for: route),
            contextSummary: contextSummary(
                analysis: analysis,
                hasExplicitContext: hasExplicitContext,
                attachmentCount: attachmentCount,
                notesContext: notesContext,
                conversationHistory: conversationHistory
            )
        )

        return ExecutionPlan(
            route: route,
            localOperatingMode: localOperatingMode,
            plan: (try? plan.validated()) ?? plan.normalized(),
            summary: summary(for: route, intent: intent, analysis: analysis)
        )
    }

    private func selectedRoute(
        query: String,
        analysis: QueryAnalysis,
        intent: InferenceTaskIntent,
        contentLength: Int,
        hasExplicitContext: Bool,
        attachmentCount: Int
    ) -> OverseerExecutionRoute {
        guard inference.effectiveLocalTextModelID != nil else {
            return .managedAgentSession
        }

        if isManagedAgentQuery(
            query: query,
            analysis: analysis,
            contentLength: contentLength,
            attachmentCount: attachmentCount
        ) {
            return .managedAgentSession
        }

        if shouldUseOverseerLocalExecution(
            analysis: analysis,
            intent: intent,
            hasExplicitContext: hasExplicitContext,
            attachmentCount: attachmentCount,
            contentLength: contentLength
        ) {
            return .overseerLocalExecution
        }

        return .localOnly
    }

    private func selectedLocalOperatingMode(
        for route: OverseerExecutionRoute,
        requestedMode: EpistemosOperatingMode,
        analysis: QueryAnalysis,
        intent: InferenceTaskIntent
    ) -> EpistemosOperatingMode {
        switch route {
        case .managedAgentSession:
            return .agent
        case .overseerLocalExecution:
            return .agent
        case .localOnly:
            if requestedMode == .thinking || requestedMode == .pro {
                return .thinking
            }
            switch intent {
            case .coding, .debugging, .comparison, .synthesis, .noteAnalysis, .graphAnalysis:
                return .thinking
            default:
                return analysis.complexity >= 0.45 ? .thinking : .fast
            }
        }
    }

    private func inferredIntent(
        from query: String,
        analysis: QueryAnalysis,
        hasExplicitContext: Bool
    ) -> InferenceTaskIntent {
        let normalized = query.lowercased()
        if normalized.contains("```")
            || normalized.contains("stack trace")
            || normalized.contains("compiler")
            || normalized.contains("build failed")
            || normalized.contains("crash")
            || normalized.contains("debug") {
            return .debugging
        }
        if normalized.contains("swift")
            || normalized.contains("rust")
            || normalized.contains("python")
            || normalized.contains("typescript")
            || normalized.contains("javascript")
            || normalized.contains("code")
            || normalized.contains("refactor") {
            return .coding
        }
        if normalized.contains("compare")
            || normalized.contains("versus")
            || normalized.contains(" vs ")
            || normalized.contains("tradeoff")
            || normalized.contains("difference") {
            return .comparison
        }
        if normalized.contains("synthesize")
            || normalized.contains("merge")
            || normalized.contains("across notes")
            || normalized.contains("connect these")
            || (hasExplicitContext && analysis.complexity >= 0.45) {
            return .synthesis
        }
        if normalized.contains("graph")
            || normalized.contains("node")
            || normalized.contains("edge")
            || normalized.contains("backlink") {
            return .graphAnalysis
        }
        if normalized.contains("analyze")
            || normalized.contains("failure mode")
            || normalized.contains("why")
            || normalized.contains("risk") {
            return .noteAnalysis
        }
        if normalized.contains("brainstorm")
            || normalized.contains("ideas")
            || normalized.contains("options") {
            return .brainstorm
        }
        if normalized.contains("summarize")
            || normalized.contains("summary")
            || normalized.contains("brief") {
            return .summarize
        }
        if normalized.contains("rewrite")
            || normalized.contains("draft")
            || normalized.contains("write") {
            return .rewrite
        }
        return analysis.complexity >= 0.4 ? .synthesis : .simpleAsk
    }

    private func isManagedAgentQuery(
        query: String,
        analysis: QueryAnalysis,
        contentLength: Int,
        attachmentCount: Int
    ) -> Bool {
        let normalized = query.lowercased()
        let managedSignals = [
            "gmail", "calendar", "drive", "twitter", "twitter/x", "x ", "reddit",
            "monitor", "keep watching", "for a few hours", "overnight", "background",
            "multimodal", "vision", "browser", "web search", "search the web",
            "managed agent", "long-running", "run for a while"
        ]

        if managedSignals.contains(where: { normalized.contains($0) }) {
            return true
        }

        if attachmentCount >= 4 && analysis.complexity >= 0.6 {
            return true
        }

        return contentLength >= 6_000 && analysis.complexity >= 0.8
    }

    private func shouldUseOverseerLocalExecution(
        analysis: QueryAnalysis,
        intent: InferenceTaskIntent,
        hasExplicitContext: Bool,
        attachmentCount: Int,
        contentLength: Int
    ) -> Bool {
        if hasExplicitContext || attachmentCount > 0 {
            return true
        }

        if contentLength >= 2_000 || analysis.complexity >= 0.45 {
            return true
        }

        switch intent {
        case .coding, .debugging, .comparison, .synthesis, .noteAnalysis, .graphAnalysis:
            return true
        case .simpleAsk, .rewrite, .summarize, .brainstorm:
            return false
        }
    }

    private func expertAllowlist(
        for route: OverseerExecutionRoute,
        intent: InferenceTaskIntent,
        hasExplicitContext: Bool
    ) -> [String] {
        var experts: [String]

        switch intent {
        case .coding, .debugging:
            experts = ["reasoning.code", "grounding.context", "memory.vault"]
        case .comparison:
            experts = ["reasoning.comparison", "grounding.context", "memory.vault"]
        case .synthesis, .noteAnalysis:
            experts = ["reasoning.synthesis", "memory.vault", "grounding.context"]
        case .graphAnalysis:
            experts = ["reasoning.graph", "memory.vault", "grounding.context"]
        case .rewrite, .brainstorm:
            experts = ["reasoning.writing", "grounding.context"]
        case .summarize:
            experts = ["reasoning.summary", "grounding.context"]
        case .simpleAsk:
            experts = ["reasoning.general", "grounding.context"]
        }

        if route == .managedAgentSession {
            experts.insert("planner.overseer", at: 0)
        } else if route == .overseerLocalExecution {
            experts.insert("planner.local_overseer", at: 0)
        }

        if !hasExplicitContext {
            experts.removeAll { $0 == "memory.vault" }
        }

        var seen: Set<String> = []
        return experts.filter { seen.insert($0).inserted }
    }

    private func rationale(
        for route: OverseerExecutionRoute,
        intent: InferenceTaskIntent
    ) -> String {
        switch (route, intent) {
        case (.managedAgentSession, _):
            return "Escalate to the managed agent path for long-running external orchestration."
        case (.overseerLocalExecution, .coding), (.overseerLocalExecution, .debugging):
            return "Keep execution local, but constrain the turn to code-heavy reasoning and explicitly permitted tools."
        case (.overseerLocalExecution, _):
            return "Keep execution local and use a narrow overseer plan to bound tools, depth, and working context."
        case (.localOnly, _):
            return "Answer locally without tool use."
        }
    }

    private func loraBlendCoefficients(for intent: InferenceTaskIntent) -> [OverseerLoRABlendCoefficient] {
        switch intent {
        case .coding, .debugging:
            return [OverseerLoRABlendCoefficient(adapterID: "code", coefficient: 0.85)]
        case .rewrite, .brainstorm:
            return [OverseerLoRABlendCoefficient(adapterID: "writing", coefficient: 0.75)]
        case .summarize, .comparison:
            return [OverseerLoRABlendCoefficient(adapterID: "research", coefficient: 0.60)]
        case .synthesis, .noteAnalysis, .graphAnalysis:
            return [
                OverseerLoRABlendCoefficient(adapterID: "research", coefficient: 0.65),
                OverseerLoRABlendCoefficient(adapterID: "writing", coefficient: 0.20),
            ]
        case .simpleAsk:
            return []
        }
    }

    private func kvPolicyFlag(
        for route: OverseerExecutionRoute,
        hasExplicitContext: Bool,
        attachmentCount: Int
    ) -> OverseerKVPolicyFlag {
        switch route {
        case .managedAgentSession:
            return .resetForDomainSwitch
        case .overseerLocalExecution:
            if hasExplicitContext || attachmentCount > 0 {
                return .preserveAdapterCompatible
            }
            return .preserveSharedBase
        case .localOnly:
            return .preserveSharedBase
        }
    }

    private func depthBudget(
        for route: OverseerExecutionRoute,
        analysis: QueryAnalysis
    ) -> OverseerDepthBudget {
        switch route {
        case .localOnly:
            return OverseerDepthBudget(
                maxTurns: 2,
                maxReasoningSteps: analysis.complexity >= 0.45 ? 2 : 1,
                maxToolCalls: 0,
                maxOutputTokens: 2_048
            )
        case .overseerLocalExecution:
            return OverseerDepthBudget(
                maxTurns: 6,
                maxReasoningSteps: 4,
                maxToolCalls: 4,
                maxOutputTokens: 4_096
            )
        case .managedAgentSession:
            return OverseerDepthBudget(
                maxTurns: 12,
                maxReasoningSteps: 8,
                maxToolCalls: 10,
                maxOutputTokens: 8_192
            )
        }
    }

    private func toolPermissions(for route: OverseerExecutionRoute) -> [OverseerToolPermission] {
        guard route == .overseerLocalExecution else { return [] }

        let liveTools = OmegaToolRegistry.all
        if !liveTools.isEmpty {
            var permissions: [OverseerToolPermission] = []
            var seen: Set<String> = []

            for tool in liveTools {
                guard let mode = permissionMode(for: tool) else { continue }
                guard seen.insert(tool.name).inserted else { continue }
                permissions.append(
                    OverseerToolPermission(
                        toolName: tool.name,
                        mode: mode
                    )
                )
            }

            if !permissions.isEmpty {
                return permissions.sorted { $0.toolName < $1.toolName }
            }
        }

        return [
            OverseerToolPermission(toolName: "vault_search", mode: .allow),
            OverseerToolPermission(toolName: "vault_get", mode: .allow),
            OverseerToolPermission(toolName: "pkm_search", mode: .allow),
            OverseerToolPermission(toolName: "pkm_get", mode: .allow),
            OverseerToolPermission(toolName: "pkm_graph_neighbors", mode: .allow),
            OverseerToolPermission(toolName: "web_search", mode: .ask),
            OverseerToolPermission(toolName: "search_web", mode: .ask),
            OverseerToolPermission(toolName: "open_url", mode: .ask),
            OverseerToolPermission(toolName: "run_command", mode: .ask),
            OverseerToolPermission(toolName: "pkm_write", mode: .deny),
            OverseerToolPermission(toolName: "edit_file", mode: .deny),
            OverseerToolPermission(toolName: "delete_file", mode: .deny),
            OverseerToolPermission(toolName: "create_note", mode: .deny),
        ]
    }

    private func permissionMode(for tool: OmegaToolDefinition) -> OverseerToolPermissionMode? {
        let name = tool.name.lowercased()

        if tool.destructive
            || name.contains("delete")
            || name.contains("write")
            || name.contains("edit")
            || name.contains("create")
            || name.contains("rename")
            || name.contains("move")
            || name.contains("trash") {
            return .deny
        }

        if name.contains("web")
            || name.contains("url")
            || name.contains("browser")
            || name.contains("http")
            || name.contains("command")
            || name.contains("terminal")
            || name.contains("shell")
            || name.contains("computer")
            || name.contains("automation") {
            return .ask
        }

        if name.contains("vault")
            || name.contains("pkm_")
            || name.contains("graph")
            || name.contains("note")
            || name.contains("list")
            || name.contains("read")
            || name.contains("search")
            || name.contains("file") {
            return .allow
        }

        return nil
    }

    private func contextSummary(
        analysis: QueryAnalysis,
        hasExplicitContext: Bool,
        attachmentCount: Int,
        notesContext: String?,
        conversationHistory: String?
    ) -> OverseerContextSummary {
        var summaryParts = [analysis.coreQuestion]

        if hasExplicitContext {
            summaryParts.append("Explicit context is attached.")
        }
        if attachmentCount > 0 {
            summaryParts.append("Attachments: \(attachmentCount).")
        }
        if let notesContext, !notesContext.isEmpty {
            summaryParts.append("Vault context is present.")
        }
        if let conversationHistory, !conversationHistory.isEmpty {
            summaryParts.append("This turn continues an existing conversation.")
        }

        let entityIDs = analysis.entities.map { "entity:\($0)" }

        return OverseerContextSummary(
            summary: summaryParts.joined(separator: " "),
            entityIDs: entityIDs,
            sourceSessionID: nil
        )
    }

    private func summary(
        for route: OverseerExecutionRoute,
        intent: InferenceTaskIntent,
        analysis: QueryAnalysis
    ) -> String {
        switch route {
        case .localOnly:
            return "Keep this turn local and answer directly with \(intentLabel(intent)) reasoning."
        case .overseerLocalExecution:
            return "Keep this turn local, but enforce an overseer plan because the request complexity is \(String(format: "%.2f", analysis.complexity))."
        case .managedAgentSession:
            return "Escalate to the managed agent path for long-running external orchestration."
        }
    }

    private func intentLabel(_ intent: InferenceTaskIntent) -> String {
        switch intent {
        case .simpleAsk: "general"
        case .rewrite: "writing"
        case .summarize: "summary"
        case .brainstorm: "brainstorm"
        case .coding: "coding"
        case .debugging: "debugging"
        case .comparison: "comparison"
        case .synthesis: "synthesis"
        case .noteAnalysis: "analysis"
        case .graphAnalysis: "graph"
        }
    }
}
