import AppKit
import CoreServices
import Foundation
import SQLite3

struct IMessageNativeSetupStatus: Equatable, Sendable {
    let messagesDatabasePath: String
    let messagesAppPath: String
    let currentAppPath: String
    let runningEpistemosAppPaths: [String]
    let databaseFileExists: Bool
    let databaseAccessible: Bool
    let messagesAppAvailable: Bool
    let messagesAutomationGranted: Bool

    var pollingReady: Bool { databaseAccessible }
    var replyReady: Bool { messagesAppAvailable && messagesAutomationGranted }
    var nativeBridgeReady: Bool { pollingReady && replyReady }
    var hasMultipleEpistemosBuildsRunning: Bool { Set(runningEpistemosAppPaths).count > 1 }
    var isDebugBuild: Bool { currentAppPath.contains("/DerivedData/") }
}

enum IMessageNativeSetupDoctor {
    static let messagesBundleIdentifier = "com.apple.MobileSMS"

    static func currentStatus() -> IMessageNativeSetupStatus {
        let databasePath = messagesDatabasePath
        return IMessageNativeSetupStatus(
            messagesDatabasePath: databasePath,
            messagesAppPath: messagesAppPath,
            currentAppPath: currentAppPath,
            runningEpistemosAppPaths: runningEpistemosAppPaths,
            databaseFileExists: FileManager.default.fileExists(atPath: databasePath),
            databaseAccessible: canOpenMessagesDatabase(at: databasePath),
            messagesAppAvailable: FileManager.default.fileExists(atPath: messagesAppPath),
            messagesAutomationGranted: messagesAutomationGranted(promptIfNeeded: false)
        )
    }

    @MainActor
    static func runGuidedSetup() async -> IMessageNativeSetupStatus {
        openFullDiskAccessSettings()
        openMessagesApp()
        _ = await requestMessagesAutomationAccess()
        if !messagesAutomationGranted(promptIfNeeded: false) {
            openAutomationSettings()
        }
        try? await Task.sleep(for: .milliseconds(350))
        return currentStatus()
    }

    @MainActor
    static func requestMessagesAutomationAccess() async -> Bool {
        await ensureMessagesAppIsRunning(activates: true)
        _ = messagesAutomationGranted(promptIfNeeded: true)
        try? await Task.sleep(for: .milliseconds(250))
        return messagesAutomationGranted(promptIfNeeded: false)
    }

    @MainActor
    static func openFullDiskAccessSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @MainActor
    static func openAutomationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @MainActor
    static func openMessagesApp() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: messagesBundleIdentifier) else {
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in }
    }

    @MainActor
    static func revealCurrentApp() {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: currentAppPath)])
    }

    @MainActor
    static func relaunchCurrentApp() async {
        let appURL = URL(fileURLWithPath: currentAppPath)
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = true

        do {
            _ = try await NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
            try? await Task.sleep(for: .milliseconds(350))
            NSApp.terminate(nil)
        } catch {
            return
        }
    }

    static func presentedDriverError(_ rawError: String?, status: IMessageNativeSetupStatus) -> String? {
        guard let raw = rawError?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }

        let normalized = raw.lowercased()
        if normalized.contains("unable to open database file")
            || normalized.contains("authorization denied")
            || normalized.contains("chat.db") {
            if status.databaseFileExists {
                if status.hasMultipleEpistemosBuildsRunning {
                    return "Messages history exists, but the active Epistemos build still cannot read it. Another Epistemos copy is also running. Grant Full Disk Access to the current build shown below, then relaunch that same copy."
                }
                if status.isDebugBuild {
                    return "Messages history exists, but this Debug Epistemos build still cannot read it. Grant Full Disk Access to the current build shown below, then relaunch it."
                }
                return "Messages history exists, but macOS is still blocking live database access for this Epistemos build. Grant Full Disk Access, then relaunch Epistemos and press Refresh setup status."
            }
            return "Messages history is not available yet. Open Messages once on this Mac, then grant Full Disk Access to Epistemos before polling again."
        }

        if normalized.contains("apple events")
            || normalized.contains("not authorized")
            || normalized.contains("automation") {
            return "Replies are blocked until macOS allows Epistemos to control Messages. Run Native Setup or open Automation Settings, then try again."
        }

        return raw
    }

    static var messagesDatabasePath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Messages", isDirectory: true)
            .appendingPathComponent("chat.db")
            .path
    }

    static var messagesAppPath: String {
        "/System/Applications/Messages.app"
    }

    static var currentAppPath: String {
        Bundle.main.bundleURL.path
    }

    static var runningEpistemosAppPaths: [String] {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.epistemos.app"
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .compactMap { $0.bundleURL?.path }
            .sorted()
    }

    private static func canOpenMessagesDatabase(at path: String) -> Bool {
        var db: OpaquePointer?
        let openResult = sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil)
        defer {
            if db != nil {
                sqlite3_close(db)
            }
        }
        guard openResult == SQLITE_OK, let db else {
            return false
        }

        var statement: OpaquePointer?
        let prepareResult = sqlite3_prepare_v2(db, "SELECT 1;", -1, &statement, nil)
        defer {
            if statement != nil {
                sqlite3_finalize(statement)
            }
        }
        return prepareResult == SQLITE_OK
    }

    private static func messagesAutomationGranted(promptIfNeeded: Bool) -> Bool {
        let descriptor = NSAppleEventDescriptor(bundleIdentifier: messagesBundleIdentifier)
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

    @MainActor
    private static func ensureMessagesAppIsRunning(activates: Bool) async {
        if !NSRunningApplication.runningApplications(withBundleIdentifier: messagesBundleIdentifier).isEmpty {
            return
        }

        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: messagesBundleIdentifier) else {
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = activates

        do {
            _ = try await NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
        } catch {
            return
        }
    }
}
