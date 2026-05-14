import Testing
@testable import Epistemos

@Suite(.serialized)
struct ToolSurfacePolicyTests {
    private static func makeTool(name: String) -> OmegaToolDefinition {
        OmegaToolDefinition(
            name: name,
            agent: "rust",
            description: "test tool \(name)",
            argumentsExample: "{}",
            schemaJson: "{}",
            destructive: false,
            requiresConfirmation: false
        )
    }

    @Test func unsupportedImageGenerationDisappearsFromVisibleToolSurfaces() {
        let filtered = ToolSurfacePolicy.surfacedTools([
            Self.makeTool(name: "media.image_generate"),
            Self.makeTool(name: "media.vision_analyze"),
            Self.makeTool(name: "media.text_to_speech"),
        ])

        #expect(filtered.map(\.name) == ["media.vision_analyze", "media.text_to_speech"])
    }

    @Test func thinkDisappearsFromVisibleToolSurfaces() {
        let filtered = ToolSurfacePolicy.surfacedTools([
            Self.makeTool(name: "think"),
            Self.makeTool(name: "vault.search"),
        ])

        #expect(filtered.map(\.name) == ["vault.search"])
    }

    @Test func coreAppStoreHiddenGatewayToolsDisappearFromVisibleToolSurfaces() {
        let hidden = [
            "action.bash",
            "action.terminal",
            "system.process",
            "claude_code",
            "codex",
            "gemini",
            "kimi",
            "send_message",
            "browser_navigate",
            "browser_click",
            "browser_type",
            "browser_press",
            "browser_close",
            "browser_scroll",
            "discovery.mcp_discover",
            "media.vision_analyze",
            "media.image_generate",
            "media.text_to_speech",
            "perceive",
            "interact",
            "screen_watch",
            "system.cron",
            "imessage",
            "imessage_contacts",
            "channel_contacts",
            "apple_notes",
            "apple_reminders",
            "apple_calendar",
            "apple_mail",
            "delegate_task",
            "intelligence.mixture_of_minds",
            "mixture_of_minds",
            "skills.list",
            "skills.view",
            "skills.manage",
            "skills",
            "skills_list",
            "skill_view",
            "skill_manage",
            "custom_tool_manage",
            "trajectory_export",
            "nightbrain_trigger",
            "inline_partner",
            "execute_code",
            "docker_run",
            "file_edit",
        ]
        let filtered = ToolSurfacePolicy.surfacedTools(
            hidden.map(Self.makeTool(name:)),
            distribution: .coreAppStore
        )

        #expect(filtered.isEmpty)
    }

    @Test func coreAppStoreAllowedToolsStayVisible() {
        let allowed = ToolSurfacePolicy.coreAppStoreAllowedToolNames.sorted()
        let filtered = ToolSurfacePolicy.surfacedTools(
            allowed.map(Self.makeTool(name:)),
            distribution: .coreAppStore
        )

        #expect(filtered.map(\.name) == allowed)
    }

    @Test func coreAppStorePolicyAcceptsRustV2AndLegacyAgentToolNames() {
        let filtered = ToolSurfacePolicy.surfacedTools([
            Self.makeTool(name: "note_template"),
            Self.makeTool(name: "note.linker"),
            Self.makeTool(name: "web_fetch"),
            Self.makeTool(name: "clarify"),
            Self.makeTool(name: "clarify.ask"),
        ], distribution: .coreAppStore)

        #expect(filtered.map(\.name) == [
            "note.template",
            "note.linker",
            "web.fetch",
            "clarify.ask",
        ])
    }

    @Test func coreAppStorePolicyCanonicalizesToolNameCase() {
        let filtered = ToolSurfacePolicy.surfacedTools([
            Self.makeTool(name: "Bash_Execute"),
            Self.makeTool(name: "Vault_Search"),
        ], distribution: .coreAppStore)

        #expect(filtered.map(\.name) == ["vault.search"])
    }

    @Test func proResearchGatewayToolsStayVisibleWhenRuntimeCanUseThem() {
        let tools = [
            "action.bash",
            "action.terminal",
            "browser_navigate",
            "discovery.mcp_discover",
            "think",
            "vault.search",
        ].map(Self.makeTool(name:))

        let filtered = ToolSurfacePolicy.surfacedTools(
            tools,
            distribution: .proResearch
        )

        #expect(filtered.map(\.name) == [
            "action.bash",
            "action.terminal",
            "browser_navigate",
            "discovery.mcp_discover",
            "vault.search",
        ])
    }

    @Test func sandboxEnvironmentForcesCoreAppStorePolicy() {
        let key = "APP_SANDBOX_CONTAINER_ID"
        let previous = ProcessInfo.processInfo.environment[key]
        _ = setenv(key, "epistemos-test-sandbox", 1)
        defer {
            if let previous {
                _ = setenv(key, previous, 1)
            } else {
                unsetenv(key)
            }
        }

        #expect(ToolSurfacePolicy.isSurfacedToolName(
            "action.bash",
            distribution: .proResearch
        ) == false)
        #expect(ToolSurfacePolicy.isSurfacedToolName(
            "vault.search",
            distribution: .proResearch
        ))
    }

    @Test @MainActor func toolExecutorDeniesCoreAppStoreHiddenToolsBeforeBindings() async {
        let bridge = ToolTierBridge(
            vaultPath: "/tmp/epistemos-tool-surface-test-vault",
            tier: .full,
            distribution: .coreAppStore
        )
        let executor = bridge.toolExecutor()

        for toolName in [
            "action.bash",
            "action.terminal",
            "get_ui_tree",
            "see",
            "click",
            "browser_navigate",
            "docker_run",
        ] {
            let result = await executor(toolName, "{}")
            #expect(result.toolName == toolName)
            #expect(result.isError)
            #expect(result.resultJson.contains("Tool not found: \(toolName)"))
            #expect(!result.resultJson.contains("agent_core bindings unavailable"))
        }
    }

    @Test @MainActor func toolExecutionPolicyPreservesAllowedAndProResearchPaths() {
        #expect(ToolTierBridge.executionPolicyDenial(
            toolName: "vault.search",
            distribution: .coreAppStore
        ) == nil)
        #expect(ToolTierBridge.executionPolicyDenial(
            toolName: "action.bash",
            distribution: .proResearch
        ) == nil)

        let deniedThink = ToolTierBridge.executionPolicyDenial(
            toolName: "think",
            distribution: .proResearch
        )
        #expect(deniedThink?.isError == true)
        #expect(deniedThink?.resultJson.contains("Tool not found: think") == true)
    }
}
