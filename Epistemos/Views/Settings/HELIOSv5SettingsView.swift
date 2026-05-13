import SwiftUI

// MARK: - HELIOS V5 W9 + W10 + W11 — deferred settings scaffold
//
// HELIOS-W9 guard
// HELIOS-W10 guard
// HELIOS-W11 guard
//
// Per docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md §3 W9 + W10 + W11:
//
//   W9  — Settings -> Verified Research Mode toggle (deferred)
//          parent for Hopfield retrieval (W15) + future VRM features
//   W10 — Settings -> Connectome Browser toggle + bundled atlas JSON
//          (Resources/connectome_atlas_v1.json, deferred)
//   W11 — Settings -> Experimental Metal Kernels parent toggle
//          parent for T-MAC (W12), BitNet b1.58 (W13), Sparse
//          Ternary GEMM (W14)
//
// V1 release freeze:
// HELIOS remains research/doctrine/guardrails only. The scaffold is
// preserved, but this view intentionally exposes no persistent runtime
// toggles and cannot change behavior until WRV + compliance gates pass.
//
// ## §2.5.2 compliance posture
//
// Not a v1 runtime UI surface. Earlier Tier-2 toggle plans remain research
// notes only; this scaffold has no controls that change app behavior, and it
// does not download executable code.

/// HELIOS V5 W9 + W10 + W11 — read-only deferred scaffold for the frozen
/// research groups. This is intentionally not listed in v1 Settings.
public struct HELIOSv5SettingsView: View {
    public init() {}

    public var body: some View {
        Form {
            Section {
                DeferredHeliosRow(
                    title: "Verified Research Mode",
                    detail: "V6.2 first wiring landed 2026-05-12: every chat turn emits an AnswerPacket with attention_mode + interrupt_bucket. See Settings → General → Diagnostics → AnswerPacket for the live audit channel."
                )
                DeferredHeliosRow(
                    title: "Modern Hopfield retrieval",
                    detail: "Deferred: no retrieval-path authority flip for v1."
                )
            } header: {
                Text("Verified Research Mode")
                    .font(.headline)
            } footer: {
                Text("Research scaffold only. No v1 runtime controls are exposed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                DeferredHeliosRow(
                    title: "Connectome Browser",
                    detail: "Deferred: bundled atlas metadata remains a research artifact."
                )
            } header: {
                Text("Connectome Browser")
                    .font(.headline)
            } footer: {
                Text("No user-facing component browser ships in v1.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                DeferredHeliosRow(
                    title: "Experimental Metal Kernels",
                    detail: "Deferred: no T-MAC, BitNet, or sparse ternary runtime path is enabled for v1."
                )
            } header: {
                Text("Experimental Metal Kernels")
                    .font(.headline)
            } footer: {
                Text("Kernel scaffold stays in source and tests; runtime toggles stay absent.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Text("HELIOS V5 Canon Lock v2 — Verified Floor: ac8c6d28")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("V1 release posture: deferred, read-only, not surfaced in Settings.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Compliance")
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("HELIOS V5")
    }
}

private struct DeferredHeliosRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.body)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("HELIOSv5SettingsView") {
    HELIOSv5SettingsView()
        .frame(width: 480, height: 600)
}
#endif
