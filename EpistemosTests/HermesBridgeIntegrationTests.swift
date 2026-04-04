import Testing
@testable import Epistemos
import Foundation

// MARK: - Bridge Protocol JSON Contract Tests

/// Tests the JSON encoding/decoding contract between the Swift bridge layer
/// and the Python Hermes subprocess. No actual subprocess is launched.

@Suite("Hermes Bridge Start Payload")
struct HermesBridgeStartPayloadTests {
    @Test("Cloud Anthropic route resolves correct wire values for the bridge")
    func cloudAnthropicRouteResolvesCorrectWireValues() throws {
        let route = try #require(
            HermesRuntimeRoute.resolve(
                for: .cloud(.anthropicClaudeOpus4),
                apiKeyLookup: { $0 == .anthropic ? "sk-ant-test-key" : nil }
            )
        )

        #expect(route.model == "claude-opus-4-20250514")
        #expect(route.requestedProvider == "anthropic")
        #expect(route.baseURL == "https://api.anthropic.com")
        #expect(route.apiMode == "anthropic_messages")
        #expect(route.environmentOverrides["ANTHROPIC_API_KEY"] == "sk-ant-test-key")
        // Cleared keys must be empty strings so Python os.environ override works.
        #expect(route.environmentOverrides["OPENAI_API_KEY"] == "")
        #expect(route.environmentOverrides["OPENROUTER_API_KEY"] == "")
    }

    @Test("Local Qwen route resolves for agent-capable model with valid port")
    func localQwenRouteResolvesForAgentCapableModel() throws {
        let route = try #require(
            HermesRuntimeRoute.resolveLocal(
                modelID: LocalTextModelID.qwen35_9B4Bit.rawValue,
                inferencePort: 9876
            )
        )

        #expect(route.model == "local-mlx")
        #expect(route.requestedProvider == "custom")
        #expect(route.baseURL == "http://127.0.0.1:9876/v1")
        #expect(route.apiMode == "chat_completions")
        #expect(route.environmentOverrides["OPENAI_API_KEY"] == "local-epistemos")
        #expect(route.environmentOverrides["OPENAI_BASE_URL"] == "http://127.0.0.1:9876/v1")
    }

    @Test("Local route returns nil for non-agent-capable model")
    func localRouteReturnsNilForSmallModel() {
        let route = HermesRuntimeRoute.resolveLocal(
            modelID: LocalTextModelID.qwen35_0_8B4Bit.rawValue,
            inferencePort: 9876
        )
        #expect(route == nil)
    }

    @Test("Local route returns nil for zero port")
    func localRouteReturnsNilForZeroPort() {
        let route = HermesRuntimeRoute.resolveLocal(
            modelID: LocalTextModelID.qwen35_9B4Bit.rawValue,
            inferencePort: 0
        )
        #expect(route == nil)
    }

    @Test("Cloud route returns nil when API key is missing")
    func cloudRouteReturnsNilWhenAPIKeyMissing() {
        let route = HermesRuntimeRoute.resolve(
            for: .cloud(.openAIGPT41Mini),
            apiKeyLookup: { _ in nil }
        )
        #expect(route == nil)
    }

    @Test("Cloud route returns nil when API key is whitespace only")
    func cloudRouteReturnsNilWhenAPIKeyWhitespace() {
        let route = HermesRuntimeRoute.resolve(
            for: .cloud(.openAIGPT41Mini),
            apiKeyLookup: { _ in "   " }
        )
        #expect(route == nil)
    }

    @Test("Cloud Anthropic OAuth route resolves Claude Code token values for the bridge")
    func cloudAnthropicOAuthRouteResolvesCorrectWireValues() throws {
        let route = HermesRuntimeRoute.resolve(
            for: .anthropicClaudeOpus4,
            credential: .anthropicOAuth(accessToken: "claude-oauth-token")
        )

        #expect(route.model == "claude-opus-4-20250514")
        #expect(route.requestedProvider == "anthropic")
        #expect(route.baseURL == "https://api.anthropic.com")
        #expect(route.apiMode == "anthropic_messages")
        #expect(route.environmentOverrides["ANTHROPIC_API_KEY"] == "")
        #expect(route.environmentOverrides["ANTHROPIC_TOKEN"] == "claude-oauth-token")
        #expect(route.environmentOverrides["CLAUDE_CODE_OAUTH_TOKEN"] == "claude-oauth-token")
    }

    @Test("Cloud Google OAuth route resolves project headers for the bridge")
    func cloudGoogleOAuthRouteResolvesProjectHeaders() throws {
        let route = HermesRuntimeRoute.resolve(
            for: .googleGemini25Flash,
            credential: .googleOAuth(
                accessToken: "google-oauth-token",
                projectID: "epistemos-gemini-project"
            )
        )

        #expect(route.model == "gemini-2.5-flash")
        #expect(route.requestedProvider == "custom")
        #expect(route.baseURL == "https://generativelanguage.googleapis.com/v1beta/openai/")
        #expect(route.apiMode == "chat_completions")
        #expect(route.environmentOverrides["OPENAI_API_KEY"] == "google-oauth-token")
        #expect(route.environmentOverrides["GOOGLE_API_KEY"] == "")
        #expect(route.environmentOverrides["GOOGLE_CLOUD_PROJECT"] == "epistemos-gemini-project")
        #expect(route.environmentOverrides["HERMES_OPENAI_DEFAULT_HEADERS_JSON"]?.contains("x-goog-user-project") == true)
    }
}

