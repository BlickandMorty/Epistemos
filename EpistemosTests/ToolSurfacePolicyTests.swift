import Foundation
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

    @Test func fileSearchPatternArgumentsNormalizeToVaultRoot() throws {
        let vaultRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-file-search-root")
            .standardizedFileURL
            .path
        let normalized = ToolTierBridge.normalizedInputJson(
            toolName: "file.search",
            inputJson: #"{"pattern":"Jordan Conley — College Resume","path":"","target":"files"}"#,
            defaultFileSearchRoot: vaultRoot
        )
        let data = try #require(normalized.data(using: .utf8))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["pattern"] as? String == "Jordan Conley — College Resume")
        #expect(object["query"] == nil)
        #expect(object["path"] as? String == vaultRoot)
        #expect(object["target"] as? String == "files")
    }

    @Test func fileSearchHomeRootNormalizesToVaultRoot() throws {
        let vaultRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-file-search-home-root")
            .standardizedFileURL
            .path
        let normalized = ToolTierBridge.normalizedInputJson(
            toolName: "file.search",
            inputJson: #"{"pattern":"My Autobiography","path":"~/","target":"files"}"#,
            defaultFileSearchRoot: vaultRoot
        )
        let data = try #require(normalized.data(using: .utf8))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["pattern"] as? String == "My Autobiography")
        #expect(object["path"] as? String == vaultRoot)
        #expect(object["target"] as? String == "files")
    }

    @Test func vaultSearchPathArgumentNormalizesToQuery() throws {
        let normalized = ToolTierBridge.normalizedInputJson(
            toolName: "vault.search",
            inputJson: #"{"path":"My Autobiography","limit":5}"#
        )
        let data = try #require(normalized.data(using: .utf8))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["query"] as? String == "My Autobiography")
        #expect(object["path"] == nil)
        #expect(object["limit"] as? Int == 5)
    }

    @Test func eidosQueryPathArgumentNormalizesToEvidenceQuery() throws {
        let normalized = ToolTierBridge.normalizedInputJson(
            toolName: "eidos.query",
            inputJson: #"{"path":"My Autobiography","limit":5}"#
        )
        let data = try #require(normalized.data(using: .utf8))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["query"] as? String == "My Autobiography")
        #expect(object["path"] == nil)
        #expect(object["top_k"] as? Int == 5)
        #expect(object["limit"] as? Int == 5)
    }

    @Test func vaultScopedFileSearchBuildsAppFirstVaultSearchInput() throws {
        let vaultRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-app-first-vault-root")
            .standardizedFileURL
            .path
        let normalized = ToolTierBridge.normalizedInputJson(
            toolName: "file.search",
            inputJson: #"{"pattern":"My Autobiography","path":"~/","target":"files","limit":250}"#,
            defaultFileSearchRoot: vaultRoot
        )
        let preflight = try #require(ToolTierBridge.appFirstVaultSearchInputForFileSearch(
            toolName: "file.search",
            normalizedInputJson: normalized,
            defaultFileSearchRoot: vaultRoot,
            allowedToolNames: ["vault.search", "file.search"]
        ))
        let data = try #require(preflight.data(using: .utf8))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["query"] as? String == "My Autobiography")
        #expect(object["limit"] as? Int == 20)
    }

    @Test func vaultScopedFileSearchPrefersEidosForAppFirstLookup() throws {
        let vaultRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-app-first-eidos-root")
            .standardizedFileURL
            .path
        let normalized = ToolTierBridge.normalizedInputJson(
            toolName: "file.search",
            inputJson: #"{"pattern":"My Autobiography","path":"~/","target":"files","limit":250}"#,
            defaultFileSearchRoot: vaultRoot
        )
        let preflight = try #require(ToolTierBridge.appFirstVaultLookupForFileSearch(
            toolName: "file.search",
            normalizedInputJson: normalized,
            defaultFileSearchRoot: vaultRoot,
            allowedToolNames: ["eidos.query", "vault.search", "file.search"]
        ))
        let data = try #require(preflight.inputJson.data(using: .utf8))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(preflight.toolName == "eidos.query")
        #expect(object["query"] as? String == "My Autobiography")
        #expect(object["top_k"] as? Int == 20)
    }

    @Test func explicitNonVaultFileSearchSkipsAppFirstVaultSearchInput() throws {
        let vaultRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-app-first-vault-root")
            .standardizedFileURL
            .path
        let normalized = ToolTierBridge.normalizedInputJson(
            toolName: "file.search",
            inputJson: #"{"pattern":"QueryRuntime","path":"/Users/jojo/Downloads/Epistemos","target":"content"}"#,
            defaultFileSearchRoot: vaultRoot
        )

        #expect(ToolTierBridge.appFirstVaultSearchInputForFileSearch(
            toolName: "file.search",
            normalizedInputJson: normalized,
            defaultFileSearchRoot: vaultRoot,
            allowedToolNames: ["vault.search", "file.search"]
        ) == nil)
    }

    @Test func vaultSearchResultDetectorRequiresRealMatches() {
        #expect(ToolTierBridge.vaultSearchOutputHasUsableResults("""
        1. **Notes/My Autobiography.md** (score: 12.00, tier: T3, variant: rrf)
        A paragraph about the note.
        """))
        #expect(ToolTierBridge.vaultSearchOutputHasUsableResults("""
        {"tool":"eidos.query","count":1,"results":[{"path":"Notes/My Autobiography.md"}]}
        """))
        #expect(!ToolTierBridge.vaultSearchOutputHasUsableResults(
            "No notes matched with high enough confidence (ladder declined; no tier above floor)."
        ))
        #expect(!ToolTierBridge.vaultSearchOutputHasUsableResults("""
        {"tool":"eidos.query","count":0,"results":[]}
        """))
    }

    @Test @MainActor func fileSearchPatternExecutesAsNonEmptyQuery() async throws {
        let vaultURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-file-search-pattern-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: vaultURL,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: vaultURL) }
        try "resume body".write(
            to: vaultURL.appendingPathComponent("Jordan Conley — College Resume.md"),
            atomically: true,
            encoding: .utf8
        )

        let bridge = ToolTierBridge(
            vaultPath: vaultURL.path,
            tier: .agent,
            allowedToolNames: ["file.search"]
        )
        let result = await bridge.toolExecutor()(
            "file.search",
            #"{"pattern":"Jordan Conley — College Resume","path":"","target":"files"}"#
        )

        #expect(!result.isError, Comment(rawValue: result.resultJson))
        #expect(
            result.resultJson.contains("Jordan Conley"),
            Comment(rawValue: result.resultJson)
        )
    }

    @Test func fileReadTitleArgumentsNormalizeToUniqueVaultFile() throws {
        let vaultURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-file-read-title-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: vaultURL,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        let resumeURL = vaultURL.appendingPathComponent("Jordan Conley — College Resume.md")
        try "resume body".write(to: resumeURL, atomically: true, encoding: .utf8)

        let normalized = ToolTierBridge.normalizedInputJson(
            toolName: "file.read",
            inputJson: #"{"path":"Jordan Conley — College Resume"}"#,
            defaultFileSearchRoot: vaultURL.path
        )
        let data = try #require(normalized.data(using: .utf8))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["path"] as? String == resumeURL.standardizedFileURL.path)
    }

    @Test @MainActor func fileReadTitleExecutesInsideActiveVault() async throws {
        let vaultURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-file-read-title-exec-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: vaultURL,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        try "resume body".write(
            to: vaultURL.appendingPathComponent("Jordan Conley — College Resume.md"),
            atomically: true,
            encoding: .utf8
        )

        let bridge = ToolTierBridge(
            vaultPath: vaultURL.path,
            tier: .agent,
            allowedToolNames: ["file.read"]
        )
        let result = await bridge.toolExecutor()(
            "file.read",
            #"{"path":"Jordan Conley — College Resume"}"#
        )

        #expect(!result.isError, Comment(rawValue: result.resultJson))
        #expect(result.resultJson.contains("resume body"), Comment(rawValue: result.resultJson))
    }

    @Test func fileReadAmbiguousTitleDoesNotChooseArbitraryVaultFile() throws {
        let vaultURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-file-read-ambiguous-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: vaultURL.appendingPathComponent("A"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: vaultURL.appendingPathComponent("B"),
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        try "first".write(
            to: vaultURL.appendingPathComponent("A/Resume.md"),
            atomically: true,
            encoding: .utf8
        )
        try "second".write(
            to: vaultURL.appendingPathComponent("B/Resume.md"),
            atomically: true,
            encoding: .utf8
        )

        let normalized = ToolTierBridge.normalizedInputJson(
            toolName: "file.read",
            inputJson: #"{"path":"Resume"}"#,
            defaultFileSearchRoot: vaultURL.path
        )
        let data = try #require(normalized.data(using: .utf8))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["path"] as? String == "Resume")
    }
}
