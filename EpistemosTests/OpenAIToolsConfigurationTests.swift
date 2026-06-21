import Testing
import Foundation

@testable import Epistemos

// A user-facing "Enable Code Interpreter" toggle exists for OpenAI (SettingsView), but the Responses
// API returns 400 "Unsupported tool type: code_interpreter" on the current GPT-5.x chat models, so the
// request builder intentionally PARKS it — never attaching the tool (avoids a silent hard-400). That
// made the toggle a silent do-nothing-toggle; it now (a) discloses its parked state in Settings and
// (b) is run-provable here. These pin the honest builder behavior + the disclosure.
@Suite("LLMService.openAIToolsConfiguration — honest parked code_interpreter")
struct OpenAIToolsConfigurationTests {

    private func types(_ tools: [[String: Any]]) -> [String] {
        tools.compactMap { $0["type"] as? String }
    }

    @Test("web_search attaches when enabled")
    func webSearchAttaches() {
        let tools = OpenAIResponsesTools.array(webSearchEnabled: true, codeInterpreterEnabled: false)
        #expect(types(tools).contains("web_search"))
    }

    @Test("code_interpreter NEVER attaches even when its toggle is on (parked, not a silent 400)")
    func codeInterpreterNeverAttaches() {
        let tools = OpenAIResponsesTools.array(webSearchEnabled: false, codeInterpreterEnabled: true)
        #expect(!types(tools).contains("code_interpreter"))
        #expect(tools.isEmpty)
    }

    @Test("both toggles on → only web_search (code_interpreter stays parked)")
    func bothOnOnlyWebSearch() {
        let tools = OpenAIResponsesTools.array(webSearchEnabled: true, codeInterpreterEnabled: true)
        #expect(types(tools) == ["web_search"])
    }

    @Test("nothing enabled → empty tools")
    func noneEnabled() {
        #expect(OpenAIResponsesTools.array(webSearchEnabled: false, codeInterpreterEnabled: false).isEmpty)
    }

    @Test("Settings discloses the parked state so the toggle is not a silent do-nothing-toggle")
    func settingsDisclosesParkedState() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsView.swift")
        #expect(src.contains("Currently parked for OpenAI"))
        #expect(src.contains("Unsupported tool type: code_interpreter"))
    }
}