// MARK: - Bridge Event Line Parsing Tests

/// Tests that the JSON wire format from the Python bridge is correctly parseable
/// into the expected Swift types. Validates the parsing contract without needing
/// to invoke private ViewModel methods -- we parse the JSON the same way the
/// production handler does and verify the resulting event structure.

@Suite("Hermes Bridge Event Parsing")
struct HermesBridgeEventParsingTests {
    /// Parse a JSON line the same way handleHermesBridgeLine does, returning
    /// the event type string and the full payload for further assertions.
    private func parseBridgeLine(_ line: String) -> (type: String, payload: [String: Any])? {
        guard let data = line.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = payload["type"] as? String else {
            return nil
        }
        return (type, payload)
    }

    private func jsonLine(_ dict: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try #require(String(data: data, encoding: .utf8))
    }

    @Test("Thinking event parses with text field")
    func thinkingEventParses() throws {
        let line = try jsonLine(["type": "thinking", "text": "Let me analyze this..."])
        let parsed = try #require(parseBridgeLine(line))
        #expect(parsed.type == "thinking")
        #expect(parsed.payload["text"] as? String == "Let me analyze this...")
    }

    @Test("Text event parses with text field")
    func textEventParses() throws {
        let line = try jsonLine(["type": "text", "text": "Here is the answer."])
        let parsed = try #require(parseBridgeLine(line))
        #expect(parsed.type == "text")
        #expect(parsed.payload["text"] as? String == "Here is the answer.")
    }

    @Test("Tool started event parses all fields")
    func toolStartedEventParsesAllFields() throws {
        let line = try jsonLine([
            "type": "tool_started",
            "id": "tool-abc",
            "name": "search_files",
            "input_json": "{\"query\":\"import\"}",
        ])
        let parsed = try #require(parseBridgeLine(line))
        #expect(parsed.type == "tool_started")
        #expect(parsed.payload["id"] as? String == "tool-abc")
        #expect(parsed.payload["name"] as? String == "search_files")
        #expect(parsed.payload["input_json"] as? String == "{\"query\":\"import\"}")
    }

    @Test("Tool completed event parses result and error flag")
    func toolCompletedEventParsesResultAndErrorFlag() throws {
        let line = try jsonLine([
            "type": "tool_completed",
            "id": "tool-abc",
            "result": "Found 3 matches",
            "is_error": false,
        ])
        let parsed = try #require(parseBridgeLine(line))
        #expect(parsed.type == "tool_completed")
        #expect(parsed.payload["id"] as? String == "tool-abc")
        #expect(parsed.payload["result"] as? String == "Found 3 matches")
        #expect(parsed.payload["is_error"] as? Bool == false)
    }

