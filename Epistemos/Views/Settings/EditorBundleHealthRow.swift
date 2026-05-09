import SwiftUI

// MARK: - EditorBundleHealthRow
//
// Wave 7.17 settings diagnostic — read-only status rows for the
// W7.17 Tiptap WKWebView bundle + the W8.4 Halo Shadow backend.
// Surfaces in the Settings sheet so the user can verify their .app
// is fully wired without launching a doc.
//
// Per the W7.17 setup-research agent's 2026-04-26 verdict: NO
// rebuild button. NO auto-install. The .app ships the bundle
// pre-compiled inside Resources/Editor/; the user never runs npm.
// This view ONLY reports health — if something is missing the user
// re-installs the .app or rebuilds from source (`xcodebuild` runs
// the `build-tiptap-bundle.sh` chain automatically).

@MainActor
public struct EditorBundleHealthRow: View {

    @State private var bundleAvailable: Bool = false
    @State private var haloOpen: Bool = false
    @State private var haloPath: String? = nil

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            row(
                label: "Editor bundle",
                symbol: "doc.text",
                ok: bundleAvailable,
                detail: bundleAvailable ? "Resources/Editor/editor.html" : "Missing — rebuild the app"
            )
            row(
                label: "Halo backend",
                symbol: "circle.hexagongrid",
                ok: haloOpen,
                detail: haloOpen
                    ? haloPath ?? "Open"
                    : "No active vault selected - Shadow/Halo closed"
            )
        }
        .onAppear { refresh() }
    }

    /// Re-probe both health indicators. Called on view appearance +
    /// optionally exposed to a "Refresh" button if the host wants one.
    public func refresh() {
        bundleAvailable = Self.bundleIsAvailable()
        let halo = Self.haloStatus()
        haloOpen = halo.isOpen
        haloPath = halo.path
    }

    @ViewBuilder
    private func row(label: String, symbol: String, ok: Bool, detail: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 18, height: 18)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                Text(detail)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(ok ? AnyShapeStyle(Color.green) : AnyShapeStyle(Color.red))
                .font(.system(size: 16))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Health probes

    /// True iff `Resources/Editor/editor.html` exists in the app
    /// bundle. Mirrors the lookup `EpdocEditorURLSchemeHandler` does
    /// at every WKWebView load, so a `false` here predicts a runtime
    /// "asset not found" the moment a doc opens.
    static func bundleIsAvailable() -> Bool {
        Bundle.main.url(
            forResource: "editor",
            withExtension: "html",
            subdirectory: "Editor"
        ) != nil
    }

    /// Read the Halo backend state. Returns (isOpen, path?) — we
    /// avoid binding to the Rust crate's static singleton directly
    /// to keep this view dependency-light. The host can update the
    /// `EpdocEditorChromeController` or a UserDefaults key when the
    /// Swift bootstrap calls `shadow_open_at(path)`; this read
    /// surfaces that flag.
    static func haloStatus() -> (isOpen: Bool, path: String?) {
        let path = UserDefaults.standard.string(forKey: "epistemos.halo.openPath")
        let opened = UserDefaults.standard.bool(forKey: "epistemos.halo.isOpen")
        return (opened, path)
    }

    /// Convenience the bootstrap calls after a successful
    /// `shadow_open_at(path)` so this diagnostic surfaces the path.
    public static func recordHaloOpened(at path: String) {
        UserDefaults.standard.set(true, forKey: "epistemos.halo.isOpen")
        UserDefaults.standard.set(path, forKey: "epistemos.halo.openPath")
    }

    public static func recordHaloClosed() {
        UserDefaults.standard.set(false, forKey: "epistemos.halo.isOpen")
        UserDefaults.standard.removeObject(forKey: "epistemos.halo.openPath")
    }
}

// MARK: - BackgroundIndexingHealthRow

nonisolated public enum BackgroundIndexingPauseReason: String, Sendable, Equatable {
    case battery = "on battery"
    case thermal = "thermal pressure"
    case lowPower = "low power mode"
    case memoryPressure = "memory pressure"
    case backgroundPolicy = "background work deferred"
}

@MainActor
public struct BackgroundIndexingHealthRow: View {
    @State private var snapshot: Snapshot

    private let refreshInterval: TimeInterval

