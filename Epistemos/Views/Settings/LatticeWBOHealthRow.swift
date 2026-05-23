import SwiftUI

// MARK: - LatticeWBOHealthRow
//
// Wiring #3 (T17B lattice/WBO → oplog) settings diagnostic. Renders
// the always-on accountant snapshot from Rust. Unlike Wirings #1/#2,
// this row carries no feature flag — the wiring is always live, so
// the row's status chip is purely a coverage indicator (entries
// accounted + tier + falsifier).
//
// Surfaces:
//   - total oplog appends accounted under the lattice/WBO ledger
//   - residency tier (L0RamHot, frozen by the substrate contract)
//   - falsifier coverage chip (F-WBO-DriftLedger)
//   - last accounted append: actor + timestamp
//
// Reads from `LatticeWBOBridge.snapshot()` on appear and on a 5s
// timer while the Settings sheet is open. The poll cadence is light
// because the snapshot is a single FFI mutex-guarded read.

@MainActor
public struct LatticeWBOHealthRow: View {

    @State private var stats: LatticeWBOStats = .empty
    @State private var lastReadAt: Date?

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            row(
                label: "Lattice/WBO accountant",
                symbol: "shield.lefthalf.filled",
                ok: true,
                detail: "Always-on per T17B (no feature flag) — \(stats.tier)"
            )
            row(
                label: "Appends accounted",
                symbol: "number",
                ok: true,
                detail: "\(stats.appendsAccounted) oplog mutation\(stats.appendsAccounted == 1 ? "" : "s") since process start"
            )
            row(
                label: "Falsifier coverage",
                symbol: "checkmark.shield",
                ok: !stats.falsifier.isEmpty && stats.falsifier != "—",
                detail: stats.falsifier
            )
            row(
                label: "Last accounted append",
                symbol: "clock.arrow.circlepath",
                ok: stats.lastActorId != nil,
                detail: lastAppendDetail
            )
        }
        .onAppear { refresh() }
        .task {
            // Light 5s poll while the row is on-screen. Cheap because
            // the snapshot read is a single FFI mutex acquire.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                refresh()
            }
        }
    }

    public func refresh() {
        if let snap = LatticeWBOBridge.snapshot() {
            stats = snap
            lastReadAt = Date()
        }
    }

    private var lastAppendDetail: String {
        guard let actor = stats.lastActorId else {
            return "(no appends yet this process)"
        }
        if let tsMs = stats.lastTsUnixMs {
            let date = Date(timeIntervalSince1970: TimeInterval(tsMs) / 1000)
            return "\(actor) — \(Self.relativeTime(date))"
        }
        return actor
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
