import AppKit
import Foundation
import Observation
import OSLog
import SwiftData
import SwiftUI
import UserNotifications

private let landingGreetingLog = Logger(subsystem: "com.epistemos", category: "LandingGreeting")

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
        // 2026-05-13 stacked-greeting refresh: the hero now renders the
        // "Greetings, / Researcher" two-line greeting permanently above
        // the rotating phrase rail, so the playlist must NOT lead with
        // the same string (that would re-type it underneath the hero
        // and read as a duplicate). The opening rail now leads with a
        // softer prompt that complements the hero instead of repeating
        // it.
        let opening: [LandingGreetingPhrase] = [
            LandingGreetingPhrase(text: "What's on your mind?", durationSeconds: 2.4),
        ]

        let instructions: [LandingGreetingPhrase] = [
            LandingGreetingPhrase(text: "click anywhere to start a conversation", durationSeconds: 2.6),
            LandingGreetingPhrase(text: "attach a note to your chat for deeper context", durationSeconds: 3.0),
            LandingGreetingPhrase(text: "chat with notes, or even chat about old chats...", durationSeconds: 3.2),
        ]

        let tips: [LandingGreetingPhrase] = [
            LandingGreetingPhrase(text: "\u{2318}G opens the knowledge graph", durationSeconds: 2.6),
            LandingGreetingPhrase(text: "^\u{2318}R — Session Intelligence reads every open window", durationSeconds: 3.2),
            LandingGreetingPhrase(text: "^\u{2318}T — Time Machine lets you revisit any past session", durationSeconds: 3.2),
            LandingGreetingPhrase(text: "^\u{2318}S saves your workspace layout for later", durationSeconds: 3.0),
            LandingGreetingPhrase(text: "wikilinks connect ideas — type [[note name]] anywhere", durationSeconds: 3.0),
            LandingGreetingPhrase(text: "AI runs entirely on-device — your data never leaves this Mac", durationSeconds: 3.2),
            LandingGreetingPhrase(text: "your vault syncs to plain markdown — portable, forever yours", durationSeconds: 3.2),
            LandingGreetingPhrase(text: "right-click in the editor for AI rewriting tools", durationSeconds: 2.8),
            LandingGreetingPhrase(text: "daily briefs summarize recent notes and conversations", durationSeconds: 3.2),
        ]

        return opening + instructions + tips
    }()

    /// Cached note insights — computed once, stable across re-renders.
    /// Prevents playlist signature from changing every SwiftUI evaluation cycle.
    private static var _cachedInsights: [LandingGreetingPhrase]?
    @MainActor
    static var cachedNoteInsights: [LandingGreetingPhrase] {
        if let cached = _cachedInsights { return cached }
        let insights = noteInsights()
        _cachedInsights = insights
        return insights
    }

    /// Extracts short insights from note titles in the vault. Runs on cached SwiftData
    /// titles only — never scans note bodies. Called once at launch, costs ~0ms.
    @MainActor
    private static func noteInsights() -> [LandingGreetingPhrase] {
        guard let bootstrap = AppBootstrap.shared else { return [] }
        let context = bootstrap.modelContainer.mainContext

        // Fetch note titles only (no body loading — the key optimization)
        var descriptor = FetchDescriptor<SDPage>(
            sortBy: [SortDescriptor(\SDPage.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 20
        let pages: [SDPage]
        do {
            pages = try context.fetch(descriptor)
        } catch {
            landingGreetingLog.error(
                "LandingGreetingResolver: failed to fetch recent pages: \(error.localizedDescription, privacy: .public)"
            )
            return []
        }
        guard !pages.isEmpty else { return [] }

        var insights: [LandingGreetingPhrase] = []

        // Recent work reminder
        if let recent = pages.first {
            let title = recent.title.isEmpty ? "Untitled" : recent.title
            insights.append(LandingGreetingPhrase(
                text: "you were last working on \"\(title)\"",
                durationSeconds: 3.0
            ))
        }

        // Note count milestone
        let count = pages.count
        if count >= 5 {
            insights.append(LandingGreetingPhrase(
                text: "your vault holds \(count) notes — a growing body of knowledge",
                durationSeconds: 3.2
            ))
        }

        // Pick 2-3 random note titles as "things you've explored"
        let shuffled = pages.filter { !$0.title.isEmpty }.shuffled().prefix(3)
        for page in shuffled {
            let title = page.title
            let phrases = [
                "remember \"\(title)\"? what if you revisited it",
                "your note \"\(title)\" might connect to something new",
                "\"\(title)\" — still curious about this?",
            ]
            if let phrase = phrases.randomElement() {
                insights.append(LandingGreetingPhrase(text: phrase, durationSeconds: 3.4))
            }
        }

        // Workspace summary insight (already cached — zero cost)
        do {
            if let ws = try context.fetch(
                FetchDescriptor<SDWorkspace>(predicate: #Predicate<SDWorkspace> { $0.isAutoSave == true })
            ).first, !ws.summary.isEmpty, ws.summary.count < 120 {
                insights.append(LandingGreetingPhrase(
                    text: ws.summary.lowercased(),
                    durationSeconds: 3.6
                ))
            }
        } catch {
            landingGreetingLog.error(
                "LandingGreetingResolver: failed to fetch workspace summary: \(error.localizedDescription, privacy: .public)"
            )
        }

        return insights
    }

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
            resolved = defaultPlaylist + cachedNoteInsights
        case .mixed:
            resolved = defaultPlaylist + cachedNoteInsights + customPlaylist
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
    private static let log = Logger(subsystem: "com.epistemos", category: "UIState")

    // MARK: - Theme

    static let themePairDefaultsKey = "epistemos.theme.pair"

    private var isNormalizingLandingGreetingLibrary = false

    var themeMode: ThemeMode = .custom {
        didSet {
            UserDefaults.standard.set(themeMode.rawValue, forKey: ThemeMode.defaultsKey)
        }
    }

    /// The active theme pair. Drives both light and dark rendering.
    var activePair: ThemePair = .platinumViolet {
        didSet {
            UserDefaults.standard.set(activePair.rawValue, forKey: Self.themePairDefaultsKey)
        }
    }

    /// Current system dark-mode state. Set by RootView via NSApp.effectiveAppearance observer.
    var isSystemDark: Bool = false

    /// The resolved theme for the current system mode — read this everywhere.
    var theme: EpistemosTheme {
        switch themeMode {
        case .systemDefault:
            isSystemDark ? .systemDark : .systemLight
        case .custom:
            activePair.resolved(isDark: isSystemDark)
        }
    }

    var customThemesEnabled: Bool { themeMode == .custom }
    var preferredColorScheme: ColorScheme? { nil }
    var shouldUseThemeWorkarounds: Bool { false }
    var windowAppearance: NSAppearance? { nil }

    // MARK: - Transparency

    /// Always reduced transparency — opaque adaptive backgrounds everywhere.
    var effectiveReduceTransparency: Bool { true }

    var usesNativeWindowBlur: Bool { false }
    var wallpaperBackground: Color { Color(nsColor: .windowBackgroundColor) }
    var windowBackgroundColor: NSColor {
        effectiveReduceTransparency ? .windowBackgroundColor : .clear
    }
    var contentBackground: Color {
        effectiveReduceTransparency ? Color(nsColor: .windowBackgroundColor) : .clear
    }
    var notesSidebarBackgroundColor: NSColor {
        .clear
    }
    var notesSidebarBackground: Color {
        .clear
    }
    var overlayChromeBackground: Color {
        Color(nsColor: .underPageBackgroundColor)
    }
    var graphOverlayTheme: EpistemosTheme {
        theme
    }
    var appearanceSyncKey: String {
        "\(themeMode.rawValue):\(activePair.rawValue):\(isSystemDark ? 1 : 0)"
    }

    var readableFontsEnabled: Bool = false {
        didSet {
            AppDisplayTypography.setReadableFontsEnabled(readableFontsEnabled)
        }
    }

    // MARK: - Setup

    /// When true, the app shows the setup/welcome screen after a full reset.
    /// Cleared when the user taps "Get Started" in the setup view.
    var needsSetup = false

    // MARK: - Navigation

    var activePanel: NavTab = .home
    var homeTab: HomeTab = .home

    // MARK: - Home Content Router (Phase 1 — embed-in-home graph)
    //
    // When `homeContent == .greeting` (default), the home window shows
    // the existing LiquidGreeting + command-hint dock. When the user
    // presses Cmd+G AND `GraphState.graphViewLocation == .embedded`,
    // this flips to `.graph` and LandingView cross-fades the greeting
    // out + the embedded graph in (HomeGraphEmbeddedView, with the
    // full graph chrome — canvas, workspace routes, sidebar, inspector,
    // floating controls, FPS HUD).
    //
    // Always resets to `.greeting` on app launch. The home window
    // never persists the embedded-graph state across restarts — the
    // greeting is the canonical "home." Toggle is session-only.
    enum HomeContent: Equatable, Sendable {
        case greeting
        case graph
    }

    var homeContent: HomeContent = .greeting

    // MARK: - Chat Sidebar

    var showChatSidebar = false

    // MARK: - Window Visibility
    /// True when the main window is minimized to the Dock.
    /// Animations (starfield, typewriter) should pause when this is true to save CPU.
    var windowOccluded = false

    // MARK: - Shaped Graph (experimental)
    //
    // Per user direction 2026-05-19: opt-in alternative graph rendering
    // where the graph canvas + inline note view live inside a soft
    // shape-blur boundary instead of an obvious window. Toggle only —
    // the current graph view is the default and stays unchanged when
    // this is off. Default-value is the literal `false` so the @Observable
    // synthesized init never reads UserDefaults during property layout
    // (which was tripping "invalid reuse after initialization failure"
    // in some run paths); the live value is restored in `init()` via
    // `restoreShapedGraphExperimental()`.
    nonisolated static let shapedGraphExperimentalDefaultsKey = "epistemos.graph.shapedExperimental"

    var shapedGraphExperimental: Bool = false {
        didSet {
            UserDefaults.standard.set(
                shapedGraphExperimental,
                forKey: UIState.shapedGraphExperimentalDefaultsKey
            )
        }
    }

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
        restoreThemeDefaults()
        clearLegacyLandingGreetingDefaults()
        readableFontsEnabled = AppDisplayTypography.readableFontsEnabled()
        // Shaped Graph experimental — read after baseline storage is up.
        // didSet writes back to UserDefaults, but we set the in-memory flag
        // directly here to avoid an unnecessary echo write on every launch.
        shapedGraphExperimental = UserDefaults.standard.bool(
            forKey: UIState.shapedGraphExperimentalDefaultsKey
        )
        if let storedGreetingSourceMode = UserDefaults.standard.string(
            forKey: LandingGreetingLibraryPolicy.sourceModeDefaultsKey
        ),
            let sourceMode = LandingGreetingSourceMode(rawValue: storedGreetingSourceMode) {
            landingGreetingSourceMode = sourceMode
        }
        if let storedGreetings = UserDefaults.standard.data(
            forKey: LandingGreetingLibraryPolicy.customGreetingsDefaultsKey
        ) {
            do {
                landingCustomGreetings = try JSONDecoder().decode(
                    [LandingGreetingEntry].self,
                    from: storedGreetings
                )
            } catch {
                Self.log.error(
                    "UIState: failed to decode custom landing greetings: \(error.localizedDescription, privacy: .public)"
                )
                UserDefaults.standard.removeObject(
                    forKey: LandingGreetingLibraryPolicy.customGreetingsDefaultsKey
                )
            }
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

    private func restoreThemeDefaults() {
        let defaults = UserDefaults.standard
        if let rawMode = defaults.string(forKey: ThemeMode.defaultsKey),
            let storedMode = ThemeMode(rawValue: rawMode) {
            themeMode = storedMode == .systemDefault ? .custom : storedMode
        } else {
            defaults.removeObject(forKey: ThemeMode.defaultsKey)
            themeMode = .custom
        }

        if let rawPair = defaults.string(forKey: Self.themePairDefaultsKey),
            let storedPair = ThemePair(rawValue: rawPair) {
            activePair = storedPair
        } else {
            defaults.removeObject(forKey: Self.themePairDefaultsKey)
            activePair = .platinumViolet
        }
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

    func setPair(_ pair: ThemePair) {
        activePair = pair
    }

    func setThemeMode(_ mode: ThemeMode) {
        themeMode = mode
    }

    func setCustomThemesEnabled(_ enabled: Bool) {
        themeMode = enabled ? .custom : .systemDefault
    }

    func setReadableFontsEnabled(_ enabled: Bool) {
        readableFontsEnabled = enabled
    }

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
            do {
                try await Task.sleep(for: .seconds(type == .error ? 5 : 3))
            } catch is CancellationError {
                return
            } catch {
                Self.log.error(
                    "UIState: toast dismissal sleep failed: \(error.localizedDescription, privacy: .public)"
                )
                return
            }
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

        let encodedGreetings: Data
        do {
            encodedGreetings = try JSONEncoder().encode(landingCustomGreetings)
        } catch {
            Self.log.error(
                "UIState: failed to encode custom landing greetings: \(error.localizedDescription, privacy: .public)"
            )
            return
        }
        UserDefaults.standard.set(
            encodedGreetings,
            forKey: LandingGreetingLibraryPolicy.customGreetingsDefaultsKey
        )
    }
}