    @Test("Tool completed with error flag set to true")
    func toolCompletedWithErrorFlagTrue() throws {
        let line = try jsonLine([
            "type": "tool_completed",
            "id": "tool-err",
            "result": "Traceback (most recent call last):\n  File ...",
            "is_error": true,
        ])
        let parsed = try #require(parseBridgeLine(line))
        #expect(parsed.payload["is_error"] as? Bool == true)
    }

    @Test("Permission required event carries all request fields for AgentPermissionRequest construction")
    func permissionRequiredEventCarriesAllFields() throws {
        let line = try jsonLine([
            "type": "permission_required",
            "permission_id": "perm-999",
            "tool_name": "terminal",
            "input_json": "{\"command\":\"rm -rf /tmp/stuff\"}",
            "risk_level": "destructive",
            "description": "This command will delete files.",
        ])
        let parsed = try #require(parseBridgeLine(line))
        #expect(parsed.type == "permission_required")

        // Construct the same AgentPermissionRequest the production code would.
        let request = AgentPermissionRequest(
            id: parsed.payload["permission_id"] as? String ?? UUID().uuidString,
            toolName: parsed.payload["tool_name"] as? String ?? "terminal",
            inputJson: parsed.payload["input_json"] as? String ?? "{}",
            riskLevel: AgentRuntimeRiskLevel(rustValue: parsed.payload["risk_level"] as? String ?? "modification"),
            description: parsed.payload["description"] as? String ?? "Hermes requires approval."
        )
        #expect(request.id == "perm-999")
        #expect(request.toolName == "terminal")
        #expect(request.inputJson == "{\"command\":\"rm -rf /tmp/stuff\"}")
        #expect(request.riskLevel == .destructive)
        #expect(request.description == "This command will delete files.")
    }

    @Test("Complete event carries stop reason and token counts")
    func completeEventCarriesStopReasonAndTokenCounts() throws {
        let line = try jsonLine([
            "type": "complete",
            "stop_reason": "max_turns",
            "input_tokens": 2048,
            "output_tokens": 512,
        ])
        let parsed = try #require(parseBridgeLine(line))
        #expect(parsed.type == "complete")
        #expect(parsed.payload["stop_reason"] as? String == "max_turns")
        #expect(parsed.payload["input_tokens"] as? Int == 2048)
        #expect(parsed.payload["output_tokens"] as? Int == 512)
    }

    @Test("Error event carries message")
    func errorEventCarriesMessage() throws {
        let line = try jsonLine(["type": "error", "message": "Rate limit exceeded"])
        let parsed = try #require(parseBridgeLine(line))
        #expect(parsed.type == "error")
        #expect(parsed.payload["message"] as? String == "Rate limit exceeded")
    }

    @Test("Ready event with inference port is parsed correctly")
    func readyEventWithInferencePort() throws {
        let line = try jsonLine(["type": "ready", "inference_port": 11434])
        let parsed = try #require(parseBridgeLine(line))
        #expect(parsed.type == "ready")
        #expect(parsed.payload["inference_port"] as? Int == 11434)
    }

    @Test("Session ID from bridge events is extractable")
    func sessionIDFromBridgeEventsIsExtractable() throws {
        let line = try jsonLine([
            "type": "text",
            "text": "Hello",
            "session_id": "ses-abc123",
        ])
        let parsed = try #require(parseBridgeLine(line))
        let sessionID = parsed.payload["session_id"] as? String
        #expect(sessionID == "ses-abc123")
        #expect(!sessionID!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    @Test("Invalid JSON line returns nil from parser")
    func invalidJSONLineReturnsNil() {
        #expect(parseBridgeLine("this is not json at all") == nil)
        #expect(parseBridgeLine("") == nil)
        #expect(parseBridgeLine("{}") == nil) // No "type" field
        #expect(parseBridgeLine("{\"type\": 42}") == nil) // type is not a string
    }

    @Test("Admin result event carries domain, action, and data")
    func adminResultEventCarriesDomainActionAndData() throws {
        let line = try jsonLine([
            "type": "admin_result",
            "domain": "cron",
            "action": "list",
            "data": [["id": "cron-001", "name": "test"]] as [[String: Any]],
        ])
        let parsed = try #require(parseBridgeLine(line))
        #expect(parsed.type == "admin_result")
        #expect(parsed.payload["domain"] as? String == "cron")
        #expect(parsed.payload["action"] as? String == "list")
        let data = parsed.payload["data"] as? [[String: Any]]
        #expect(data != nil)
        #expect(data?.count == 1)
    }
}

// MARK: - Admin Command Payload Tests

@Suite("Hermes Admin Command Payloads")
struct HermesAdminCommandPayloadTests {
    @Test("Cron list admin command generates correct payload structure")
    func cronListPayload() throws {
        let (payload, _) = try buildAdminPayload(domain: "cron", action: "list")
        #expect(payload["command"] as? String == "admin")
        #expect(payload["domain"] as? String == "cron")
        #expect(payload["action"] as? String == "list")
    }

