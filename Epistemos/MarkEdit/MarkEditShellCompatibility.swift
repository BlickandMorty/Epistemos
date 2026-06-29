import AppKit

#if canImport(MarkEditKit)
import MarkEditKit

typealias AppDelegate = EpistemosAppDelegate

enum AppDocumentController {
    nonisolated(unsafe) static var suggestedFilename: String?
    nonisolated(unsafe) static var suggestedTextEncoding: EditorTextEncoding?
}

extension EpistemosAppDelegate {
    var fileNewTabItem: NSMenuItem? { nil }
    var fileReopenClosedTabItem: NSMenuItem? { nil }

    var mainEditMenu: NSMenu? { nil }
    var editCommandsMenu: NSMenu? { nil }
    var editTableOfContentsMenu: NSMenu? { nil }
    var editFontMenu: NSMenu? { nil }
    var editFindMenu: NSMenu? { nil }
    var reopenFileMenu: NSMenu? { nil }
    var lineEndingsMenu: NSMenu? { nil }
    var textFormatMenu: NSMenu? { nil }
    var formatHeadersMenu: NSMenu? { nil }
    var copyPandocCommandMenu: NSMenu? { nil }
    var mainExtensionsMenu: NSMenu? { nil }

    var editGotoLineItem: NSMenuItem? { nil }
    var editReadOnlyItem: NSMenuItem? { nil }
    var editStatisticsItem: NSMenuItem? { nil }
    var formatBulletItem: NSMenuItem? { nil }
    var formatNumberingItem: NSMenuItem? { nil }
    var formatTodoItem: NSMenuItem? { nil }
    var formatCodeItem: NSMenuItem? { nil }
    var formatCodeBlockItem: NSMenuItem? { nil }
    var formatMathItem: NSMenuItem? { nil }
    var formatMathBlockItem: NSMenuItem? { nil }
    var activeWritingToolsItem: NSMenuItem? { nil }
    var mainUpdateItem: NSMenuItem? { nil }
    var presentUpdateItem: NSMenuItem? { nil }
    var postponeUpdateItem: NSMenuItem? { nil }
    var ignoreUpdateItem: NSMenuItem? { nil }

    func createNewFile(fileName: String?, initialContent: String?, isIntent: Bool) {
        AppDocumentController.suggestedFilename = fileName
        NSDocumentController.shared.newDocument(nil)
    }
}
#endif
