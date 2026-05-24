import SwiftUI

// MARK: - FUlpHealthRow
//
// Wiring #5 (T12 F-ULP → EML witness emission) settings diagnostic.
// The F-ULP oracle is the EML arithmetic floor (≤2 ULP fp16 in
// [0.5,2]); the AnswerPacket schema freeze is blocked until this gate
// is green (DECK:266). This row surfaces the gate live.
//
// Mirrors the EidosHealthRow / SystemGHealthRow / VaultRecallHealthRow
// shape. Adds a "Run acceptance witness" button — the witness is
// ~412k+2k point evaluations; user-triggered so the row is cheap on
// idle paint.

@MainActor
public struct FUlpHealthRow: View {

    @State private var snapshot: FUlpMetrics.Snapshot
    @State private var running: Bool = false
    @State private var refreshTask: Task<Void, Never>?

    public init() {
        self._snapshot = State(initialValue: FUlpMetrics.shared.snapshot())
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            row(
                label: "F-ULP oracle flag",
                symbol: "flag.fill",
                ok: snapshot.isFlagEnabled,
                detail: snapshot.isFlagEnabled
                    ? "EPISTEMOS_F_ULP_ORACLE_V0 on"
                    : "EPISTEMOS_F_ULP_ORACLE_V0 off"
            )
            VerifiedFloorChipStrip(
                flag: snapshot.isFlagEnabled ? "on" : "off",
                substrate: "research-only",
                substrateTint: .blue
            )
            row(
                label: "Acceptance witness",
                symbol: "checkmark.shield",
                ok: snapshot.lastWitness?.pass ?? false,
                detail: witnessDetail
            )
            row(
                label: "Substrate floor",
                symbol: "scalemass",
                ok: (snapshot.lastWitness?.pass ?? false),
                detail: floorDetail
            )
            HStack {
                Button(running ? "Running…" : "Run acceptance witness") {
                    runWitness()
                }
                .disabled(running)
                .controlSize(.small)
                Spacer()
            }
            .padding(.horizontal, 12)
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
            for: FUlpMetrics.didChangeNotification,
            object: FUlpMetrics.shared
        )) { _ in
            Task { @MainActor in
                refresh()
            }
        }
    }

    public func refresh() {
        snapshot = FUlpMetrics.shared.snapshot()
    }

    private func startTimer() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { break }
                refresh()
            }
        }
    }

    private func runWitness() {
        running = true
        Task.detached {
            _ = FUlpBridge.run()
            await MainActor.run {
                running = false
                refresh()
            }
        }
    }

    private var witnessDetail: String {
        if let err = snapshot.lastErrorDescription, snapshot.lastWitness == nil {
            return "research-feature only (\(err.prefix(60)))"
        }
        guard let witness = snapshot.lastWitness else {
            return "no run yet — press the button to verify"
        }
        let pass = witness.pass ? "PASS" : "FAIL"
        let date = snapshot.lastRunAt.map { Self.relativeTime($0) } ?? "—"
        return "\(pass) over \(witness.point_count) points (\(date))"
    }

    private var floorDetail: String {
        guard let witness = snapshot.lastWitness else {
            return "(unknown until run)"
        }
        return "evaluator=\(witness.evaluator_variant) fingerprint=\(witness.grid_fingerprint.prefix(12))…"
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
