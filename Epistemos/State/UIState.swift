import AppKit
import Foundation
import Observation
import SwiftUI
import UserNotifications

enum LandingGreetingSourceMode: String, CaseIterable, Codable, Sendable {
    case defaultsOnly
    case mixed
    case customOnly

    static let defaultValue: Self = .defaultsOnly

    var title: String {
        switch self {
        case .defaultsOnly: "Defaults Only"
        case .mixed: "Defaults + Custom"
        case .customOnly: "Custom Only"
        }
    }

    var detail: String {
        switch self {
        case .defaultsOnly: "Keep the built-in greeting rotation."
        case .mixed: "Play the built-in greetings first, then your custom phrases."
        case .customOnly: "Use only your greeting library. Falls back to defaults if empty."
        }
    }
}

enum LandingGreetingLibraryPolicy {
    static let sourceModeDefaultsKey = "epistemos.landingGreetingSourceMode"
    static let customGreetingsDefaultsKey = "epistemos.landingCustomGreetings"
}

struct LandingGreetingEntry: Identifiable, Codable, Equatable, Sendable {
    static let minimumDurationSeconds = 1.2
    static let maximumDurationSeconds = 12.0
    static let defaultDurationSeconds = 2.8

    let id: UUID
    var text: String
    var durationSeconds: Double
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        text: String,
        durationSeconds: Double = LandingGreetingEntry.defaultDurationSeconds,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.text = text
        self.durationSeconds = Self.clampedDuration(durationSeconds)
        self.isEnabled = isEnabled
    }

    var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func clampedDuration(_ value: Double) -> Double {
        guard value.isFinite else { return defaultDurationSeconds }
        return min(max(value, minimumDurationSeconds), maximumDurationSeconds)
    }
}

struct LandingGreetingPhrase: Equatable, Sendable {
    let text: String
    let durationSeconds: Double
}

