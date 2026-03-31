import AppKit
import Foundation
import ScreenCaptureKit

// MARK: - Agent Desktop Manager (VLM Desktop Isolation)

/// Manages a dedicated macOS Space for agent computer use.
///
/// The agent operates on a separate desktop, isolated from the user's workspace.
/// Uses ScreenCaptureKit to capture the agent's windows regardless of which Space
/// is active, and AXUIElement actions for cross-Space element interaction.
///
/// Architecture: Dedicated Space + ScreenCaptureKit PiP (hybrid approach).
/// - Agent windows assigned to a dedicated Space
/// - AX-based actions work cross-Space (no need to switch frontmost)
/// - CGEvent fallback for apps with poor AX support (requires brief Space switch)
/// - User watches via PiP Metal view in Epistemos
@MainActor @Observable
final class AgentDesktopManager {

    // MARK: - State

    enum DesktopState: String, Sendable {
        case idle
        case creatingSpace
        case ready
        case active          // Agent is running on the desktop
        case tearingDown
        case error
    }

    private(set) var state: DesktopState = .idle
    private(set) var errorMessage: String?

    /// Windows tracked as belonging to the agent's desktop.
    private(set) var agentWindows: [SCWindow] = []

    /// The PID of the target app the agent is controlling.
    private(set) var targetAppPID: pid_t?

    /// Screen capture service for the agent's desktop.
    let capture: AgentDesktopCapture

    // MARK: - Init

    init() {
        self.capture = AgentDesktopCapture()
    }

    // MARK: - Lifecycle

    /// Prepare the agent desktop: discover windows, start capture.
    func prepare(targetBundleID: String) async {
        state = .creatingSpace
        errorMessage = nil

        // Launch or activate the target app.
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: targetBundleID) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = false // Don't steal focus from user
            do {
                let app = try await NSWorkspace.shared.openApplication(at: url, configuration: config)
                targetAppPID = app.processIdentifier
            } catch {
                errorMessage = "Failed to launch \(targetBundleID): \(error.localizedDescription)"
                state = .error
                return
            }
        } else {
            errorMessage = "App not found: \(targetBundleID)"
            state = .error
            return
        }

        // Discover the target app's windows for capture.
        await refreshAgentWindows()

        // Start screen capture on the agent's windows.
        if let primaryWindow = agentWindows.first {
            do {
                try await capture.startCapture(window: primaryWindow)
                state = .ready
            } catch {
                errorMessage = "Failed to start capture: \(error.localizedDescription)"
                state = .error
            }
        } else {
            // No windows yet — app may still be launching.
            state = .ready
        }
    }

    /// Refresh the list of windows belonging to the target app.
    func refreshAgentWindows() async {
        guard let pid = targetAppPID else { return }

        do {
            let content = try await SCShareableContent.current
            agentWindows = content.windows.filter { window in
                window.owningApplication?.processID == pid
                    && window.isOnScreen
                    && window.frame.width > 100
                    && window.frame.height > 100
            }
        } catch {
            agentWindows = []
        }
    }

    /// Mark the desktop as actively running an agent session.
    func activate() {
        guard state == .ready else { return }
        state = .active
    }

    /// Tear down the agent desktop: stop capture, clean up.
    func tearDown() async {
        state = .tearingDown
        await capture.stopCapture()
        agentWindows.removeAll()
        targetAppPID = nil
        state = .idle
    }

    // MARK: - Window Assignment

    /// Assign a window to the agent's Space via collectionBehavior.
    /// This keeps the window on a dedicated Space and prevents it from
    /// appearing on the user's active Space.
    func assignToAgentSpace(_ window: NSWindow) {
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .managed]
    }
}
