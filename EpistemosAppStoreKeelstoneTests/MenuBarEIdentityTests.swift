import Foundation
import Testing

#if !EPISTEMOS_APP_STORE || !MAS_SANDBOX || !EPISTEMOS_FREE_V1
#error("Menu-bar E identity tests must compile in the App Store Free V1 target.")
#endif

@Suite("Menu-bar E identity")
struct MenuBarEIdentityTests {
    @Test("the template menu-bar asset is the native Epistemos E, never the retired book")
    func menuBarUsesTemplateSafeEpistemosE() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let imageSet = repositoryRoot.appendingPathComponent(
            "Epistemos/Assets.xcassets/MenuBarIcon.imageset",
            isDirectory: true
        )
        let contents = try String(
            contentsOf: imageSet.appendingPathComponent("Contents.json"),
            encoding: .utf8
        )
        let vector = try String(
            contentsOf: imageSet.appendingPathComponent("epistemos_e_template.svg"),
            encoding: .utf8
        )
        let statusBar = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Epistemos/App/StatusBar.swift"),
            encoding: .utf8
        )

        #expect(contents.contains("template-rendering-intent"))
        #expect(contents.contains("epistemos_e_template.svg"))
        #expect(!contents.contains("menubar_icon_18.png"))
        #expect(!contents.contains("menubar_icon_36.png"))
        #expect(!FileManager.default.fileExists(atPath: imageSet.appendingPathComponent("menubar_icon_18.png").path))
        #expect(!FileManager.default.fileExists(atPath: imageSet.appendingPathComponent("menubar_icon_36.png").path))
        #expect(vector.contains("viewBox=\"0 0 64 64\""))
        #expect(vector.contains("aria-label=\"Epistemos E\""))
        #expect(statusBar.contains("NSImage(named: \"MenuBarIcon\")"))
        #expect(statusBar.contains("systemSymbolName: \"e.circle\""))
        #expect(!statusBar.contains("systemSymbolName: \"book\""))
    }
}
