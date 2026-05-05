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
            Self.makeTool(name: "image_generate"),
            Self.makeTool(name: "vision_analyze"),
            Self.makeTool(name: "text_to_speech"),
        ])

        #expect(filtered.map(\.name) == ["vision_analyze", "text_to_speech"])
    }

    @Test func thinkDisappearsFromVisibleToolSurfaces() {
        let filtered = ToolSurfacePolicy.surfacedTools([
            Self.makeTool(name: "think"),
            Self.makeTool(name: "vault_search"),
        ])

        #expect(filtered.map(\.name) == ["vault_search"])
    }

    @Test func coreAppStoreHiddenGatewayToolsDisappearFromVisibleToolSurfaces() {
        let hidden = [
            "bash_execute",
            "terminal",
            "process",
            "claude_code",
            "codex",
            "send_message",
            "browser_navigate",
            "browser_click",
            "browser_type",
            "browser_press",
            "browser_close",
            "browser_scroll",
            "mcp_discover",
            "vision_analyze",
            "image_generate",
            "text_to_speech",
            "perceive",
            "interact",
            "screen_watch",
            "cronjob",
            "imessage",
            "imessage_contacts",
            "channel_contacts",
            "apple_notes",
            "apple_reminders",
            "apple_calendar",
            "apple_mail",
            "skill_manage",
            "custom_tool_manage",
            "trajectory_export",
            "nightbrain_trigger",
            "inline_partner",
            "execute_code",
            "web_fetch",
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

    @Test func coreAppStorePolicyCanonicalizesToolNameCase() {
        let filtered = ToolSurfacePolicy.surfacedTools([
            Self.makeTool(name: "Bash_Execute"),
            Self.makeTool(name: "Vault_Search"),
        ], distribution: .coreAppStore)

        #expect(filtered.map(\.name) == ["Vault_Search"])
    }

    @Test func proResearchGatewayToolsStayVisibleWhenRuntimeCanUseThem() {
        let tools = [
            "bash_execute",
            "terminal",
            "browser_navigate",
            "mcp_discover",
            "think",
            "vault_search",
        ].map(Self.makeTool(name:))

        let filtered = ToolSurfacePolicy.surfacedTools(
            tools,
            distribution: .proResearch
        )

        #expect(filtered.map(\.name) == [
            "bash_execute",
            "terminal",
            "browser_navigate",
            "mcp_discover",
            "vault_search",
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
            "bash_execute",
            distribution: .proResearch
        ) == false)
        #expect(ToolSurfacePolicy.isSurfacedToolName(
            "vault_search",
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
            "run_command",
            "run_persistent",
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
            toolName: "vault_search",
            distribution: .coreAppStore
        ) == nil)
        #expect(ToolTierBridge.executionPolicyDenial(
            toolName: "run_command",
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