    @Test("MCP list admin command generates correct payload structure")
    func mcpListPayload() throws {
        let (payload, _) = try buildAdminPayload(domain: "mcp", action: "list")
        #expect(payload["command"] as? String == "admin")
        #expect(payload["domain"] as? String == "mcp")
        #expect(payload["action"] as? String == "list")
    }

    @Test("Skills list admin command generates correct payload structure")
    func skillsListPayload() throws {
        let (payload, _) = try buildAdminPayload(domain: "skills", action: "list")
        #expect(payload["command"] as? String == "admin")
        #expect(payload["domain"] as? String == "skills")
        #expect(payload["action"] as? String == "list")
    }

    @Test("Config get admin command generates correct payload structure")
    func configGetPayload() throws {
        let (payload, _) = try buildAdminPayload(domain: "config", action: "get")
        #expect(payload["command"] as? String == "admin")
        #expect(payload["domain"] as? String == "config")
        #expect(payload["action"] as? String == "get")
    }

    @Test("Diagnostics doctor admin command generates correct payload structure")
    func diagnosticsDoctorPayload() throws {
        let (payload, _) = try buildAdminPayload(domain: "diagnostics", action: "doctor")
        #expect(payload["command"] as? String == "admin")
        #expect(payload["domain"] as? String == "diagnostics")
        #expect(payload["action"] as? String == "doctor")
    }

    @Test("Admin payload with extra parameters merges them into the command")
    func adminPayloadWithExtraParams() throws {
        let (payload, _) = try buildAdminPayload(
            domain: "cron",
            action: "create",
            extra: ["name": "nightly", "schedule": "0 2 * * *", "prompt": "Run cleanup"]
        )
        #expect(payload["command"] as? String == "admin")
        #expect(payload["domain"] as? String == "cron")
        #expect(payload["action"] as? String == "create")
        #expect(payload["name"] as? String == "nightly")
        #expect(payload["schedule"] as? String == "0 2 * * *")
        #expect(payload["prompt"] as? String == "Run cleanup")
    }

    @Test("Admin payload round-trips through JSON serialization without data loss")
    func adminPayloadRoundTripsWithoutDataLoss() throws {
        let (_, line) = try buildAdminPayload(
            domain: "skills",
            action: "install",
            extra: ["name": "code_review", "url": "https://example.com/skill.tar.gz"]
        )
        // Re-parse the serialized line.
        let data = try #require(line.data(using: .utf8))
        let reparsed = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        #expect(reparsed["command"] as? String == "admin")
        #expect(reparsed["domain"] as? String == "skills")
        #expect(reparsed["action"] as? String == "install")
        #expect(reparsed["name"] as? String == "code_review")
        #expect(reparsed["url"] as? String == "https://example.com/skill.tar.gz")
    }

