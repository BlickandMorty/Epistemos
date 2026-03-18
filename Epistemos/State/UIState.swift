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
    static let asciiEnabledDefaultsKey = "epistemos.landingGreetingASCIIEnabled"
    static let typewriterEnabledDefaultsKey = "epistemos.landingGreetingTypewriterEnabled"
    static let asciiHoverEnabledDefaultsKey = "epistemos.landingGreetingASCIIHoverEnabled"
    static let typewriterVersionDefaultsKey = "epistemos.landingGreetingTypewriterVersion"
    static let intensityDefaultsKey = "epistemos.landingGreetingIntensity"
    static let varietyDefaultsKey = "epistemos.landingGreetingVariety"
    static let paceDefaultsKey = "epistemos.landingGreetingPace"
    static let thresholdDefaultsKey = "epistemos.landingGreetingThreshold"
    static let blurDefaultsKey = "epistemos.landingGreetingBlur"
    static let pullDefaultsKey = "epistemos.landingGreetingPull"
    static let expansionDefaultsKey = "epistemos.landingGreetingExpansion"
    static let centerSofteningDefaultsKey = "epistemos.landingGreetingCenterSoftening"
    static let pullRadiusDefaultsKey = "epistemos.landingGreetingPullRadius"
    static let dampingDefaultsKey = "epistemos.landingGreetingDamping"
    static let scaleDefaultsKey = "epistemos.landingGreetingScale"

    static let defaultEnabled = true
    static let defaultASCIIEnabled = true
    static let defaultTypewriterEnabled = true
    static let defaultASCIIHoverEnabled = false
    static let defaultTypewriterVersion: LandingGreetingTypewriterVersion = .liquid
    static let defaultIntensity = 0.52
    static let defaultVariety = 0.58
    static let defaultPace = 0.46
    static let defaultThreshold = 0.42
    static let defaultBlur = 0.5
    static let defaultPull = 0.45
    static let defaultExpansion = 0.3
    static let defaultCenterSoftening = 0.05
    static let defaultPullRadius = 0.5 // Maps to 80-240
    static let defaultDamping = 0.5    // Maps to 0.2-0.9
    static let defaultScale = 0.4
}

enum LandingGreetingTypewriterVersion: String, CaseIterable, Codable, Sendable {
    case liquid = "liquid"
    case nodeTitle = "nodeTitle"

    var displayName: String {
        switch self {
        case .liquid: "Liquid"
        case .nodeTitle: "Node Title"
        }
    }
}

enum LandingWakeFieldPolicy {
    static let responseDefaultsKey = "epistemos.landingCursorResponse"
    static let spreadDefaultsKey = "epistemos.landingCursorSpread"
    static let trialDefaultsKey = "epistemos.landingCursorTrail"
    static let viscosityDefaultsKey = "epistemos.landingCursorViscosity"
    static let turbulenceDefaultsKey = "epistemos.landingCursorTurbulence"
    static let blastPowerDefaultsKey = "epistemos.landingCursorBlastPower"

    static let defaultResponse = 0.56
    static let defaultSpread = 0.6
    static let defaultTrail = 0.62
    static let defaultViscosity = 0.8
    static let defaultTurbulence = 0.5
    static let defaultBlastPower = 50.0
}

// MARK: - UI State
// Ephemeral UI state only — no persistent data arrays.
// Theme pair, navigation, command palette, breathe mode, toast, window visibility.

@MainActor @Observable
final class UIState {
    // MARK: - Theme

    static let themePairDefaultsKey = "epistemos.theme.pair"

    private var isEnforcingSystemAppearance = false

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

    var landingGreetingASCIIEnabled = LandingGreetingAnimationPolicy.defaultASCIIEnabled {
        didSet {
            UserDefaults.standard.set(
                landingGreetingASCIIEnabled,
                forKey: LandingGreetingAnimationPolicy.asciiEnabledDefaultsKey
            )
        }
    }

    var landingGreetingTypewriterEnabled = LandingGreetingAnimationPolicy.defaultTypewriterEnabled {
        didSet {
            UserDefaults.standard.set(
                landingGreetingTypewriterEnabled,
                forKey: LandingGreetingAnimationPolicy.typewriterEnabledDefaultsKey
            )
        }
    }

    var landingGreetingASCIIHoverEnabled = LandingGreetingAnimationPolicy.defaultASCIIHoverEnabled {
        didSet {
            UserDefaults.standard.set(
                landingGreetingASCIIHoverEnabled,
                forKey: LandingGreetingAnimationPolicy.asciiHoverEnabledDefaultsKey
            )
        }
    }