enum LandingGreetingResolver {
    static let defaultPlaylist: [LandingGreetingPhrase] = {
        // Title greetings — cycle through personas.
        let titles: [LandingGreetingPhrase] = [
            LandingGreetingPhrase(text: LiquidGreeting.restingGreeting, durationSeconds: 2.8),
            LandingGreetingPhrase(text: "Greetings, Researcher", durationSeconds: 2.4),
            LandingGreetingPhrase(text: "Greetings, Student", durationSeconds: 2.4),
            LandingGreetingPhrase(text: "Greetings, Engineer??", durationSeconds: 2.6),
        ]

        // Instructional phrases.
        let instructions: [LandingGreetingPhrase] = [
            LandingGreetingPhrase(text: "click anywhere to chat", durationSeconds: 2.6),
            LandingGreetingPhrase(text: "chat with notes, maybe an old chat", durationSeconds: 3.0),
            LandingGreetingPhrase(text: "you can literally ask me to chat about other chats...", durationSeconds: 3.2),
        ]

        // Fun facts about Epistemos — things users might not know.
        let facts: [LandingGreetingPhrase] = [
            LandingGreetingPhrase(text: "your notes are embedded into vectors for semantic search", durationSeconds: 3.4),
            LandingGreetingPhrase(text: "the graph runs on a Rust physics engine at 120fps", durationSeconds: 3.2),
            LandingGreetingPhrase(text: "try attaching a note to your chat for context-aware answers", durationSeconds: 3.4),
            LandingGreetingPhrase(text: "Cmd+G opens the knowledge graph — your ideas visualized", durationSeconds: 3.2),
            LandingGreetingPhrase(text: "AI runs entirely on-device — your data never leaves your Mac", durationSeconds: 3.4),
            LandingGreetingPhrase(text: "right-click a graph node to open the note directly", durationSeconds: 3.0),
            LandingGreetingPhrase(text: "wikilinks connect your notes — type [[note name]] anywhere", durationSeconds: 3.2),
            LandingGreetingPhrase(text: "block references let you embed paragraphs across notes", durationSeconds: 3.2),
            LandingGreetingPhrase(text: "your vault syncs to markdown files — portable, forever yours", durationSeconds: 3.4),
            LandingGreetingPhrase(text: "the AI can analyze connections between your notes automatically", durationSeconds: 3.4),
            LandingGreetingPhrase(text: "try asking me to summarize, expand, or restructure your writing", durationSeconds: 3.4),
            LandingGreetingPhrase(text: "shift-click a graph node to highlight its neighborhood", durationSeconds: 3.0),
            LandingGreetingPhrase(text: "save your window layout as a workspace — Ctrl+\u{2318}S to save, Ctrl+\u{2318}W to switch", durationSeconds: 3.6),
            LandingGreetingPhrase(text: "workspaces remember your open notes, chats, and even cursor positions", durationSeconds: 3.4),
            LandingGreetingPhrase(text: "Ctrl+\u{2318}R shows what you're working on — AI reads every open window", durationSeconds: 3.4),
            LandingGreetingPhrase(text: "Ctrl+\u{2318}T opens the time machine — go back to any past session", durationSeconds: 3.2),
            LandingGreetingPhrase(text: "every session is permanently logged — you'll never lose your work history", durationSeconds: 3.4),
            LandingGreetingPhrase(text: "the app tracks paragraph-level changes to understand what you're editing", durationSeconds: 3.4),
            LandingGreetingPhrase(text: "AI summaries use Map-Reduce — each window summarized, then synthesized", durationSeconds: 3.4),
            LandingGreetingPhrase(text: "on quit, you can name your workspace and leave yourself a note", durationSeconds: 3.2),
            LandingGreetingPhrase(text: "the time machine diffs your entire knowledge base — notes, chats, graph", durationSeconds: 3.4),
            LandingGreetingPhrase(text: "restore any past session as a new workspace — non-destructive time travel", durationSeconds: 3.4),
            LandingGreetingPhrase(text: "Chat with Chat lets you reference past conversations as context", durationSeconds: 3.2),
            LandingGreetingPhrase(text: "session history uses a dedicated SQLite database — never slows down your notes", durationSeconds: 3.4),
        ]

        return titles + instructions + facts
    }()

    static func resolve(
        sourceMode: LandingGreetingSourceMode,
        customGreetings: [LandingGreetingEntry]
    ) -> [LandingGreetingPhrase] {
        let customPlaylist = customGreetings.compactMap { greeting -> LandingGreetingPhrase? in
            guard greeting.isEnabled else { return nil }
            let trimmedText = greeting.trimmedText
            guard !trimmedText.isEmpty else { return nil }
            return LandingGreetingPhrase(
                text: trimmedText,
                durationSeconds: LandingGreetingEntry.clampedDuration(greeting.durationSeconds)
            )
        }

        let resolved: [LandingGreetingPhrase]
        switch sourceMode {
        case .defaultsOnly:
            resolved = defaultPlaylist
        case .mixed:
            resolved = defaultPlaylist + customPlaylist
        case .customOnly:
            resolved = customPlaylist
        }

        return resolved.isEmpty ? defaultPlaylist : resolved
    }

    static func signature(for playlist: [LandingGreetingPhrase]) -> String {
        playlist
            .map { "\($0.text)|\($0.durationSeconds)" }
            .joined(separator: "•")
    }
}

enum ThemeMode: String, CaseIterable, Codable, Sendable {
    static let defaultsKey = "epistemos.theme.mode"

    case systemDefault = "systemDefault"
    case custom = "custom"
}

enum LandingGreetingAnimationPolicy {
    static let enabledDefaultsKey = "epistemos.landingGreetingAnimationEnabled"
    static let typewriterEnabledDefaultsKey = "epistemos.landingGreetingTypewriterEffectEnabled"
    static let defaultTypewriterEnabled = true
}

// MARK: - UI State
// Ephemeral UI state only — no persistent data arrays.
// Theme pair, navigation, breathe mode, toast, window visibility.

