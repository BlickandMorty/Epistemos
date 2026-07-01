import Foundation

@MainActor
public enum CommandRegistrations {
    public static func registerEpdocCommands(in registry: CommandRegistry = .shared) {
        registerNoteCommand(
            registry,
            id: "epdoc.save",
            title: "Save Note",
            subtitle: "Save the active Epdoc document",
            symbol: "tray.and.arrow.down",
            shortcut: EpistemosCommandShortcut("s", modifiers: .command, display: "⌘S"),
            menuPath: .file
        ) {
            registry.saveActiveNote()
        }
        registerNoteCommand(
            registry,
            id: "epdoc.findReplace",
            title: "Find and Replace",
            subtitle: "Search and replace inside the active note",
            symbol: "magnifyingglass",
            shortcut: EpistemosCommandShortcut("f", modifiers: .command, display: "⌘F"),
            menuPath: .edit
        ) {
            registry.showFindReplaceForActiveNote()
        }

        registerEditorCommand(
            registry,
            id: "epdoc.bold",
            title: "Bold",
            subtitle: "Toggle bold text",
            symbol: "bold",
            shortcut: EpistemosCommandShortcut("b", modifiers: .command, display: "⌘B"),
            command: .runCommand(name: "toggleBold", argsJSON: emptyArgs)
        )
        registerEditorCommand(
            registry,
            id: "epdoc.italic",
            title: "Italic",
            subtitle: "Toggle italic text",
            symbol: "italic",
            shortcut: EpistemosCommandShortcut("i", modifiers: .command, display: "⌘I"),
            command: .runCommand(name: "toggleItalic", argsJSON: emptyArgs)
        )
        registerEditorCommand(
            registry,
            id: "epdoc.strike",
            title: "Strikethrough",
            subtitle: "Toggle strikethrough text",
            symbol: "strikethrough",
            shortcut: EpistemosCommandShortcut("s", modifiers: [.command, .shift], display: "⇧⌘S"),
            command: .runCommand(name: "toggleStrike", argsJSON: emptyArgs)
        )
        registerEditorCommand(
            registry,
            id: "epdoc.highlight",
            title: "Highlight",
            subtitle: "Toggle highlighted text",
            symbol: "highlighter",
            shortcut: EpistemosCommandShortcut("h", modifiers: [.command, .shift], display: "⇧⌘H"),
            command: .runCommand(name: "toggleHighlight", argsJSON: emptyArgs)
        )
        registerEditorCommand(
            registry,
            id: "epdoc.inlineCode",
            title: "Inline Code",
            subtitle: "Toggle inline code",
            symbol: "chevron.left.forwardslash.chevron.right",
            shortcut: EpistemosCommandShortcut("e", modifiers: [.command, .shift], display: "⇧⌘E"),
            command: .runCommand(name: "toggleCode", argsJSON: emptyArgs)
        )
        registerEditorCommand(
            registry,
            id: "epdoc.codeBlock",
            title: "Code Block",
            subtitle: "Toggle a fenced code block",
            symbol: "curlybraces",
            shortcut: EpistemosCommandShortcut("c", modifiers: [.command, .shift], display: "⇧⌘C"),
            command: .runCommand(name: "toggleCodeBlock", argsJSON: emptyArgs)
        )
        registerEditorCommand(
            registry,
            id: "epdoc.link",
            title: "Link",
            subtitle: "Insert or edit a link",
            symbol: "link",
            shortcut: EpistemosCommandShortcut("k", modifiers: [.command, .shift], display: "⇧⌘K"),
            command: .runCommand(name: "setLink", argsJSON: emptyArgs)
        )
        registerEditorCommand(
            registry,
            id: "epdoc.widthNormal",
            title: "Normal Note Width",
            subtitle: "Use the canonical 720 px note width",
            symbol: "arrow.left.and.right",
            menuPath: .view,
            command: .setContentWidth(mode: .normal)
        )
        registerEditorCommand(
            registry,
            id: "epdoc.widthWide",
            title: "Wide Note Width",
            subtitle: "Use the full editor width",
            symbol: "rectangle.expand.vertical",
            menuPath: .view,
            command: .setContentWidth(mode: .wide)
        )
        registerEditorCommand(
            registry,
            id: "epdoc.aiDiffAccept",
            title: "Accept AI Edit",
            subtitle: "Apply the staged AI edit preview",
            symbol: "checkmark.circle",
            menuPath: .edit,
            command: .acceptAIDiff
        )
        registerEditorCommand(
            registry,
            id: "epdoc.aiDiffReject",
            title: "Reject AI Edit",
            subtitle: "Discard the staged AI edit preview",
            symbol: "xmark.circle",
            menuPath: .edit,
            command: .rejectAIDiff
        )
        registerEditorCommand(
            registry,
            id: "epdoc.aiDiffClear",
            title: "Clear AI Edit Preview",
            subtitle: "Remove AI edit preview decorations",
            symbol: "eraser",
            menuPath: .edit,
            command: .clearAIDiff
        )

        registerEditorCommand(
            registry,
            id: "epdoc.paragraph",
            title: "Paragraph",
            subtitle: "Set the current block to paragraph",
            symbol: "paragraphsign",
            command: .runCommand(name: "setParagraph", argsJSON: emptyArgs)
        )
        for level in 1...6 {
            registerEditorCommand(
                registry,
                id: "epdoc.heading\(level)",
                title: "Heading \(level)",
                subtitle: "Set the current block to heading \(level)",
                symbol: "h\(level).square",
                command: .runCommand(
                    name: "setHeadingLevel",
                    argsJSON: commandArgsJSON([HeadingCommandArgs(level: level)])
                )
            )
        }

        registerEditorCommand(
            registry,
            id: "epdoc.quote",
            title: "Quote",
            subtitle: "Insert a quote block",
            symbol: "text.quote",
            shortcut: EpistemosCommandShortcut(".", modifiers: [.command, .shift], display: "⇧⌘."),
            command: .insertSlashChoice(blockType: "blockquote")
        )
        registerEditorCommand(
            registry,
            id: "epdoc.bulletList",
            title: "Bulleted List",
            subtitle: "Insert a bulleted list",
            symbol: "list.bullet",
            shortcut: EpistemosCommandShortcut("8", modifiers: [.command, .shift], display: "⇧⌘8"),
            command: .insertSlashChoice(blockType: "bullet-list")
        )
        registerEditorCommand(
            registry,
            id: "epdoc.numberedList",
            title: "Numbered List",
            subtitle: "Insert a numbered list",
            symbol: "list.number",
            shortcut: EpistemosCommandShortcut("7", modifiers: [.command, .shift], display: "⇧⌘7"),
            command: .insertSlashChoice(blockType: "numbered-list")
        )
        registerEditorCommand(
            registry,
            id: "epdoc.taskList",
            title: "Task List",
            subtitle: "Insert a task list",
            symbol: "checklist",
            shortcut: EpistemosCommandShortcut("9", modifiers: [.command, .shift], display: "⇧⌘9"),
            command: .insertSlashChoice(blockType: "task-list")
        )
        registerEditorCommand(
            registry,
            id: "epdoc.divider",
            title: "Divider",
            subtitle: "Insert a horizontal divider",
            symbol: "minus",
            shortcut: EpistemosCommandShortcut("r", modifiers: [.command, .shift], display: "⇧⌘R"),
            command: .insertSlashChoice(blockType: "divider")
        )
        registerEditorCommand(
            registry,
            id: "epdoc.table",
            title: "Table",
            subtitle: "Insert a 3 by 3 table",
            symbol: "tablecells",
            command: .insertSlashChoice(blockType: "table-3x3")
        )
        registerEditorCommand(
            registry,
            id: "epdoc.math",
            title: "Inline Math",
            subtitle: "Insert a math block",
            symbol: "function",
            shortcut: EpistemosCommandShortcut("m", modifiers: .command, display: "⌘M"),
            command: .insertSlashChoice(blockType: "math-display")
        )
        registerEditorCommand(
            registry,
            id: "epdoc.calloutNote",
            title: "Note Callout",
            subtitle: "Insert a note callout",
            symbol: "note.text",
            command: .insertSlashChoice(blockType: "callout-note")
        )
        registerEditorCommand(
            registry,
            id: "epdoc.calloutWarning",
            title: "Warning Callout",
            subtitle: "Insert a warning callout",
            symbol: "exclamationmark.triangle",
            command: .insertSlashChoice(blockType: "callout-warning")
        )
    }

