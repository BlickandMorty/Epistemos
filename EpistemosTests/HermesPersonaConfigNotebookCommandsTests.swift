import Foundation
import Testing
@testable import Epistemos

// MARK: - /persona

@Suite("Hermes /persona Command")
struct HermesPersonaCommandTests {
    @Test("bare /persona shows current")
    func bareShowsCurrent() {
        #expect(HermesPersonaCommand.parse("/persona")?.action == .showCurrent)
    }

    @Test("/persona list parses and is read-only")
    func listAction() {
        let cmd = HermesPersonaCommand.parse("/persona list")
        #expect(cmd?.action == .list)
        #expect(cmd?.requiresApproval == false)
    }

    @Test("/persona <name> switches and is read-only")
    func switchTo() {
        let cmd = HermesPersonaCommand.parse("/persona Researcher")
        #expect(cmd?.action == .switchTo(name: "Researcher"))
        #expect(cmd?.requiresApproval == false)
    }

    @Test("/persona create/edit/delete/export require approval")
    func mutationsRequireApproval() {
        for verb in ["create", "edit", "delete", "export"] {
            let cmd = HermesPersonaCommand.parse("/persona \(verb) Demo")
            #expect(cmd != nil)
            #expect(cmd?.requiresApproval == true,
                    "\(verb) must require approval")
        }
    }

    @Test("/persona import requires approval and captures file path")
    func importRequiresApproval() {
        let cmd = HermesPersonaCommand.parse("/persona import /tmp/p.json")
        #expect(cmd?.action == .importFrom(filePath: "/tmp/p.json"))
        #expect(cmd?.requiresApproval == true)
    }

    @Test("/persona info <name> is read-only")
    func infoReadOnly() {
        let cmd = HermesPersonaCommand.parse("/persona info Researcher")
        #expect(cmd?.action == .info(name: "Researcher"))
        #expect(cmd?.requiresApproval == false)
    }

    @Test("/persona <verb> with missing argument returns nil")
    func verbsWithoutArgsAreNil() {
        for verb in ["create", "edit", "delete", "export", "import", "info"] {
            #expect(HermesPersonaCommand.parse("/persona \(verb)") == nil,
                    "\(verb) with no argument should return nil")
        }
    }
}

// MARK: - /memory

@Suite("Hermes /memory Command")
struct HermesMemoryCommandTests {
    @Test("/memory on / off / clear parse")
    func threeActionsParse() {
        #expect(HermesMemoryCommand.parse("/memory on")?.action == .enable)
        #expect(HermesMemoryCommand.parse("/memory off")?.action == .disable)
        #expect(HermesMemoryCommand.parse("/memory clear")?.action == .clear)
    }

    @Test("bare /memory or unknown verb returns nil")
    func bareAndUnknownReject() {
        #expect(HermesMemoryCommand.parse("/memory") == nil)
        #expect(HermesMemoryCommand.parse("/memory toggle") == nil)
    }

    @Test("all memory actions require approval")
    func allRequireApproval() {
        for action: HermesMemoryCommand.Action in [.enable, .disable, .clear] {
            #expect(HermesMemoryCommand(action: action).requiresApproval)
        }
    }
}

// MARK: - /tools toggle

@Suite("Hermes /tools Toggle Command")
struct HermesToolsToggleCommandTests {
    @Test("/tools on/off parses; /tools alone returns nil")
    func parseOnOffOnly() {
        #expect(HermesToolsToggleCommand.parse("/tools on")?.action == .enable)
        #expect(HermesToolsToggleCommand.parse("/tools off")?.action == .disable)
        #expect(HermesToolsToggleCommand.parse("/tools") == nil)
        #expect(HermesToolsToggleCommand.parse("/tools list") == nil)
    }

    @Test("toggle requires approval")
    func togglerequiresApproval() {
        #expect(HermesToolsToggleCommand(action: .enable).requiresApproval)
        #expect(HermesToolsToggleCommand(action: .disable).requiresApproval)
    }
}

// MARK: - /config show

@Suite("Hermes /config show Command")
struct HermesConfigShowCommandTests {
    @Test("/config show is the only accepted form")
    func onlyExactForm() {
        #expect(HermesConfigShowCommand.parse("/config show") != nil)
        #expect(HermesConfigShowCommand.parse("/config") == nil)
        #expect(HermesConfigShowCommand.parse("/config show extra") == nil)
    }

    @Test("read-only — no approval")
    func noApproval() {
        #expect(!HermesConfigShowCommand().requiresApproval)
    }
}

// MARK: - /notebook

@Suite("Hermes /notebook Command")
struct HermesNotebookCommandTests {
    @Test("bare /notebook shows current")
    func bareShowsCurrent() {
        #expect(HermesNotebookCommand.parse("/notebook")?.action == .showCurrent)
    }

    @Test("/notebook list and /notebook clear parse")
    func listAndClearParse() {
        #expect(HermesNotebookCommand.parse("/notebook list")?.action == .list)
        #expect(HermesNotebookCommand.parse("/notebook clear")?.action == .clear)
    }

    @Test("/notebook clear requires approval (destructive)")
    func clearRequiresApproval() {
        #expect(HermesNotebookCommand(action: .clear).requiresApproval)
        #expect(!HermesNotebookCommand(action: .list).requiresApproval)
        #expect(!HermesNotebookCommand(action: .showCurrent).requiresApproval)
    }

    @Test("/notebook open <name> opens a notebook by name")
    func openByName() {
        #expect(HermesNotebookCommand.parse("/notebook open Research")?.action == .open(name: "Research"))
    }

    @Test("/notebook <name> shorthand also opens")
    func bareNameOpens() {
        // No verb, but a name → shorthand for open.
        #expect(HermesNotebookCommand.parse("/notebook Research")?.action == .open(name: "Research"))
    }
}
