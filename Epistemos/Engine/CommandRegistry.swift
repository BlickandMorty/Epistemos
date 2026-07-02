import SwiftUI

public enum EpistemosCommandScope: Sendable, Hashable, CaseIterable {
    case global
    case note
    case code
}

public enum EpistemosCommandMenuPath: Sendable, Hashable, CaseIterable {
    case file
    case edit
    case view
    case format
    case workspace
    case none
}

public struct EpistemosCommandShortcut: Sendable {
    public let key: Character
    public let modifiers: EventModifiers
    public let display: String

    public init(
        _ key: Character,
        modifiers: EventModifiers,
        display: String
    ) {
        self.key = key
        self.modifiers = modifiers
        self.display = display
    }

    public var keyboardShortcut: KeyboardShortcut {
        KeyboardShortcut(KeyEquivalent(key), modifiers: modifiers)
    }
}

public struct EpistemosCommandSurfaceState: Sendable, Hashable {
    public var isDirty: Bool
    public var isBoldActive: Bool
    public var isItalicActive: Bool
    public var isStrikeActive: Bool
    public var isCodeActive: Bool
    public var isHighlightActive: Bool
    public var activeHeadingLevel: Int?

    public init(
        isDirty: Bool = false,
        isBoldActive: Bool = false,
        isItalicActive: Bool = false,
        isStrikeActive: Bool = false,
        isCodeActive: Bool = false,
        isHighlightActive: Bool = false,
        activeHeadingLevel: Int? = nil
    ) {
        self.isDirty = isDirty
        self.isBoldActive = isBoldActive
        self.isItalicActive = isItalicActive
        self.isStrikeActive = isStrikeActive
        self.isCodeActive = isCodeActive
        self.isHighlightActive = isHighlightActive
        self.activeHeadingLevel = activeHeadingLevel
    }
}

public struct EpistemosCommand: Identifiable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let symbol: String
    public let shortcut: EpistemosCommandShortcut?
    public let scope: EpistemosCommandScope
    public let menuPath: EpistemosCommandMenuPath
    public let isEnabled: @MainActor () -> Bool
    public let run: @MainActor () -> Void

    public init(
        id: String,
        title: String,
        subtitle: String? = nil,
        symbol: String,
        shortcut: EpistemosCommandShortcut? = nil,
        scope: EpistemosCommandScope,
        menuPath: EpistemosCommandMenuPath = .none,
        isEnabled: @escaping @MainActor () -> Bool,
        run: @escaping @MainActor () -> Void
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.shortcut = shortcut
        self.scope = scope
        self.menuPath = menuPath
        self.isEnabled = isEnabled
        self.run = run
    }
}

@MainActor
@Observable
public final class CommandRegistry {
    public static let shared = CommandRegistry()

    public private(set) var activeScope: EpistemosCommandScope = .global
    public var isCommandPalettePresented = false

    private var commandStorage: [String: EpistemosCommand] = [:]
    private var commandOrder: [String] = []
    private var activeNoteSurfaceID: ObjectIdentifier?
    private var activeNoteDispatch: (@MainActor (EpdocEditorCommand) -> Void)?
    private var activeNoteSave: (@MainActor () -> Void)?
    private var activeNoteShowFindReplace: (@MainActor () -> Void)?
    private var activeNoteState: (@MainActor () -> EpistemosCommandSurfaceState)?

    public init() {}

    public var commands: [EpistemosCommand] {
        commandOrder.compactMap { commandStorage[$0] }
    }

    public var commandIDs: [String] {
        commandOrder
    }

    public func containsCommand(id: String) -> Bool {
        commandStorage[id] != nil
    }

    public func register(_ command: EpistemosCommand) {
        if commandStorage[command.id] == nil {
            commandOrder.append(command.id)
        }
        commandStorage[command.id] = command
    }

    public func unregisterAll() {
        commandStorage.removeAll(keepingCapacity: true)
        commandOrder.removeAll(keepingCapacity: true)
        resetActiveNoteSurface()
        isCommandPalettePresented = false
    }

    public func showCommandPalette() {
        isCommandPalettePresented = true
    }

    public func dismissCommandPalette() {
        isCommandPalettePresented = false
    }

    public func setActiveScope(_ scope: EpistemosCommandScope) {
        activeScope = scope
    }

    public func activateNoteSurface(
        id: ObjectIdentifier,
        dispatch: @escaping @MainActor (EpdocEditorCommand) -> Void,
        save: @escaping @MainActor () -> Void,
        showFindReplace: @escaping @MainActor () -> Void = {},
        state: @escaping @MainActor () -> EpistemosCommandSurfaceState
    ) {
        activeNoteSurfaceID = id
        activeNoteDispatch = dispatch
        activeNoteSave = save
        activeNoteShowFindReplace = showFindReplace
        activeNoteState = state
        activeScope = .note
    }

