import SwiftUI

// MARK: - ACSAdmissionHealthRow
//
// Wiring #6 (T18B ACS dispatch admission gate) — HIGH RISK production
// status surface. Mirrors EidosHealthRow / SystemGHealthRow / FUlpHealthRow
// shape. Reads strict policy summary on appear via
// `ACSAdmissionBridge.strictPolicySummary()`.
//
// The row remains read-only UI, but the underlying ACS admission path
// is wired into the v2 tool-call handoff and the distillation write
// path. Legacy consumers that have not adopted those paths are still
// tracked as explicit follow-up wirings.

@MainActor
public struct ACSAdmissionHealthRow: View {

    @State private var snapshot: ACSAdmissionMetrics.Snapshot

    public init() {
        self._snapshot = State(initialValue: ACSAdmissionMetrics.shared.snapshot())
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            row(
                label: "ACS admission flag",
                symbol: "flag.fill",
                ok: snapshot.isFlagEnabled,
                detail: snapshot.isFlagEnabled
                    ? "EPISTEMOS_ACS_ADMISSION_V0 on (production gate active)"
                    : "EPISTEMOS_ACS_ADMISSION_V0 off"
            )
            VerifiedFloorChipStrip(
                flag: snapshot.isFlagEnabled ? "on" : "off",
                substrate: "substrate-only · gate not witnessed",
                productionWired: false,
                falsifierPassed: false,
                falsifier: "docs/falsifiers/F-ACS-Anchor-Addressing_2026_05_17.md",
                wiredToday: "Strict ACS policy summary is readable from Settings.",
                stillStub: "Settings has not observed a production ACSRunEventLogSink admission witness."
            )
            row(
                label: "Strict policy",
                symbol: "lock.shield",
                ok: snapshot.lastPolicy != nil,
                detail: policyDetail
            )
            row(
                label: "Capability rules",
                symbol: "key",
                ok: (snapshot.lastPolicy?.capabilityRulesCount ?? 0) > 0,
                detail: capabilityDetail
            )
            row(
                label: "Canonical verdicts",
                symbol: "list.bullet.indent",
                ok: (snapshot.lastPolicy?.canonicalVerdicts.count ?? 0) == 5,
                detail: verdictDetail
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
        .substrateHealthPoll {
            _ = ACSAdmissionBridge.strictPolicySummary()
            refresh()
        }
        .onReceive(NotificationCenter.default.publisher(
            for: ACSAdmissionMetrics.didChangeNotification,
            object: ACSAdmissionMetrics.shared
        )) { _ in
            Task { @MainActor in
                refresh()
            }
        }
    }

    public func refresh() {
        snapshot = ACSAdmissionMetrics.shared.snapshot()
    }

    private var policyDetail: String {
        guard let p = snapshot.lastPolicy else { return "(no read yet)" }
        return "\(p.policyId) v\(p.version) (policy substrate readable; gate witness pending)"
    }

    private var capabilityDetail: String {
        guard let p = snapshot.lastPolicy else { return "—" }
        return "\(p.capabilityRulesCount) required, \(p.operationThresholdRulesCount) thresholds"
    }

    private var verdictDetail: String {
        guard let p = snapshot.lastPolicy else { return "—" }
        return p.canonicalVerdicts.joined(separator: " | ")
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
