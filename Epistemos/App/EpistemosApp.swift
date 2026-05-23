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

    static func applyModularZoomBehavior(
        to window: NSWindow,
        minimumContentSize: CGSize = mainWindowMinimumSize
    ) {
        if window.contentMinSize != minimumContentSize {
            window.contentMinSize = minimumContentSize
        }

        var collectionBehavior = window.collectionBehavior
        collectionBehavior.remove([.fullScreenPrimary, .fullScreenAuxiliary, .fullScreenAllowsTiling])
        if collectionBehavior != window.collectionBehavior {
            window.collectionBehavior = collectionBehavior
        }

        if let zoomButton = window.standardWindowButton(.zoomButton) {
            zoomButton.target = window
            zoomButton.action = #selector(NSWindow.performZoom(_:))
        }
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

private enum RuntimeAuditFlags {
    static let minimalHomeSceneKey = "EPI_HOME_WINDOW_MINIMAL_CONTENT"

    static var minimalHomeSceneEnabled: Bool {
        ProcessInfo.processInfo.environment[minimalHomeSceneKey] == "1"
    }
}

private struct AuditMinimalHomeSceneView: View {
    var body: some View {
        VStack {
            Button("test") {
                RuntimeDiagnostics.recordLifecycleEvent("minimal_home_button_pressed")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct HomeSceneRootContent: View {
    private static let isRunningTests =
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    let bootstrap: AppBootstrap
    @Binding var showQuickCapture: Bool
    @AppStorage("epistemos.setupComplete") private var setupComplete = false
    // ISSUE-2026-05-12-002 — post-setup vault re-prompt. Per-launch
    // flag that resets when the app cold-starts; lets the user dismiss
    // the re-prompt this session if they really want to use the app
    // vault-less, but re-fires next launch so they don't forget.
    @State private var vaultReprompDismissedThisSession = false

    var body: some View {
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
                    get: {
                        // Fires once per cold launch when setup is done
                        // but no vault folder has been chosen yet, and
                        // the user hasn't already dismissed it this
                        // session. This is the gentle force-selection
                        // gate from ISSUE-2026-05-12-002 — non-modal
                        // (user can dismiss) but persistent across
                        // launches.
                        //
                        // CRITICAL: also check that no bookmark is
                        // pending restore (per the user report dated
                        // 2026-05-12: the sheet was firing during the
                        // brief window after launch but before
                        // restoreVaultFromBookmark() completed). If a
                        // bookmark exists in defaults, the vault is
                        // about to be restored; don't show the prompt.
                        //
                        // USER REPORT 2026-05-12 v2: also gate on
                        // `hasEverConnectedAVault`. If the user has
                        // EVER connected a vault, explicit disconnect
                        // should NOT re-prompt — the user disconnected
                        // intentionally and knows how to re-connect
                        // through Settings. The sheet's purpose is
                        // onboarding (truly-fresh users), not nagging.
                        let bookmarkPending = UserDefaults.standard
                            .data(forKey: "epistemos.vaultBookmark") != nil
                        let hasEverConnected = UserDefaults.standard
                            .bool(forKey: "epistemos.hasEverConnectedAVault")
                        return setupComplete
                            && bootstrap.vaultSync.vaultURL == nil
                            && !bookmarkPending
                            && !hasEverConnected
                            && !vaultReprompDismissedThisSession
                    },
                    set: { isPresented in
                        if !isPresented {
                            vaultReprompDismissedThisSession = true
                        }
                    }
                )) {
                    VaultReprompSheet(
                        onSelectVault: {
                            VaultConnectionActions.selectVaultFolder(
                                notesUI: bootstrap.notesUI,
                                vaultSync: bootstrap.vaultSync
                            )
                            // Dismiss the sheet — vaultURL will flip
                            // non-nil after the picker callback fires,
                            // and the predicate will go false anyway.
                            vaultReprompDismissedThisSession = true
                        },
                        onDismiss: {
                            vaultReprompDismissedThisSession = true
                        }
                    )
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
                .sheet(item: Binding<ApprovalModalView.PendingApproval?>(
                    get: { bootstrap.chatApprovalQueue.pendingApproval },
                    set: { _ in }
                )) { pendingApproval in
                    ApprovalModalView(
                        approval: pendingApproval,
                        onResolve: { decision in
                            bootstrap.chatApprovalQueue.resolve(
                                pendingApproval,
                                decision: decision
                            )
                        }
                    )
                    .interactiveDismissDisabled(true)
                }
                .sheet(isPresented: $showQuickCapture) {
                    QuickCaptureView()
                        .withAppEnvironment(bootstrap)
                }
                .onReceive(
                    NotificationCenter.default.publisher(for: .showQuickCapture)
                ) { _ in
                    showQuickCapture = true
                }
                .onAppear {
                    guard !Self.isRunningTests else { return }
                    StatusBar.shared.setup()
                    HologramController.shared.setup(
                        graphState: bootstrap.graphState,
                        queryEngine: bootstrap.queryEngine,
                        modelContainer: bootstrap.modelContainer,
                        physicsCoordinator: bootstrap.physicsCoordinator,
                        dialogueChatState: bootstrap.dialogueChatState
                    )
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(500))
                        await bootstrap.performPrimaryLaunchInitialization()
                    }
                }
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    guard let pageId = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String
                    else { return }
                    NoteWindowManager.shared.open(pageId: pageId)
                }
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
}

#if EPISTEMOS_APP_STORE
private struct AppStoreFallbackHomeWindowContent: View {
    let bootstrap: AppBootstrap
    @State private var showQuickCapture = false

    var body: some View {
        HomeSceneRootContent(bootstrap: bootstrap, showQuickCapture: $showQuickCapture)
    }
}

@MainActor
private final class AppStoreFirstWindowPresenter {
    static let shared = AppStoreFirstWindowPresenter()

    private static let log = Logger(subsystem: "com.epistemos", category: "AppStoreFirstWindow")
    private var fallbackWindow: NSWindow?
    private weak var bootstrap: AppBootstrap?
    private var didSchedule = false

    private init() {}

    private static func viableHomeWindow() -> NSWindow? {
        NSApp.windows.first { window in
            HomeWindowIdentity.matches(window)
                && window.frame.width >= WindowPresentationPolicy.mainWindowMinimumSize.width
                && window.frame.height >= WindowPresentationPolicy.mainWindowMinimumSize.height
        }
    }

    func schedule(bootstrap: AppBootstrap? = AppBootstrap.shared) {
        if let bootstrap {
            self.bootstrap = bootstrap
        }
        guard !didSchedule else { return }
        didSchedule = true
        Self.log.info("App Store first-window fallback scheduled")

        Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(700))
            } catch {
                return
            }
            surfaceOrCreateHomeWindow()
        }
    }

    func scheduleAfterLaunch(bootstrap: AppBootstrap? = AppBootstrap.shared) {
        if let bootstrap {
            self.bootstrap = bootstrap
        }
        didSchedule = false
        schedule(bootstrap: bootstrap ?? self.bootstrap)
    }

    func ensureHomeWindow(bootstrap: AppBootstrap? = AppBootstrap.shared) {
        if let bootstrap {
            self.bootstrap = bootstrap
        }
        didSchedule = false
        surfaceOrCreateHomeWindow()
    }

    private func surfaceOrCreateHomeWindow() {
        if let existingWindow = Self.viableHomeWindow() {
            Self.log.info("App Store first-window fallback surfaced existing window")
            surface(existingWindow)
            return
        }

        guard let bootstrap = bootstrap ?? AppBootstrap.shared else {
            Self.log.info("App Store first-window fallback waiting for AppBootstrap")
            didSchedule = false
            schedule()
            return
        }

        let controller = NSHostingController(
            rootView: AppStoreFallbackHomeWindowContent(bootstrap: bootstrap)
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = HomeWindowIdentity.title
        window.isReleasedWhenClosed = false
        window.contentViewController = controller
        window.center()
        HomeWindowIdentity.apply(to: window)
        WindowPresentationPolicy.applyModularZoomBehavior(to: window)
        fallbackWindow = window

        Self.log.info("App Store first-window fallback created NSWindow")
        surface(window)
    }

    private func surface(_ window: NSWindow) {
        Self.log.info("App Store first-window fallback ordering window front")
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
    }
}
#endif

