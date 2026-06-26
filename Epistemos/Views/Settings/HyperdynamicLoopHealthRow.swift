import SwiftUI

// MARK: - HyperdynamicLoopHealthRow
//
// Terminal S (2026-05-24) — Hyperdynamic Schema Loop primitive health
// surface. Mirrors ACSAdmissionHealthRow / FUlpHealthRow / EidosHealthRow
// shape: read-only chip strip + per-loop-kind rows.
//
// Per the Terminal S acceptance bar in
// docs/PHASE_2_TERMINAL_PROMPTS_2026_05_23.md §Terminal S, the chip
// strip surfaces:
//   per loop kind: total drafts · accepted · repaired · quarantined ·
//   avg repair count
//
// The Rust trait + RepairBudget + LoopCounters live in
// agent_core::hyperdynamic_loop (committed 8572ae961c, 405fa8bba7).
// The FFI bridge that streams LoopCounters → HyperdynamicLoopMetrics
// is wired in a follow-up iter. Until that lands, the row reports
// "no read yet" and the chips show ·.

@MainActor
public struct HyperdynamicLoopHealthRow: View {

    @State private var snapshot: HyperdynamicLoopMetrics.Snapshot
    @State private var refreshTask: Task<Void, Never>?

    public init() {
        self._snapshot = State(initialValue: HyperdynamicLoopMetrics.shared.snapshot())
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            row(
                label: "Hyperdynamic loop",
                symbol: "arrow.triangle.2.circlepath",
                ok: snapshot.anyBackendReady,
                detail: snapshot.anyBackendReady
                    ? "schema/admission/witness repair loops armed"
                    : "no read yet (loop bridge not yet wired)"
            )
            chipStrip(
                label: "schema_repair",
                stats: snapshot.schemaRepair
            )
            chipStrip(
                label: "admission_repair",
                stats: snapshot.admissionRepair
            )
            chipStrip(
                label: "witness_repair",
                stats: snapshot.witnessRepair
            )
            row(
                label: "Repair budget",
                symbol: "timer",
                ok: true,
                detail: "default: min(3 retries, 5 s, 1024 tokens)"
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
            refresh()
            startTimer()
        }
        .onDisappear {
            refreshTask?.cancel()
            refreshTask = nil
        }
        .onReceive(NotificationCenter.default.publisher(
            for: HyperdynamicLoopMetrics.didChangeNotification,
            object: HyperdynamicLoopMetrics.shared
        )) { _ in
            Task { @MainActor in
                refresh()
            }
        }
    }

    public func refresh() {
        snapshot = HyperdynamicLoopMetrics.shared.snapshot()
    }

    private func startTimer() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: SubstrateHealthClock.defaultPollInterval)
                if Task.isCancelled { break }
                refresh()
            }
        }
    }

    @ViewBuilder
    private func chipStrip(label: String, stats: HyperdynamicLoopMetrics.LoopStats) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                chip("drafts", value: stats.drafts)
                chip("accepted", value: stats.accepted)
                chip("repaired", value: stats.repaired)
                chip("quarantined", value: stats.quarantined)
                chip(
                    "avg",
                    value: nil,
                    text: String(format: "%.2f", stats.avgRepairCount)
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func chip(_ label: String, value: UInt64?, text: String? = nil) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.system(size: 9, weight: .regular, design: .monospaced))
                .foregroundStyle(.tertiary)
            Text(text ?? (value.map { String($0) } ?? "·"))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.tertiary.opacity(0.4), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
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

// MARK: - HyperdynamicLoopMetrics
//
// Lives in the same file because Terminal S's designated-file scope
// caps Swift surface to HyperdynamicLoopHealthRow.swift. Once the FFI
// bridge for LoopCounters is wired, the singleton's `ingest(...)`
// method consumes counter snapshots from the Rust side and posts
// `didChangeNotification` to refresh the row.

@MainActor
public final class HyperdynamicLoopMetrics: ObservableObject {

    public static let shared = HyperdynamicLoopMetrics()
    public static let didChangeNotification = Notification.Name(
        "HyperdynamicLoopMetricsDidChange"
    )

    public struct LoopStats: Sendable, Equatable {
        public var drafts: UInt64
        public var accepted: UInt64
        public var repaired: UInt64
        public var quarantined: UInt64
        public var totalRepairAttempts: UInt64

        public init(
            drafts: UInt64 = 0,
            accepted: UInt64 = 0,
            repaired: UInt64 = 0,
            quarantined: UInt64 = 0,
            totalRepairAttempts: UInt64 = 0
        ) {
            self.drafts = drafts
            self.accepted = accepted
            self.repaired = repaired
            self.quarantined = quarantined
            self.totalRepairAttempts = totalRepairAttempts
        }

        public static let empty = LoopStats()

        public var avgRepairCount: Double {
            let finalized = accepted + quarantined
            guard finalized > 0 else { return 0.0 }
            return Double(totalRepairAttempts) / Double(finalized)
        }

        public var anyActivity: Bool {
            drafts > 0
        }
    }

    public struct Snapshot: Sendable, Equatable {
        public var schemaRepair: LoopStats
        public var admissionRepair: LoopStats
        public var witnessRepair: LoopStats
        public var lastErrorDescription: String?

        public var anyBackendReady: Bool {
            schemaRepair.anyActivity
                || admissionRepair.anyActivity
                || witnessRepair.anyActivity
        }
    }

    private var schemaRepair: LoopStats = .empty
    private var admissionRepair: LoopStats = .empty
    private var witnessRepair: LoopStats = .empty
    private var lastError: String?

    private init() {}

    public func snapshot() -> Snapshot {
        Snapshot(
            schemaRepair: schemaRepair,
            admissionRepair: admissionRepair,
            witnessRepair: witnessRepair,
            lastErrorDescription: lastError
        )
    }

    /// Ingest a counter snapshot from the Rust side once the FFI
    /// bridge lands. Kind is one of `schema_repair`, `admission_repair`,
    /// `witness_repair` per the trait's `kind()` strings.
    public func ingest(kind: String, stats: LoopStats) {
        switch kind {
        case "schema_repair":
            schemaRepair = stats
        case "admission_repair":
            admissionRepair = stats
        case "witness_repair":
            witnessRepair = stats
        default:
            lastError = "unknown loop kind: \(kind)"
        }
        NotificationCenter.default.post(
            name: Self.didChangeNotification,
            object: self
        )
    }

    public func recordError(_ description: String) {
        lastError = description
        NotificationCenter.default.post(
            name: Self.didChangeNotification,
            object: self
        )
    }
}