    /// Build an admin command payload the same way HermesAdminViewModel.sendAdmin does.
    private func buildAdminPayload(
        domain: String,
        action: String,
        extra: [String: Any] = [:]
    ) throws -> ([String: Any], String) {
        var payload: [String: Any] = [
            "command": "admin",
            "domain": domain,
            "action": action,
        ]
        for (key, value) in extra {
            payload[key] = value
        }

        #expect(JSONSerialization.isValidJSONObject(payload))
        let data = try JSONSerialization.data(withJSONObject: payload)
        let line = try #require(String(data: data, encoding: .utf8))
        let reparsed = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        return (reparsed, line)
    }
}

// MARK: - Session Command Payload Tests

@Suite("Hermes Session Command Payloads")
struct HermesSessionCommandPayloadTests {
    @Test("list_sessions command generates minimal payload")
    func listSessionsPayload() throws {
        let payload: [String: Any] = ["command": "list_sessions"]
        #expect(JSONSerialization.isValidJSONObject(payload))
        let data = try JSONSerialization.data(withJSONObject: payload)
        let reparsed = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        #expect(reparsed["command"] as? String == "list_sessions")
    }

    @Test("new_session command includes cwd")
    func newSessionPayload() throws {
        let payload: [String: Any] = [
            "command": "new_session",
            "cwd": "/Users/test/vault",
        ]
        #expect(JSONSerialization.isValidJSONObject(payload))
        let data = try JSONSerialization.data(withJSONObject: payload)
        let reparsed = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        #expect(reparsed["command"] as? String == "new_session")
        #expect(reparsed["cwd"] as? String == "/Users/test/vault")
    }

