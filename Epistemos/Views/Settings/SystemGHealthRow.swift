import SwiftUI

// MARK: - SystemGHealthRow
//
// Wiring #4 (T11 System G / Agent Runtime v2 → LocalAgentLoop) settings
// diagnostic. Mirrors the EidosHealthRow / VaultRecallHealthRow /
// LatticeWBOHealthRow shape so Settings -> Diagnostics renders in one
// vocabulary across substrate health surfaces.
//
// Surfaces:
//   - flag state (`EPISTEMOS_SYSTEM_G_V0`)
//   - active mode from Rust (`Disabled` on MAS; `IpcBounded` on Pro;
//     `Subprocess` on Pro Research)
//   - allows_execution / allows_subprocess capability chips
//   - build tier (mas / pro)
//   - last read timestamp + total reads
//   - last error (if any)
//
// Reads from `SystemGMetrics.shared` (populated by
// `SystemGBridge.status()`). The row triggers one status read on appear
// + on the `didChangeNotification` event so we never poll.

@MainActor
public struct SystemGHealthRow: View {

    @State private var snapshot: SystemGMetrics.Snapshot
    @State private var registryStats: SystemGRegistryStats?
    @State private var registryError: String?
    @State private var refreshTask: Task<Void, Never>?

    public init() {
        self._snapshot = State(initialValue: SystemGMetrics.shared.snapshot())
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            row(
                label: "System G flag",
                symbol: "flag.fill",
                ok: snapshot.isFlagEnabled,
                detail: snapshot.isFlagEnabled
                    ? "EPISTEMOS_SYSTEM_G_V0 on (LocalAgentLoop breadcrumb active)"
                    : "EPISTEMOS_SYSTEM_G_V0 off (no breadcrumb)"
            )
            VerifiedFloorChipStrip(
                flag: snapshot.isFlagEnabled ? "on" : "off",
                substrate: "real seam · falsifier pending",
                productionWired: snapshot.lastStatus != nil && registryError == nil,
                falsifierPassed: false,
                falsifier: "docs/falsifiers/F-ActiveAssembly-Minimal_2026_05_17.md",
                wiredToday: "RealSystemGRunSeam is registered and registry stats are readable when FFI is available.",
                stillStub: "ActiveAssembly/System G green remains blocked until a primary PASS falsifier witness exists."
            )
            row(
                label: "Runtime mode",
                symbol: "cpu",
                ok: snapshot.lastStatus != nil,
                detail: modeDetail
            )
            row(
                label: "Capability gates",
                symbol: "checkmark.shield",
                ok: snapshot.lastStatus?.mode != .subprocess,
                detail: capabilityDetail
            )
            row(
                label: "Dispatch registry",
                symbol: "tray.full",
                ok: registryError == nil,
                detail: registryDetail
            )
            row(
                label: "Last status read",
                symbol: "clock",
                ok: snapshot.lastReadAt != nil && snapshot.lastErrorDescription == nil,
                detail: readDetail
            )
            if let err = snapshot.lastErrorDescription {
                row(
                    label: "Last error",
                    symbol: "exclamationmark.triangle",
                    ok: false,
                    detail: err
                )
            }
        }
        .onAppear {
            _ = SystemGBridge.status()
            refresh()
            startTimer()
        }
        .onDisappear {
            refreshTask?.cancel()
            refreshTask = nil
        }
        .onReceive(NotificationCenter.default.publisher(
            for: SystemGMetrics.didChangeNotification,
            object: SystemGMetrics.shared
        )) { _ in
            Task { @MainActor in
                refresh()
            }
        }
    }

    public func refresh() {
        // SS-SH phase 2: the local Metrics read stays on-main (cheap); the Rust
        // registryStats() FFI moves OFF the MainActor (nonisolated bridge) so the 1Hz
        // poll can't block the panel. The Result's Error isn't Sendable, so map to a
        // Sendable (stats?, error?) before hopping back; a failure keeps the last-good
        // stats (unchanged behavior).
        snapshot = SystemGMetrics.shared.snapshot()
        Task {
            let outcome = await Task.detached { () -> (stats: SystemGRegistryStats?, error: String?) in
                switch SystemGBridge.registryStats() {
                case .success(let stats):
                    return (stats, nil)
                case .failure(let error):
                    return (nil, String(describing: error))
                }
            }.value
            if let stats = outcome.stats {
                registryStats = stats
                registryError = nil
            } else {
                registryError = outcome.error
            }
        }
    }

    private var registryDetail: String {
        if let err = registryError {
            return "Error: \(err)"
        }
        guard let stats = registryStats else {
            return "(no read yet)"
        }
        return "in-flight \(stats.inFlight)/\(stats.maxConcurrentRuns) · parked \(stats.total - stats.inFlight) · \(stats.totalDispatchedSinceLaunch) since launch"
    }

    private func startTimer() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { break }
                _ = SystemGBridge.status()
                refresh()
            }
        }
    }

    private var modeDetail: String {
        guard let status = snapshot.lastStatus else {
            return "(no status read yet)"
        }
        return "\(status.mode.rawValue) (\(status.buildTier))"
    }

    private var capabilityDetail: String {
        guard let status = snapshot.lastStatus else {
            return "(unknown)"
        }
        let exec = status.allowsExecution ? "exec✓" : "exec✗"
        let sub = status.allowsSubprocess ? "subprocess✓" : "subprocess✗"
        return "\(exec) \(sub) (run seam: real Rust dispatch via systemGStartRunJson + systemGDrainEventsJson)"
    }

    private var readDetail: String {
        if let err = snapshot.lastErrorDescription, snapshot.lastReadAt == nil {
            return "Error: \(err)"
        }
        guard let date = snapshot.lastReadAt else {
            return "No reads yet"
        }
        return "\(Self.relativeTime(date)) — \(snapshot.totalReads) total"
    }

    private static func relativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 1 { return "just now" }
        if interval < 60 { return "\(Int(interval))s ago" }
        if interval < 3_600 { return "\(Int(interval / 60))m ago" }
        return "\(Int(interval / 3_600))h ago"
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
}
