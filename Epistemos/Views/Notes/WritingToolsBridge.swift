import AppKit

enum WritingToolsBridge {
    static let showNotification = Notification.Name("EpistemosShowWritingTools")

    @MainActor
    static func present(in textView: NSTextView) {
        textView.window?.makeFirstResponder(textView)
        textView.showWritingTools(nil)
    }

    static func appendStandardItems(to menu: NSMenu, hasSelection: Bool) {
        guard hasSelection else { return }
        let items = NSMenuItem.writingToolsItems
        guard !items.isEmpty else { return }
        menu.addItem(.separator())
        items.forEach(menu.addItem)
    }
}