    @Test("resume_session command includes session_id and cwd")
    func resumeSessionPayload() throws {
        let payload: [String: Any] = [
            "command": "resume_session",
            "session_id": "ses-xyz789",
            "cwd": "/Users/test/vault",
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let reparsed = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        #expect(reparsed["command"] as? String == "resume_session")
        #expect(reparsed["session_id"] as? String == "ses-xyz789")
        #expect(reparsed["cwd"] as? String == "/Users/test/vault")
    }

    @Test("fork_session command includes session_id")
    func forkSessionPayload() throws {
        let payload: [String: Any] = [
            "command": "fork_session",
            "session_id": "ses-fork-source",
            "cwd": "/Users/test/vault",
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let reparsed = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        #expect(reparsed["command"] as? String == "fork_session")
        #expect(reparsed["session_id"] as? String == "ses-fork-source")
    }
}

// MARK: - Admin Result Parsing Tests

@Suite("Hermes Admin Result Parsing")
struct HermesAdminResultParsingTests {
    @Test("Diagnostics doctor result populates DiagnosticsResult fields")
    @MainActor
    func diagnosticsDoctorResultPopulatesFields() {
        let manager = HermesSubprocessManager()
        let adminVM = HermesAdminViewModel(hermesManager: manager)

        let payload: [String: Any] = [
            "type": "admin_result",
            "domain": "diagnostics",
            "action": "doctor",
            "data": [
                "python_version": "Python 3.13.1",
                "python_path": "/opt/homebrew/bin/python3.13",
                "hermes_version": "0.14.0",
                "hermes_home": "/Users/test/Library/Application Support/Epistemos/Hermes",
                "hermes_home_exists": true,
                "config_exists": true,
                "skills_dir_exists": true,
                "memories_dir_exists": true,
                "sessions_dir_exists": true,
                "cron_dir_exists": false,
                "dependencies": ["rich": true, "acp_adapter": true, "yaml": true],
                "git_revision": "abc1234",
                "disk_free_gb": 150.5,
                "mcp_server_count": 2,
                "cron_job_count": 0,
                "skill_count": 5,
            ] as [String: Any],
        ]

        adminVM.handleAdminResult(payload)

        let diag = adminVM.diagnostics
        #expect(diag != nil)
        #expect(diag?.pythonVersion == "Python 3.13.1")
        #expect(diag?.pythonPath == "/opt/homebrew/bin/python3.13")
        #expect(diag?.hermesVersion == "0.14.0")
        #expect(diag?.hermesHomeExists == true)
        #expect(diag?.configExists == true)
        #expect(diag?.skillsDirExists == true)
        #expect(diag?.memoriesDirExists == true)
        #expect(diag?.sessionsDirExists == true)
        #expect(diag?.cronDirExists == false)
        #expect(diag?.dependencies["rich"] == true)
        #expect(diag?.dependencies["acp_adapter"] == true)
        #expect(diag?.gitRevision == "abc1234")
        #expect(diag?.diskFreeGB == 150.5)
        #expect(diag?.mcpServerCount == 2)
        #expect(diag?.cronJobCount == 0)
        #expect(diag?.skillCount == 5)
    }

    @Test("Cron list result populates CronJobEntry array")
    @MainActor
    func cronListResultPopulatesCronJobs() {
        let manager = HermesSubprocessManager()
        let adminVM = HermesAdminViewModel(hermesManager: manager)

        let payload: [String: Any] = [
            "type": "admin_result",
            "domain": "cron",
            "action": "list",
            "data": [
                [
                    "id": "cron-001",
                    "name": "nightly-backup",
                    "prompt": "Back up the vault",
                    "schedule": "0 2 * * *",
                    "enabled": true,
                    "state": "scheduled",
                    "last_run_at": "2026-03-29T02:00:00Z",
                    "next_run_at": "2026-03-30T02:00:00Z",
                ] as [String: Any],
                [
                    "id": "cron-002",
                    "name": "weekly-summary",
                    "prompt": "Generate weekly summary",
                    "schedule": "0 9 * * 1",
                    "enabled": false,
                    "state": "paused",
                ] as [String: Any],
            ] as [[String: Any]],
        ]

        adminVM.handleAdminResult(payload)

        #expect(adminVM.cronJobs.count == 2)
        let first = adminVM.cronJobs.first { $0.id == "cron-001" }
        #expect(first?.name == "nightly-backup")
        #expect(first?.prompt == "Back up the vault")
        #expect(first?.schedule == "0 2 * * *")
        #expect(first?.enabled == true)
        #expect(first?.state == "scheduled")
        #expect(first?.lastRunAt == "2026-03-29T02:00:00Z")
        #expect(first?.nextRunAt == "2026-03-30T02:00:00Z")

        let second = adminVM.cronJobs.first { $0.id == "cron-002" }
        #expect(second?.name == "weekly-summary")
        #expect(second?.enabled == false)
        #expect(second?.state == "paused")
    }

    @Test("MCP server list result populates MCPServerEntry array")
    @MainActor
    func mcpServerListResultPopulatesServers() {
        let manager = HermesSubprocessManager()
        let adminVM = HermesAdminViewModel(hermesManager: manager)

        let payload: [String: Any] = [
            "type": "admin_result",
            "domain": "mcp",
            "action": "list",
            "data": [
                "filesystem": [
                    "command": "/usr/local/bin/mcp-filesystem",
                    "timeout": 30,
                ] as [String: Any],
                "web-search": [
                    "url": "http://localhost:3001/mcp",
                ] as [String: Any],
            ] as [String: Any],
        ]

        adminVM.handleAdminResult(payload)

        #expect(adminVM.mcpServers.count == 2)
        let fsServer = adminVM.mcpServers.first { $0.name == "filesystem" }
        #expect(fsServer?.transportType == "stdio")
        #expect(fsServer?.command == "/usr/local/bin/mcp-filesystem")
        #expect(fsServer?.timeout == 30)

        let webServer = adminVM.mcpServers.first { $0.name == "web-search" }
        #expect(webServer?.transportType == "HTTP")
        #expect(webServer?.url == "http://localhost:3001/mcp")
    }

    @Test("Skills list result populates HermesSkillEntry array")
    @MainActor
    func skillsListResultPopulatesSkills() {
        let manager = HermesSubprocessManager()
        let adminVM = HermesAdminViewModel(hermesManager: manager)

        let payload: [String: Any] = [
            "type": "admin_result",
            "domain": "skills",
            "action": "list",
            "data": [
                [
                    "name": "code_review",
                    "path": "/Users/test/.hermes/skills/code_review",
                    "description": "Reviews code for issues",
                    "version": "1.2.0",
                    "enabled": true,
                ] as [String: Any],
                [
                    "name": "summarize",
                    "path": "/Users/test/.hermes/skills/summarize",
                    "description": "Summarizes text",
                    "version": "0.9.1",
                    "enabled": false,
                ] as [String: Any],
            ] as [[String: Any]],
        ]

        adminVM.handleAdminResult(payload)

        #expect(adminVM.installedSkills.count == 2)
        let codeReview = adminVM.installedSkills.first { $0.name == "code_review" }
        #expect(codeReview?.description == "Reviews code for issues")
        #expect(codeReview?.version == "1.2.0")
        #expect(codeReview?.enabled == true)

        let summarize = adminVM.installedSkills.first { $0.name == "summarize" }
        #expect(summarize?.description == "Summarizes text")
        #expect(summarize?.enabled == false)
    }

    @Test("Admin result with error sets lastError")
    @MainActor
    func adminResultWithErrorSetsLastError() {
        let manager = HermesSubprocessManager()
        let adminVM = HermesAdminViewModel(hermesManager: manager)

        let payload: [String: Any] = [
            "type": "admin_result",
            "domain": "mcp",
            "action": "add",
            "error": "Server connection refused",
        ]

        adminVM.handleAdminResult(payload)

        #expect(adminVM.lastError == "mcp/add: Server connection refused")
        #expect(!adminVM.isLoading)
    }

    @Test("Config get result populates flattened config entries")
    @MainActor
    func configGetResultPopulatesFlattenedEntries() {
        let manager = HermesSubprocessManager()
        let adminVM = HermesAdminViewModel(hermesManager: manager)

        let payload: [String: Any] = [
            "type": "admin_result",
            "domain": "config",
            "action": "get",
            "data": [
                "model": [
                    "default": "anthropic/claude-opus-4.6",
                    "provider": "auto",
                ] as [String: Any],
                "terminal": [
                    "timeout": 120,
                ] as [String: Any],
            ] as [String: Any],
        ]

        adminVM.handleAdminResult(payload)

        #expect(adminVM.configEntries.count == 3)

        let modelDefault = adminVM.configEntries.first { $0.key == "model.default" }
        #expect(modelDefault?.value == "anthropic/claude-opus-4.6")

        let modelProvider = adminVM.configEntries.first { $0.key == "model.provider" }
        #expect(modelProvider?.value == "auto")

        let terminalTimeout = adminVM.configEntries.first { $0.key == "terminal.timeout" }
        #expect(terminalTimeout?.value == "120")
    }
}

// MARK: - Runtime Route Resolver Tests

@Suite("HermesRuntimeRoute Resolver")
struct HermesRuntimeRouteResolverTests {
    @Test("OpenAI route uses codex_responses API mode")
    func openAIRouteUsesCodexResponses() throws {
        let route = try #require(
            HermesRuntimeRoute.resolve(
                for: .cloud(.openAIGPT41Mini),
                apiKeyLookup: { $0 == .openAI ? "sk-openai-test" : nil }
            )
        )
        #expect(route.apiMode == "codex_responses")
        #expect(route.baseURL == "https://api.openai.com/v1")
        #expect(route.requestedProvider == "custom")
    }

    @Test("Anthropic route uses anthropic_messages API mode")
    func anthropicRouteUsesAnthropicMessages() throws {
        let route = try #require(
            HermesRuntimeRoute.resolve(
                for: .cloud(.anthropicClaudeSonnet4),
                apiKeyLookup: { $0 == .anthropic ? "sk-ant-test" : nil }
            )
        )
        #expect(route.apiMode == "anthropic_messages")
        #expect(route.baseURL == "https://api.anthropic.com")
        #expect(route.requestedProvider == "anthropic")
    }

