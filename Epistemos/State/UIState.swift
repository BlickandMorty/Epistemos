import AppKit
import Foundation
import Observation
import SwiftUI
import UserNotifications

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
    static let intensityDefaultsKey = "epistemos.landingGreetingIntensity"
    static let varietyDefaultsKey = "epistemos.landingGreetingVariety"
    static let paceDefaultsKey = "epistemos.landingGreetingPace"

    static let defaultEnabled = true
    static let defaultIntensity = 0.52
    static let defaultVariety = 0.58
    static let defaultPace = 0.46
}

enum LandingWakeFieldPolicy {
    static let responseDefaultsKey = "epistemos.landingCursorResponse"
    static let spreadDefaultsKey = "epistemos.landingCursorSpread"
    static let trailDefaultsKey = "epistemos.landingCursorTrail"

    static let defaultResponse = 0.56
    static let defaultSpread = 0.6
    static let defaultTrail = 0.62
}

// MARK: - UI State
// Ephemeral UI state only — no persistent data arrays.
// Theme pair, navigation, command palette, breathe mode, toast, window visibility.

@MainActor @Observable
final class UIState {
    // MARK: - Theme

    static let themePairDefaultsKey = "epistemos.theme.pair"

    var themeMode: ThemeMode = .systemDefault {
        didSet {
            UserDefaults.standard.set(themeMode.rawValue, forKey: ThemeMode.defaultsKey)
        }
    }

    /// The active theme pair. Drives both light and dark rendering.
    var activePair: ThemePair = .classic {
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
            isSystemDark ? .oled : .light
        case .custom:
            activePair.resolved(isDark: isSystemDark)
        }
    }

    var customThemesEnabled: Bool { themeMode == .custom }
    var preferredColorScheme: ColorScheme? { customThemesEnabled ? theme.colorScheme : nil }
    var shouldUseThemeWorkarounds: Bool { customThemesEnabled }
    var windowAppearance: NSAppearance? {
        customThemesEnabled
            ? NSAppearance(named: theme.isDark ? .darkAqua : .aqua)
            : nil
    }
    var usesNativeWindowBlur: Bool { themeMode == .systemDefault || theme.usesNativeWindowBlur }
    var wallpaperBackground: Color {
        customThemesEnabled ? theme.background : Color(nsColor: .windowBackgroundColor)
    }
    var windowBackgroundColor: NSColor {
        usesNativeWindowBlur ? .clear : theme.nsBackground
    }
    var contentBackground: Color {
        customThemesEnabled ? theme.background : Color(nsColor: .windowBackgroundColor)
    }
    var overlayChromeBackground: Color {
        customThemesEnabled ? theme.background : Color(nsColor: .windowBackgroundColor)
    }
    var appearanceSyncKey: String {
        "\(themeMode.rawValue):\(activePair.rawValue):\(isSystemDark ? 1 : 0)"
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

    /// Global command palette overlay — visible from any panel via Cmd+S.
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
        }
    }

    var landingGreetingAnimationEnabled = LandingGreetingAnimationPolicy.defaultEnabled {
        didSet {
            UserDefaults.standard.set(
                landingGreetingAnimationEnabled,
                forKey: LandingGreetingAnimationPolicy.enabledDefaultsKey
            )
        }
    }

    var landingGreetingIntensity = LandingGreetingAnimationPolicy.defaultIntensity {
        didSet {
            UserDefaults.standard.set(
                landingGreetingIntensity,
                forKey: LandingGreetingAnimationPolicy.intensityDefaultsKey
            )
        }
    }

    var landingGreetingCharacterVariety = LandingGreetingAnimationPolicy.defaultVariety {
        didSet {
            UserDefaults.standard.set(
                landingGreetingCharacterVariety,
                forKey: LandingGreetingAnimationPolicy.varietyDefaultsKey
            )
        }
    }

    var landingGreetingPace = LandingGreetingAnimationPolicy.defaultPace {
        didSet {
            UserDefaults.standard.set(
                landingGreetingPace,
                forKey: LandingGreetingAnimationPolicy.paceDefaultsKey
            )
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

    // MARK: - Mini-Chat

    var miniChatOpen = false

    // MARK: - Toast

    var toastMessage: String?
    var toastType: ToastType = .info
    private var toastDismissTask: Task<Void, Never>?

    // MARK: - Init

    init() {
        isSystemDark = SystemAppearanceState.isDark()
        if let savedMode = UserDefaults.standard.string(forKey: ThemeMode.defaultsKey),
           let restoredMode = ThemeMode(rawValue: savedMode) {
            themeMode = restoredMode
        }
        if let saved = UserDefaults.standard.string(forKey: Self.themePairDefaultsKey),
           let pair = ThemePair(rawValue: saved) {
            activePair = pair
        }
        displayMode = AppDisplayMode.current()
        if UserDefaults.standard.object(forKey: LandingCursorAnimationPolicy.defaultsKey) != nil {
            landingCursorAnimationEnabled = UserDefaults.standard.bool(
                forKey: LandingCursorAnimationPolicy.defaultsKey
            )
        }
        if UserDefaults.standard.object(forKey: LandingGreetingAnimationPolicy.enabledDefaultsKey) != nil {
            landingGreetingAnimationEnabled = UserDefaults.standard.bool(
                forKey: LandingGreetingAnimationPolicy.enabledDefaultsKey
            )
        }
        if UserDefaults.standard.object(forKey: LandingGreetingAnimationPolicy.intensityDefaultsKey) != nil {
            landingGreetingIntensity = UserDefaults.standard.double(
                forKey: LandingGreetingAnimationPolicy.intensityDefaultsKey
            )
        }
        if UserDefaults.standard.object(forKey: LandingGreetingAnimationPolicy.varietyDefaultsKey) != nil {
            landingGreetingCharacterVariety = UserDefaults.standard.double(
                forKey: LandingGreetingAnimationPolicy.varietyDefaultsKey
            )
        }
        if UserDefaults.standard.object(forKey: LandingGreetingAnimationPolicy.paceDefaultsKey) != nil {
            landingGreetingPace = UserDefaults.standard.double(
                forKey: LandingGreetingAnimationPolicy.paceDefaultsKey
            )
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
    }

    // MARK: - Theme Methods

    func setPair(_ pair: ThemePair) { activePair = pair }
    func setThemeMode(_ mode: ThemeMode) { themeMode = mode }
    func setCustomThemesEnabled(_ enabled: Bool) { themeMode = enabled ? .custom : .systemDefault }
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
}
