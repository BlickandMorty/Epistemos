import AppKit
import Testing
@testable import Epistemos

@Suite("Writing Tools Bridge")
struct WritingToolsBridgeTests {
    @Test("Writing tools items are skipped without a selection")
    func skipsWithoutSelection() {
        let menu = NSMenu(title: "Test")

        WritingToolsBridge.appendStandardItems(to: menu, hasSelection: false)

        #expect(menu.items.isEmpty)
    }

    @Test("Writing tools items are added when a selection exists")
    func addsItemsWithSelection() {
        let menu = NSMenu(title: "Test")

        WritingToolsBridge.appendStandardItems(to: menu, hasSelection: true)

        #expect(!menu.items.isEmpty)
    }
}
