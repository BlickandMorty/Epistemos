import Foundation
import Testing
@testable import Epistemos

@Suite("Hermes Command Dispatcher")
struct HermesCommandDispatcherTests {

    @Test("non-slash input returns nil")
    func nonSlashReturnsNil() {
        #expect(HermesCommandDispatcher.parseCore("hello world") == nil)
        #expect(HermesCommandDispatcher.parseCore("") == nil)
        #expect(HermesCommandDispatcher.parseCore("   ") == nil)
    }

    @Test("unknown slash command returns nil")
    func unknownSlashReturnsNil() {
        #expect(HermesCommandDispatcher.parseCore("/wat") == nil)
        #expect(HermesCommandDispatcher.parseCore("/run echo hi") == nil)  // Pro-only, not Core
    }

    @Test("dispatcher routes /todo to .todo branch")
    func routesTodo() {
        let parsed = HermesCommandDispatcher.parseCore("/todo")
        if case .todo = parsed { /* ok */ } else {
            Issue.record("expected .todo branch, got \(String(describing: parsed))")
        }
    }

    @Test("dispatcher routes /calc to .calc branch")
    func routesCalc() {
        let parsed = HermesCommandDispatcher.parseCore("/calc 2+2")
        if case .calc = parsed { /* ok */ } else {
            Issue.record("expected .calc branch, got \(String(describing: parsed))")
        }
    }

    @Test("dispatcher routes /help, /status, /tokens, /cost, /think")
    func routesPriorBatch() {
        for input in ["/help", "/status", "/tokens", "/cost", "/think hello"] {
            #expect(HermesCommandDispatcher.parseCore(input) != nil,
                    "\(input) should dispatch to a Core command")
        }
    }

    @Test("dispatcher routes /new, /clear, /save, /load, /export, /compact, /summary, /model, /system")
    func routesSessionOps() {
        for input in [
            "/new",
            "/clear",
            "/save",
            "/load",
            "/export",
            "/compact",
            "/summary",
            "/model",
            "/system You are an assistant"
        ] {
            #expect(HermesCommandDispatcher.parseCore(input) != nil,
                    "\(input) should dispatch to a Core command")
        }
    }

    @Test("dispatcher routes parameter setters")
    func routesParameterSetters() {
        for input in [
            "/temperature 0.7",
            "/max-tokens 4096",
            "/top-p 0.9",
            "/top-k 40"
        ] {
            #expect(HermesCommandDispatcher.parseCore(input) != nil,
                    "\(input) should dispatch to a Core command")
        }
    }

    @Test("dispatcher routes persona, memory, tools, config, notebook")
    func routesConfigToggles() {
        for input in [
            "/persona", "/persona list", "/persona Researcher",
            "/memory on", "/memory off", "/memory clear",
            "/tools on", "/tools off",
            "/config show",
            "/notebook", "/notebook list", "/notebook clear"
        ] {
            #expect(HermesCommandDispatcher.parseCore(input) != nil,
                    "\(input) should dispatch to a Core command")
        }
    }

    @Test("dispatcher routes /ask <question>")
    func routesAsk() {
        let parsed = HermesCommandDispatcher.parseCore("/ask why is the sky blue?")
        if case .ask(let question) = parsed {
            #expect(question == "why is the sky blue?")
        } else {
            Issue.record("expected .ask branch with question text, got \(String(describing: parsed))")
        }
    }

    @Test("dispatcher.requiresApproval reflects per-command flag")
    func requiresApprovalReflectsCommand() {
        // Trivial — should not require approval
        #expect(HermesCommandDispatcher.parseCore("/help")?.requiresApproval == false)
        #expect(HermesCommandDispatcher.parseCore("/calc 1+1")?.requiresApproval == false)
        #expect(HermesCommandDispatcher.parseCore("/status")?.requiresApproval == false)
        #expect(HermesCommandDispatcher.parseCore("/temperature 0.7")?.requiresApproval == false)

        // Approval-required
        #expect(HermesCommandDispatcher.parseCore("/export json")?.requiresApproval == true)
        #expect(HermesCommandDispatcher.parseCore("/system You are an assistant")?.requiresApproval == true)
        #expect(HermesCommandDispatcher.parseCore("/memory clear")?.requiresApproval == true)
        #expect(HermesCommandDispatcher.parseCore("/clear session")?.requiresApproval == true)
        #expect(HermesCommandDispatcher.parseCore("/persona create Demo")?.requiresApproval == true)
        #expect(HermesCommandDispatcher.parseCore("/notebook clear")?.requiresApproval == true)
    }

    @Test("dispatcher trims surrounding whitespace before parsing")
    func dispatcherTrimsWhitespace() {
        #expect(HermesCommandDispatcher.parseCore("   /help   ") != nil)
        #expect(HermesCommandDispatcher.parseCore("\n/todo\n") != nil)
    }

    @Test("dispatcher returns nil for Pro-only commands not implemented in Core")
    func proOnlyCommandsReturnNil() {
        for input in [
            "/run echo hi",
            "/shell",
            "/kill 123",
            "/web search foo",
            "/web page http://example.com",
            "/mcp list"
        ] {
            #expect(HermesCommandDispatcher.parseCore(input) == nil,
                    "\(input) is Pro-only and must not dispatch via Core dispatcher")
        }
    }
}
