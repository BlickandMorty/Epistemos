import Foundation
import Testing
@testable import Epistemos

@Suite("Work Tool MCP Core")
struct WorkToolMCPCoreTests {
    /// Stub executor: echoes the tool name + args (no FFI, no real tool execution).
    private static let echoExecutor: LocalAgentToolExecutor = { name, argumentsJson in
        LocalToolResult(
            toolName: name,
            resultJson: "{\"echoed\":\"\(name)\",\"args\":\(argumentsJson)}",
            isError: false)
    }

    @Test("tools/call runs the executor and maps LocalToolResult → MCP content (the W-R3 execution bridge)")
    func toolsCallRunsExecutor() async throws {
        let core = WorkToolMCPCore(executor: Self.echoExecutor)
        let req = #"{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"see","arguments":{"app":"Finder"}}}"#
        let resp = await core.handle(requestJSON: req)
        let obj = try #require(try JSONSerialization.jsonObject(with: Data(resp.utf8)) as? [String: Any])
        let result = try #require(obj["result"] as? [String: Any])
        let content = try #require(result["content"] as? [[String: Any]])
        #expect(result["isError"] as? Bool == false)
        #expect(content.first?["type"] as? String == "text")
        #expect((content.first?["text"] as? String)?.contains("\"echoed\":\"see\"") == true)
    }

