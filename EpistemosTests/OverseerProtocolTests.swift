import Testing
@testable import Epistemos

@Suite("Overseer Protocol")
struct OverseerProtocolTests {
    @Test("v1 plan encodes the required snake case schema fields")
    func v1PlanEncodesRequiredSnakeCaseSchemaFields() throws {
        let plan = makePlan()

        let json = try plan.encodedJSON(prettyPrinted: false)

        #expect(json.contains("\"version\":\"v1\""))
        #expect(json.contains("\"route\":\"overseer_local_execution\""))
        #expect(json.contains("\"mask_plan\""))
        #expect(json.contains("\"expert_allowlist\""))
        #expect(json.contains("\"lora_blend_coefficients\""))
        #expect(json.contains("\"kv_policy_flag\""))
        #expect(json.contains("\"depth_budget\""))
        #expect(json.contains("\"tool_permissions\""))
        #expect(json.contains("\"context_summary\""))
    }

    @Test("v1 plan round trips through JSON with normalized fields")
    func v1PlanRoundTripsThroughJSONWithNormalizedFields() throws {
        let raw = OverseerPlanV1(
            version: .v1,
            route: .overseerLocalExecution,
            maskPlan: OverseerMaskPlan(
                expertAllowlist: [" expert.alpha ", "expert.beta", "expert.alpha"],
                rationale: "  Narrow to writing experts.  "
            ),
            loraBlendCoefficients: [
                OverseerLoRABlendCoefficient(adapterID: " writing ", coefficient: 0.7),
                OverseerLoRABlendCoefficient(adapterID: "research", coefficient: 0.2),
            ],
            kvPolicyFlag: .preserveAdapterCompatible,
            depthBudget: OverseerDepthBudget(
                maxTurns: 8,
                maxReasoningSteps: 4,
                maxToolCalls: 6,
                maxOutputTokens: 4096
            ),
            toolPermissions: [
                OverseerToolPermission(toolName: " web_search ", mode: .ask),
                OverseerToolPermission(toolName: "pkm_get", mode: .allow),
            ],
            contextSummary: OverseerContextSummary(
                summary: "  Jordan's current project plan and note context. ",
                entityIDs: [" Project/Epistemos ", "People/Jordan", "Project/Epistemos"],
                sourceSessionID: " session-42 "
            )
        )

        let decoded = try OverseerPlanV1.decode(json: raw.encodedJSON(prettyPrinted: false))

        #expect(decoded.maskPlan.expertAllowlist == ["expert.alpha", "expert.beta"])
        #expect(decoded.maskPlan.rationale == "Narrow to writing experts.")
        #expect(decoded.loraBlendCoefficients.map(\.adapterID) == ["writing", "research"])
        #expect(decoded.toolPermissions.map(\.toolName) == ["web.search", "vault.read"])
        #expect(decoded.contextSummary.entityIDs == ["Project/Epistemos", "People/Jordan"])
        #expect(decoded.contextSummary.sourceSessionID == "session-42")
    }

