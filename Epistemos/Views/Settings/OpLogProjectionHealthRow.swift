import SwiftUI

// MARK: - OpLogProjectionHealthRow
//
// Read-only diagnostics for the EventStore -> Rust OpLog projection spine.
// This surfaces dead-letter state without creating a repair/retry UI or putting
// raw Rust OpLog ABI calls in Settings.

@MainActor
struct OpLogProjectionHealthRow: View {
    @State private var snapshot: EventStore.MutationProjectionOutboxDiagnostics
    @State private var replayBundleReport: MutationOpLogReplayBundleVisibilityReport

    init() {
        _snapshot = State(initialValue: Self.snapshot())
        _replayBundleReport = State(initialValue: Self.replayBundleReport())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            row(
                label: "OpLog projection",
                symbol: snapshot.deadLetteredRows == 0 ? "link.badge.plus" : "exclamationmark.triangle",
                ok: snapshot.deadLetteredRows == 0,
                detail: projectionDetail
            )
            row(
                label: "Dead letters",
                symbol: snapshot.deadLetteredRows == 0 ? "checkmark.seal" : "tray.full",
                ok: snapshot.deadLetteredRows == 0,
                detail: deadLetterDetail
            )
            row(
                label: "ReplayBundle",
                symbol: replayBundleReport.status == .unavailable ? "xmark.octagon" : "doc.badge.gearshape",
                ok: replayBundleReport.status != .unavailable,
                detail: replayBundleDetail
            )
        }
        .onAppear { refresh() }
    }

    func refresh() {
        snapshot = Self.snapshot()
        replayBundleReport = Self.replayBundleReport()
    }

    private static func snapshot() -> EventStore.MutationProjectionOutboxDiagnostics {
        EventStore.shared?.mutationProjectionOutboxDiagnostics() ?? .empty
    }

    private static func replayBundleReport() -> MutationOpLogReplayBundleVisibilityReport {
        MutationOpLogReplayBundleVisibilityReport.load()
    }

    private var projectionDetail: String {
        guard snapshot.totalRows > 0 else {
            return "No mutation projection rows yet"
        }
        return "\(snapshot.projectedRows) projected · \(snapshot.pendingRows) pending · \(snapshot.leasedRows) leased · \(snapshot.deadLetteredRows) dead"
    }

    private var deadLetterDetail: String {
        guard snapshot.deadLetteredRows > 0 else {
            return "No dead-lettered projection rows"
        }
        guard let row = snapshot.latestDeadLetter else {
            return "\(snapshot.deadLetteredRows) dead-lettered row(s)"
        }

        let reason = row.deadLetterReason ?? "unknown"
        let mutation = row.mutationID.isEmpty ? "unknown" : String(row.mutationID.prefix(12))
        if let lastError = row.lastError, !lastError.isEmpty {
            return "\(mutation) · \(reason) · \(lastError)"
        }
        return "\(mutation) · \(reason)"
    }

    private var replayBundleDetail: String {
        switch replayBundleReport.status {
        case .unavailable:
            return "ReplayBundle unavailable"
        case .empty:
            return [
                "ReplayBundle empty",
                "replayedEntryCount 0",
                "recordCount 0",
                "duplicateCount 0",
                "ignoredNonProjectionCount 0",
            ].joined(separator: " · ")
        case .available:
            let latest = replayBundleReport.latestMutationID.map { String($0.prefix(12)) } ?? "none"
            let highestSeq = replayBundleReport.highestReplayedSeq.map { String($0) } ?? "none"
            return [
                "replayedEntryCount \(replayBundleReport.replayedEntryCount)",
                "recordCount \(replayBundleReport.recordCount)",
                "duplicateCount \(replayBundleReport.duplicateCount)",
                "ignoredNonProjectionCount \(replayBundleReport.ignoredNonProjectionCount)",
                "seq \(highestSeq)",
                "latest \(latest)",
            ].joined(separator: " · ")
        }
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
