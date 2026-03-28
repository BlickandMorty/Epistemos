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
    func refresh() async {
        // Accessibility: check via Rust (omega-ax)
        let status = checkPermissions()
        accessibilityGranted = status.accessibility == .granted

        // Screen Recording: check via ScreenCaptureKit
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
    static func checkAccessibility() -> Bool {
        let status = checkPermissions()
        return status.accessibility == .granted
    }

    // MARK: - Private

    private func checkScreenRecording() async -> Bool {
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
            return true
        } catch {
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