    @Test("v1 plan rejects duplicate tool permissions")
    func v1PlanRejectsDuplicateToolPermissions() {
        let plan = OverseerPlanV1(
            version: .v1,
            route: .overseerLocalExecution,
            maskPlan: OverseerMaskPlan(expertAllowlist: ["expert.alpha"], rationale: nil),
            loraBlendCoefficients: [],
            kvPolicyFlag: .preserveSharedBase,
            depthBudget: OverseerDepthBudget(
                maxTurns: 4,
                maxReasoningSteps: 2,
                maxToolCalls: 2,
                maxOutputTokens: 1024
            ),
            toolPermissions: [
                OverseerToolPermission(toolName: "web_search", mode: .ask),
                OverseerToolPermission(toolName: "web_search", mode: .deny),
            ],
            contextSummary: OverseerContextSummary(
                summary: "Working set for the current vault task.",
                entityIDs: [],
                sourceSessionID: nil
            )
        )

        #expect(throws: OverseerProtocolError.self) {
            _ = try plan.validated()
        }
    }

    @Test("v1 plan rejects invalid blend coefficient budgets")
    func v1PlanRejectsInvalidBlendCoefficientBudgets() {
        let plan = OverseerPlanV1(
            version: .v1,
            route: .overseerLocalExecution,
            maskPlan: OverseerMaskPlan(expertAllowlist: ["expert.alpha"], rationale: nil),
            loraBlendCoefficients: [
                OverseerLoRABlendCoefficient(adapterID: "writing", coefficient: 0.8),
                OverseerLoRABlendCoefficient(adapterID: "research", coefficient: 0.4),
            ],
            kvPolicyFlag: .preserveAdapterCompatible,
            depthBudget: OverseerDepthBudget(
                maxTurns: 4,
                maxReasoningSteps: 2,
                maxToolCalls: 2,
                maxOutputTokens: 1024
            ),
            toolPermissions: [],
            contextSummary: OverseerContextSummary(
                summary: "Working set for the current vault task.",
                entityIDs: [],
                sourceSessionID: nil
            )
        )

        #expect(throws: OverseerProtocolError.self) {
            _ = try plan.validated()
        }
    }

    @Test("v1 schema lists all required contract fields")
    func v1SchemaListsAllRequiredContractFields() throws {
        let required = try #require(OverseerPlanV1.jsonSchema.schema["required"] as? [String])

        #expect(required.contains("mask_plan"))
        #expect(required.contains("lora_blend_coefficients"))
        #expect(required.contains("kv_policy_flag"))
        #expect(required.contains("depth_budget"))
        #expect(required.contains("tool_permissions"))
        #expect(required.contains("context_summary"))
    }

    @Test("Core App Store fallback permissions hide Pro gateway tools")
    func coreAppStoreFallbackPermissionsHideProGatewayTools() {
        let permissions = OverseerComplexityRouter.fallbackToolPermissions(distribution: .coreAppStore)
        let names = Set(permissions.map(\.toolName))

        #expect(names.contains("vault.search"))
        #expect(names.contains("web.search"))
        #expect(names.allSatisfy {
            ToolSurfacePolicy.isSurfacedToolName($0, distribution: .coreAppStore)
        })

        for forbidden in [
            "action.bash",
            "web.fetch",
            "browser_navigate",
            "get_ui_tree",
            "docker_run",
        ] {
            #expect(!names.contains(forbidden))
        }
    }

    @Test("Pro Research fallback permissions preserve explicit ask tools")
    func proResearchFallbackPermissionsPreserveExplicitAskTools() {
        let permissions = OverseerComplexityRouter.fallbackToolPermissions(distribution: .proResearch)
        let byName = Dictionary(uniqueKeysWithValues: permissions.map { ($0.toolName, $0.mode) })

        #expect(byName["vault.search"] == .allow)
        #expect(byName["web.search"] == .ask)
        #expect(byName["web.fetch"] == .ask)
        #expect(byName["action.bash"] == .ask)
        #expect(byName["vault.write"] == .deny)
        #expect(byName["file.delete"] == .deny)
    }

    private func makePlan() -> OverseerPlanV1 {
        OverseerPlanV1(
            version: .v1,
            route: .overseerLocalExecution,
            maskPlan: OverseerMaskPlan(
                expertAllowlist: ["expert.alpha", "expert.beta"],
                rationale: "Prefer the writing and research experts for this turn."
            ),
            loraBlendCoefficients: [
                OverseerLoRABlendCoefficient(adapterID: "writing", coefficient: 0.6),
                OverseerLoRABlendCoefficient(adapterID: "research", coefficient: 0.3),
            ],
            kvPolicyFlag: .preserveAdapterCompatible,
            depthBudget: OverseerDepthBudget(
                maxTurns: 6,
                maxReasoningSteps: 4,
                maxToolCalls: 5,
                maxOutputTokens: 4096
            ),
            toolPermissions: [
                OverseerToolPermission(toolName: "web_search", mode: .ask),
                OverseerToolPermission(toolName: "pkm_get", mode: .allow),
                OverseerToolPermission(toolName: "pkm_write", mode: .deny),
            ],
            contextSummary: OverseerContextSummary(
                summary: "Recent work centers on the Epistemos architecture migration and local runtime hardening.",
                entityIDs: ["Projects/Epistemos", "Decisions/Serial-Pipeline"],
                sourceSessionID: "session-ep-001"
            )
        )
    }
}
