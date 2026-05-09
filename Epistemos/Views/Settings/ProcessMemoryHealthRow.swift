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

    init() {
        self._snapshot = State(initialValue: ProcessMemoryDiagnostics.liveSnapshot())
    }

    var body: some View {
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
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onAppear {
            snapshot = ProcessMemoryDiagnostics.liveSnapshot()
        }
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
