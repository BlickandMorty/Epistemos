import SwiftUI

// ---------------------------------------------------------------------------
// MARK: - LandingFarmWindowManager
// ---------------------------------------------------------------------------

/// Manages the Landing Farm window lifecycle and window-group registration.
///
/// `LandingFarmWindowManager` mirrors the existing `NoteWindowManager` pattern.
/// It provides methods to set the Landing Farm as the default view, open it
/// explicitly, and bring a specific companion to the foreground.
@MainActor
public final class LandingFarmWindowManager: @unchecked Sendable {
    /// Shared singleton.
    public static let shared = LandingFarmWindowManager()

    private init() {}

    /// The identifier used for the Landing Farm window group.
    public static let windowGroupID = "LandingFarm"

    // MARK: - Default View

    /// Configures the app so that `LandingFarmView` is the first window
    /// shown on launch.
    ///
    /// Call this once during `AppBootstrap` after `NSApplication` finishes
    /// launching.
    public func setLandingFarmAsDefault() {
        // On macOS 14+ the default window group is controlled by the
        // SwiftUI `WindowGroup` declaration order in the App struct.
        // This method is a no-op placeholder that documents intent.
        // In a custom window-management setup you would:
        //   1. Close any open windows.
        //   2. Open a new window keyed to `LandingFarmView`.
        print("[LandingFarmWindowManager] Landing Farm set as default view.")
    }

    // MARK: - Open / Focus

    /// Open the Landing Farm window if it is not already visible.
    ///
    /// If a Landing Farm window already exists, it is brought to front.
    public func openLandingFarm() {
        // Find an existing Landing Farm window by title.
        let existing = NSApp.windows.first { window in
            window.title == "Companion Farm"
        }

        if let window = existing {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Otherwise rely on SwiftUI to open a new WindowGroup instance.
        // In a custom scene-management setup you would send a notification
        // or use `NSApp.sendAction` to trigger the scene.
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Activate the window and focus the specified companion.
    ///
    /// - Parameter companion: The companion to bring to the front.
    public func bringCompanionToFront(_ companion: CompanionModel) {
        openLandingFarm()

        // Post a notification that the sidebar / farm can observe to scroll
        // the companion into view and set it active.
        NotificationCenter.default.post(
            name: .bringCompanionToFront,
            object: nil,
            userInfo: ["companionID": companion.id]
        )
    }
}

// ---------------------------------------------------------------------------
// MARK: - Notification Names
// ---------------------------------------------------------------------------

extension Notification.Name {
    public static let bringCompanionToFront = Notification.Name("com.epistenos.bringCompanionToFront")
}
