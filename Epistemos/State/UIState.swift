import Foundation
import SwiftUI
import Observation

// MARK: - UI State
// Ephemeral UI state only — no persistent data arrays.
// Theme pair, navigation, command palette, breathe mode, toast, window visibility.

@MainActor @Observable
final class UIState {
    // MARK: - Theme

    /// The active theme pair. Drives both light and dark rendering.
    var activePair: ThemePair = .classic {
        didSet {
            UserDefaults.standard.set(activePair.rawValue, forKey: "epistemos.theme.pair")
        }
    }

    /// Current system dark-mode state. Set by RootView via NSApp.effectiveAppearance observer.
    var isSystemDark: Bool = false

    /// The resolved theme for the current system mode — read this everywhere.
    var theme: EpistemosTheme { activePair.resolved(isDark: isSystemDark) }

    // MARK: - Setup

    /// When true, the app shows the setup/welcome screen after a full reset.
    /// Cleared when the user taps "Get Started" in the setup view.
    var needsSetup = false

    // MARK: - Navigation

    var activePanel: NavTab = .home

    // MARK: - Chat Sidebar

    var showChatSidebar = false

    // MARK: - Command Palette

    /// Global command palette overlay — visible from any panel via Cmd+S.
    var isCommandPaletteVisible = false

    // MARK: - Breathe Mode

    var breatheActive = false

    /// How often the breathe reminder pops up (0 = off)
    var breatheReminder: BreatheReminder = .off {
        didSet {
            UserDefaults.standard.set(breatheReminder.rawValue, forKey: "epistemos.breathe.reminder")
        }
    }

    /// Number of 4-7-8 cycles per session (1–10)
    var breatheCycles: Int = 3 {
        didSet {
            UserDefaults.standard.set(breatheCycles, forKey: "epistemos.breathe.cycles")
        }
    }

    private var breatheReminderTask: Task<Void, Never>?

    // MARK: - Window Visibility
    /// True when the main window is minimized to the Dock.
    /// Animations (starfield, typewriter) should pause when this is true to save CPU.
    var windowOccluded = false

    // MARK: - Mini-Chat

    var miniChatOpen = false

    // MARK: - Toast

    var toastMessage: String?
    var toastType: ToastType = .info
    private var toastDismissTask: Task<Void, Never>?

    // MARK: - Init

    init() {
        if let saved = UserDefaults.standard.string(forKey: "epistemos.theme.pair"),
           let pair = ThemePair(rawValue: saved) {
            activePair = pair
        }
        if let savedReminder = UserDefaults.standard.string(forKey: "epistemos.breathe.reminder"),
           let reminder = BreatheReminder(rawValue: savedReminder) {
            breatheReminder = reminder
        }
        let savedCycles = UserDefaults.standard.integer(forKey: "epistemos.breathe.cycles")
        if savedCycles > 0 { breatheCycles = min(10, max(1, savedCycles)) }
    }

    // MARK: - Theme Methods

    func setPair(_ pair: ThemePair) { activePair = pair }

    func cycleTheme() {
        let pairs = ThemePair.allCases
        guard let idx = pairs.firstIndex(of: activePair) else { return }
        activePair = pairs[(idx + 1) % pairs.count]
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

    // MARK: - Breathe Methods

    func startBreathe() { breatheActive = true }
    func stopBreathe() { breatheActive = false }

    /// Schedule the next breathe reminder based on the current interval.
    func scheduleBreatheReminder() {
        breatheReminderTask?.cancel()
        guard breatheReminder != .off else { return }
        let minutes = breatheReminder.minutes
        breatheReminderTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(minutes * 60))
            guard !Task.isCancelled else { return }
            startBreathe()
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
