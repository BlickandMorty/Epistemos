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

    @Test("unknown method → JSON-RPC method-not-found (-32601)")
    func unknownMethodErrors() async {
        let core = WorkToolMCPCore(executor: Self.echoExecutor)
        let resp = await core.handle(requestJSON: #"{"jsonrpc":"2.0","id":1,"method":"frobnicate"}"#)
        #expect(resp.contains("-32601"))
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

    @Test("reserved context snapshot tool does not fall through to the generic executor")
    func contextSnapshotToolWithoutProviderIsHonestUnavailable() async throws {
        let core = WorkToolMCPCore(
            executor: { name, _ in
                LocalToolResult(toolName: name, resultJson: #"{"executor":"called"}"#, isError: false)
            })

        let list = await core.handle(requestJSON: #"{"jsonrpc":"2.0","id":4,"method":"tools/list"}"#)
        #expect(!list.contains(WorkToolMCPCore.contextSnapshotToolName))

        let call = await core.handle(
            requestJSON: #"{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"epistemos.context.snapshot","arguments":{}}}"#)
        let obj = try #require(try JSONSerialization.jsonObject(with: Data(call.utf8)) as? [String: Any])
        let result = try #require(obj["result"] as? [String: Any])
        let content = try #require(result["content"] as? [[String: Any]])
        let text = try #require(content.first?["text"] as? String)
        #expect(text.contains(#""available":false"#))
        #expect(text.contains("No Epistemos Work context is attached."))
        #expect(!text.contains(#""executor":"called""#))
        #expect(result["isError"] as? Bool == false)
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
}