    public init(refreshInterval: TimeInterval = 1.0) {
        self.refreshInterval = refreshInterval
        self._snapshot = State(initialValue: Self.snapshot())
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            row(
                label: "Background indexing",
                symbol: snapshot.symbol,
                ok: snapshot.isHealthy,
                detail: snapshot.detail
            )
        }
        .onAppear { refresh() }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(refreshInterval))
                refresh()
            }
        }
    }

    public func refresh() {
        snapshot = Self.snapshot()
    }

    @ViewBuilder
    private func row(label: String, symbol: String, ok: Bool, detail: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 18, height: 18)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                Text(detail)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(ok ? AnyShapeStyle(Color.green) : AnyShapeStyle(Color.red))
                .font(.system(size: 16))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Recorder

    public static func recordUnavailable(reason: String, defaults: UserDefaults = .standard) {
        write(
            phase: .unavailable,
            vaultPath: nil,
            shadowPath: nil,
            domain: nil,
            enqueued: 0,
            total: 0,
            error: reason,
            defaults: defaults
        )
        clearEtlStats(defaults: defaults)
    }

    public static func recordStarted(
        vaultPath: String,
        shadowPath: String,
        defaults: UserDefaults = .standard
    ) {
        write(
            phase: .scanning,
            vaultPath: vaultPath,
            shadowPath: shadowPath,
            domain: nil,
            enqueued: 0,
            total: -1,
            error: nil,
            defaults: defaults
        )
        clearEtlStats(defaults: defaults)
    }

    public static func recordProgress(
        _ progress: ShadowVaultBootstrapProgress,
        vaultPath: String,
        shadowPath: String,
        defaults: UserDefaults = .standard
    ) {
        write(
            phase: progress.isComplete ? .complete : .indexing,
            vaultPath: vaultPath,
            shadowPath: shadowPath,
            domain: progress.domain.displayName,
            enqueued: progress.enqueued,
            total: progress.total,
            error: nil,
            defaults: defaults
        )
    }

    public static func recordComplete(
        vaultPath: String,
        shadowPath: String,
        defaults: UserDefaults = .standard
    ) {
        write(
            phase: .complete,
            vaultPath: vaultPath,
            shadowPath: shadowPath,
            domain: nil,
            enqueued: 0,
            total: 0,
            error: nil,
            defaults: defaults
        )
    }

    public static func recordFailed(
        vaultPath: String?,
        shadowPath: String?,
        error: String,
        defaults: UserDefaults = .standard
    ) {
        write(
            phase: .failed,
            vaultPath: vaultPath,
            shadowPath: shadowPath,
            domain: nil,
            enqueued: 0,
            total: 0,
            error: error,
            defaults: defaults
        )
        clearEtlStats(defaults: defaults)
    }

    public static func recordPaused(
        vaultPath: String?,
        shadowPath: String?,
        reason: BackgroundIndexingPauseReason,
        defaults: UserDefaults = .standard
    ) {
        write(
            phase: .paused,
            vaultPath: vaultPath,
            shadowPath: shadowPath,
            domain: nil,
            enqueued: 0,
            total: 0,
            error: reason.rawValue,
            defaults: defaults
        )
    }

    public static func recordEtlQueueStats(
        _ stats: EtlQueueStatsSnapshot,
        queuePath: String,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(queuePath, forKey: Keys.etlQueuePath)
        defaults.set(stats.available, forKey: Keys.etlAvailable)
        defaults.set(Int(clamping: stats.total), forKey: Keys.etlTotal)
        defaults.set(Int(clamping: stats.pending), forKey: Keys.etlPending)
        defaults.set(Int(clamping: stats.running), forKey: Keys.etlRunning)
        defaults.set(Int(clamping: stats.done), forKey: Keys.etlDone)
        defaults.set(Int(clamping: stats.failed), forKey: Keys.etlFailed)
        defaults.set(Int(clamping: stats.killed), forKey: Keys.etlKilled)
        defaults.set(Int(clamping: stats.active), forKey: Keys.etlActive)
        defaults.set(Int(clamping: stats.completed), forKey: Keys.etlCompleted)
        defaults.set(stats.error, forKey: Keys.etlError)
        defaults.set(Date(), forKey: Keys.updatedAt)
    }

    public static func snapshot(defaults: UserDefaults = .standard) -> Snapshot {
        let phase = Phase(
            rawValue: defaults.string(forKey: Keys.phase) ?? Phase.unavailable.rawValue
        ) ?? .unavailable
        return Snapshot(
            phase: phase,
            vaultPath: defaults.string(forKey: Keys.vaultPath),
            shadowPath: defaults.string(forKey: Keys.shadowPath),
            domain: defaults.string(forKey: Keys.domain),
            enqueued: defaults.integer(forKey: Keys.enqueued),
            total: defaults.object(forKey: Keys.total) as? Int ?? -1,
            updatedAt: defaults.object(forKey: Keys.updatedAt) as? Date,
            error: defaults.string(forKey: Keys.error),
            etlQueuePath: defaults.string(forKey: Keys.etlQueuePath),
            etlAvailable: defaults.bool(forKey: Keys.etlAvailable),
            etlTotal: defaults.integer(forKey: Keys.etlTotal),
            etlPending: defaults.integer(forKey: Keys.etlPending),
            etlRunning: defaults.integer(forKey: Keys.etlRunning),
            etlDone: defaults.integer(forKey: Keys.etlDone),
            etlFailed: defaults.integer(forKey: Keys.etlFailed),
            etlKilled: defaults.integer(forKey: Keys.etlKilled),
            etlActive: defaults.integer(forKey: Keys.etlActive),
            etlCompleted: defaults.integer(forKey: Keys.etlCompleted),
            etlError: defaults.string(forKey: Keys.etlError)
        )
    }

    public static func reset(defaults: UserDefaults = .standard) {
        for key in Keys.all {
            defaults.removeObject(forKey: key)
        }
    }

    private static func write(
        phase: Phase,
        vaultPath: String?,
        shadowPath: String?,
        domain: String?,
        enqueued: Int,
        total: Int,
        error: String?,
        defaults: UserDefaults
    ) {
        defaults.set(phase.rawValue, forKey: Keys.phase)
        defaults.set(vaultPath, forKey: Keys.vaultPath)
        defaults.set(shadowPath, forKey: Keys.shadowPath)
        defaults.set(domain, forKey: Keys.domain)
        defaults.set(enqueued, forKey: Keys.enqueued)
        defaults.set(total, forKey: Keys.total)
        defaults.set(Date(), forKey: Keys.updatedAt)
        defaults.set(error, forKey: Keys.error)
    }

    private static func clearEtlStats(defaults: UserDefaults) {
        for key in Keys.etlAll {
            defaults.removeObject(forKey: key)
        }
    }

    public enum Phase: String, Sendable {
        case unavailable
        case scanning
        case indexing
        case paused
        case complete
        case failed
    }

    public struct Snapshot: Equatable, Sendable {
        public let phase: Phase
        public let vaultPath: String?
        public let shadowPath: String?
        public let domain: String?
        public let enqueued: Int
        public let total: Int
        public let updatedAt: Date?
        public let error: String?
        public let etlQueuePath: String?
        public let etlAvailable: Bool
        public let etlTotal: Int
        public let etlPending: Int
        public let etlRunning: Int
        public let etlDone: Int
        public let etlFailed: Int
        public let etlKilled: Int
        public let etlActive: Int
        public let etlCompleted: Int
        public let etlError: String?

        var isHealthy: Bool {
            switch phase {
            case .scanning, .indexing, .complete:
                return true
            case .unavailable, .paused, .failed:
                return false
            }
        }

        var symbol: String {
            switch phase {
            case .unavailable:
                return "pause.circle"
            case .scanning:
                return "magnifyingglass.circle"
            case .indexing:
                return "arrow.triangle.2.circlepath.circle"
            case .paused:
                return "pause.circle"
            case .complete:
                return "checkmark.seal"
            case .failed:
                return "exclamationmark.triangle"
            }
        }

        var detail: String {
            switch phase {
            case .unavailable:
                return error ?? "No active vault selected - cached local note/graph data only"
            case .scanning:
                return appendEtlDetail(to: vaultPath.map { "Scanning \($0)" } ?? "Scanning active vault")
            case .indexing:
                return appendEtlDetail(to: progressDetail(prefix: "Indexing"))
            case .paused:
                return appendEtlDetail(to: error.map { "Paused - \($0)" } ?? "Paused")
            case .complete:
                return appendEtlDetail(to: shadowPath.map { "Complete — \($0)" } ?? "Complete")
            case .failed:
                return error.map { "Failed — \($0)" } ?? "Failed"
            }
        }

        private func progressDetail(prefix: String) -> String {
            let target = domain ?? "vault"
            if total < 0 {
                return "\(prefix) \(target): scanning…"
            }
            return "\(prefix) \(target): \(enqueued)/\(total)"
        }

        private func appendEtlDetail(to base: String) -> String {
            guard let etlDetail else { return base }
            return "\(base) | \(etlDetail)"
        }

        private var etlDetail: String? {
            guard etlQueuePath != nil else { return nil }
            if !etlAvailable {
                if let etlError, etlError.contains("does not exist") {
                    return "ETL not started"
                }
                return etlError.map { "ETL unavailable: \($0)" } ?? "ETL unavailable"
            }
            if etlActive > 0 {
                return "ETL \(etlPending) pending, \(etlRunning) running"
            }
            if etlFailed > 0 || etlKilled > 0 {
                return "ETL \(etlDone)/\(etlTotal) done, \(etlFailed + etlKilled) failed"
            }
            return "ETL \(etlDone)/\(etlTotal) done"
        }
    }

    private enum Keys {
        static let phase = "epistemos.backgroundIndexing.phase"
        static let vaultPath = "epistemos.backgroundIndexing.vaultPath"
        static let shadowPath = "epistemos.backgroundIndexing.shadowPath"
        static let domain = "epistemos.backgroundIndexing.domain"
        static let enqueued = "epistemos.backgroundIndexing.enqueued"
        static let total = "epistemos.backgroundIndexing.total"
        static let updatedAt = "epistemos.backgroundIndexing.updatedAt"
        static let error = "epistemos.backgroundIndexing.error"
        static let etlQueuePath = "epistemos.backgroundIndexing.etl.queuePath"
        static let etlAvailable = "epistemos.backgroundIndexing.etl.available"
        static let etlTotal = "epistemos.backgroundIndexing.etl.total"
        static let etlPending = "epistemos.backgroundIndexing.etl.pending"
        static let etlRunning = "epistemos.backgroundIndexing.etl.running"
        static let etlDone = "epistemos.backgroundIndexing.etl.done"
        static let etlFailed = "epistemos.backgroundIndexing.etl.failed"
        static let etlKilled = "epistemos.backgroundIndexing.etl.killed"
        static let etlActive = "epistemos.backgroundIndexing.etl.active"
        static let etlCompleted = "epistemos.backgroundIndexing.etl.completed"
        static let etlError = "epistemos.backgroundIndexing.etl.error"
        static let etlAll = [
            etlQueuePath,
            etlAvailable,
            etlTotal,
            etlPending,
            etlRunning,
            etlDone,
            etlFailed,
            etlKilled,
            etlActive,
            etlCompleted,
            etlError,
        ]
        static let all = [
            phase,
            vaultPath,
            shadowPath,
            domain,
            enqueued,
            total,
            updatedAt,
            error,
        ] + etlAll
    }
}

private extension ShadowVaultDomain {
    var displayName: String {
        switch self {
        case .notes:
            return "notes"
        case .chats:
            return "chats"
        }
    }
}

#if DEBUG
#Preview("EditorBundleHealthRow — both ready") {
    EditorBundleHealthRow.recordHaloOpened(at: "/Users/jojo/Library/Application Support/Epistemos/shadow")
    return EditorBundleHealthRow()
        .padding()
        .frame(width: 480)
}

#Preview("EditorBundleHealthRow — both missing") {
    EditorBundleHealthRow.recordHaloClosed()
    return EditorBundleHealthRow()
        .padding()
        .frame(width: 480)
}

#Preview("BackgroundIndexingHealthRow — indexing") {
    BackgroundIndexingHealthRow.recordStarted(
        vaultPath: "/Users/jojo/Notes",
        shadowPath: "/Users/jojo/Notes/.epcache/shadow"
    )
    return BackgroundIndexingHealthRow()
        .padding()
        .frame(width: 480)
}
#endif
