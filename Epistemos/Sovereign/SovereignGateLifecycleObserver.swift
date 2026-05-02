import AppKit
import Foundation

@MainActor
final class SovereignGateLifecycleObserver {
    private struct ObserverToken {
        let center: NotificationCenter
        let token: NSObjectProtocol
    }

    private weak var gate: SovereignGate?
    private var observerTokens: [ObserverToken] = []

    var isStarted: Bool {
        !observerTokens.isEmpty
    }

    func start(
        gate: SovereignGate,
        applicationCenter: NotificationCenter = .default,
        workspaceCenter: NotificationCenter = NSWorkspace.shared.notificationCenter
    ) {
        if !observerTokens.isEmpty {
            self.gate = gate
            return
        }

        self.gate = gate
        observe(applicationCenter, name: NSApplication.didResignActiveNotification)
        observe(applicationCenter, name: NSApplication.didHideNotification)
        observe(workspaceCenter, name: NSWorkspace.willSleepNotification)
        observe(workspaceCenter, name: NSWorkspace.sessionDidResignActiveNotification)
        observe(workspaceCenter, name: NSWorkspace.screensDidSleepNotification)
    }

    func stop() {
        for observer in observerTokens {
            observer.center.removeObserver(observer.token)
        }
        observerTokens.removeAll(keepingCapacity: true)
        gate = nil
    }

    private func observe(
        _ center: NotificationCenter,
        name: Notification.Name
    ) {
        let token = center.addObserver(forName: name, object: nil, queue: nil) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.gate?.clearGrace()
            }
        }
        observerTokens.append(ObserverToken(center: center, token: token))
    }
}
