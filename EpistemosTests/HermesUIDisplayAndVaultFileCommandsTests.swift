import Foundation
import Testing
@testable import Epistemos

// MARK: - /theme

@Suite("Hermes /theme Command")
struct HermesThemeCommandTests {
    @Test("bare /theme shows current; /theme list lists; /theme <name> sets")
    func threeForms() {
        #expect(HermesThemeCommand.parse("/theme")?.action == .showCurrent)
        #expect(HermesThemeCommand.parse("/theme list")?.action == .list)
        #expect(HermesThemeCommand.parse("/theme dawn")?.action == .set(name: "dawn"))
    }

    @Test("requires no approval")
    func noApproval() {
        #expect(!HermesThemeCommand(action: .showCurrent).requiresApproval)
        #expect(!HermesThemeCommand(action: .set(name: "x")).requiresApproval)
    }
}

// MARK: - /mode

@Suite("Hermes /mode Command")
struct HermesModeCommandTests {
    @Test("/mode simple, /mode rich parse")
    func bothModesParse() {
        #expect(HermesModeCommand.parse("/mode simple")?.mode == .simple)
        #expect(HermesModeCommand.parse("/mode rich")?.mode == .rich)
    }

    @Test("unknown mode and bare /mode return nil")
    func unknownReturnsNil() {
        #expect(HermesModeCommand.parse("/mode") == nil)
        #expect(HermesModeCommand.parse("/mode complex") == nil)
    }
}

// MARK: - /markdown, /image, /pager (UIToggleCommand)

@Suite("Hermes UI Toggle Command")
struct HermesUIToggleCommandTests {
    @Test("each surface accepts on/off")
    func threeSurfacesParseOnOff() {
        for surface in ["markdown", "image", "pager"] {
            #expect(HermesUIToggleCommand.parse("/\(surface) on") != nil)
            #expect(HermesUIToggleCommand.parse("/\(surface) off") != nil)
        }
    }

    @Test("unknown surface returns nil")
    func unknownSurfaceReturnsNil() {
        #expect(HermesUIToggleCommand.parse("/wat on") == nil)
    }

    @Test("invalid state returns nil")
    func invalidStateReturnsNil() {
        #expect(HermesUIToggleCommand.parse("/markdown maybe") == nil)
    }
}

// MARK: - /width

@Suite("Hermes /width Command")
struct HermesWidthCommandTests {
    @Test("accepts in [40, 500]")
    func widthInRange() {
        #expect(HermesWidthCommand.parse("/width 40")?.width == 40)
        #expect(HermesWidthCommand.parse("/width 80")?.width == 80)
        #expect(HermesWidthCommand.parse("/width 500")?.width == 500)
    }

    @Test("rejects out-of-range and non-numeric")
    func widthOutOfRange() {
        #expect(HermesWidthCommand.parse("/width 39") == nil)
        #expect(HermesWidthCommand.parse("/width 501") == nil)
        #expect(HermesWidthCommand.parse("/width wide") == nil)
    }
}

// MARK: - /font + /fontsize

@Suite("Hermes /font + /fontsize Commands")
struct HermesFontFontSizeCommandTests {
    @Test("/font <name> captures the name")
    func fontParses() {
        #expect(HermesFontCommand.parse("/font SF Pro")?.name == "SF Pro")
    }

    @Test("/font with no name returns nil")
    func bareFontReturnsNil() {
        #expect(HermesFontCommand.parse("/font") == nil)
    }

    @Test("/fontsize accepts in [8, 72]")
    func fontsizeInRange() {
        #expect(HermesFontSizeCommand.parse("/fontsize 8")?.size == 8)
        #expect(HermesFontSizeCommand.parse("/fontsize 14")?.size == 14)
        #expect(HermesFontSizeCommand.parse("/fontsize 72")?.size == 72)
    }

    @Test("/fontsize rejects out-of-range")
    func fontsizeOutOfRange() {
        #expect(HermesFontSizeCommand.parse("/fontsize 7") == nil)
        #expect(HermesFontSizeCommand.parse("/fontsize 73") == nil)
    }
}

// MARK: - /colors

@Suite("Hermes /colors Command")
struct HermesColorsCommandTests {
    @Test("only exact /colors matches")
    func onlyExactMatches() {
        #expect(HermesColorsCommand.parse("/colors") != nil)
        #expect(HermesColorsCommand.parse("/colors x") == nil)
    }
}

// MARK: - /read