@MainActor @Observable
final class UIState {
    // MARK: - Theme

    static let themePairDefaultsKey = "epistemos.theme.pair"

    private var isEnforcingSystemAppearance = false
    private var isNormalizingLandingGreetingLibrary = false

    var themeMode: ThemeMode = .systemDefault {
        didSet {
            enforceSystemAppearance()
        }
    }

    /// The active theme pair. Drives both light and dark rendering.
    var activePair: ThemePair = .classic {
        didSet {
            enforceSystemAppearance()
        }
    }

    /// Current system dark-mode state. Set by RootView via NSApp.effectiveAppearance observer.
    var isSystemDark: Bool = false

    /// The resolved theme for the current system mode — read this everywhere.
    var theme: EpistemosTheme {
        isSystemDark ? .systemDark : .systemLight
    }

    var customThemesEnabled: Bool { false }
    var preferredColorScheme: ColorScheme? { nil }
    var shouldUseThemeWorkarounds: Bool { false }
    var windowAppearance: NSAppearance? { nil }
    var usesNativeWindowBlur: Bool { true }
    var wallpaperBackground: Color { Color(nsColor: .windowBackgroundColor) }
    var windowBackgroundColor: NSColor {
        .clear
    }
    var contentBackground: Color { Color(nsColor: .textBackgroundColor) }
    var notesSidebarBackgroundColor: NSColor {
        .textBackgroundColor
    }
    var notesSidebarBackground: Color {
        Color(nsColor: notesSidebarBackgroundColor)
    }
    var overlayChromeBackground: Color {
        Color(nsColor: .underPageBackgroundColor)
    }
    var graphOverlayTheme: EpistemosTheme {
        theme
    }
    var appearanceSyncKey: String {
        "systemDefault:classic:\(isSystemDark ? 1 : 0)"
    }

    var displayMode: AppDisplayMode = .opulent {
        didSet {
            UserDefaults.standard.set(displayMode.rawValue, forKey: AppDisplayMode.defaultsKey)
        }
    }

    // MARK: - Setup

    /// When true, the app shows the setup/welcome screen after a full reset.
    /// Cleared when the user taps "Get Started" in the setup view.
    var needsSetup = false

    // MARK: - Navigation

    var activePanel: NavTab = .home
    var homeTab: HomeTab = .home

    // MARK: - Chat Sidebar

    var showChatSidebar = false

    // MARK: - Window Visibility
    /// True when the main window is minimized to the Dock.
    /// Animations (starfield, typewriter) should pause when this is true to save CPU.
    var windowOccluded = false

    // MARK: - Landing Animation

    var landingGreetingTypewriterEnabled = LandingGreetingAnimationPolicy.defaultTypewriterEnabled {
        didSet {
            UserDefaults.standard.set(
                landingGreetingTypewriterEnabled,
                forKey: LandingGreetingAnimationPolicy.typewriterEnabledDefaultsKey
            )
            persistLegacyLandingGreetingAnimationToggle()
        }
    }

    var landingGreetingSourceMode = LandingGreetingSourceMode.defaultValue {
        didSet {
            UserDefaults.standard.set(
                landingGreetingSourceMode.rawValue,
                forKey: LandingGreetingLibraryPolicy.sourceModeDefaultsKey
            )
        }
    }

    var landingCustomGreetings: [LandingGreetingEntry] = [] {
        didSet {
            normalizeLandingGreetingLibrary()
        }
    }

    var resolvedLandingGreetingPlaylist: [LandingGreetingPhrase] {
        LandingGreetingResolver.resolve(
            sourceMode: landingGreetingSourceMode,
            customGreetings: landingCustomGreetings
        )
    }

    var landingGreetingPlaylistSignature: String {
        LandingGreetingResolver.signature(for: resolvedLandingGreetingPlaylist)
    }

    // MARK: - Toast

    var toastMessage: String?
    var toastType: ToastType = .info
    private var toastDismissTask: Task<Void, Never>?