    public func activateNoteUtilitySurface(
        id: ObjectIdentifier,
        save: @escaping @MainActor () -> Void,
        showFindReplace: @escaping @MainActor () -> Void,
        state: @escaping @MainActor () -> EpistemosCommandSurfaceState = { EpistemosCommandSurfaceState() }
    ) {
        activeNoteSurfaceID = id
        activeNoteDispatch = nil
        activeNoteSave = save
        activeNoteShowFindReplace = showFindReplace
        activeNoteState = state
        activeScope = .note
    }

    public func deactivateNoteSurface(id: ObjectIdentifier) {
        guard activeNoteSurfaceID == id else { return }
        resetActiveNoteSurface()
    }

    public func hasActiveNoteSurface() -> Bool {
        activeScope == .note
            && (activeNoteDispatch != nil
                || activeNoteSave != nil
                || activeNoteShowFindReplace != nil)
    }

    public func hasActiveNoteEditorSurface() -> Bool {
        activeScope == .note && activeNoteDispatch != nil
    }

    public func activeNoteSurfaceState() -> EpistemosCommandSurfaceState {
        activeNoteState?() ?? EpistemosCommandSurfaceState()
    }

    public func dispatchActiveNote(_ command: EpdocEditorCommand) {
        activeNoteDispatch?(command)
    }

    public func saveActiveNote() {
        activeNoteSave?()
    }

    public func showFindReplaceForActiveNote() {
        activeNoteShowFindReplace?()
    }

    public func menuCommands(path: EpistemosCommandMenuPath) -> [EpistemosCommand] {
        commands.filter { $0.menuPath == path && $0.isEnabled() }
    }

    public func matching(
        query: String,
        scope requestedScope: EpistemosCommandScope? = nil
    ) -> [EpistemosCommand] {
        let resolvedScope = requestedScope ?? activeScope
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        let candidates = commands.filter { command in
            command.scope == .global || command.scope == resolvedScope
        }
        .filter { $0.isEnabled() }

        guard !trimmedQuery.isEmpty else { return candidates }

        return candidates
            .compactMap { command -> (EpistemosCommand, Int)? in
                guard let score = fuzzyScore(command: command, query: trimmedQuery) else {
                    return nil
                }
                return (command, score)
            }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return commandOrderIndex(lhs.0.id) < commandOrderIndex(rhs.0.id)
            }
            .map(\.0)
    }

    private func resetActiveNoteSurface() {
        activeNoteSurfaceID = nil
        activeNoteDispatch = nil
        activeNoteSave = nil
        activeNoteShowFindReplace = nil
        activeNoteState = nil
        activeScope = .global
    }

    private func commandOrderIndex(_ id: String) -> Int {
        commandOrder.firstIndex(of: id) ?? Int.max
    }

    private func fuzzyScore(command: EpistemosCommand, query: String) -> Int? {
        let haystacks = [
            command.title,
            command.subtitle,
            command.id,
        ].compactMap { $0?.lowercased() }
        let needle = query.lowercased()
        var best: Int?
        for haystack in haystacks {
            guard let baseScore = subsequenceScore(haystack: haystack, needle: needle) else {
                continue
            }
            let boundaryBonus = wordBoundaryBonus(haystack: haystack, needle: needle)
            let score = baseScore + boundaryBonus
            best = max(best ?? score, score)
        }
        return best
    }

    private func subsequenceScore(haystack: String, needle: String) -> Int? {
        guard !needle.isEmpty else { return 0 }
        var haystackIndex = haystack.startIndex
        var score = 0
        var streak = 0
        for character in needle {
            guard let matchIndex = haystack[haystackIndex...].firstIndex(of: character) else {
                return nil
            }
            if matchIndex == haystackIndex {
                streak += 1
                score += 8 + streak
            } else {
                streak = 0
                score += 3
            }
            haystackIndex = haystack.index(after: matchIndex)
        }
        if haystack.hasPrefix(needle) {
            score += 30
        }
        return score
    }

    private func wordBoundaryBonus(haystack: String, needle: String) -> Int {
        guard !needle.isEmpty else { return 0 }
        let separators = CharacterSet.alphanumerics.inverted
        let words = haystack.components(separatedBy: separators)
        if words.contains(where: { $0.hasPrefix(needle) }) {
            return 16
        }
        return 0
    }
}
