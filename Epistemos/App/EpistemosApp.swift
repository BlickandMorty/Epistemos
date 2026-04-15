import AppKit
import CoreSpotlight
import Dispatch
import MetricKit
import SwiftData
import SwiftUI
import UserNotifications
import os

// MARK: - App Entry Point

@MainActor
enum WindowPresentationPolicy {
    static let mainWindowMinimumSize = CGSize(width: 720, height: 520)

    static func needsModularZoomBehavior(
        _ window: NSWindow,
        minimumContentSize: CGSize = mainWindowMinimumSize
    ) -> Bool {
        if window.contentMinSize != minimumContentSize {
            return true
        }
        if window.collectionBehavior.contains(.fullScreenPrimary)
            || window.collectionBehavior.contains(.fullScreenAuxiliary)
            || window.collectionBehavior.contains(.fullScreenAllowsTiling)
        {
            return true
        }
        guard let zoomButton = window.standardWindowButton(.zoomButton) else {
            return false
        }
        return zoomButton.target !== window || zoomButton.action != #selector(NSWindow.performZoom(_:))
    }

    static func applyModularZoomBehavior(
        to window: NSWindow,
        minimumContentSize: CGSize = mainWindowMinimumSize
    ) {
        if window.contentMinSize != minimumContentSize {
            window.contentMinSize = minimumContentSize
        }

        var collectionBehavior = window.collectionBehavior
        collectionBehavior.remove(.fullScreenPrimary)
        collectionBehavior.remove(.fullScreenAuxiliary)
        collectionBehavior.remove(.fullScreenAllowsTiling)
        if collectionBehavior != window.collectionBehavior {
            window.collectionBehavior = collectionBehavior
        }

        if let zoomButton = window.standardWindowButton(.zoomButton) {
            if zoomButton.target !== window {
                zoomButton.target = window
            }
            if zoomButton.action != #selector(NSWindow.performZoom(_:)) {
                zoomButton.action = #selector(NSWindow.performZoom(_:))
            }
        }
    }
}

@MainActor
final class ModularZoomWindowObserverView: NSView {
    private var applyTask: Task<Void, Never>?
    private static let applyDelay: Duration = .milliseconds(1)

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window {
            // Main window always uses opaque adaptive background (never transparent)
            window.appearance = nil
            window.isOpaque = true
            window.backgroundColor = .windowBackgroundColor

            if WindowPresentationPolicy.needsModularZoomBehavior(window) {
                WindowPresentationPolicy.applyModularZoomBehavior(to: window)
                return
            }
        }
        schedulePolicyApply()
    }

    deinit {
        applyTask?.cancel()
    }

    func schedulePolicyApply() {
        applyTask?.cancel()
        applyTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.applyDelay)
            guard let self, let window = self.window,
                WindowPresentationPolicy.needsModularZoomBehavior(window)
            else { return }
            WindowPresentationPolicy.applyModularZoomBehavior(to: window)
        }
    }
}

struct ModularZoomWindowObserver: NSViewRepresentable {
    func makeNSView(context: Context) -> ModularZoomWindowObserverView {
        ModularZoomWindowObserverView(frame: .zero)
    }

    func updateNSView(_ nsView: ModularZoomWindowObserverView, context: Context) {
        nsView.schedulePolicyApply()
    }
}

private struct LaunchIntegrityGateView<Content: View>: View {
    @State private var didStartGate = false

    let bootstrap: AppBootstrap
    let content: () -> Content

    var body: some View {
        content()
            .task { @MainActor in
                guard !didStartGate else { return }
                didStartGate = true
                await bootstrap.runAutomaticVaultRestoreAfterLaunchIfNeeded()
            }
    }
}

enum SavedApplicationStatePurger {
    private static let log = Logger(subsystem: "com.epistemos", category: "SavedApplicationState")

