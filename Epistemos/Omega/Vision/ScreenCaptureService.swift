import Foundation
import AppKit
import ScreenCaptureKit

// MARK: - Screen Capture Service

/// Captures screenshots via ScreenCaptureKit (macOS 13+).
/// Requires Screen Recording permission (TCC prompt on first use).
@MainActor
final class ScreenCaptureService {

    /// Capture the frontmost window as a CGImage via ScreenCaptureKit.
    func captureFrontmostWindow() async -> CGImage? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

            // Find the frontmost on-screen window (excluding desktop and menubar)
            guard let window = content.windows
                .filter({ $0.isOnScreen && $0.frame.width > 100 && $0.frame.height > 100 })
                .sorted(by: { $0.windowLayer < $1.windowLayer })
                .first
            else {
                return nil
            }

            return try await captureWindow(window)
        } catch {
            return nil
        }
    }

    /// Capture a specific window by its SCWindow reference.
    func captureWindow(_ window: SCWindow) async throws -> CGImage? {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width) * 2 // Retina
        config.height = Int(window.frame.height) * 2
        config.scalesToFit = false
        config.showsCursor = false

        return try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )
    }

    /// Capture a specific display (full screen).
    func captureDisplay(_ display: SCDisplay? = nil) async -> CGImage? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

            guard let targetDisplay = display ?? content.displays.first else {
                return nil
            }

            let filter = SCContentFilter(
                display: targetDisplay,
                excludingWindows: []
            )
            let config = SCStreamConfiguration()
            config.width = Int(targetDisplay.width) * 2
            config.height = Int(targetDisplay.height) * 2
            config.showsCursor = false

            return try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
        } catch {
            return nil
        }
    }

    /// Capture a specific app's windows by bundle ID.
    func captureApp(bundleID: String) async -> CGImage? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

            guard let app = content.applications.first(where: { $0.bundleIdentifier == bundleID }),
                  let window = content.windows.first(where: {
                      $0.owningApplication?.bundleIdentifier == bundleID && $0.isOnScreen
                  }) else {
                return nil
            }

            return try await captureWindow(window)
        } catch {
            return nil
        }
    }

    /// Check if Screen Recording permission is available.
    func hasScreenRecordingPermission() async -> Bool {
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
            return true
        } catch {
            return false
        }
    }
}
