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
    func refresh() async {
        accessibility = AXIsProcessTrusted() ? .granted : .denied
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
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
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
        // Prompt the system TCC dialog for Accessibility access
        // Use string key directly to avoid concurrency-unsafe global ref
        let options = [String("AXTrustedCheckOptionPrompt"): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        startPollingForGrant()
    }

    /// Request Screen Recording permission via the native TCC dialog.
    /// Must be called from the Swift @MainActor layer — the Python daemon
    /// cannot trigger kTCCServiceScreenCapture natively.
    // Fix: [Issue 3 - TCC Permissions] — always call CGRequestScreenCaptureAccess()
    // proactively when preflight reports denied, and start polling for grant.
    func requestScreenRecording() {
        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
            startPollingForGrant()
        }
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

    private func checkScreenRecording() async -> TCCStatus {
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
            return .granted
        } catch {
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