    @Test("Google route uses chat_completions API mode with OpenAI compatibility endpoint")
    func googleRouteUsesChatCompletions() throws {
        let route = try #require(
            HermesRuntimeRoute.resolve(
                for: .cloud(.googleGemini25Flash),
                apiKeyLookup: { $0 == .google ? "gsk-google-test" : nil }
            )
        )
        #expect(route.apiMode == "chat_completions")
        #expect(route.baseURL == "https://generativelanguage.googleapis.com/v1beta/openai/")
        #expect(route.requestedProvider == "custom")
        // Google route must set both OPENAI_API_KEY and GOOGLE_API_KEY.
        #expect(route.environmentOverrides["OPENAI_API_KEY"] == "gsk-google-test")
        #expect(route.environmentOverrides["GOOGLE_API_KEY"] == "gsk-google-test")
    }

    @Test("OpenAI account route uses Codex bearer access instead of legacy keys")
    func openAIAccountRouteUsesCodexBearerAccess() {
        let route = HermesRuntimeRoute.resolve(
            for: .openAIGPT54Mini,
            credential: .openAICodex(accessToken: "codex-oauth-token")
        )

        #expect(route.apiMode == "codex_responses")
        #expect(route.baseURL == "https://chatgpt.com/backend-api/codex")
        #expect(route.requestedProvider == "custom")
        #expect(route.environmentOverrides["OPENAI_API_KEY"] == "codex-oauth-token")
    }

