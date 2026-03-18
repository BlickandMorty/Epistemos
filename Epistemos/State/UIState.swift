import AppKit
import Foundation
import Observation
import SwiftUI
import UserNotifications

enum LandingCursorSurface: String, CaseIterable, Codable, Sendable {
    case landing
    case search
}

enum LandingCursorVisibilityMode: String, CaseIterable, Codable, Sendable {
    case landingOnly
    case searchOnly
    case both
    case neither

    static let defaultValue: Self = .both

    func shows(on surface: LandingCursorSurface) -> Bool {
        switch (self, surface) {
        case (.landingOnly, .landing), (.searchOnly, .search), (.both, _):
            true
        case (.landingOnly, .search), (.searchOnly, .landing), (.neither, _):
            false
        }
    }

    var title: String {
        switch self {
        case .landingOnly: "Landing Only"
        case .searchOnly: "Search Only"
        case .both: "Both"
        case .neither: "Neither"
        }
    }

    var detail: String {
        switch self {
        case .landingOnly: "Show the wake field on the greeting screen only."
        case .searchOnly: "Show the wake field only behind the landing search composer."
        case .both: "Keep the wake field visible on both landing surfaces."
        case .neither: "Disable the wake field everywhere on the landing experience."
        }
    }
}

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
    static let defaultPlaylist: [LandingGreetingPhrase] = [
        LandingGreetingPhrase(text: LiquidGreeting.restingGreeting, durationSeconds: 2.8),
        LandingGreetingPhrase(text: "Greetings, Researcher", durationSeconds: 3.0),
        LandingGreetingPhrase(text: "Sup, Brainiac!", durationSeconds: 2.6),
        LandingGreetingPhrase(text: "click me to search…", durationSeconds: 2.4),
    ]

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

enum LandingCursorAnimationPolicy {
    static let defaultsKey = "epistemos.landingCursorAnimationEnabled"
    static let defaultValue = true
}

enum LandingGreetingAnimationPolicy {
    static let enabledDefaultsKey = "epistemos.landingGreetingAnimationEnabled"
    static let typewriterEnabledDefaultsKey = "epistemos.landingGreetingTypewriterEffectEnabled"
    static let defaultTypewriterEnabled = true
}

enum LandingWakeFieldPolicy {
    static let visibilityModeDefaultsKey = "epistemos.landingCursorVisibilityMode"
    static let responseDefaultsKey = "epistemos.landingCursorResponse"
    static let spreadDefaultsKey = "epistemos.landingCursorSpread"
    static let trailDefaultsKey = "epistemos.landingCursorTrail"
    static let viscosityDefaultsKey = "epistemos.landingCursorViscosity"
    static let turbulenceDefaultsKey = "epistemos.landingCursorTurbulence"
    static let blastPowerDefaultsKey = "epistemos.landingCursorBlastPower"
    static let opacityDefaultsKey = "epistemos.landingCursorOpacity"
    static let blurDefaultsKey = "epistemos.landingCursorBlur"

    static let defaultResponse = 0.56
    static let defaultSpread = 0.6
    static let defaultTrail = 0.62
    static let defaultViscosity = 0.8
    static let defaultTurbulence = 0.5
    static let defaultBlastPower = 50.0
    static let defaultOpacity = 1.0
    static let defaultBlur = 0.5
}

// MARK: - UI State
// Ephemeral UI state only — no persistent data arrays.
// Theme pair, navigation, command palette, breathe mode, toast, window visibility.

@MainActor @Observable
final class UIState {
    // MARK: - Theme

    static let themePairDefaultsKey = "epistemos.theme.pair"

    private var isEnforcingSystemAppearance = false
    private var isSyncingLandingCursorPreferences = false
    private var isNormalizingLandingGreetingLibrary = false
    private var lastEnabledLandingCursorVisibilityMode = LandingCursorVisibilityMode.defaultValue

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

    // MARK: - Command Palette

    /// Global command palette overlay — visible from any panel via Option+Space.
    var isCommandPaletteVisible = false

    // MARK: - Window Visibility
    /// True when the main window is minimized to the Dock.
    /// Animations (starfield, typewriter) should pause when this is true to save CPU.
    var windowOccluded = false

    // MARK: - Landing Animation