@Suite("Hermes /read Command")
struct HermesReadCommandTests {
    @Test("/read <file> captures path")
    func readCapturesPath() {
        #expect(HermesReadCommand.parse("/read notes/x.md")?.path == "notes/x.md")
    }

    @Test("bare /read returns nil")
    func bareReadReturnsNil() {
        #expect(HermesReadCommand.parse("/read") == nil)
    }

    @Test("read does not require approval")
    func readNoApproval() {
        #expect(!HermesReadCommand(path: "x").requiresApproval)
    }
}

// MARK: - /write + /append

@Suite("Hermes /write + /append Commands")
struct HermesWriteAppendCommandTests {
    @Test("/write <path> <content> captures both fields")
    func writeCapturesBoth() {
        let cmd = HermesWriteCommand.parse("/write notes/x.md hello there")
        #expect(cmd?.path == "notes/x.md")
        #expect(cmd?.content == "hello there")
    }

    @Test("/write with only path returns nil")
    func writeWithOnlyPathReturnsNil() {
        #expect(HermesWriteCommand.parse("/write notes/x.md") == nil)
    }

    @Test("/append <path> <content> captures both fields")
    func appendCapturesBoth() {
        let cmd = HermesAppendCommand.parse("/append notes/x.md more text")
        #expect(cmd?.path == "notes/x.md")
        #expect(cmd?.content == "more text")
    }

    @Test("write + append both require approval (Sensitive class)")
    func mutationsRequireApproval() {
        #expect(HermesWriteCommand(path: "x", content: "y").requiresApproval)
        #expect(HermesAppendCommand(path: "x", content: "y").requiresApproval)
    }
}

// MARK: - /ls

@Suite("Hermes /ls Command")
struct HermesLsCommandTests {
    @Test("bare /ls has nil path (vault root)")
    func bareHasNilPath() {
        #expect(HermesLsCommand.parse("/ls")?.path == nil)
    }

    @Test("/ls <path> captures path")
    func capturesPath() {
        #expect(HermesLsCommand.parse("/ls notes/research")?.path == "notes/research")
    }
}

// MARK: - /search + /grep

@Suite("Hermes /search + /grep Commands")
struct HermesSearchGrepCommandTests {
    @Test("/search <query> captures query")
    func searchCapturesQuery() {
        #expect(HermesSearchCommand.parse("/search cognitive substrate")?.query == "cognitive substrate")
    }

    @Test("/grep <pattern> captures pattern")
    func grepCapturesPattern() {
        #expect(HermesGrepCommand.parse("/grep TODO.*urgent")?.pattern == "TODO.*urgent")
    }

    @Test("bare /search and /grep return nil")
    func bareReturnsNil() {
        #expect(HermesSearchCommand.parse("/search") == nil)
        #expect(HermesGrepCommand.parse("/grep") == nil)
    }
}

// MARK: - Dispatcher routing for the new batch

@Suite("Hermes Command Dispatcher — UI display + vault file routing")
struct HermesDispatcherUIDisplayAndVaultRoutingTests {
    @Test("UI display commands route correctly")
    func uiDisplayRoutes() {
        for input in [
            "/theme", "/theme list", "/theme dawn",
            "/mode simple",
            "/markdown on", "/image off", "/pager on",
            "/width 80",
            "/font SF Pro", "/fontsize 14",
            "/colors"
        ] {
            #expect(HermesCommandDispatcher.parseCore(input) != nil,
                    "\(input) should dispatch")
        }
    }

    @Test("vault file commands route correctly")
    func vaultFileRoutes() {
        for input in [
            "/read notes/x.md",
            "/write notes/x.md content",
            "/append notes/x.md more",
            "/ls",
            "/ls notes/",
            "/search query",
            "/grep pattern"
        ] {
            #expect(HermesCommandDispatcher.parseCore(input) != nil,
                    "\(input) should dispatch")
        }
    }

    @Test("write + append + export request approval; read + ls + search + grep do not")
    func approvalIsCorrectlyDelegated() {
        #expect(HermesCommandDispatcher.parseCore("/write x.md content")?.requiresApproval == true)
        #expect(HermesCommandDispatcher.parseCore("/append x.md content")?.requiresApproval == true)
        #expect(HermesCommandDispatcher.parseCore("/read x.md")?.requiresApproval == false)
        #expect(HermesCommandDispatcher.parseCore("/ls")?.requiresApproval == false)
        #expect(HermesCommandDispatcher.parseCore("/search foo")?.requiresApproval == false)
        #expect(HermesCommandDispatcher.parseCore("/grep foo")?.requiresApproval == false)
    }
}
