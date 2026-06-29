import AppKit
import SwiftUI

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

    var mainEditMenu: NSMenu? { MarkEditShellMenus.mainEditMenu() }
    var editCommandsMenu: NSMenu? { MarkEditShellMenus.editCommandsMenu() }
    var editTableOfContentsMenu: NSMenu? { MarkEditShellMenus.tableOfContentsMenu() }
    var editFontMenu: NSMenu? { MarkEditShellMenus.fontMenu() }
    var editFindMenu: NSMenu? { MarkEditShellMenus.findMenu() }
    var reopenFileMenu: NSMenu? { nil }
    var lineEndingsMenu: NSMenu? { nil }
    var textFormatMenu: NSMenu? { MarkEditShellMenus.textFormatMenu() }
    var formatHeadersMenu: NSMenu? { MarkEditShellMenus.formatHeadersMenu() }
    var copyPandocCommandMenu: NSMenu? { MarkEditShellMenus.copyPandocCommandMenu() }
    var mainExtensionsMenu: NSMenu? { NSMenu(title: "Extensions") }

    var editGotoLineItem: NSMenuItem? { nil }
    var editReadOnlyItem: NSMenuItem? { nil }
    var editStatisticsItem: NSMenuItem? { nil }
    var formatBulletItem: NSMenuItem? { MarkEditShellMenus.item("Bullet List", action: #selector(EditorViewController.toggleBullet(_:))) }
    var formatNumberingItem: NSMenuItem? { MarkEditShellMenus.item("Numbered List", action: #selector(EditorViewController.toggleNumbering(_:))) }
    var formatTodoItem: NSMenuItem? { MarkEditShellMenus.item("Task List", action: #selector(EditorViewController.toggleTodo(_:))) }
    var formatCodeItem: NSMenuItem? { MarkEditShellMenus.item("Inline Code", action: #selector(EditorViewController.toggleInlineCode(_:))) }
    var formatCodeBlockItem: NSMenuItem? { MarkEditShellMenus.item("Code Block", action: #selector(EditorViewController.insertCodeBlock(_:))) }
    var formatMathItem: NSMenuItem? { MarkEditShellMenus.item("Inline Math", action: #selector(EditorViewController.toggleInlineMath(_:))) }
    var formatMathBlockItem: NSMenuItem? { MarkEditShellMenus.item("Math Block", action: #selector(EditorViewController.insertMathBlock(_:))) }
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

@MainActor
enum MarkEditShellMenus {
    static func item(
        _ title: String,
        action: Selector,
        keyEquivalent: String = "",
        modifiers: NSEvent.ModifierFlags = []
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = nil
        item.keyEquivalentModifierMask = modifiers
        return item
    }

    static func formatHeadersMenu() -> NSMenu {
        let menu = NSMenu(title: Localized.Toolbar.formatHeaders)
        menu.items = [
            item("Heading 1", action: #selector(EditorViewController.toggleH1(_:)), keyEquivalent: "1", modifiers: [.command, .option]),
            item("Heading 2", action: #selector(EditorViewController.toggleH2(_:)), keyEquivalent: "2", modifiers: [.command, .option]),
            item("Heading 3", action: #selector(EditorViewController.toggleH3(_:)), keyEquivalent: "3", modifiers: [.command, .option]),
            item("Heading 4", action: #selector(EditorViewController.toggleH4(_:))),
            item("Heading 5", action: #selector(EditorViewController.toggleH5(_:))),
            item("Heading 6", action: #selector(EditorViewController.toggleH6(_:)))
        ]
        return menu
    }

    static func textFormatMenu() -> NSMenu {
        let menu = NSMenu(title: Localized.Toolbar.textFormat)
        menu.items = [
            item(Localized.Toolbar.toggleBold, action: #selector(EditorViewController.toggleBold(_:)), keyEquivalent: "b", modifiers: [.command]),
            item(Localized.Toolbar.toggleItalic, action: #selector(EditorViewController.toggleItalic(_:)), keyEquivalent: "i", modifiers: [.command]),
            item(Localized.Toolbar.toggleStrikethrough, action: #selector(EditorViewController.toggleStrikethrough(_:))),
            .separator(),
            item(Localized.Toolbar.insertLink, action: #selector(EditorViewController.insertLink(_:)), keyEquivalent: "k", modifiers: [.command]),
            item(Localized.Toolbar.insertImage, action: #selector(EditorViewController.insertImage(_:))),
            .separator(),
            item("Bullet List", action: #selector(EditorViewController.toggleBullet(_:))),
            item("Numbered List", action: #selector(EditorViewController.toggleNumbering(_:))),
            item("Task List", action: #selector(EditorViewController.toggleTodo(_:))),
            .separator(),
            item(Localized.Toolbar.toggleBlockquote, action: #selector(EditorViewController.toggleBlockquote(_:))),
            item(Localized.Toolbar.horizontalRule, action: #selector(EditorViewController.insertHorizontalRule(_:))),
            item(Localized.Toolbar.insertTable, action: #selector(EditorViewController.insertTable(_:))),
            .separator(),
            item("Inline Code", action: #selector(EditorViewController.toggleInlineCode(_:))),
            item("Code Block", action: #selector(EditorViewController.insertCodeBlock(_:))),
            item("Inline Math", action: #selector(EditorViewController.toggleInlineMath(_:))),
            item("Math Block", action: #selector(EditorViewController.insertMathBlock(_:)))
        ]
        return menu
    }

    static func editCommandsMenu() -> NSMenu {
        let menu = NSMenu(title: "Commands")
        menu.items = [
            item(Localized.Toolbar.tableOfContents, action: Selector(("openTableOfContents:")), keyEquivalent: "o", modifiers: [.command, .shift]),
            item(Localized.Toolbar.statistics, action: Selector(("toggleStatistics:")), keyEquivalent: "i", modifiers: [.command, .shift])
        ]
        return menu
    }

    static func tableOfContentsMenu() -> NSMenu {
        let menu = NSMenu(title: Localized.Toolbar.tableOfContents)
        menu.items = [
            item(Localized.Toolbar.tableOfContents, action: Selector(("openTableOfContents:")))
        ]
        return menu
    }

    static func fontMenu() -> NSMenu {
        let menu = NSMenu(title: Localized.Settings.font)
        menu.items = [
            item("Bigger", action: Selector(("makeFontBigger:")), keyEquivalent: "+", modifiers: [.command]),
            item("Smaller", action: Selector(("makeFontSmaller:")), keyEquivalent: "-", modifiers: [.command]),
            item("Actual Size", action: Selector(("actualSize:")), keyEquivalent: "0", modifiers: [.command])
        ]
        return menu
    }

    static func findMenu() -> NSMenu {
        let menu = NSMenu(title: Localized.Search.find)
        menu.items = [
            item(Localized.Search.find, action: #selector(EditorViewController.startFind(_:)), keyEquivalent: "f", modifiers: [.command]),
            item(Localized.Search.replace, action: #selector(EditorViewController.startReplace(_:)), keyEquivalent: "f", modifiers: [.command, .option]),
            item(Localized.Search.findSelection, action: #selector(EditorViewController.findSelection(_:)), keyEquivalent: "e", modifiers: [.command]),
            item(Localized.Search.selectAllOccurrences, action: #selector(EditorViewController.selectAllOccurrences(_:)))
        ]
        return menu
    }

    static func mainEditMenu() -> NSMenu {
        let menu = NSMenu(title: "Edit")
        menu.items = [
            item(Localized.Toolbar.tableOfContents, action: Selector(("openTableOfContents:"))),
            .separator()
        ] + textFormatMenu().items + [
            .separator(),
            item(Localized.Toolbar.statistics, action: Selector(("toggleStatistics:")))
        ]
        return menu
    }

    static func copyPandocCommandMenu() -> NSMenu {
        let menu = NSMenu(title: Localized.Toolbar.copyPandocCommand)
        menu.items = [
            pandocItem("HTML", format: "html"),
            pandocItem("PDF", format: "pdf"),
            pandocItem("DOCX", format: "docx"),
            pandocItem("LaTeX", format: "latex"),
            .separator(),
            item("Learn Pandoc", action: Selector(("learnPandoc:")))
        ]
        return menu
    }

    private static func pandocItem(_ title: String, format: String) -> NSMenuItem {
        let item = item(title, action: Selector(("copyPandocCommand:")))
        item.identifier = NSUserInterfaceItemIdentifier(format)
        return item
    }
}

@MainActor
enum MarkEditSourceSettingsTab: String, CaseIterable, Identifiable {
    case editor = "Editor"
    case assistant = "Assistant"
    case general = "General"
    case window = "Window"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .editor: "character.cursor.ibeam"
        case .assistant: "wand.and.sparkles"
        case .general: "gearshape"
        case .window: "macwindow"
        }
    }
}

@MainActor
struct MarkEditSourceSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: MarkEditSourceSettingsTab = .editor

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Settings", selection: $selectedTab) {
                    ForEach(MarkEditSourceSettingsTab.allCases) { tab in
                        Label(tab.rawValue, systemImage: tab.symbolName).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 520)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Label(Localized.General.done, systemImage: "checkmark")
                }
            }
            .padding(16)

            Divider()

            ScrollView {
                Group {
                    switch selectedTab {
                    case .editor:
                        EditorSettingsView()
                    case .assistant:
                        AssistantSettingsView()
                    case .general:
                        GeneralSettingsView()
                    case .window:
                        WindowSettingsView()
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .frame(minWidth: 660, minHeight: 520)
    }
}
#endif