    // MARK: - Init

    init() {
        isSystemDark = SystemAppearanceState.isDark()
        clearLegacyThemeDefaults()
        clearLegacyLandingGreetingDefaults()
        displayMode = AppDisplayMode.current()
        if let storedGreetingSourceMode = UserDefaults.standard.string(
            forKey: LandingGreetingLibraryPolicy.sourceModeDefaultsKey
        ),
            let sourceMode = LandingGreetingSourceMode(rawValue: storedGreetingSourceMode) {
            landingGreetingSourceMode = sourceMode
        }
        if let storedGreetings = UserDefaults.standard.data(
            forKey: LandingGreetingLibraryPolicy.customGreetingsDefaultsKey
        ),
            let decodedGreetings = try? JSONDecoder().decode(
                [LandingGreetingEntry].self,
                from: storedGreetings
            ) {
            landingCustomGreetings = decodedGreetings
        }
        let legacyGreetingAnimationEnabled: Bool? = if UserDefaults.standard.object(
            forKey: LandingGreetingAnimationPolicy.enabledDefaultsKey
        ) != nil {
            UserDefaults.standard.bool(forKey: LandingGreetingAnimationPolicy.enabledDefaultsKey)
        } else {
            nil
        }

        if UserDefaults.standard.object(
            forKey: LandingGreetingAnimationPolicy.typewriterEnabledDefaultsKey
        ) != nil {
            landingGreetingTypewriterEnabled = UserDefaults.standard.bool(
                forKey: LandingGreetingAnimationPolicy.typewriterEnabledDefaultsKey
            )
        } else if let legacyGreetingAnimationEnabled {
            landingGreetingTypewriterEnabled = legacyGreetingAnimationEnabled
        }
        normalizeLandingGreetingLibrary()
    }

    // MARK: - Theme Methods

    private func clearLegacyThemeDefaults() {
        UserDefaults.standard.removeObject(forKey: ThemeMode.defaultsKey)
        UserDefaults.standard.removeObject(forKey: Self.themePairDefaultsKey)
    }

