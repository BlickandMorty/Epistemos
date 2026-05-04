#if EPISTEMOS_APP_STORE
import Foundation

// MARK: - Omega Permissions (App Store profile)

/// The App Store build does not expose native computer-use automation.
/// Keep the type available for shared source compatibility, but do not
/// link screen capture, accessibility mutation, or Apple Events APIs.
@MainActor @Observable
final class OmegaPermissions {
    var accessibilityGranted: Bool = false
    var screenRecordingGranted: Bool = false
    var automationGranted: Bool = false
    var allGranted: Bool { false }

    func refresh() async {
        accessibilityGranted = false
        screenRecordingGranted = false
        automationGranted = false
    }

    func requestAutomationAccess() async {
        automationGranted = false
    }

    func openAccessibilitySettings() {}
    func openScreenRecordingSettings() {}
    func openAutomationSettings() {}

    nonisolated static func checkAccessibility() -> Bool { false }
}
#else
import AppKit
import CoreServices
import Foundation
import ScreenCaptureKit

// MARK: - Omega Permissions

/// Checks and manages macOS permissions needed by the Omega agent system.
/// Accessibility: required for AX tree walking and UI automation.
/// Screen Recording: required for ScreenCaptureKit-based screen capture.
@MainActor @Observable
final class OmegaPermissions {
    private let automationTargetBundleIdentifier = "com.apple.systemevents"

    var accessibilityGranted: Bool = false
    var screenRecordingGranted: Bool = false
    var automationGranted: Bool = false

    /// Combined: all permissions needed for full Omega functionality.
    var allGranted: Bool { accessibilityGranted && screenRecordingGranted && automationGranted }

    /// Refresh permission status from the OS.
    /// Blocking calls (Rust FFI AXIsProcessTrusted) are dispatched off main thread.
    func refresh() async {
        // Accessibility: check via Rust (omega-ax) — OFF main thread.
        // checkPermissions() calls AXIsProcessTrusted via FFI, which is synchronous IPC.
        let accessibilityGranted = await Task.detached(priority: .userInitiated) {
            checkPermissions().accessibility == .granted
        }.value
        self.accessibilityGranted = accessibilityGranted

        // Screen Recording: check via ScreenCaptureKit (with timeout)
        screenRecordingGranted = await checkScreenRecording()

        // Automation: check System Events Apple Events permission without prompting.
        await ensureAutomationTargetIsRunning()
        automationGranted = await automationPermissionState(promptIfNeeded: false)
    }

    /// Trigger the macOS Automation consent prompt for System Events if needed.
    func requestAutomationAccess() async {
        await ensureAutomationTargetIsRunning()
        _ = await automationPermissionState(promptIfNeeded: true)
        try? await Task.sleep(for: .milliseconds(250))
        automationGranted = await automationPermissionState(promptIfNeeded: false)
    }

    /// Open System Settings to the Accessibility pane.
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Open System Settings to the Screen Recording pane.
    func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Open System Settings to the Automation pane.
    func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Static Helpers

    /// Quick accessibility check (for use outside the Observable instance).
    /// NOTE: This calls AXIsProcessTrusted via Rust FFI which is synchronous.
    /// Prefer `refresh()` in async contexts. This exists for startup gate checks.
    nonisolated static func checkAccessibility() -> Bool {
        let status = checkPermissions()
        return status.accessibility == .granted
    }

    // MARK: - Private

    /// Check screen recording with 5-second timeout.
    /// SCShareableContent can hang if replayd is in a broken state.
    private func checkScreenRecording() async -> Bool {
        let fetchTask = Task.detached(priority: .utility) { () -> Bool in
            _ = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
            return true
        }
        let timeoutTask = Task.detached(priority: .utility) {
            try await Task.sleep(for: .seconds(5))
            fetchTask.cancel()
        }
        do {
            let result = try await fetchTask.value
            timeoutTask.cancel()
            return result
        } catch {
            timeoutTask.cancel()
            return false
        }
    }

    func automationPermissionState(promptIfNeeded: Bool) async -> Bool {
        let descriptor = NSAppleEventDescriptor(bundleIdentifier: automationTargetBundleIdentifier)
        guard let target = descriptor.aeDesc else {
            return false
        }

        let status = AEDeterminePermissionToAutomateTarget(
            target,
            AEEventClass(typeWildCard),
            AEEventID(typeWildCard),
            promptIfNeeded
        )
        return status == noErr
    }

    private func ensureAutomationTargetIsRunning() async {
        if !NSRunningApplication.runningApplications(withBundleIdentifier: automationTargetBundleIdentifier).isEmpty {
            return
        }

        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: automationTargetBundleIdentifier) else {
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.hides = true

        do {
            _ = try await NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
        } catch {
            // Leave automation as not granted if the target cannot be launched.
        }
    }
}
#endif
