import Foundation
import Testing
@testable import Epistemos

// MARK: - /new

@Suite("Hermes /new Command")
struct HermesNewSessionCommandTests {
    @Test("parse only matches exact /new")
    func parseExactOnly() {
        #expect(HermesNewSessionCommand.parse("/new") != nil)
        #expect(HermesNewSessionCommand.parse("/new arg") == nil)
        #expect(HermesNewSessionCommand.parse("new") == nil)
    }

    @Test("requiresApproval is false (Trivial)")
    func noApproval() {
        #expect(!HermesNewSessionCommand().requiresApproval)
    }
}

// MARK: - /clear

@Suite("Hermes /clear Command")
struct HermesClearCommandTests {
    @Test("bare /clear defaults to screen scope")
    func bareDefaultsToScreen() {
        #expect(HermesClearCommand.parse("/clear")?.scope == .screen)
    }

    @Test("/clear screen and /clear session each parse")
    func explicitScopeParses() {
        #expect(HermesClearCommand.parse("/clear screen")?.scope == .screen)
        #expect(HermesClearCommand.parse("/clear session")?.scope == .session)
    }

    @Test("unknown scope returns nil")
    func unknownScopeRejected() {
        #expect(HermesClearCommand.parse("/clear everything") == nil)
    }

    @Test("session scope requires approval; screen scope does not")
    func approvalIsScopeSensitive() {
        #expect(!HermesClearCommand(scope: .screen).requiresApproval)
        #expect(HermesClearCommand(scope: .session).requiresApproval)
    }
}

// MARK: - /save

@Suite("Hermes /save Command")
struct HermesSaveCommandTests {
    @Test("bare /save has nil label (auto-generate)")
    func bareSaveHasNilLabel() {
        #expect(HermesSaveCommand.parse("/save")?.label == nil)
    }

    @Test("/save <label> captures the label")
    func savesWithLabel() {
        #expect(HermesSaveCommand.parse("/save my session")?.label == "my session")
    }

    @Test("does not require approval")
    func noApproval() {
        #expect(!HermesSaveCommand(label: nil).requiresApproval)
    }
}

// MARK: - /load

@Suite("Hermes /load Command")
struct HermesLoadCommandTests {
    @Test("bare /load opens picker (nil query)")
    func bareLoadHasNilQuery() {
        #expect(HermesLoadCommand.parse("/load")?.query == nil)
    }

    @Test("/load <query> captures the query")
    func loadWithQuery() {
        #expect(HermesLoadCommand.parse("/load yesterday")?.query == "yesterday")
    }
}

// MARK: - /export

@Suite("Hermes /export Command")
struct HermesExportCommandTests {
    @Test("bare /export defaults to markdown")
    func bareDefaultsToMarkdown() {
        #expect(HermesExportCommand.parse("/export")?.format == .markdown)
    }

    @Test("explicit /export md, /export json, /export txt parse")
    func explicitFormatsParse() {
        #expect(HermesExportCommand.parse("/export md")?.format == .markdown)
        #expect(HermesExportCommand.parse("/export json")?.format == .json)
        #expect(HermesExportCommand.parse("/export txt")?.format == .text)
    }

    @Test("unknown format returns nil")
    func unknownFormatRejected() {
        #expect(HermesExportCommand.parse("/export pdf") == nil)
    }

    @Test("export always requires approval (file write)")
    func alwaysRequiresApproval() {
        #expect(HermesExportCommand(format: .markdown).requiresApproval)
        #expect(HermesExportCommand(format: .json).requiresApproval)
    }
}

// MARK: - /compact + /summary

@Suite("Hermes /compact Command")
struct HermesCompactCommandTests {
    @Test("parse exact only")
    func exactOnly() {
        #expect(HermesCompactCommand.parse("/compact") != nil)
        #expect(HermesCompactCommand.parse("/compact x") == nil)
    }
}

@Suite("Hermes /summary Command")
struct HermesSummaryCommandTests {
    @Test("parse exact only")
    func exactOnly() {
        #expect(HermesSummaryCommand.parse("/summary") != nil)
        #expect(HermesSummaryCommand.parse("/summary x") == nil)
    }
}

// MARK: - /model

@Suite("Hermes /model Command")
struct HermesModelCommandTests {
    @Test("bare /model shows current")
    func bareShowsCurrent() {
        #expect(HermesModelCommand.parse("/model")?.action == .showCurrent)
    }

    @Test("/model list lists available models")
    func listAction() {
        #expect(HermesModelCommand.parse("/model list")?.action == .list)
    }

    @Test("/model <name> switches to a model")
    func switchAction() {
        #expect(HermesModelCommand.parse("/model gpt-5.5")?.action == .switchTo(name: "gpt-5.5"))
        #expect(HermesModelCommand.parse("/model claude-opus-4-7")?.action == .switchTo(name: "claude-opus-4-7"))
    }

    @Test("switch action requires approval; show + list do not")
    func approvalIsActionSensitive() {
        #expect(!HermesModelCommand(action: .showCurrent).requiresApproval)
        #expect(!HermesModelCommand(action: .list).requiresApproval)
        #expect(HermesModelCommand(action: .switchTo(name: "x")).requiresApproval)
    }
}

// MARK: - /system