    var landingCursorAnimationEnabled = LandingCursorAnimationPolicy.defaultValue {
        didSet {
            UserDefaults.standard.set(
                landingCursorAnimationEnabled,
                forKey: LandingCursorAnimationPolicy.defaultsKey
            )
            syncLandingCursorVisibilityModeFromLegacyToggle()
        }
    }

    var landingCursorVisibilityMode = LandingCursorVisibilityMode.defaultValue {
        didSet {
            UserDefaults.standard.set(
                landingCursorVisibilityMode.rawValue,
                forKey: LandingWakeFieldPolicy.visibilityModeDefaultsKey
            )
            syncLegacyCursorAnimationEnabledFromVisibilityMode()
        }
    }

    var landingGreetingTypewriterEnabled = LandingGreetingAnimationPolicy.defaultTypewriterEnabled {
        didSet {
            UserDefaults.standard.set(
                landingGreetingTypewriterEnabled,
                forKey: LandingGreetingAnimationPolicy.typewriterEnabledDefaultsKey
            )
            persistLegacyLandingGreetingAnimationToggle()
        }
    }

    var landingCursorResponse = LandingWakeFieldPolicy.defaultResponse {
        didSet {
            UserDefaults.standard.set(
                landingCursorResponse,
                forKey: LandingWakeFieldPolicy.responseDefaultsKey
            )
        }
    }

    var landingCursorSpread = LandingWakeFieldPolicy.defaultSpread {
        didSet {
            UserDefaults.standard.set(
                landingCursorSpread,
                forKey: LandingWakeFieldPolicy.spreadDefaultsKey
            )
        }
    }

    var landingCursorTrail = LandingWakeFieldPolicy.defaultTrail {
        didSet {
            UserDefaults.standard.set(
                landingCursorTrail,
                forKey: LandingWakeFieldPolicy.trailDefaultsKey
            )
        }
    }

    var landingCursorViscosity: Double = LandingWakeFieldPolicy.defaultViscosity {
        didSet {
            UserDefaults.standard.set(
                landingCursorViscosity,
                forKey: LandingWakeFieldPolicy.viscosityDefaultsKey
            )
        }
    }

    var landingCursorTurbulence: Double = LandingWakeFieldPolicy.defaultTurbulence {
        didSet {
            UserDefaults.standard.set(
                landingCursorTurbulence,
                forKey: LandingWakeFieldPolicy.turbulenceDefaultsKey
            )
        }
    }

    var landingCursorBlastPower: Double = LandingWakeFieldPolicy.defaultBlastPower {
        didSet {
            UserDefaults.standard.set(
                landingCursorBlastPower,
                forKey: LandingWakeFieldPolicy.blastPowerDefaultsKey
            )
        }
    }

    var landingCursorOpacity: Double = LandingWakeFieldPolicy.defaultOpacity {
        didSet {
            UserDefaults.standard.set(
                landingCursorOpacity,
                forKey: LandingWakeFieldPolicy.opacityDefaultsKey
            )
        }
    }