    static func purgeIfNeeded(bundleIdentifier: String? = Bundle.main.bundleIdentifier) {
        guard let bundleIdentifier, !bundleIdentifier.isEmpty else { return }
        let fileManager = FileManager.default

        for directory in candidateDirectories(for: bundleIdentifier) {
            guard fileManager.fileExists(atPath: directory.path) else { continue }
            do {
                try fileManager.removeItem(at: directory)
            } catch {
                log.error(
                    "Failed to remove saved state directory \(directory.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    private static func candidateDirectories(for bundleIdentifier: String) -> [URL] {
        var directories: [URL] = [
            URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent("\(bundleIdentifier).savedState", isDirectory: true)
        ]

        if let libraryDirectory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first {
            directories.append(
                libraryDirectory
                    .appendingPathComponent("Saved Application State", isDirectory: true)
                    .appendingPathComponent("\(bundleIdentifier).savedState", isDirectory: true)
            )
        }

        return directories
    }
}

// MetricKit calls didReceive(_:) on com.apple.metrickit.manager.queue, NOT the
// main actor. The entire class is nonisolated — it only does file I/O, no UI.
// Using @unchecked Sendable because NSObject subclass with internal
// synchronization via serial file ops.
final class CrashReportCollector: NSObject, @unchecked Sendable, MXMetricManagerSubscriber {
    static let shared = CrashReportCollector()

    private let log = Logger(subsystem: "com.epistemos", category: "CrashReportCollector")
    private let maxRetainedReports = 100

    nonisolated override init() {
        super.init()
    }

    nonisolated func startCollecting() {
        pruneOldReportsIfNeeded()
        MXMetricManager.shared.add(self)
    }

    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let formatter = ISO8601DateFormatter()
        do {
            let reportsDir = try reportsDirectory()
            for payload in payloads {
                saveDiagnostics(payload.crashDiagnostics, type: "crash", dir: reportsDir, formatter: formatter)
                saveDiagnostics(payload.hangDiagnostics, type: "hang", dir: reportsDir, formatter: formatter)
                saveDiagnostics(payload.diskWriteExceptionDiagnostics, type: "disk_write", dir: reportsDir, formatter: formatter)
            }
            pruneOldReportsIfNeeded()
        } catch {
            log.error("Failed to persist MetricKit payloads: \(error.localizedDescription, privacy: .public)")
        }
    }

    private nonisolated func saveDiagnostics(_ diagnostics: [MXDiagnostic]?, type: String, dir: URL, formatter: ISO8601DateFormatter) {
        guard let diagnostics else { return }

        for diagnostic in diagnostics {
            let data = diagnostic.jsonRepresentation()
            let filename = "\(type)_\(formatter.string(from: Date()))_\(UUID().uuidString).json"
            let destination = dir.appendingPathComponent(filename, isDirectory: false)
            do {
                try data.write(to: destination, options: .atomic)
            } catch {
                log.error("Failed to write MetricKit \(type, privacy: .public) report: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private nonisolated func pruneOldReportsIfNeeded() {
        do {
            let reportsDir = try reportsDirectory()
            let contents = try FileManager.default.contentsOfDirectory(
                at: reportsDir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            let sorted = try contents.sorted { lhs, rhs in
                let lhsDate = try lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast
                let rhsDate = try rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast
                return lhsDate > rhsDate
            }

            guard sorted.count > maxRetainedReports else { return }
            for url in sorted.dropFirst(maxRetainedReports) {
                do {
                    try FileManager.default.removeItem(at: url)
                } catch {
                    log.error("Failed to prune MetricKit report \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }
        } catch {
            log.error("Failed to prune MetricKit reports: \(error.localizedDescription, privacy: .public)")
        }
    }

    private nonisolated func reportsDirectory() throws -> URL {
        let directory = FoundationSafety.userApplicationSupportDirectory()
            .appendingPathComponent("Epistemos", isDirectory: true)
            .appendingPathComponent("crash_reports", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

@MainActor
final class RuntimeIssueMonitor {
    static let shared = RuntimeIssueMonitor()

    enum MemoryPressureLevel: String, Sendable {
        case warning
        case critical
    }

    enum MemoryPressureTransition: Sendable, Equatable {
        case entered(MemoryPressureLevel)
        case recovered(from: MemoryPressureLevel)
    }

    struct MemoryPressureTracker: Sendable {
        private(set) var activeLevel: MemoryPressureLevel?

        mutating func transition(
            for event: DispatchSource.MemoryPressureEvent
        ) -> MemoryPressureTransition? {
            if event.contains(.critical) {
                return enter(.critical)
            }
            if event.contains(.warning) {
                return enter(.warning)
            }
            if event.contains(.normal), let activeLevel {
                self.activeLevel = nil
                return .recovered(from: activeLevel)
            }
            return nil
        }

        private mutating func enter(_ level: MemoryPressureLevel) -> MemoryPressureTransition? {
            guard activeLevel != level else { return nil }
            activeLevel = level
            return .entered(level)
        }
    }

    private struct ObserverToken {
        let center: NotificationCenter
        let token: NSObjectProtocol
    }

    private var observerTokens: [ObserverToken] = []
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    private var memoryPressureTracker = MemoryPressureTracker()
    private var started = false

    private init() {}

    func start() {
        guard !started else { return }
        started = true

        NSSetUncaughtExceptionHandler { exception in
            RuntimeDiagnostics.record(
                .fault,
                category: "Diagnostics",
                message: "uncaught_exception",
                metadata: [
                    "name": exception.name.rawValue,
                    "reason": exception.reason ?? "unknown",
                    "userInfo": String(describing: exception.userInfo ?? [:]),
                    "callStack": exception.callStackSymbols.joined(separator: "\n"),
                ]
            )
        }
        wireApplicationLifecycle()
        wireSystemLifecycle()
        startMemoryPressureMonitoring()
        recordLifecycle("monitor_started", metadata: launchMetadata())
    }

    func stop(reason: String) {
        guard started else { return }
        started = false

        for observer in observerTokens {
            observer.center.removeObserver(observer.token)
        }
        observerTokens.removeAll()

        memoryPressureSource?.cancel()
        memoryPressureSource = nil
        memoryPressureTracker = MemoryPressureTracker()

        recordLifecycle("monitor_stopped", metadata: ["reason": reason])
        RuntimeDiagnostics.recordSessionEnd(
            reason: reason,
            metadata: currentEnvironmentMetadata()
        )
    }

    private func wireApplicationLifecycle() {
        let center = NotificationCenter.default
        observe(center, name: NSApplication.didBecomeActiveNotification) { [weak self] in
            self?.recordLifecycle("app_became_active")
        }
        observe(center, name: NSApplication.didResignActiveNotification) { [weak self] in
            self?.recordLifecycle("app_resigned_active")
        }
        observe(center, name: NSApplication.didHideNotification) { [weak self] in
            self?.recordLifecycle("app_hidden")
        }
        observe(center, name: NSApplication.didUnhideNotification) { [weak self] in
            self?.recordLifecycle("app_unhidden")
        }
        observe(center, name: ProcessInfo.thermalStateDidChangeNotification) { [weak self] in
            self?.recordThermalState()
        }
        observe(center, name: .NSProcessInfoPowerStateDidChange) { [weak self] in
            self?.recordPowerState()
        }
    }

    private func wireSystemLifecycle() {
        let center = NSWorkspace.shared.notificationCenter
        observe(center, name: NSWorkspace.willSleepNotification) { [weak self] in
            self?.recordLifecycle("system_will_sleep")
        }
        observe(center, name: NSWorkspace.didWakeNotification) { [weak self] in
            self?.recordLifecycle("system_did_wake")
        }
    }

    private func observe(
        _ center: NotificationCenter,
        name: Notification.Name,
        using handler: @escaping @MainActor @Sendable () -> Void
    ) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { _ in
            Task { @MainActor in
                handler()
            }
        }
        observerTokens.append(ObserverToken(center: center, token: token))
    }

    private func startMemoryPressureMonitoring() {
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.normal, .warning, .critical],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.recordMemoryPressure(source.data)
        }
        source.resume()
        memoryPressureSource = source
    }

    private func recordMemoryPressure(_ event: DispatchSource.MemoryPressureEvent) {
        guard let transition = memoryPressureTracker.transition(for: event) else { return }

        var metadata = currentEnvironmentMetadata()
        metadata["pressureSource"] = "dispatch_source"
        metadata["memoryScope"] = "process_resident"
        let residentMB = currentMemoryUsageMB()
        metadata["residentMB"] = String(residentMB)

        switch transition {
        case .entered(let level):
            metadata["level"] = level.rawValue
            RuntimeDiagnostics.record(
                level == .critical ? .fault : .warning,
                category: "Diagnostics",
                message: "memory_pressure",
                metadata: metadata
            )
            StructuredDiagnosticLogger().log(
                .memoryPressure(
                    level: level.rawValue,
                    usedMB: residentMB,
                    pressureSource: "dispatch_source",
                    memoryScope: "process_resident",
                    isAppActive: NSApp.isActive
                )
            )
        case .recovered(let previousLevel):
            metadata["level"] = "normal"
            metadata["recoveredFrom"] = previousLevel.rawValue
            recordLifecycle("memory_pressure_recovered", metadata: metadata)
        }
    }

    private func currentMemoryUsageMB() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rawPtr in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), rawPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Int(info.resident_size / (1024 * 1024))
    }

    private func recordThermalState() {
        let state = ProcessInfo.processInfo.thermalState
        var metadata = currentEnvironmentMetadata()
        metadata["thermalState"] = thermalStateLabel(state)

        let severity: RuntimeDiagnosticSeverity
        switch state {
        case .serious:
            severity = .warning
        case .critical:
            severity = .fault
        case .nominal, .fair:
            severity = .info
        @unknown default:
            severity = .warning
        }

        if severity == .warning || severity == .error || severity == .fault {
            RuntimeDiagnostics.record(
                severity,
                category: "Diagnostics",
                message: "thermal_state_changed",
                metadata: metadata
            )
        } else {
            recordLifecycle("thermal_state_changed", metadata: metadata)
        }
    }

    private func recordPowerState() {
        var metadata = currentEnvironmentMetadata()
        metadata["lowPowerMode"] = boolLabel(ProcessInfo.processInfo.isLowPowerModeEnabled)
        recordLifecycle("power_state_changed", metadata: metadata)
    }

    private func recordLifecycle(
        _ name: String,
        metadata: [String: String] = [:]
    ) {
        RuntimeDiagnostics.recordLifecycleEvent(
            name,
            metadata: currentEnvironmentMetadata().merging(metadata) { _, new in new }
        )
    }

    private func launchMetadata() -> [String: String] {
        currentEnvironmentMetadata().merging(
            [
                "pid": "\(ProcessInfo.processInfo.processIdentifier)",
                "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
                "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            ],
            uniquingKeysWith: { _, new in new }
        )
    }

    private func currentEnvironmentMetadata() -> [String: String] {
        let application = NSApplication.shared
        let windows = application.windows
        return [
            "windowCount": "\(windows.count)",
            "visibleWindowCount": "\(windows.filter(\.isVisible).count)",
            "isActive": boolLabel(application.isActive),
            "thermalState": thermalStateLabel(ProcessInfo.processInfo.thermalState),
            "lowPowerMode": boolLabel(ProcessInfo.processInfo.isLowPowerModeEnabled),
        ]
    }

    private func boolLabel(_ value: Bool) -> String {
        value ? "true" : "false"
    }

    private func thermalStateLabel(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: "nominal"
        case .fair: "fair"
        case .serious: "serious"
        case .critical: "critical"
        @unknown default: "unknown"
        }
    }
}

@main
struct EpistemosApp: App {
    private static let isRunningTests =
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    @NSApplicationDelegateAdaptor(EpistemosAppDelegate.self) private var appDelegate
    @State private var bootstrap = AppBootstrap()
    @AppStorage("epistemos.setupComplete") private var setupComplete = false

    init() {
        SavedApplicationStatePurger.purgeIfNeeded()
        if !Self.isRunningTests {
            CrashReportCollector.shared.startCollecting()
            RuntimeDiagnostics.logStorageLocations()
            _ = RuntimeDiagnostics.recordSessionStart(metadata: [
                "pid": "\(ProcessInfo.processInfo.processIdentifier)",
                "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
                "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            ])
            RuntimeIssueMonitor.shared.start()
        }
    }

    var body: some Scene {
        Window("Epistemos", id: "main") {
            LaunchIntegrityGateView(bootstrap: bootstrap) {
                RootView(
                    databaseError: bootstrap.databaseError,
                    onResetDatabase: { bootstrap.resetDatabaseAndRelaunch() }
                )
                    .withAppEnvironment(bootstrap)
                    .sheet(isPresented: Binding(
                        get: { !setupComplete },
                        set: { if !$0 { setupComplete = true } }
                    )) {
                        SetupAssistantView {
                            setupComplete = true
                        }
                        .withAppEnvironment(bootstrap)
                    }
                    .sheet(isPresented: Binding(
                        get: { bootstrap.vaultChatMutator.stagedDiff != nil },
                        set: { isPresented in
                            if !isPresented {
                                bootstrap.vaultChatMutator.rejectPendingDiff()
                            }
                        }
                    )) {
                        if let diff = bootstrap.vaultChatMutator.stagedDiff {
                            DiffApprovalSheet(
                                diffResult: diff,
                                onApprove: {
                                    Task { @MainActor in
                                        do {
                                            _ = try await bootstrap.vaultChatMutator.approvePendingDiff()
                                            bootstrap.uiState.showToast(
                                                "Vault change committed.",
                                                type: .success
                                            )
                                        } catch {
                                            bootstrap.uiState.showToast(
                                                error.localizedDescription,
                                                type: .error
                                            )
                                        }
                                    }
                                },
                                onReject: {
                                    bootstrap.vaultChatMutator.rejectPendingDiff()
                                }
                            )
                        }
                    }
                    .background(ModularZoomWindowObserver().allowsHitTesting(false))
                    .onAppear {
                        guard !Self.isRunningTests else { return }
                        StatusBar.shared.setup()
                        HologramController.shared.setup(graphState: bootstrap.graphState, queryEngine: bootstrap.queryEngine, modelContainer: bootstrap.modelContainer, physicsCoordinator: bootstrap.physicsCoordinator, dialogueChatState: bootstrap.dialogueChatState)
                        // Restore last session after UI settles, then start tracking
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(500))
                            await bootstrap.performPrimaryLaunchInitialization()
                        }
                    }
                    // Handle Spotlight deep-links — user tapped a note in Spotlight results
                    .onContinueUserActivity(CSSearchableItemActionType) { activity in
                        guard let pageId = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String
                        else { return }
                        NoteWindowManager.shared.open(pageId: pageId)
                    }
                    // Handle Siri Suggestions / NSUserActivity continuations
                    .onContinueUserActivity("com.epistemos.openNote") { activity in
                        guard let pageId = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String
                        else { return }
                        NoteWindowManager.shared.open(pageId: pageId)
                    }
                    .onReceive(
                        NotificationCenter.default.publisher(
                            for: NSApplication.willTerminateNotification)
                    ) { _ in
                        // Teardown handled by EpistemosAppDelegate.applicationShouldTerminate / applicationWillTerminate
                    }
            }
        }
        .restorationBehavior(.disabled)
        .defaultSize(width: 1100, height: 720)
        .windowResizability(.contentSize)
        .modelContainer(bootstrap.modelContainer)
        .commands {
            EpistemosCommands(
                ui: bootstrap.uiState, chat: bootstrap.chatState, notesUI: bootstrap.notesUI,
                vaultSync: bootstrap.vaultSync)
        }

        // Knowledge Graph uses a full-screen hologram overlay (HologramController),
        // not a SwiftUI Window scene. Toggle with Cmd+Shift+G.
    }
}

// MARK: - App Delegate (Dock Menu + Native Hooks)

final class EpistemosAppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private static let isRunningTests =
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    private var mainWindowObservers: [NSObjectProtocol] = []
    private var didTeardown = false
    private var quitObserver: NSObjectProtocol?
    private static let showQuitDialogKey = "epistemos.showSaveOnQuitDialog"

    private static var canConfigureUserNotificationCenter: Bool {
        let bundleURL = Bundle.main.bundleURL
        return bundleURL.pathExtension == "app"
            || bundleURL.deletingLastPathComponent().pathExtension == "app"
    }

    var showSaveOnQuitDialogEnabled: Bool {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: Self.showQuitDialogKey) == nil
            ? true
            : defaults.bool(forKey: Self.showQuitDialogKey)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            NSWindow.didBecomeMainNotification,
            NSWindow.didBecomeKeyNotification,
            NSWindow.didDeminiaturizeNotification,
        ]

        mainWindowObservers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { note in
                guard let window = note.object as? NSWindow else { return }
                Task { @MainActor in
                    Self.applyMainWindowPolicyIfNeeded(to: window)
                }
            }
        }

        if Self.canConfigureUserNotificationCenter {
            UNUserNotificationCenter.current().delegate = self
        }

        Task { @MainActor in
            NSApp.windows.forEach(Self.applyMainWindowPolicyIfNeeded(to:))
        }
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        SavedApplicationStatePurger.purgeIfNeeded()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep the app alive in the background when NightBrain menu bar agent mode is on
        let menuBarAgent = UserDefaults.standard.bool(forKey: "nightbrain.menuBarAgent")
        if menuBarAgent {
            NSApp.setActivationPolicy(.accessory)
            return false
        }
        return false  // macOS default: don't quit on last window close (standard for document apps)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard showSaveOnQuitDialogEnabled else {
            performTeardown()
            return .terminateNow
        }
        let hasOpenNotes = !NoteWindowManager.shared.orderedPageIds().isEmpty
        let hasOpenChats = !MiniChatWindowController.shared.openChatIds.isEmpty
        guard hasOpenNotes || hasOpenChats else {
            performTeardown()
            return .terminateNow
        }

        // Show a floating save panel above ALL windows (note editors, mini chats, etc.).
        // Borderless panel with frosted glass blur and rounded corners.
        QuitSavePanelController.showQuitSave { [weak self] shouldQuit in
            if shouldQuit {
                self?.performTeardown()
                NSApp.reply(toApplicationShouldTerminate: true)
            } else {
                NSApp.reply(toApplicationShouldTerminate: false)
            }
        }
        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Idempotent fallback — performTeardown guards against double calls
        performTeardown()
        let center = NotificationCenter.default
        mainWindowObservers.forEach(center.removeObserver)
        mainWindowObservers.removeAll()
    }

    func applicationShouldSaveApplicationState(_ app: NSApplication) -> Bool {
        false
    }

    func applicationShouldRestoreApplicationState(_ app: NSApplication) -> Bool {
        false
    }

    private func performTeardown() {
        guard !didTeardown else { return }
        didTeardown = true
        guard !Self.isRunningTests else {
            StatusBar.shared.remove()
            HologramController.shared.teardown()
            return
        }
        RuntimeIssueMonitor.shared.stop(reason: "application_teardown")
        guard let bootstrap = AppBootstrap.shared else { return }
        bootstrap.activityTracker.stopTracking()
        bootstrap.activityTracker.flushToDisk()
        bootstrap.workspaceSummaryService.stopAutoSummaryLoop()
        bootstrap.workspaceService.stopAutoSave()
        if !bootstrap.workspaceService.consumeSkipAutoSaveRequest() {
            bootstrap.workspaceService.autoSave()
        }
        bootstrap.vaultSync.stopWatching(preserveData: true)
        StatusBar.shared.remove()
        HologramController.shared.teardown()
    }

    // Save-on-quit dialog is now handled via WorkspaceSavePanel (SwiftUI overlay).
    // The panel posts .proceedWithQuit when the user confirms, which triggers performTeardown + reply.

    @MainActor
    private static func applyMainWindowPolicyIfNeeded(to window: NSWindow) {
        guard HomeWindowIdentity.matches(window) else { return }
        if window.isRestorable {
            window.isRestorable = false
        }
        WindowPresentationPolicy.applyModularZoomBehavior(to: window)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let chatId = response.notification.request.content.userInfo["chatId"] as? String else {
            return
        }

        await MainActor.run {
            AppBootstrap.shared?.loadChat(chatId: chatId)
            HomeWindowIdentity.surfaceHomeWindow()
        }
    }

    /// Native macOS dock menu — right-click the dock icon for quick actions.
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()

        let newNote = NSMenuItem(
            title: "New Note", action: #selector(dockNewNote), keyEquivalent: "")
        newNote.image = NSImage(systemSymbolName: "plus.square", accessibilityDescription: "New Note")
        newNote.target = self
        menu.addItem(newNote)

        let miniChat = NSMenuItem(
            title: "New Mini Chat", action: #selector(dockMiniChat), keyEquivalent: "")
        miniChat.image = NSImage(
            systemSymbolName: "bubble.left.and.bubble.right", accessibilityDescription: "Mini Chat")
        miniChat.target = self
        menu.addItem(miniChat)

        menu.addItem(.separator())

        let skipRestore = NSMenuItem(
            title: "Skip Restore and Relaunch Home",
            action: #selector(dockSkipRestoreAndRelaunch),
            keyEquivalent: ""
        )
        skipRestore.image = NSImage(
            systemSymbolName: "arrow.clockwise.circle",
            accessibilityDescription: "Skip Restore and Relaunch Home"
        )
        skipRestore.target = self
        menu.addItem(skipRestore)

        return menu
    }

    @objc private func dockNewNote() {
        Task { @MainActor in
            guard let vaultSync = AppBootstrap.shared?.vaultSync else { return }
            if let pageId = await vaultSync.createPage(title: "Untitled") {
                NoteWindowManager.shared.open(pageId: pageId)
            }
            NSApp.activate()
        }
    }

    @objc private func dockMiniChat() {
        Task { @MainActor in
            MiniChatWindowController.shared.openNewChat()
        }
    }

    @objc private func dockSkipRestoreAndRelaunch() {
        Task { @MainActor in
            AppBootstrap.shared?.relaunchSkippingRestoreAndDiscardSession()
        }
    }
}

// MARK: - Keyboard Commands

extension Notification.Name {
    static let toggleWorkspaceSwitcher = Notification.Name("epistemos.toggleWorkspaceSwitcher")
    static let toggleSessionIntelligence = Notification.Name("epistemos.toggleSessionIntelligence")
    static let toggleTimeMachine = Notification.Name("epistemos.toggleTimeMachine")
    static let showSaveWorkspacePanel = Notification.Name("epistemos.showSaveWorkspacePanel")
    static let showQuitSavePanel = Notification.Name("epistemos.showQuitSavePanel")
    static let proceedWithQuit = Notification.Name("epistemos.proceedWithQuit")
}

struct EpistemosCommands: Commands {
    let ui: UIState
    let chat: ChatState
    let notesUI: NotesUIState
    let vaultSync: VaultSyncService
    var body: some Commands {
        CommandGroup(after: .saveItem) {
            Button("Save Workspace...") {
                NotificationCenter.default.post(name: .showSaveWorkspacePanel, object: nil)
            }
            .keyboardShortcut("s", modifiers: [.command, .control])

            Button("Switch Workspace  \u{2303}\u{2318}W") {
                NotificationCenter.default.post(name: .toggleWorkspaceSwitcher, object: nil)
            }

            Button("Session Intelligence  \u{2303}\u{2318}R") {
                NotificationCenter.default.post(name: .toggleSessionIntelligence, object: nil)
            }
        }

        CommandGroup(after: .sidebar) {
            Button("Show Home") {
                chat.goHome()
                ui.homeTab = .home
                ui.setActivePanel(.home)
                HomeWindowIdentity.surfaceHomeWindow()
            }
            .keyboardShortcut("1", modifiers: .command)

            Button("Show Notes") { UtilityWindowManager.shared.show(.notes) }
                .keyboardShortcut("2", modifiers: .command)

            Button("New Mini Chat") {
                MiniChatWindowController.shared.openNewChat()
            }
            .keyboardShortcut("3", modifiers: .command)

            Button("Knowledge Graph") {
                HologramController.shared.toggle()
            }
            .keyboardShortcut("g", modifiers: .command)

            Divider()

            Button("Open Settings") {
                UtilityWindowManager.shared.show(.settings)
                NSApp.activate()
            }

            Divider()

            Button("New Mini Chat") {
                MiniChatWindowController.shared.openNewChat()
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .newItem) {
            Button("New Note") {
                Task { @MainActor in
                    if let pageId = await vaultSync.createPage(title: "Untitled") {
                        NoteWindowManager.shared.open(pageId: pageId)
                    }
                }
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        CommandGroup(replacing: .appVisibility) {
            Button("Go Home") {
                chat.goHome()
                ui.setActivePanel(.home)
                ui.homeTab = .home
                HomeWindowIdentity.surfaceHomeWindow()
            }
            .keyboardShortcut("h", modifiers: .command)

            Button("Hide Others") {
                NSApp.hideOtherApplications(nil)
            }
            .keyboardShortcut("h", modifiers: [.command, .option])

            Button("Show All") {
                NSApp.unhideAllApplications(nil)
            }
        }
    }

    // Save workspace UI is now handled via WorkspaceSavePanel (SwiftUI overlay).
}
