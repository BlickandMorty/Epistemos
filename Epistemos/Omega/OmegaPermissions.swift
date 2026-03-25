import AppKit
import Foundation
import ScreenCaptureKit

// MARK: - Omega Permissions

/// Checks and manages macOS permissions needed by the Omega agent system.
/// Accessibility: required for AX tree walking and UI automation.
/// Screen Recording: required for ScreenCaptureKit-based screen capture.
@MainActor @Observable
final class OmegaPermissions {

    var accessibilityGranted: Bool = false
    var screenRecordingGranted: Bool = false

    /// Combined: all permissions needed for full Omega functionality.
    var allGranted: Bool { accessibilityGranted && screenRecordingGranted }

    /// Refresh permission status from the OS.
    func refresh() async {
        // Accessibility: check via Rust (omega-ax)
        let status = checkPermissions()
        accessibilityGranted = status.accessibility == .granted

        // Screen Recording: check via ScreenCaptureKit
        screenRecordingGranted = await checkScreenRecording()
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
}