    var landingGreetingTypewriterVersion = LandingGreetingAnimationPolicy.defaultTypewriterVersion {
        didSet {
            UserDefaults.standard.set(
                landingGreetingTypewriterVersion.rawValue,
                forKey: LandingGreetingAnimationPolicy.typewriterVersionDefaultsKey
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

    var landingGreetingThreshold = LandingGreetingAnimationPolicy.defaultThreshold {
        didSet {
            UserDefaults.standard.set(
                landingGreetingThreshold,
                forKey: LandingGreetingAnimationPolicy.thresholdDefaultsKey
            )
        }
    }

    var landingGreetingBlur = LandingGreetingAnimationPolicy.defaultBlur {
        didSet {
            UserDefaults.standard.set(
                landingGreetingBlur,
                forKey: LandingGreetingAnimationPolicy.blurDefaultsKey
            )
        }
    }

    var landingGreetingPull = LandingGreetingAnimationPolicy.defaultPull {
        didSet {
            UserDefaults.standard.set(
                landingGreetingPull,
                forKey: LandingGreetingAnimationPolicy.pullDefaultsKey
            )
        }
    }

    var landingGreetingExpansion = LandingGreetingAnimationPolicy.defaultExpansion {
        didSet {
            UserDefaults.standard.set(
                landingGreetingExpansion,
                forKey: LandingGreetingAnimationPolicy.expansionDefaultsKey
            )
        }
    }

    var landingGreetingCenterSoftening = LandingGreetingAnimationPolicy.defaultCenterSoftening {
        didSet {
            UserDefaults.standard.set(
                landingGreetingCenterSoftening,
                forKey: LandingGreetingAnimationPolicy.centerSofteningDefaultsKey
            )
        }
    }

    var landingGreetingPullRadius = LandingGreetingAnimationPolicy.defaultPullRadius {
        didSet {
            UserDefaults.standard.set(
                landingGreetingPullRadius,
                forKey: LandingGreetingAnimationPolicy.pullRadiusDefaultsKey
            )
        }
    }

    var landingGreetingDamping = LandingGreetingAnimationPolicy.defaultDamping {
        didSet {
            UserDefaults.standard.set(
                landingGreetingDamping,
                forKey: LandingGreetingAnimationPolicy.dampingDefaultsKey
            )
        }
    }

    var landingGreetingScale = LandingGreetingAnimationPolicy.defaultScale {
        didSet {
            UserDefaults.standard.set(
                landingGreetingScale,
                forKey: LandingGreetingAnimationPolicy.scaleDefaultsKey
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
                forKey: LandingWakeFieldPolicy.trialDefaultsKey
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
        if UserDefaults.standard.object(forKey: LandingWakeFieldPolicy.trialDefaultsKey) != nil {
            landingCursorTrail = UserDefaults.standard.double(
                forKey: LandingWakeFieldPolicy.trialDefaultsKey
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

        if UserDefaults.standard.object(forKey: LandingGreetingAnimationPolicy.thresholdDefaultsKey) != nil {
            landingGreetingThreshold = UserDefaults.standard.double(
                forKey: LandingGreetingAnimationPolicy.thresholdDefaultsKey
            )
        }
        if UserDefaults.standard.object(forKey: LandingGreetingAnimationPolicy.blurDefaultsKey) != nil {
            landingGreetingBlur = UserDefaults.standard.double(
                forKey: LandingGreetingAnimationPolicy.blurDefaultsKey
            )
        }
        if UserDefaults.standard.object(forKey: LandingGreetingAnimationPolicy.pullDefaultsKey) != nil {
            landingGreetingPull = UserDefaults.standard.double(
                forKey: LandingGreetingAnimationPolicy.pullDefaultsKey
            )
        }
        if UserDefaults.standard.object(forKey: LandingGreetingAnimationPolicy.expansionDefaultsKey) != nil {
            landingGreetingExpansion = UserDefaults.standard.double(
                forKey: LandingGreetingAnimationPolicy.expansionDefaultsKey
            )
        }
        if UserDefaults.standard.object(forKey: LandingGreetingAnimationPolicy.centerSofteningDefaultsKey) != nil {
            landingGreetingCenterSoftening = UserDefaults.standard.double(
                forKey: LandingGreetingAnimationPolicy.centerSofteningDefaultsKey
            )
        }
        if UserDefaults.standard.object(forKey: LandingGreetingAnimationPolicy.pullRadiusDefaultsKey) != nil {
            landingGreetingPullRadius = UserDefaults.standard.double(
                forKey: LandingGreetingAnimationPolicy.pullRadiusDefaultsKey
            )
        }
        if UserDefaults.standard.object(forKey: LandingGreetingAnimationPolicy.dampingDefaultsKey) != nil {
            landingGreetingDamping = UserDefaults.standard.double(
                forKey: LandingGreetingAnimationPolicy.dampingDefaultsKey
            )
        }
        if UserDefaults.standard.object(forKey: LandingGreetingAnimationPolicy.scaleDefaultsKey) != nil {
            landingGreetingScale = UserDefaults.standard.double(
                forKey: LandingGreetingAnimationPolicy.scaleDefaultsKey
            )
        }
    }

    // MARK: - Theme Methods

    private func clearLegacyThemeDefaults() {
        UserDefaults.standard.removeObject(forKey: ThemeMode.defaultsKey)
        UserDefaults.standard.removeObject(forKey: Self.themePairDefaultsKey)
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
