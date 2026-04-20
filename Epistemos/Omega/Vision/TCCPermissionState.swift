import Foundation
import ScreenCaptureKit
import os

// MARK: - TCC Permission State

/// Observable state for macOS TCC (Transparency, Consent, and Control) permissions
/// required by the Omega agent system.
///
/// Required permissions:
/// - Accessibility: AX tree reading, input simulation (AXorcist, omega-ax)
/// - Screen Recording: ScreenCaptureKit screenshot/streaming
/// - Automation: Apple Events for controlling other apps (optional)
@MainActor @Observable
final class TCCPermissionState {

    private let log = Logger(subsystem: "com.epistemos.omega", category: "Permissions")

    /// Current permission statuses.
    private(set) var accessibility: TCCStatus = .unknown
    private(set) var screenRecording: TCCStatus = .unknown
    private(set) var automation: TCCStatus = .unknown

    /// Whether all required permissions are granted.
    var allRequiredGranted: Bool {
        accessibility == .granted && screenRecording == .granted
    }

    /// Human-readable summary.
    var summary: String {
        let statuses = [
            ("Accessibility", accessibility),
            ("Screen Recording", screenRecording),
            ("Automation", automation),
        ]
        return statuses.map { "\($0.0): \($0.1.label)" }.joined(separator: " | ")
    }

    /// Refresh all permission statuses.
    /// Performs blocking TCC calls off the main thread to prevent UI hangs.
    func refresh() async {
        // AXIsProcessTrusted() is a synchronous IPC call to tccd.
        // NEVER call it on the main thread — it can block for 1-3 seconds.
        let trusted = await Task.detached(priority: .userInitiated) {
            AXIsProcessTrusted()
        }.value
        accessibility = trusted ? .granted : .denied

        screenRecording = await checkScreenRecording()
        automation = .unknown // Automation status can't be checked directly
        log.info("Permissions: \(self.summary)")
    }

    // Fix: [Issue 3 - TCC Permissions] — poll for late user grants after
    // redirecting to System Settings. Checks every 2 seconds until both
    // Accessibility and Screen Recording are granted, then stops.
    private var pollingTask: Task<Void, Never>?

    func startPollingForGrant() {
        pollingTask?.cancel()
        pollingTask = Task { @MainActor [weak self] in
            // Poll every 5 seconds — TCC state changes are rare, no need to hammer.
            // Previous 2s interval was causing main thread pressure from
            // AXIsProcessTrusted() IPC round-trips stacking up.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled, let self else { return }
                await self.refresh()
                if self.allRequiredGranted {
                    self.log.info("All required TCC permissions granted via polling")
                    return
                }
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    /// Prompt the user for accessibility permission.
    /// Opens System Settings → Privacy → Accessibility.
    // Fix: [Issue 3 - TCC Permissions] — start polling after prompting so we
    // detect when user grants access in System Settings.
    func requestAccessibility() {
        // Prompt the system TCC dialog for Accessibility access.
        // AXIsProcessTrustedWithOptions is synchronous IPC — run off main thread.
        Task.detached(priority: .userInitiated) {
            let options = [String("AXTrustedCheckOptionPrompt"): true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
        startPollingForGrant()
    }

    /// Request Screen Recording permission via the native TCC dialog.
    /// Must be called from the Swift @MainActor layer — the Python daemon
    /// cannot trigger kTCCServiceScreenCapture natively.
    func requestScreenRecording() {
        // CGPreflight/RequestScreenCaptureAccess are synchronous IPC — run off main thread.
        Task.detached(priority: .userInitiated) {
            if !CGPreflightScreenCaptureAccess() {
                CGRequestScreenCaptureAccess()
            }
        }
        startPollingForGrant()
    }

    /// Open System Settings → Privacy → Screen Recording.
    func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Open System Settings → Privacy → Accessibility.
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Open System Settings → Privacy → Automation.
    func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Private

    /// Check screen recording permission with a 5-second timeout.
    /// SCShareableContent can block indefinitely if replayd is in a bad state.
    private func checkScreenRecording() async -> TCCStatus {
        let fetchTask = Task.detached(priority: .utility) { () -> TCCStatus in
            _ = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
            return .granted
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
            return .denied
        }
    }
}

// MARK: - Permission Status

enum TCCStatus: String, Sendable {
    case granted
    case denied
    case unknown

    var label: String {
        switch self {
        case .granted: return "Granted"
        case .denied: return "Not Granted"
        case .unknown: return "Unknown"
        }
    }

    var isGranted: Bool { self == .granted }
}
