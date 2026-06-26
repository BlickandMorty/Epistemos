import Foundation
import Testing
@testable import Epistemos

@Suite("Work Native Tool Executor — composed production executor (W-R3 b)")
struct WorkNativeToolExecutorTests {
    // MARK: routing membership

    @Test("computer-category tool names are recognized; Rust-side tools are not")
    func computerToolMembership() {
        for name in ["see", "click", "type", "scroll", "keys", "screenshot"] {
            #expect(WorkNativeToolExecutor.computerToolNames.contains(name))
        }
        for name in ["file.read", "vault.search", "click_element", "type_text", "get_ui_tree"] {
            #expect(!WorkNativeToolExecutor.computerToolNames.contains(name))
        }
    }

    @Test("composed() routes NON-computer tools to the base executor (Rust FFI path)")
    func routesNonComputerToBase() async {
        let base: LocalAgentToolExecutor = { name, _ in
            LocalToolResult(toolName: name, resultJson: "{\"base\":\"\(name)\"}", isError: false)
        }
        let exec = WorkNativeToolExecutor.composed(base: base)
        let result = await exec("vault.search", "{\"query\":\"x\"}")
        #expect(result.toolName == "vault.search")
        #expect(result.resultJson.contains("\"base\":\"vault.search\""))
        #expect(result.isError == false)
    }

    // (The computer-use path → ComputerUseBridge is RUNTIME-PROOF-OWED: it needs TCC Accessibility + a live
    // screen, so it is not exercised here — only the pure shaping/routing helpers are.)

    // MARK: computerActionJSON — fold tool name into the bridge's "action" discriminator

    @Test("computerActionJSON injects the tool name as `action`, preserving args")
    func actionJSONMergesName() throws {
        let json = WorkNativeToolExecutor.computerActionJSON(name: "click", argumentsJson: "{\"app\":\"Safari\",\"element\":\"Downloads\"}")
        let object = try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        #expect(object["action"] as? String == "click")
        #expect(object["app"] as? String == "Safari")
        #expect(object["element"] as? String == "Downloads")
    }

    @Test("computerActionJSON tolerates empty / invalid args → bare action object")
    func actionJSONHandlesEmpty() throws {
        for raw in ["{}", "", "not json"] {
            let json = WorkNativeToolExecutor.computerActionJSON(name: "see", argumentsJson: raw)
            let object = try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
            #expect(object["action"] as? String == "see")
        }
    }

    // MARK: isErrorResult — map ComputerUseBridge result → MCP isError

    @Test("isErrorResult flags `success:false` / `error` payloads, passes successes")
    func errorDetection() {
        #expect(WorkNativeToolExecutor.isErrorResult(#"{"success":false,"error":"Accessibility permission not granted."}"#))
        #expect(WorkNativeToolExecutor.isErrorResult(#"{"error":"boom"}"#))
        #expect(!WorkNativeToolExecutor.isErrorResult(#"{"success":true,"screenshot":"<base64>"}"#))
        #expect(!WorkNativeToolExecutor.isErrorResult(#"{"elements":[]}"#))
        #expect(!WorkNativeToolExecutor.isErrorResult("not json")) // non-JSON is not treated as an error marker
    }
}
