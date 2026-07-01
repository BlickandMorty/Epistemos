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

    @Test("computerActionJSON injects the bridge action name, preserving args")
    func actionJSONMergesName() throws {
        let json = WorkNativeToolExecutor.computerActionJSON(
            name: "click",
            argumentsJson: #"{"app":"Safari","x":120,"y":300,"element":"Downloads"}"#)
        let object = try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        #expect(object["action"] as? String == "click")
        #expect(object["app"] as? String == "Safari")
        #expect(object["app_name"] as? String == "Safari")
        #expect(object["x"] as? Int == 120)
        #expect(object["y"] as? Int == 300)
        #expect(object["element"] as? String == "Downloads")
    }

    @Test("computerActionJSON accepts empty object args and rejects malformed args")
    func actionJSONHandlesEmptyObjectAndRejectsMalformedArguments() throws {
        let emptyObjectJson = WorkNativeToolExecutor.computerActionJSON(name: "see", argumentsJson: "{}")
        let emptyObject = try #require(try JSONSerialization.jsonObject(with: Data(emptyObjectJson.utf8)) as? [String: Any])
        #expect(emptyObject["action"] as? String == "screenshot")

        for raw in ["", "not json"] {
            let json = WorkNativeToolExecutor.computerActionJSON(name: "see", argumentsJson: raw)
            let object = try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
            #expect(object["action"] as? String == "unsupported")
            #expect((object["error"] as? String)?.contains("require JSON object arguments") == true)
        }

        let unknownToolJson = WorkNativeToolExecutor.computerActionJSON(name: "unknown", argumentsJson: "{}")
        let unknownTool = try #require(try JSONSerialization.jsonObject(with: Data(unknownToolJson.utf8)) as? [String: Any])
        #expect(unknownTool["action"] as? String == "unsupported")
        #expect((unknownTool["error"] as? String)?.contains("Unsupported Work MCP computer-use tool") == true)
    }

    @Test("keys tool distinguishes text typing from special key presses")
    func keysActionShapes() throws {
        let commandJson = WorkNativeToolExecutor.computerActionJSON(
            name: "keys",
            argumentsJson: #"{"keys":"open -a Safari","modifiers":[]}"#)
        let command = try #require(try JSONSerialization.jsonObject(with: Data(commandJson.utf8)) as? [String: Any])
        #expect(command["action"] as? String == "type_text")
        #expect(command["text"] as? String == "open -a Safari")

        let returnJson = WorkNativeToolExecutor.computerActionJSON(
            name: "keys",
            argumentsJson: #"{"key":"return"}"#)
        let returnKey = try #require(try JSONSerialization.jsonObject(with: Data(returnJson.utf8)) as? [String: Any])
        #expect(returnKey["action"] as? String == "key_press")
        #expect(returnKey["text"] as? String == "return")
    }

    @Test("destructive computer-use actions reject unsafe fallback inputs before the bridge")
    func destructiveActionValidation() throws {
        let missingClickCoordinates = WorkNativeToolExecutor.computerActionJSON(
            name: "click",
            argumentsJson: "{}")
        let click = try #require(try JSONSerialization.jsonObject(with: Data(missingClickCoordinates.utf8)) as? [String: Any])
        #expect(click["action"] as? String == "unsupported")
        #expect((click["error"] as? String)?.contains("requires integer x and y") == true)

        let negativeClickCoordinate = WorkNativeToolExecutor.computerActionJSON(
            name: "click",
            argumentsJson: #"{"x":-1,"y":20}"#)
        let negativeClick = try #require(try JSONSerialization.jsonObject(with: Data(negativeClickCoordinate.utf8)) as? [String: Any])
        #expect(negativeClick["action"] as? String == "unsupported")
        #expect((negativeClick["error"] as? String)?.contains("requires integer x and y") == true)

        let invalidScrollDirection = WorkNativeToolExecutor.computerActionJSON(
            name: "scroll",
            argumentsJson: #"{"x":10,"y":20,"direction":"sideways"}"#)
        let scroll = try #require(try JSONSerialization.jsonObject(with: Data(invalidScrollDirection.utf8)) as? [String: Any])
        #expect(scroll["action"] as? String == "unsupported")
        #expect((scroll["error"] as? String)?.contains("direction must be") == true)
    }

    // MARK: result classification — map ComputerUseBridge result → MCP isError

    @Test("ToolOutputErrorClassifier flags `success:false` / `error` payloads, passes successes")
    func errorDetection() {
        #expect(ToolOutputErrorClassifier.isError(toolName: "see", outputJson: #"{"success":false,"error":"Accessibility permission not granted."}"#))
        #expect(ToolOutputErrorClassifier.isError(toolName: "see", outputJson: #"{"error":"boom"}"#))
        #expect(ToolOutputErrorClassifier.isError(toolName: "see", outputJson: #"{"success":true,"error":"boom"}"#))
        #expect(!ToolOutputErrorClassifier.isError(toolName: "see", outputJson: #"{"success":true,"screenshot":"<base64>"}"#))
        #expect(!ToolOutputErrorClassifier.isError(toolName: "see", outputJson: #"{"success":true,"error":null}"#))
        #expect(!ToolOutputErrorClassifier.isError(toolName: "see", outputJson: #"{"error":""}"#))
        #expect(!ToolOutputErrorClassifier.isError(toolName: "see", outputJson: #"{"elements":[]}"#))
        #expect(!ToolOutputErrorClassifier.isError(toolName: "see", outputJson: "not json")) // non-JSON is not treated as an error marker
    }

    @Test("browser.complete_task failure signals cannot be masked by optimistic fields")
    func browserCompleteTaskErrorDetection() {
        #expect(AgentToolNameAliases.canonical("browser_complete_task") == "browser.complete_task")
        #expect(ToolOutputErrorClassifier.isError(
            toolName: "browser.complete_task",
            outputJson: #"{"adapter_success":false,"task_success":true,"success":true,"status":"completed"}"#))
        #expect(ToolOutputErrorClassifier.isError(
            toolName: "browser_complete_task",
            outputJson: #"{"adapter_success":false,"task_success":true,"success":true,"status":"completed"}"#))
        #expect(ToolOutputErrorClassifier.isError(
            toolName: "browser.complete_task",
            outputJson: #"{"adapter_success":true,"task_success":true,"success":false,"status":"completed"}"#))
        #expect(ToolOutputErrorClassifier.isError(
            toolName: "browser.complete_task",
            outputJson: #"{"adapter_success":true,"task_success":true,"success":true,"status":"failed"}"#))
        #expect(ToolOutputErrorClassifier.isError(
            toolName: "browser.complete_task",
            outputJson: #"{"adapter_success":true,"status":"completed","error":null}"#))
        #expect(ToolOutputErrorClassifier.isError(
            toolName: "browser.complete_task",
            outputJson: #"{"adapter_success":true,"task_success":true,"success":true,"status":"completed","errors":["late browser-use warning"]}"#))
        #expect(!ToolOutputErrorClassifier.isError(
            toolName: "browser.complete_task",
            outputJson: #"{"adapter_success":true,"task_success":true,"success":true,"status":"completed","error":null,"errors":[]}"#))
    }
}
