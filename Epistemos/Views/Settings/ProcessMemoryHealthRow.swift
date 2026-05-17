import Darwin.Mach
import SwiftUI

// MARK: - ProcessMemoryHealthRow
//
// Read-only v1 diagnostics for the idle-memory regression ledger. This reports
// the process resident footprint and the app-wide memory-pressure flag.
// It does not attempt to classify root allocations or replace an Instruments pass.

nonisolated enum ProcessMemoryDiagnostics {
    struct Snapshot: Equatable, Sendable {
        enum Status: Equatable, Sendable {
            case unavailable
            case nominal
            case elevated
            case pressure
        }

        let residentBytes: UInt64?
        let physicalMemoryBytes: UInt64
        let residentFraction: Double?
        let memoryPressureActive: Bool
        let status: Status
        let detail: String

        var ok: Bool {
            status == .nominal || status == .elevated
        }
    }

    @MainActor
    static func liveSnapshot() -> Snapshot {
        snapshot(
            residentBytes: currentResidentBytes(),
            physicalMemoryBytes: ProcessInfo.processInfo.physicalMemory,
            memoryPressureActive: PowerGate.isMemoryPressureActive
        )
    }

    static func snapshot(
        residentBytes: UInt64?,
        physicalMemoryBytes: UInt64,
        memoryPressureActive: Bool
    ) -> Snapshot {
        let fraction = residentBytes.flatMap { bytes -> Double? in
            guard physicalMemoryBytes > 0 else { return nil }
            return Double(bytes) / Double(physicalMemoryBytes)
        }
        let status: Snapshot.Status
        if residentBytes == nil {
            status = .unavailable
        } else if memoryPressureActive {
            status = .pressure
        } else if (fraction ?? 0) >= 0.30 {
            status = .elevated
        } else {
            status = .nominal
        }

        let residentLabel = residentBytes.map(byteCount(_:)) ?? "unavailable"
        let physicalLabel = byteCount(physicalMemoryBytes)
        let ratioLabel = fraction.map { String(format: "%.1f%%", $0 * 100) } ?? "unknown"
        let pressureLabel = memoryPressureActive ? "memory pressure active" : "pressure clear"
        return Snapshot(
            residentBytes: residentBytes,
            physicalMemoryBytes: physicalMemoryBytes,
            residentFraction: fraction,
            memoryPressureActive: memoryPressureActive,
            status: status,
            detail: "RSS \(residentLabel) of \(physicalLabel) unified · \(ratioLabel) · \(pressureLabel)"
        )
    }

    static func currentResidentBytes() -> UInt64? {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return UInt64(info.resident_size)
    }

    private static func byteCount(_ value: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: value), countStyle: .memory)
    }
}

@MainActor
struct ProcessMemoryHealthRow: View {
    @State private var snapshot: ProcessMemoryDiagnostics.Snapshot

    // ISSUE-2026-05-12-006: in-app substitute for Instruments → Allocations.
    // Tap "Force Idle Unload" to run the same sequence the critical
    // memory-pressure handler runs, then see the RSS delta in the row.
    // Lets users diagnose the 2GB idle regression without running
    // Instruments themselves.
    @State private var lastReport: AppBootstrap.IdleUnloadReport?
    @State private var unloadInFlight: Bool = false

    init() {
        self._snapshot = State(initialValue: ProcessMemoryDiagnostics.liveSnapshot())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 18, height: 18)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Process memory")
                        .font(.system(size: 13, weight: .medium))
                    Text(snapshot.detail)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Image(systemName: statusIconName)
                    .foregroundStyle(statusStyle)
                    .font(.system(size: 16))
            }
            // UI/UX audit 2026-05-17 iter-12 CC-1 remainder: apply the
            // shared a11y modifier to the status HStack only — NOT the
            // outer VStack — so VoiceOver still reaches the Force Idle
            // Unload Button below as an independent element.
            .diagnosticsRowAccessibility(
                label: "Process memory",
                detail: snapshot.detail,
                isHealthy: snapshot.status == .nominal
            )

            // Force-unload diagnostic: tap to run the critical-pressure
            // unload sequence on demand. Reports MB freed + per-subsystem
            // contribution. Use this to diagnose the 2GB idle regression.
            HStack(spacing: 8) {
                Button(action: triggerForceIdleUnload) {
                    HStack(spacing: 4) {
                        if unloadInFlight {
                            ProgressView()
                                .controlSize(.mini)
                        }
                        Text(unloadInFlight ? "Unloading…" : "Force Idle Unload")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(unloadInFlight || AppBootstrap.shared == nil)

                if let lastReport {
                    Text(reportSummary(lastReport))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onAppear {
            snapshot = ProcessMemoryDiagnostics.liveSnapshot()
        }
    }

    private func triggerForceIdleUnload() {
        guard let bootstrap = AppBootstrap.shared else { return }
        unloadInFlight = true
        Task { @MainActor in
            let report = await bootstrap.forceIdleUnload()
            // Refresh the snapshot so the "after" RSS shows in the row.
            snapshot = ProcessMemoryDiagnostics.liveSnapshot()
            lastReport = report
            unloadInFlight = false
        }
    }

    private func reportSummary(_ report: AppBootstrap.IdleUnloadReport) -> String {
        // Compact one-line summary so the row stays short. Detail is
        // available in Console.app under com.epistemos.app.Log.app.
        let mlx = report.mlxUnloaded ? "MLX✓" : "MLX⨯"
        let search = report.searchCachesReleased ? "Search✓" : "Search⨯"
        let rust = "Rust\(report.rustSegmentsEvicted)seg/\(report.rustSessionsPruned)sess"
        return "Freed \(report.mbFreed) MB · \(mlx) · \(search) · \(rust) · \(report.durationMs) ms"
    }

    private var iconName: String {
        snapshot.memoryPressureActive ? "memorychip.fill" : "memorychip"
    }

    private var statusIconName: String {
        switch snapshot.status {
        case .nominal:
            "checkmark.circle.fill"
        case .elevated:
            "info.circle.fill"
        case .pressure, .unavailable:
            "exclamationmark.triangle.fill"
        }
    }

    private var statusStyle: AnyShapeStyle {
        switch snapshot.status {
        case .nominal:
            AnyShapeStyle(Color.green)
        case .elevated:
            AnyShapeStyle(Color.orange)
        case .pressure, .unavailable:
            AnyShapeStyle(Color.red)
        }
    }
}