    private func clearLegacyLandingGreetingDefaults() {
        let legacyKeys = [
            "epistemos.landingCursorAnimationEnabled",
            "epistemos.landingCursorVisibilityMode",
            "epistemos.landingCursorResponse",
            "epistemos.landingCursorSpread",
            "epistemos.landingCursorTrail",
            "epistemos.landingCursorViscosity",
            "epistemos.landingCursorTurbulence",
            "epistemos.landingCursorBlastPower",
            "epistemos.landingCursorOpacity",
            "epistemos.landingCursorBlur",
            "epistemos.landingGreetingASCIIEnabled",
            "epistemos.landingGreetingTypewriterEnabled",
            "epistemos.landingGreetingASCIIHoverEnabled",
            "epistemos.landingGreetingTypewriterVersion",
            "epistemos.landingGreetingIntensity",
            "epistemos.landingGreetingVariety",
            "epistemos.landingGreetingPace",
            "epistemos.landingGreetingLiquidEffectEnabled",
            "epistemos.landingGreetingThreshold",
            "epistemos.landingGreetingBlur",
            "epistemos.landingGreetingPull",
            "epistemos.landingGreetingExpansion",
            "epistemos.landingGreetingCenterSoftening",
            "epistemos.landingGreetingPullRadius",
            "epistemos.landingGreetingDamping",
            "epistemos.landingGreetingScale",
        ]
        for key in legacyKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private func persistLegacyLandingGreetingAnimationToggle() {
        UserDefaults.standard.set(
            landingGreetingTypewriterEnabled,
            forKey: LandingGreetingAnimationPolicy.enabledDefaultsKey
        )
    }

    private func enforceSystemAppearance() {
        guard !isEnforcingSystemAppearance else {
            clearLegacyThemeDefaults()
            return
        }

        isEnforcingSystemAppearance = true
        if themeMode != .systemDefault {
            themeMode = .systemDefault
        }
        if activePair != .classic {
            activePair = .classic
        }
        clearLegacyThemeDefaults()
        isEnforcingSystemAppearance = false
    }

    func setPair(_ pair: ThemePair) {
        _ = pair
        enforceSystemAppearance()
    }

    func setThemeMode(_ mode: ThemeMode) {
        _ = mode
        enforceSystemAppearance()
    }

    func setCustomThemesEnabled(_ enabled: Bool) {
        _ = enabled
        enforceSystemAppearance()
    }

    func setDisplayMode(_ mode: AppDisplayMode) { displayMode = mode }

    // MARK: - Navigation Methods

    func setActivePanel(_ tab: NavTab) {
        activePanel = tab
    }

    // MARK: - Chat Sidebar Methods

    func toggleChatSidebar() {
        showChatSidebar.toggle()
    }

    func dismissChatSidebar() {
        showChatSidebar = false
    }

    func addLandingGreeting() {
        landingCustomGreetings.append(
            LandingGreetingEntry(text: "", durationSeconds: LandingGreetingEntry.defaultDurationSeconds)
        )
    }

    func updateLandingGreetingText(id: UUID, text: String) {
        guard let index = landingCustomGreetings.firstIndex(where: { $0.id == id }) else { return }
        landingCustomGreetings[index].text = text
    }

    func updateLandingGreetingDuration(id: UUID, durationSeconds: Double) {
        guard let index = landingCustomGreetings.firstIndex(where: { $0.id == id }) else { return }
        landingCustomGreetings[index].durationSeconds = LandingGreetingEntry.clampedDuration(
            durationSeconds
        )
    }

    func updateLandingGreetingEnabled(id: UUID, isEnabled: Bool) {
        guard let index = landingCustomGreetings.firstIndex(where: { $0.id == id }) else { return }
        landingCustomGreetings[index].isEnabled = isEnabled
    }

    func moveLandingGreeting(id: UUID, by offset: Int) {
        guard let index = landingCustomGreetings.firstIndex(where: { $0.id == id }) else { return }
        let destination = index + offset
        guard landingCustomGreetings.indices.contains(destination) else { return }
        let greeting = landingCustomGreetings.remove(at: index)
        landingCustomGreetings.insert(greeting, at: destination)
    }

    func removeLandingGreeting(id: UUID) {
        landingCustomGreetings.removeAll { $0.id == id }
    }

    // MARK: - Toast Methods

    func showToast(_ message: String, type: ToastType = .info) {
        toastDismissTask?.cancel()
        toastMessage = message
        toastType = type
        toastDismissTask = Task {
            try? await Task.sleep(for: .seconds(type == .error ? 5 : 3))
            guard !Task.isCancelled else { return }
            self.toastMessage = nil
        }
    }

    func dismissToast() {
        toastDismissTask?.cancel()
        toastDismissTask = nil
        toastMessage = nil
    }

    private func normalizeLandingGreetingLibrary() {
        let normalizedGreetings = landingCustomGreetings.map { greeting in
            var normalizedGreeting = greeting
            normalizedGreeting.durationSeconds = LandingGreetingEntry.clampedDuration(
                greeting.durationSeconds
            )
            return normalizedGreeting
        }

        if !isNormalizingLandingGreetingLibrary && normalizedGreetings != landingCustomGreetings {
            isNormalizingLandingGreetingLibrary = true
            landingCustomGreetings = normalizedGreetings
            isNormalizingLandingGreetingLibrary = false
            return
        }

        guard let encodedGreetings = try? JSONEncoder().encode(landingCustomGreetings) else {
            UserDefaults.standard.removeObject(
                forKey: LandingGreetingLibraryPolicy.customGreetingsDefaultsKey
            )
            return
        }
        UserDefaults.standard.set(
            encodedGreetings,
            forKey: LandingGreetingLibraryPolicy.customGreetingsDefaultsKey
        )
    }
}