enum SavedApplicationStatePurger {
    private static let log = Logger(subsystem: "com.epistemos", category: "SavedApplicationState")

    static func shouldPurgeAtLaunch(
        processInfoEnvironment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        !VaultSyncService.shouldRestoreVaultFromBookmark(
            processInfoEnvironment: processInfoEnvironment
        )
    }

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
        PowerGate.recordMemoryPressureActive(false)

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
        PowerGate.recordMemoryPressureActive(false)

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
        Self.publishPowerGateMemoryPressure(transition)

        var metadata = currentEnvironmentMetadata()
        metadata["pressureSource"] = "dispatch_source"
        metadata["memoryScope"] = "process_resident"
        let residentMB = currentMemoryUsageMB()
        metadata["residentMB"] = String(residentMB)

        switch transition {
        case .entered(let level):
            metadata["level"] = level.rawValue
            let searchService = AppBootstrap.shared?.vaultSync.searchService
            let localInferenceService = level == .critical
                ? AppBootstrap.shared?.localInferenceService
                : nil
            let webViewIdle = EpdocWebViewShared.isIdleForMemoryPressure
            let isAppActive = NSApp.isActive
            Task.detached(priority: .utility) {
                await Self.performMemoryPressureRelief(
                    level: level,
                    residentMB: residentMB,
                    metadata: metadata,
                    searchService: searchService,
                    localInferenceService: localInferenceService,
                    webViewIdle: webViewIdle,
                    isAppActive: isAppActive
                )
            }
        case .recovered(let previousLevel):
            metadata["level"] = "normal"
            metadata["recoveredFrom"] = previousLevel.rawValue
            recordLifecycle("memory_pressure_recovered", metadata: metadata)
        }
    }

    private nonisolated static func performMemoryPressureRelief(
        level: MemoryPressureLevel,
        residentMB: Int,
        metadata initialMetadata: [String: String],
        searchService: SearchIndexService?,
        localInferenceService: MLXInferenceService?,
        webViewIdle: Bool,
        isAppActive: Bool
    ) async {
        var metadata = initialMetadata
        let relief = respondToMemoryPressure(level: level == .critical ? 2 : 1)
        metadata["rustSegmentsEvicted"] = String(relief.segmentsEvicted)
        metadata["rustSegmentBytesFreedMB"] = String(relief.segmentBytesFreed / (1024 * 1024))
        metadata["rustSessionsPruned"] = String(relief.sessionsPruned)

        if let searchService {
            searchService.releaseMemoryPressureCaches()
            metadata["searchIndexCachesReleased"] = "true"
        }
        if level == .critical, let localInferenceService {
            metadata["localModelUnloadRequested"] = "true"
            await localInferenceService.unload()
        }
        metadata["webViewIdle"] = webViewIdle ? "true" : "false"

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
                isAppActive: isAppActive
            )
        )
    }

    static func publishPowerGateMemoryPressure(_ transition: MemoryPressureTransition) {
        switch transition {
        case .entered:
            PowerGate.recordMemoryPressureActive(true)
        case .recovered:
            PowerGate.recordMemoryPressureActive(false)
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
    @State private var bootstrap: AppBootstrap
    @State private var showQuickCapture = false

    init() {
        let bootstrap = AppBootstrap()
        _bootstrap = State(initialValue: bootstrap)

        if SavedApplicationStatePurger.shouldPurgeAtLaunch() {
            SavedApplicationStatePurger.purgeIfNeeded()
        }
        if !Self.isRunningTests {
            CrashReportCollector.shared.startCollecting()
            RuntimeDiagnostics.logStorageLocations()
            _ = RuntimeDiagnostics.recordSessionStart(metadata: [
                "pid": "\(ProcessInfo.processInfo.processIdentifier)",
                "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
                "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            ])
            RuntimeIssueMonitor.shared.start()
            HomeWindowInputDiagnostics.shared.startIfNeeded()
            #if EPISTEMOS_APP_STORE
                AppStoreFirstWindowPresenter.shared.schedule(bootstrap: bootstrap)
            #endif
        }
    }

    var body: some Scene {
        WindowGroup("Epistemos") {
            homeSceneContent
        }
        .restorationBehavior(.disabled)
        .defaultSize(width: 1100, height: 720)
        .windowResizability(.contentMinSize)
        .modelContainer(bootstrap.modelContainer)
        .commands {
            EpistemosCommands(
                ui: bootstrap.uiState, chat: bootstrap.chatState, notesUI: bootstrap.notesUI,
                vaultSync: bootstrap.vaultSync)
        }

        // Knowledge Graph uses a full-screen hologram overlay (HologramController),
        // not a SwiftUI Window scene. Toggle with Cmd+Shift+G.
    }

    @ViewBuilder
    private var homeSceneContent: some View {
        if RuntimeAuditFlags.minimalHomeSceneEnabled {
            AuditMinimalHomeSceneView()
        } else {
            HomeSceneRootContent(bootstrap: bootstrap, showQuickCapture: $showQuickCapture)
        }
    }
}

// MARK: - App Delegate (Dock Menu + Native Hooks)

final class EpistemosAppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private static let isRunningTests =
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    private var didTeardown = false
    private static let showQuitDialogKey = "epistemos.showSaveOnQuitDialog"

    /// Local keyDown monitor for ⌘G that toggles the graph overlay even when
    /// the graph window has key focus and would normally swallow Cmd-G as
    /// "Find Next." `addLocalMonitorForEvents` returns a token that MUST be
    /// retained — without this stored property the monitor was being
    /// deallocated immediately and never fired (2026-05-19 fix).
    private var cmdGEventMonitor: Any?

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

    /// Audit gap F8 close-out (per
    /// `docs/audits/T+4_T+5_DEEP_AUDIT_2026-04-27.md`). Apple's
    /// NSDocumentController contract: "The first instance of
    /// NSDocumentController or any of its subclasses created during
    /// the launch of an application becomes the shared document
    /// controller." We instantiate `EpistemosDocumentController`
    /// here — BEFORE SwiftUI scene construction touches
    /// `NSDocumentController.shared` — so our subclass wins the
    /// `.shared` slot and every `EpdocDocument` opened thereafter
    /// gets dependency-injected with the readable-blocks FTS
    /// writer (wired in `applicationDidFinishLaunching` once
    /// AppBootstrap has produced the SearchIndexService).
    ///
    /// Per Option C explicit DI (vs Option B singleton) the
    /// controller starts with `databaseWriter = nil` and gracefully
    /// degrades — `EpdocDocument.projectAndIndexBlocks` is a no-op
    /// when the writer is unset, so opening a .epdoc before the
    /// pool is ready never crashes; the next save after wiring
    /// completes refreshes FTS.
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Claim the shared NSDocumentController slot. Discard the
        // returned reference — the framework retains it as `.shared`.
        _ = EpistemosDocumentController(databaseWriter: nil)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if Self.canConfigureUserNotificationCenter {
            UNUserNotificationCenter.current().delegate = self
        }

        // Audit gap F8 close-out — push the SearchIndexService
        // writer to the EpistemosDocumentController installed in
        // `applicationWillFinishLaunching`. By the time AppKit
        // calls didFinishLaunching, AppBootstrap (constructed
        // during SwiftUI scene init) has already produced the
        // shared SearchIndexService, so `vaultSync.searchService`
        // is reachable.
        //
        // Failure modes (all graceful):
        //   - shared controller is the default NSDocumentController
        //     (subclass init failed): downcast returns nil, wiring
        //     skipped, EpdocDocument stays in no-FTS mode.
        //   - AppBootstrap.shared not yet built: skip; the next
        //     bootstrap-completion hook can re-attempt.
        //   - vaultSync.searchService nil (vault not picked yet):
        //     skip; once the user opens a vault and SearchIndex
        //     spins up, the existing vault-change notification can
        //     re-attempt.
        if let controller = NSDocumentController.shared as? EpistemosDocumentController,
           let bootstrap = AppBootstrap.shared {
            controller.modelContainer = bootstrap.modelContainer
            if let searchService = bootstrap.vaultSync.searchService {
                controller.databaseWriter = searchService.databaseWriter()
            }
            Task { @MainActor in
                await controller.injectMissingDependenciesIntoOpenEpdocDocuments()
            }
        }
        if let bootstrap = AppBootstrap.shared {
            HologramController.shared.setup(
                graphState: bootstrap.graphState,
                queryEngine: bootstrap.queryEngine,
                modelContainer: bootstrap.modelContainer,
                physicsCoordinator: bootstrap.physicsCoordinator,
                dialogueChatState: bootstrap.dialogueChatState
            )
        }
        installKnowledgeGraphMenuFallback()
        Task { @MainActor in
            await Task.yield()
            self.installKnowledgeGraphMenuFallback()
        }
        // 2026-05-19: when the graph overlay window has key focus, the
        // responder chain eats Cmd+G (NSStandardKeyBindingResponding's
        // Find Next) before the menu item fires, so the toggle never
        // runs from inside the open graph. Install a local event monitor
        // that always handles ⌘G regardless of first responder. The
        // returned token MUST be retained — without storing it the
        // monitor is deallocated immediately and never fires (the bug
        // the user hit in the first attempt).
        cmdGEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let cmdOnly = event.modifierFlags
                .intersection([.command, .shift, .option, .control]) == .command
            guard cmdOnly,
                  event.charactersIgnoringModifiers?.lowercased() == "g"
            else { return event }
            HologramController.shared.toggle()
            return nil
        }
        guard !Self.isRunningTests else { return }

        #if EPISTEMOS_APP_STORE
            Logger(subsystem: "com.epistemos", category: "AppStoreFirstWindow")
                .info("App Store applicationDidFinishLaunching reached")
            AppStoreFirstWindowPresenter.shared.scheduleAfterLaunch()
        #endif
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !flag else { return true }
        #if EPISTEMOS_APP_STORE
            AppStoreFirstWindowPresenter.shared.ensureHomeWindow()
        #else
            HomeWindowIdentity.surfaceHomeWindow()
        #endif
        return true
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        false
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
        // RCA13 .epdoc persistence: drain every live save pipeline FIRST,
        // before anything else tears down. If a user typed and quit during
        // the 300ms debounce window, the in-flight keystroke would have
        // been dropped — NSDocument's dirty flag was set but the bytes
        // never reached fileWrapper(ofType:). flushNow() short-circuits
        // the debounce and saves synchronously.
        EpdocEditorSavePipeline.flushAllForShutdown()
        guard !Self.isRunningTests else {
            StatusBar.shared.remove()
            HologramController.shared.teardown()
            HomeWindowInputDiagnostics.shared.stop()
            return
        }
        RuntimeIssueMonitor.shared.stop(reason: "application_teardown")
        HomeWindowInputDiagnostics.shared.stop()
        guard let bootstrap = AppBootstrap.shared else { return }
        bootstrap.teardownRuntimeObservers()
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

    private func installKnowledgeGraphMenuFallback() {
        guard let viewMenu = NSApp.mainMenu?.item(withTitle: "View")?.submenu,
              let item = viewMenu.items.first(where: { $0.title == "Knowledge Graph" })
        else { return }
        item.target = self
        item.action = #selector(toggleKnowledgeGraphFromMenu(_:))
        item.keyEquivalent = "g"
        item.keyEquivalentModifierMask = [.command]

        if let revealItem = viewMenu.items.first(where: { $0.title == "Reveal Current Document in Graph" }) {
            revealItem.target = self
            revealItem.action = #selector(revealCurrentDocumentInKnowledgeGraph(_:))
        }
    }

    @objc private func toggleKnowledgeGraphFromMenu(_ sender: NSMenuItem) {
        HologramController.shared.toggle()
    }

    @objc func revealCurrentDocumentInKnowledgeGraph(_ sender: Any?) {
        guard let epdoc = activeEpdocDocument() else {
            HologramController.shared.toggle()
            return
        }
        HologramController.shared.revealDocument(epdoc.package.manifest.id)
    }

    private func activeEpdocDocument() -> EpdocDocument? {
        if let epdoc = NSDocumentController.shared.currentDocument as? EpdocDocument {
            return epdoc
        }
        let openEpdocs = NSDocumentController.shared.documents
            .compactMap { $0 as? EpdocDocument }
        if let activeWindowDocument = openEpdocs.first(where: { document in
                document.windowControllers.contains { controller in
                    guard let window = controller.window else { return false }
                    return window.isKeyWindow || window.isMainWindow
                }
            }) {
            return activeWindowDocument
        }
        return openEpdocs.count == 1 ? openEpdocs[0] : nil
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
            if let pageId = await vaultSync.createPage(title: "Untitled", allowVaultSelectionPrompt: true) {
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
    static let showQuickCapture = Notification.Name("epistemos.showQuickCapture")
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

            Button("Reveal Current Document in Graph") {
                (NSApp.delegate as? EpistemosAppDelegate)?
                    .revealCurrentDocumentInKnowledgeGraph(nil)
            }

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
            Button("New Document") {
                Task { @MainActor in
                    createEpdocDocument()
                }
            }
            .keyboardShortcut("n", modifiers: [.command, .option])

            Button("New Note") {
                Task { @MainActor in
                    if let pageId = await vaultSync.createPage(title: "Untitled", allowVaultSelectionPrompt: true) {
                        NoteWindowManager.shared.open(pageId: pageId)
                    }
                }
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("Quick Capture") {
                NotificationCenter.default.post(name: .showQuickCapture, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
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

    @MainActor
    private func createEpdocDocument() {
        do {
            try NSDocumentController.shared.createUntitledEpdocDocument(in: vaultSync.vaultURL)
        } catch {
            NSApplication.shared.presentError(error)
        }
    }

    // Save workspace UI is now handled via WorkspaceSavePanel (SwiftUI overlay).
}