@Suite("Hermes /system Command")
struct HermesSystemPromptCommandTests {
    @Test("bare /system rejects (no prompt)")
    func bareRejected() {
        #expect(HermesSystemPromptCommand.parse("/system") == nil)
        #expect(HermesSystemPromptCommand.parse("/system   ") == nil)
    }

    @Test("/system <prompt> captures prompt")
    func capturesPrompt() {
        #expect(HermesSystemPromptCommand.parse("/system You are a helpful assistant")?.prompt
                == "You are a helpful assistant")
    }

    @Test("system prompt change always requires approval")
    func alwaysRequiresApproval() {
        #expect(HermesSystemPromptCommand(prompt: "x").requiresApproval)
    }
}

// MARK: - /temperature, /max-tokens, /top-p, /top-k

@Suite("Hermes Parameter Commands")
struct HermesParameterCommandTests {

    // MARK: temperature

    @Test("temperature accepts values in [0, 2]")
    func temperatureInBounds() {
        #expect(HermesParameterCommand.parse("/temperature 0")?.value == .temperature(0))
        #expect(HermesParameterCommand.parse("/temperature 0.7")?.value == .temperature(0.7))
        #expect(HermesParameterCommand.parse("/temperature 2")?.value == .temperature(2))
        #expect(HermesParameterCommand.parse("/temperature 2.0")?.value == .temperature(2))
    }

    @Test("temperature rejects out-of-range values")
    func temperatureOutOfBounds() {
        #expect(HermesParameterCommand.parse("/temperature -0.1") == nil)
        #expect(HermesParameterCommand.parse("/temperature 2.01") == nil)
        #expect(HermesParameterCommand.parse("/temperature 100") == nil)
    }

    @Test("temperature rejects non-numeric input")
    func temperatureRejectsGarbage() {
        #expect(HermesParameterCommand.parse("/temperature high") == nil)
        #expect(HermesParameterCommand.parse("/temperature inf") == nil)
        #expect(HermesParameterCommand.parse("/temperature nan") == nil)
    }

    // MARK: max-tokens

    @Test("max-tokens accepts positive integers")
    func maxTokensPositiveOnly() {
        #expect(HermesParameterCommand.parse("/max-tokens 1")?.value == .maxTokens(1))
        #expect(HermesParameterCommand.parse("/max-tokens 4096")?.value == .maxTokens(4096))
        #expect(HermesParameterCommand.parse("/max-tokens 200000")?.value == .maxTokens(200000))
    }

    @Test("max-tokens rejects 0, negatives, and non-integers")
    func maxTokensRejectsInvalid() {
        #expect(HermesParameterCommand.parse("/max-tokens 0") == nil)
        #expect(HermesParameterCommand.parse("/max-tokens -1") == nil)
        #expect(HermesParameterCommand.parse("/max-tokens 1.5") == nil)
        #expect(HermesParameterCommand.parse("/max-tokens lots") == nil)
    }

    // MARK: top-p

    @Test("top-p accepts values in (0, 1]")
    func topPInBounds() {
        #expect(HermesParameterCommand.parse("/top-p 0.5")?.value == .topP(0.5))
        #expect(HermesParameterCommand.parse("/top-p 1")?.value == .topP(1))
        #expect(HermesParameterCommand.parse("/top-p 0.95")?.value == .topP(0.95))
    }

    @Test("top-p rejects 0 (closed lower) and >1")
    func topPOutOfBounds() {
        #expect(HermesParameterCommand.parse("/top-p 0") == nil)
        #expect(HermesParameterCommand.parse("/top-p -0.1") == nil)
        #expect(HermesParameterCommand.parse("/top-p 1.01") == nil)
    }

    // MARK: top-k

    @Test("top-k accepts positive integers")
    func topKPositiveOnly() {
        #expect(HermesParameterCommand.parse("/top-k 40")?.value == .topK(40))
        #expect(HermesParameterCommand.parse("/top-k 1")?.value == .topK(1))
    }

    @Test("top-k rejects 0 and negatives")
    func topKRejectsInvalid() {
        #expect(HermesParameterCommand.parse("/top-k 0") == nil)
        #expect(HermesParameterCommand.parse("/top-k -5") == nil)
    }

    // MARK: parameter dispatch

    @Test("parameter property returns matching enum case")
    func parameterPropertyMatches() {
        #expect(HermesParameterCommand(value: .temperature(0.5)).parameter == .temperature)
        #expect(HermesParameterCommand(value: .maxTokens(100)).parameter == .maxTokens)
        #expect(HermesParameterCommand(value: .topP(0.9)).parameter == .topP)
        #expect(HermesParameterCommand(value: .topK(40)).parameter == .topK)
    }

    @Test("requiresApproval is false (Trivial action class)")
    func noApproval() {
        for value: HermesParameterValue in [
            .temperature(0.5), .maxTokens(100), .topP(0.9), .topK(40)
        ] {
            #expect(!HermesParameterCommand(value: value).requiresApproval)
        }
    }

    @Test("parser rejects non-parameter commands")
    func nonParameterCommandsRejected() {
        #expect(HermesParameterCommand.parse("/todo") == nil)
        #expect(HermesParameterCommand.parse("/calc 1+1") == nil)
        #expect(HermesParameterCommand.parse("nonsense") == nil)
    }

    @Test("HermesParameter has 4 cases")
    func fourParameters() {
        #expect(HermesParameter.allCases.count == 4)
    }
}