    @Test("All cloud routes clear competing provider keys to empty strings")
    func allCloudRoutesClearCompetingProviderKeys() throws {
        let providerKeys: Set<String> = [
            "OPENAI_API_KEY", "OPENROUTER_API_KEY", "ANTHROPIC_API_KEY",
            "ANTHROPIC_TOKEN", "CLAUDE_CODE_OAUTH_TOKEN",
            "GOOGLE_CLOUD_PROJECT", "HERMES_OPENAI_DEFAULT_HEADERS_JSON",
            "GLM_API_KEY", "KIMI_API_KEY", "MINIMAX_API_KEY", "DEEPSEEK_API_KEY",
        ]

        let selections: [(ChatModelSelection, CloudModelProvider)] = [
            (.cloud(.openAIGPT41Mini), .openAI),
            (.cloud(.anthropicClaudeSonnet4), .anthropic),
            (.cloud(.googleGemini25Flash), .google),
            (.cloud(.zaiGLM5), .zai),
            (.cloud(.kimiK25), .kimi),
            (.cloud(.minimaxM25), .minimax),
            (.cloud(.deepseekChat), .deepseek),
        ]

        for (selection, _) in selections {
            let route = try #require(
                HermesRuntimeRoute.resolve(
                    for: selection,
                    apiKeyLookup: { _ in "test-key" }
                )
            )

            // Every provider key must be present in the overrides (either set or cleared).
            for key in providerKeys {
                #expect(route.environmentOverrides[key] != nil,
                        "Expected \(key) to be present in environment overrides")
            }
        }
    }

    @Test("Equatable conformance compares all fields")
    func equatableComparesAllFields() {
        let routeA = HermesRuntimeRoute(
            model: "gpt-4.1-mini",
            requestedProvider: "custom",
            baseURL: "https://api.openai.com/v1",
            apiMode: "codex_responses",
            environmentOverrides: ["OPENAI_API_KEY": "key"]
        )
        let routeB = HermesRuntimeRoute(
            model: "gpt-4.1-mini",
            requestedProvider: "custom",
            baseURL: "https://api.openai.com/v1",
            apiMode: "codex_responses",
            environmentOverrides: ["OPENAI_API_KEY": "key"]
        )
        let routeC = HermesRuntimeRoute(
            model: "gpt-4.1-mini",
            requestedProvider: "custom",
            baseURL: "https://api.openai.com/v1",
            apiMode: "chat_completions",
            environmentOverrides: ["OPENAI_API_KEY": "key"]
        )

        #expect(routeA == routeB)
        #expect(routeA != routeC)
    }
}

// MARK: - AgentRuntimeRiskLevel Tests

@Suite("AgentRuntimeRiskLevel")
struct AgentRuntimeRiskLevelTests {
    @Test("Risk level parses known Rust values")
    func riskLevelParsesKnownRustValues() {
        #expect(AgentRuntimeRiskLevel(rustValue: "read_only") == .readOnly)
        #expect(AgentRuntimeRiskLevel(rustValue: "destructive") == .destructive)
        #expect(AgentRuntimeRiskLevel(rustValue: "modification") == .modification)
    }

    @Test("Unknown risk level defaults to modification")
    func unknownRiskLevelDefaultsToModification() {
        #expect(AgentRuntimeRiskLevel(rustValue: "unknown_future_value") == .modification)
        #expect(AgentRuntimeRiskLevel(rustValue: "") == .modification)
    }
}
