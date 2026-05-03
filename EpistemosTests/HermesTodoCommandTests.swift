import Foundation
import Testing
@testable import Epistemos

@Suite("Hermes Todo Command")
struct HermesTodoCommandTests {
    @Test("parses Hermes todo slash commands into native todo actions")
    func parsesHermesTodoSlashCommands() throws {
        #expect(HermesTodoCommand.parse("/todo")?.action == .list)
        #expect(HermesTodoCommand.parse("/todo list")?.action == .list)
        #expect(HermesTodoCommand.parse("/todo add Ship native task bridge")?.action == .add(content: "Ship native task bridge"))
        #expect(HermesTodoCommand.parse("/todo done task-7")?.action == .done(id: "task-7"))
        #expect(HermesTodoCommand.parse("/todo clear")?.action == .clear)

        #expect(HermesTodoCommand.parse("/todo add") == nil)
        #expect(HermesTodoCommand.parse("/todo done") == nil)
        #expect(HermesTodoCommand.parse("/todo clear extra") == nil)
        #expect(HermesTodoCommand.parse("/run echo nope") == nil)
    }

    @Test("todo add maps to existing Rust todo action payload")
    func todoAddMapsToRustTodoPayload() throws {
        let command = try #require(HermesTodoCommand.parse("/todo add Build the direct path"))
        let payload = try Self.object(from: command.toolInputJSON(generatedID: "todo-direct-1"))

        #expect(payload["action"] as? String == "add")
        #expect(payload["id"] as? String == "todo-direct-1")
        #expect(payload["content"] as? String == "Build the direct path")
        #expect(payload["active_form"] as? String == "Build the direct path")
        #expect(command.toolName == "todo")
        #expect(!command.requiresApproval)
    }

    @Test("todo done and clear map to bounded native actions")
    func todoDoneAndClearMapToBoundedNativeActions() throws {
        let done = try #require(HermesTodoCommand.parse("/todo done todo-direct-1"))
        let donePayload = try Self.object(from: done.toolInputJSON())
        #expect(donePayload["action"] as? String == "done")
        #expect(donePayload["id"] as? String == "todo-direct-1")
        #expect(!done.requiresApproval)

        let clear = try #require(HermesTodoCommand.parse("/todo clear"))
        let clearPayload = try Self.object(from: clear.toolInputJSON())
        #expect(clearPayload["action"] as? String == "clear")
        #expect(clear.requiresApproval)
    }

    @Test("ACC slash parser exposes todo as native task substrate")
    func accSlashParserExposesTodo() throws {
        let result = CommandInputParser.parse("/todo add Finish M3")

        #expect(result.slashToken == .builtinMode(.todo))
        #expect(result.cleanedQuery == "add Finish M3")
        #expect(ACCSlashCommand.todo.defaultOperatingMode == .agent)
        #expect(ACCSlashCommand.todo.preferredToolNames == ["todo"])
        #expect(ACCSlashCommand.todo.helpText.localizedCaseInsensitiveContains("native agent task"))
    }

    @Test("Hermes registry and native slash command agree on destructive clear approval")
    func registryAndNativeSlashCommandAgreeOnClearApproval() throws {
        let capability = try #require(
            HermesCapabilityRegistry.capability(commandPattern: "/todo clear")
        )
        let command = try #require(HermesTodoCommand.parse("/todo clear"))

        #expect(capability.owner == .nativeCore)
        #expect(capability.requiresApproval)
        #expect(command.requiresApproval)
    }

    private static func object(from json: String) throws -> [String: Any] {
        let data = try #require(json.data(using: .utf8))
        let object = try JSONSerialization.jsonObject(with: data)
        return try #require(object as? [String: Any])
    }
}
