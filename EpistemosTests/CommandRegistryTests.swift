import Foundation
import Testing

@testable import Epistemos

@Suite("CommandRegistry (Plan 2 native controls)")
@MainActor
struct CommandRegistryTests {
    @Test("Register replaces duplicate IDs without duplicating menu or palette entries")
    func registerReplacesDuplicateIDs() {
        let registry = CommandRegistry()
        registry.register(EpistemosCommand(
            id: "test.duplicate",
            title: "Old Title",
            symbol: "command",
            scope: .global,
            isEnabled: { true },
            run: {}
        ))
        registry.register(EpistemosCommand(
            id: "test.duplicate",
            title: "New Title",
            symbol: "command",
            scope: .global,
            isEnabled: { true },
            run: {}
        ))

        #expect(registry.commandIDs == ["test.duplicate"])
        #expect(registry.matching(query: "new").map(\.id) == ["test.duplicate"])
        #expect(registry.matching(query: "").first?.title == "New Title")
    }

    @Test("Matching narrows to global plus active scope and filters disabled commands")
    func matchingNarrowsByScopeAndEnabledState() {
        let registry = CommandRegistry()
        registry.register(command(id: "global.ready", title: "Global Ready", scope: .global))
        registry.register(command(id: "note.ready", title: "Note Ready", scope: .note))
        registry.register(command(id: "code.ready", title: "Code Ready", scope: .code))
        registry.register(command(id: "code.disabled", title: "Code Disabled", scope: .code, enabled: false))

        #expect(registry.matching(query: "", scope: .code).map(\.id) == [
            "global.ready",
            "code.ready",
        ])
        #expect(registry.matching(query: "", scope: .note).map(\.id) == [
            "global.ready",
            "note.ready",
        ])
        #expect(!registry.matching(query: "", scope: .code).map(\.id).contains("code.disabled"))
    }

    @Test("Menu commands use the same enabled-state contract as palette matching")
    func menuCommandsFilterByPathAndEnabledState() {
        let registry = CommandRegistry()
        registry.register(command(id: "format.ready", title: "Format Ready", menuPath: .format))
        registry.register(command(id: "format.disabled", title: "Format Disabled", menuPath: .format, enabled: false))
        registry.register(command(id: "view.ready", title: "View Ready", menuPath: .view))

        #expect(registry.menuCommands(path: .format).map(\.id) == ["format.ready"])
    }

    @Test("Epdoc command catalog dispatches through the active note surface")
    func epdocCommandsDispatchThroughActiveNoteSurface() {
        final class SurfaceToken {}

        let registry = CommandRegistry()
        CommandRegistrations.registerEpdocCommands(in: registry)
        let token = SurfaceToken()
        var captured: [EpdocEditorCommand] = []
        var didShowFindReplace = false
        registry.activateNoteSurface(
            id: ObjectIdentifier(token),
            dispatch: { command in captured.append(command) },
            save: {},
            showFindReplace: { didShowFindReplace = true },
            state: { EpistemosCommandSurfaceState(isBoldActive: true) }
        )

        let bold = registry.matching(query: "bold", scope: .note).first { $0.id == "epdoc.bold" }
        #expect(bold != nil)
        bold?.run()

        #expect(captured.count == 1)
        if case let .runCommand(name, argsJSON) = captured.first {
            #expect(name == "toggleBold")
            #expect(String(data: argsJSON, encoding: .utf8) == "[]")
        } else {
            #expect(Bool(false), "expected bold to dispatch through EpdocEditorCommand.runCommand")
        }

        let link = registry.matching(query: "link", scope: .note).first { $0.id == "epdoc.link" }
        #expect(link != nil)
        link?.run()
        if case let .runCommand(name, argsJSON) = captured.last {
            #expect(name == "setLink")
            #expect(String(data: argsJSON, encoding: .utf8) == "[]")
        } else {
            #expect(Bool(false), "expected link to dispatch through EpdocEditorCommand.runCommand")
        }

        let wideWidth = registry.matching(query: "wide width", scope: .note).first { $0.id == "epdoc.widthWide" }
        #expect(wideWidth != nil)
        wideWidth?.run()
        if case let .setContentWidth(mode)? = captured.last {
            #expect(mode == .wide)
        } else {
            #expect(Bool(false), "expected wide-width command to dispatch through EpdocEditorCommand.setContentWidth")
        }

        let viewMenuIDs = registry.menuCommands(path: .view).map(\.id)
        #expect(viewMenuIDs.contains("epdoc.widthNormal"))
        #expect(viewMenuIDs.contains("epdoc.widthWide"))

        let findReplace = registry.matching(query: "find replace", scope: .note).first { $0.id == "epdoc.findReplace" }
        #expect(findReplace != nil)
        findReplace?.run()
        #expect(didShowFindReplace)

        let editMenuIDs = registry.menuCommands(path: .edit).map(\.id)
        #expect(editMenuIDs.contains("epdoc.findReplace"))
        #expect(editMenuIDs.contains("epdoc.aiDiffAccept"))
        #expect(editMenuIDs.contains("epdoc.aiDiffReject"))

        let acceptAIEdit = registry.matching(query: "accept ai edit", scope: .note).first { $0.id == "epdoc.aiDiffAccept" }
        #expect(acceptAIEdit != nil)
        acceptAIEdit?.run()
        #expect(captured.last == .acceptAIDiff)

        registry.deactivateNoteSurface(id: ObjectIdentifier(token))
        #expect(registry.matching(query: "bold", scope: .note).isEmpty)
    }

    @Test("Note utility surfaces expose find and save without enabling Epdoc formatting")
    func noteUtilitySurfaceExposesOnlyFindAndSaveCommands() {
        final class SurfaceToken {}

        let registry = CommandRegistry()
        CommandRegistrations.registerEpdocCommands(in: registry)
        let token = SurfaceToken()
        var didSave = false
        var didShowFind = false
        registry.activateNoteUtilitySurface(
            id: ObjectIdentifier(token),
            save: { didSave = true },
            showFindReplace: { didShowFind = true }
        )

        let commandIDs = registry.matching(query: "", scope: .note).map(\.id)
        #expect(commandIDs.contains("epdoc.save"))
        #expect(commandIDs.contains("epdoc.findReplace"))
        #expect(!commandIDs.contains("epdoc.bold"))
        #expect(!commandIDs.contains("epdoc.aiDiffAccept"))
        #expect(registry.menuCommands(path: .file).map(\.id) == ["epdoc.save"])
        #expect(registry.menuCommands(path: .edit).map(\.id) == ["epdoc.findReplace"])

        registry.matching(query: "save note", scope: .note).first { $0.id == "epdoc.save" }?.run()
        registry.matching(query: "find replace", scope: .note).first { $0.id == "epdoc.findReplace" }?.run()
        #expect(didSave)
        #expect(didShowFind)

        registry.deactivateNoteSurface(id: ObjectIdentifier(token))
        #expect(registry.matching(query: "save note", scope: .note).isEmpty)
    }

    @Test("Note utility activation refreshes when the workspace target changes")
    func noteUtilityActivationRefreshesWhenWorkspaceTargetChanges() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Notes/NoteWorkspaceCommandSurfaceActivation.swift")

        #expect(source.contains("let activationKey: String"))
        #expect(source.contains(".onChange(of: activationKey)"))
        #expect(source.contains("syncActivation(isKeyWindow: windowIsKey, surfaceIsActive: isActive)"))
    }

    @Test("Key-window observer publishes only real state changes")
    func keyWindowObserverPublishesOnlyRealStateChanges() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Command/CommandPaletteHost.swift")

        #expect(source.contains("lastPublishedKeyWindow"))
        #expect(source.contains("guard lastPublishedKeyWindow != isKeyWindow else { return }"))
    }

    @Test("Key-window observer defers callbacks outside SwiftUI updateNSView")
    func keyWindowObserverDefersCallbacksOutsideUpdateNSView() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Command/CommandPaletteHost.swift")

        #expect(source.contains("private func deliver(_ isKeyWindow: Bool)"))
        #expect(source.contains("Task { @MainActor [onChange] in"))
        #expect(!source.contains("onChange(isKeyWindow)\n        }"))
    }

    @Test("Epdoc command catalog is registered once outside activation hot paths")
    func epdocCommandCatalogIsRegisteredOutsideActivationHotPaths() throws {
        let registrySource = try loadMirroredSourceTextFile("Epistemos/Engine/CommandRegistry.swift")
        let registrationsSource = try loadMirroredSourceTextFile("Epistemos/Engine/CommandRegistrations.swift")
        let workspaceActivation = try loadMirroredSourceTextFile("Epistemos/Views/Notes/NoteWorkspaceCommandSurfaceActivation.swift")
        let editorActivation = try loadMirroredSourceTextFile("Epistemos/Views/Epdoc/EpdocCommandSurfaceActivation.swift")

        #expect(registrySource.contains("func containsCommand(id: String) -> Bool"))
        #expect(registrationsSource.contains("guard !registry.containsCommand(id: \"epdoc.save\") else { return }"))
        #expect(!workspaceActivation.contains("private func activate() {\n        CommandRegistrations.registerEpdocCommands()"))
        #expect(!editorActivation.contains("private func activate() {\n        CommandRegistrations.registerEpdocCommands()"))
    }

    @Test("Cmd+K is reserved only for the command palette")
    func commandKReservedForPalette() throws {
        let app = try loadMirroredSourceTextFile("Epistemos/App/EpistemosApp.swift")
        let paletteCommands = try loadMirroredSourceTextFile("Epistemos/Views/Command/CommandPaletteCommands.swift")
        let toolbar = try loadMirroredSourceTextFile("Epistemos/Views/Epdoc/EpdocEditorToolbar.swift")
        let bubbleMenu = try loadMirroredSourceTextFile("Epistemos/Views/Epdoc/EpdocBubbleMenuView.swift")

        #expect(app.contains("CommandPaletteCommands()"))
        #expect(paletteCommands.components(separatedBy: #"keyboardShortcut("k""#).count - 1 == 1)
        #expect(paletteCommands.contains(#"CommandRegistry.shared.showCommandPalette()"#))
        #expect(!toolbar.contains(#"shortcut: "⌘K""#))
        #expect(toolbar.contains(#"shortcut: "⌘⇧K""#))
        #expect(!bubbleMenu.contains("⌘K"))
        #expect(bubbleMenu.contains("⌘⇧K"))
    }

    private func command(
        id: String,
        title: String,
        scope: EpistemosCommandScope = .global,
        menuPath: EpistemosCommandMenuPath = .none,
        enabled: Bool = true
    ) -> EpistemosCommand {
        EpistemosCommand(
            id: id,
            title: title,
            symbol: "command",
            scope: scope,
            menuPath: menuPath,
            isEnabled: { enabled },
            run: {}
        )
    }
}