    private static func registerEditorCommand(
        _ registry: CommandRegistry,
        id: String,
        title: String,
        subtitle: String?,
        symbol: String,
        shortcut: EpistemosCommandShortcut? = nil,
        menuPath: EpistemosCommandMenuPath = .format,
        command: EpdocEditorCommand
    ) {
        registerNoteCommand(
            registry,
            id: id,
            title: title,
            subtitle: subtitle,
            symbol: symbol,
            shortcut: shortcut,
            menuPath: menuPath,
            requiresEditorSurface: true
        ) {
            registry.dispatchActiveNote(command)
        }
    }

    private static func registerNoteCommand(
        _ registry: CommandRegistry,
        id: String,
        title: String,
        subtitle: String?,
        symbol: String,
        shortcut: EpistemosCommandShortcut? = nil,
        menuPath: EpistemosCommandMenuPath,
        requiresEditorSurface: Bool = false,
        run: @escaping @MainActor () -> Void
    ) {
        registry.register(EpistemosCommand(
            id: id,
            title: title,
            subtitle: subtitle,
            symbol: symbol,
            shortcut: shortcut,
            scope: .note,
            menuPath: menuPath,
            isEnabled: {
                requiresEditorSurface
                    ? registry.hasActiveNoteEditorSurface()
                    : registry.hasActiveNoteSurface()
            },
            run: run
        ))
    }

    private static var emptyArgs: Data {
        Data("[]".utf8)
    }

    private static func commandArgsJSON<T: Encodable>(_ args: [T]) -> Data {
        (try? JSONEncoder().encode(args)) ?? emptyArgs
    }

    private struct HeadingCommandArgs: Encodable {
        let level: Int
    }
}