    @Test("tools/call rejects guessed names that are not in the advertised Work MCP catalog")
    func toolsCallRejectsUnlistedToolName() async throws {
        let core = WorkToolMCPCore(
            executor: { name, _ in
                LocalToolResult(toolName: name, resultJson: #"{"executor":"called"}"#, isError: false)
            })

        let resp = await core.handle(
            requestJSON: #"{"jsonrpc":"2.0","id":70,"method":"tools/call","params":{"name":"not.a.real.tool","arguments":{}}}"#)
        let obj = try #require(try JSONSerialization.jsonObject(with: Data(resp.utf8)) as? [String: Any])
        let error = try #require(obj["error"] as? [String: Any])
        #expect(error["code"] as? Int == -32601)
        #expect((error["message"] as? String)?.contains("Tool not found: not.a.real.tool") == true)
        #expect(!resp.contains(#""executor":"called""#))
    }

    @Test("Work computer-use MCP names map to the ComputerUseBridge action vocabulary")
    func computerUseActionNamesMapToBridgeActions() throws {
        let see = try Self.jsonObject(WorkNativeToolExecutor.computerActionJSON(
            name: "see",
            argumentsJson: #"{"app":"Finder"}"#))
        #expect(see["action"] as? String == "screenshot")
        #expect(see["app_name"] as? String == "Finder")

        let type = try Self.jsonObject(WorkNativeToolExecutor.computerActionJSON(
            name: "type",
            argumentsJson: #"{"text":"hello"}"#))
        #expect(type["action"] as? String == "type_text")

        let keys = try Self.jsonObject(WorkNativeToolExecutor.computerActionJSON(
            name: "keys",
            argumentsJson: #"{"key":"return"}"#))
        #expect(keys["action"] as? String == "key_press")
        #expect(keys["text"] as? String == "return")
    }

    @Test("Core App Store Work MCP surface omits Swift-native computer-use tools")
    func coreAppStoreWorkMCPOmitsComputerUseTools() async throws {
        let core = WorkToolMCPCore(
            executor: { name, _ in
                return LocalToolResult(toolName: name, resultJson: #"{"executor":"called"}"#, isError: false)
            },
            distribution: .coreAppStore)

        let list = await core.handle(requestJSON: #"{"jsonrpc":"2.0","id":71,"method":"tools/list"}"#)
        let listObject = try #require(try JSONSerialization.jsonObject(with: Data(list.utf8)) as? [String: Any])
        let result = try #require(listObject["result"] as? [String: Any])
        let tools = try #require(result["tools"] as? [[String: Any]])
        let names = Set(tools.compactMap { $0["name"] as? String })
        for toolName in WorkNativeToolExecutor.computerToolNames {
            #expect(!names.contains(toolName))
        }
        #expect(!names.contains("browser.complete_task"))
        #expect(!names.contains("browser_complete_task"))

        let call = await core.handle(
            requestJSON: #"{"jsonrpc":"2.0","id":72,"method":"tools/call","params":{"name":"see","arguments":{}}}"#)
        let callObject = try #require(try JSONSerialization.jsonObject(with: Data(call.utf8)) as? [String: Any])
        let error = try #require(callObject["error"] as? [String: Any])
        #expect(error["code"] as? Int == -32601)
        #expect((error["message"] as? String)?.contains("Tool not found: see") == true)
        #expect(!call.contains(#""executor":"called""#))

        for toolName in ["browser.complete_task", "browser_complete_task"] {
            let browserCall = await core.handle(
                requestJSON: #"{"jsonrpc":"2.0","id":73,"method":"tools/call","params":{"name":"\#(toolName)","arguments":{"task":"Open example.com"}}}"#)
            let browserObject = try #require(
                try JSONSerialization.jsonObject(with: Data(browserCall.utf8)) as? [String: Any]
            )
            let browserError = try #require(browserObject["error"] as? [String: Any])
            #expect(browserError["code"] as? Int == -32601)
            #expect((browserError["message"] as? String)?.contains("Tool not found: \(toolName)") == true)
            #expect(!browserCall.contains(#""executor":"called""#))
        }
    }

    @Test("unknown method → JSON-RPC method-not-found (-32601)")
    func unknownMethodErrors() async {
        let core = WorkToolMCPCore(executor: Self.echoExecutor)
        let resp = await core.handle(requestJSON: #"{"jsonrpc":"2.0","id":1,"method":"frobnicate"}"#)
        #expect(resp.contains("-32601"))
    }

    @Test("JSON-RPC error diagnostics bound and redact rejected identifiers")
    func errorDiagnosticsBoundAndRedactRejectedIdentifiers() async throws {
        let secret = "api_key=sk-secret-token-" + String(repeating: "x", count: 300)
        let longUnknown = "unknown." + String(repeating: "segment", count: 30)
        let core = WorkToolMCPCore(
            executor: { name, _ in
                LocalToolResult(toolName: name, resultJson: #"{"executor":"called"}"#, isError: false)
            })

        let secretToolResponse = await core.handle(
            requestJSON: #"{"jsonrpc":"2.0","id":90,"method":"tools/call","params":{"name":"\#(secret)","arguments":{}}}"#)
        let secretToolObject = try #require(
            try JSONSerialization.jsonObject(with: Data(secretToolResponse.utf8)) as? [String: Any]
        )
        let secretToolError = try #require(secretToolObject["error"] as? [String: Any])
        #expect((secretToolError["message"] as? String)?.contains("[redacted]") == true)
        #expect(!secretToolResponse.contains("sk-secret-token"))
        #expect(!secretToolResponse.contains(#""executor":"called""#))

        let longMethodResponse = await core.handle(
            requestJSON: #"{"jsonrpc":"2.0","id":91,"method":"\#(longUnknown)"}"#)
        let longMethodObject = try #require(
            try JSONSerialization.jsonObject(with: Data(longMethodResponse.utf8)) as? [String: Any]
        )
        let longMethodError = try #require(longMethodObject["error"] as? [String: Any])
        let message = try #require(longMethodError["message"] as? String)
        #expect(message.contains("Method not found: unknown."))
        #expect(message.count < longUnknown.count)
        #expect(message.contains("..."))
    }

    @Test("tools/call rejects missing or blank tool names before the executor")
    func toolsCallRejectsBlankName() async {
        let core = WorkToolMCPCore(
            executor: { name, _ in
                LocalToolResult(toolName: name, resultJson: #"{"executor":"called"}"#, isError: false)
            })
        for request in [
            #"{"jsonrpc":"2.0","id":8,"method":"tools/call","params":{"arguments":{}}}"#,
            #"{"jsonrpc":"2.0","id":9,"method":"tools/call","params":{"name":"   ","arguments":{}}}"#,
        ] {
            let resp = await core.handle(requestJSON: request)
            #expect(resp.contains("-32602"))
            #expect(!resp.contains(#""executor":"called""#))
        }
    }

    @Test("tools/list returns Epistemos app-native note/vault tools, not just a generic engine catalog")
    func toolsListSurfacesEpistemosAppTools() async throws {
        let vault = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-work-mcp-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)
        let core = WorkToolMCPCore(executor: Self.echoExecutor, nativeToolVaultPath: vault.path)
        let resp = await core.handle(requestJSON: #"{"jsonrpc":"2.0","id":2,"method":"tools/list"}"#)
        let obj = try #require(try JSONSerialization.jsonObject(with: Data(resp.utf8)) as? [String: Any])
        let result = try #require(obj["result"] as? [String: Any])
        let tools = try #require(result["tools"] as? [[String: Any]])
        let names = Set(tools.compactMap { $0["name"] as? String })
        #expect(names.contains("vault.search"))
        #expect(names.contains("vault.list"))
        #expect(names.contains("vault.read"))
        #expect(names.contains("vault.write"))
        #expect(names.contains("note.create"))
        #expect(names.contains("note.edit"))
    }

    @Test("Pro Work MCP surfaces browser-use task and canonicalizes legacy calls")
    func proWorkMCPSurfacesBrowserUseTask() async throws {
        let vault = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-work-mcp-browser-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: vault) }

        let core = WorkToolMCPCore(
            executor: Self.echoExecutor,
            distribution: .proResearch,
            nativeToolVaultPath: vault.path)
        let list = await core.handle(requestJSON: #"{"jsonrpc":"2.0","id":81,"method":"tools/list"}"#)
        let listObject = try #require(try JSONSerialization.jsonObject(with: Data(list.utf8)) as? [String: Any])
        let result = try #require(listObject["result"] as? [String: Any])
        let tools = try #require(result["tools"] as? [[String: Any]])
        let names = Set(tools.compactMap { $0["name"] as? String })

        #expect(names.contains("browser.complete_task"))
        #expect(!names.contains("browser_complete_task"))

        let call = await core.handle(
            requestJSON: #"{"jsonrpc":"2.0","id":82,"method":"tools/call","params":{"name":"browser_complete_task","arguments":{"task":"Open example.com","max_steps":2}}}"#)
        let callObject = try #require(try JSONSerialization.jsonObject(with: Data(call.utf8)) as? [String: Any])
        let callResult = try #require(callObject["result"] as? [String: Any])
        let content = try #require(callResult["content"] as? [[String: Any]])
        let text = try #require(content.first?["text"] as? String)

        #expect(callResult["isError"] as? Bool == false)
        #expect(text.contains(#""echoed":"browser.complete_task""#))
        #expect(!text.contains(#""echoed":"browser_complete_task""#))
    }

    @Test("context snapshot descriptor append is idempotent")
    func contextSnapshotDescriptorAppendIsIdempotent() {
        var tools = [WorkToolMCPCore.contextSnapshotToolDescriptor()]
        WorkToolMCPCore.appendContextSnapshotToolIfNeeded(tools: &tools)
        WorkToolMCPCore.appendContextSnapshotToolIfNeeded(tools: &tools)
        let names = tools.compactMap { $0["name"] as? String }
        #expect(names.filter { $0 == WorkToolMCPCore.contextSnapshotToolName }.count == 1)
    }

    @Test("tools/list and tools/call expose the Work-owned Epistemos context snapshot")
    func contextSnapshotTool() async throws {
        let snapshot = WorkAppContextSnapshot(
            workspacePath: "/work",
            vaultPath: "/vault",
            managedSkillsCount: 2,
            nativeToolsAvailable: true,
            appMode: "work")
        let core = WorkToolMCPCore(
            executor: Self.echoExecutor,
            appContextProvider: { @Sendable in snapshot })

        let list = await core.handle(requestJSON: #"{"jsonrpc":"2.0","id":2,"method":"tools/list"}"#)
        #expect(list.contains(WorkToolMCPCore.contextSnapshotToolName))

        let call = await core.handle(
            requestJSON: #"{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"epistemos.context.snapshot","arguments":{}}}"#)
        let obj = try #require(try JSONSerialization.jsonObject(with: Data(call.utf8)) as? [String: Any])
        let result = try #require(obj["result"] as? [String: Any])
        let content = try #require(result["content"] as? [[String: Any]])
        let text = try #require(content.first?["text"] as? String)
        #expect(text.contains(#""workspacePath":"\/work""#) || text.contains(#""workspacePath":"/work""#))
        #expect(text.contains(#""managedSkillsCount":2"#))
        #expect(text.contains(#""nativeToolsAvailable":true"#))
    }

    @Test("unadvertised context snapshot tool does not fall through to the generic executor")
    func contextSnapshotToolWithoutProviderIsRejectedAsUnlisted() async throws {
        let core = WorkToolMCPCore(
            executor: { name, _ in
                LocalToolResult(toolName: name, resultJson: #"{"executor":"called"}"#, isError: false)
            })

        let list = await core.handle(requestJSON: #"{"jsonrpc":"2.0","id":4,"method":"tools/list"}"#)
        #expect(!list.contains(WorkToolMCPCore.contextSnapshotToolName))

        let call = await core.handle(
            requestJSON: #"{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"epistemos.context.snapshot","arguments":{}}}"#)
        let obj = try #require(try JSONSerialization.jsonObject(with: Data(call.utf8)) as? [String: Any])
        let error = try #require(obj["error"] as? [String: Any])
        #expect(error["code"] as? Int == -32601)
        #expect((error["message"] as? String)?.contains("Tool not found: epistemos.context.snapshot") == true)
        #expect(!call.contains(#""executor":"called""#))
    }

    @Test("argumentsJSON normalizes dict / string / nil")
    func argumentsJSONNormalizes() {
        #expect(WorkToolMCPCore.argumentsJSON(from: nil) == "{}")
        #expect(WorkToolMCPCore.argumentsJSON(from: "{\"k\":1}") == "{\"k\":1}")
        #expect(WorkToolMCPCore.argumentsJSON(from: ["k": 1]).contains("\"k\""))
    }

    @Test("toolCallResult maps isError + resultJson into MCP content")
    func toolCallResultMaps() {
        let r = WorkToolMCPCore.toolCallResult(
            from: LocalToolResult(toolName: "x", resultJson: "{\"ok\":true}", isError: true))
        #expect(r["isError"] as? Bool == true)
        let content = r["content"] as? [[String: Any]]
        #expect(content?.first?["text"] as? String == "{\"ok\":true}")
    }

    private static func jsonObject(_ json: String) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    }
}