    var landingCursorBlur: Double = LandingWakeFieldPolicy.defaultBlur {
        didSet {
            UserDefaults.standard.set(
                landingCursorBlur,
                forKey: LandingWakeFieldPolicy.blurDefaultsKey
            )
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

    // MARK: - Mini-Chat

    var miniChatOpen = false

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
        if let storedVisibilityMode = UserDefaults.standard.string(
            forKey: LandingWakeFieldPolicy.visibilityModeDefaultsKey
        ),
            let visibilityMode = LandingCursorVisibilityMode(rawValue: storedVisibilityMode) {
            landingCursorVisibilityMode = visibilityMode
            landingCursorAnimationEnabled = visibilityMode != .neither
        } else if UserDefaults.standard.object(forKey: LandingCursorAnimationPolicy.defaultsKey) != nil {
            let legacyEnabled = UserDefaults.standard.bool(
                forKey: LandingCursorAnimationPolicy.defaultsKey
            )
            landingCursorAnimationEnabled = legacyEnabled
            landingCursorVisibilityMode = legacyEnabled ? .both : .neither
        } else {
            landingCursorVisibilityMode = .both
            landingCursorAnimationEnabled = true
        }
        lastEnabledLandingCursorVisibilityMode = landingCursorVisibilityMode == .neither
            ? .both
            : landingCursorVisibilityMode
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

        if UserDefaults.standard.object(forKey: LandingWakeFieldPolicy.responseDefaultsKey) != nil {
            landingCursorResponse = UserDefaults.standard.double(
                forKey: LandingWakeFieldPolicy.responseDefaultsKey
            )
        }
        if UserDefaults.standard.object(forKey: LandingWakeFieldPolicy.spreadDefaultsKey) != nil {
            landingCursorSpread = UserDefaults.standard.double(
                forKey: LandingWakeFieldPolicy.spreadDefaultsKey
            )
        }
        if UserDefaults.standard.object(forKey: LandingWakeFieldPolicy.trailDefaultsKey) != nil {
            landingCursorTrail = UserDefaults.standard.double(
                forKey: LandingWakeFieldPolicy.trailDefaultsKey
            )
        }
        if UserDefaults.standard.object(forKey: LandingWakeFieldPolicy.viscosityDefaultsKey) != nil {
            landingCursorViscosity = UserDefaults.standard.double(
                forKey: LandingWakeFieldPolicy.viscosityDefaultsKey
            )
        }
        if UserDefaults.standard.object(forKey: LandingWakeFieldPolicy.turbulenceDefaultsKey) != nil {
            landingCursorTurbulence = UserDefaults.standard.double(
                forKey: LandingWakeFieldPolicy.turbulenceDefaultsKey
            )
        }
        if UserDefaults.standard.object(forKey: LandingWakeFieldPolicy.blastPowerDefaultsKey) != nil {
            landingCursorBlastPower = UserDefaults.standard.double(
                forKey: LandingWakeFieldPolicy.blastPowerDefaultsKey
            )
        }
        if UserDefaults.standard.object(forKey: LandingWakeFieldPolicy.opacityDefaultsKey) != nil {
            landingCursorOpacity = UserDefaults.standard.double(
                forKey: LandingWakeFieldPolicy.opacityDefaultsKey
            )
        }
        if UserDefaults.standard.object(forKey: LandingWakeFieldPolicy.blurDefaultsKey) != nil {
            landingCursorBlur = UserDefaults.standard.double(
                forKey: LandingWakeFieldPolicy.blurDefaultsKey
            )
        }
        syncLegacyCursorAnimationEnabledFromVisibilityMode()
        normalizeLandingGreetingLibrary()
    }

    // MARK: - Theme Methods

    private func clearLegacyThemeDefaults() {
        UserDefaults.standard.removeObject(forKey: ThemeMode.defaultsKey)
        UserDefaults.standard.removeObject(forKey: Self.themePairDefaultsKey)
    }

    private func clearLegacyLandingGreetingDefaults() {
        let legacyKeys = [
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

    // MARK: - Command Palette Methods

    func toggleCommandPalette() {
        withAnimation(Motion.smooth) {
            isCommandPaletteVisible.toggle()
        }
    }

    func dismissCommandPalette() {
        withAnimation(Motion.smooth) {
            isCommandPaletteVisible = false
        }
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

    // MARK: - Mini-Chat Methods

    func toggleMiniChat() { miniChatOpen.toggle() }

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

    private func syncLandingCursorVisibilityModeFromLegacyToggle() {
        guard !isSyncingLandingCursorPreferences else { return }
        isSyncingLandingCursorPreferences = true
        defer { isSyncingLandingCursorPreferences = false }

        if landingCursorAnimationEnabled {
            if landingCursorVisibilityMode == .neither {
                landingCursorVisibilityMode = lastEnabledLandingCursorVisibilityMode
            }
        } else {
            if landingCursorVisibilityMode != .neither {
                lastEnabledLandingCursorVisibilityMode = landingCursorVisibilityMode
            }
            landingCursorVisibilityMode = .neither
        }
    }

    private func syncLegacyCursorAnimationEnabledFromVisibilityMode() {
        guard !isSyncingLandingCursorPreferences else { return }
        isSyncingLandingCursorPreferences = true
        defer { isSyncingLandingCursorPreferences = false }

        if landingCursorVisibilityMode != .neither {
            lastEnabledLandingCursorVisibilityMode = landingCursorVisibilityMode
        }
        landingCursorAnimationEnabled = landingCursorVisibilityMode != .neither
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
