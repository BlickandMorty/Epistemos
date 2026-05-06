import SwiftUI

// MARK: - HELIOS V5 W9 + W10 + W11 — Settings parent toggles
//
// HELIOS-W9 guard
// HELIOS-W10 guard
// HELIOS-W11 guard
//
// Per docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md §3 W9 + W10 + W11:
//
//   W9  — Settings → Verified Research Mode toggle (default OFF)
//          parent for Hopfield retrieval (W15) + future VRM features
//   W10 — Settings → Connectome Browser toggle + bundled atlas JSON
//          (Resources/connectome_atlas_v1.json, default OFF)
//   W11 — Settings → Experimental Metal Kernels parent toggle
//          parent for T-MAC (W12), BitNet b1.58 (W13), Sparse
//          Ternary GEMM (W14)
//
// All three toggles default OFF per Tier-2 §2.5.2 compliance:
// bundled in MAS but never auto-enabled. User must explicitly opt
// in. Toggles persist via @AppStorage (UserDefaults backing) per
// the existing SettingsView idiom.
//
// ## §2.5.2 compliance posture
//
// Tier 2: bundled-but-default-OFF UI surface. The toggles change
// app behavior when user opts in but never download executable
// code; alternate model files (when bundled per release-prep)
// ship inside the .app per §2.5.2 verbatim.

/// HELIOS V5 W9 + W10 + W11 — Settings parent for the three Tier-2
/// toggle groups. Wire into the main SettingsView via a navigation
/// row or section in a follow-up integration slice.
public struct HELIOSv5SettingsView: View {
    public init() {}

    // W9 parent + child: Verified Research Mode → Hopfield retrieval
    @AppStorage("epistemos.helios.v5.verifiedResearchMode") private var vrmEnabled = false
    @AppStorage("epistemos.helios.v5.hopfieldRetrieval") private var hopfieldEnabled = false

    // W10: Connectome Browser
    @AppStorage("epistemos.helios.v5.connectomeBrowser") private var connectomeBrowserEnabled = false

    // W11 parent + children: Experimental Metal Kernels
    @AppStorage("epistemos.helios.v5.experimentalMetalKernels") private var metalKernelsEnabled = false
    @AppStorage("epistemos.helios.v5.kernel.tMac") private var tMacEnabled = false
    @AppStorage("epistemos.helios.v5.kernel.bitnet") private var bitnetEnabled = false
    @AppStorage("epistemos.helios.v5.kernel.sparseTernaryGEMM") private var sparseTernaryEnabled = false

    public var body: some View {
        Form {
            Section {
                Toggle("Verified Research Mode", isOn: $vrmEnabled)
                    .help("Surfaces Verified / Plausible / Speculative / Blocked labels for every chat reply.")
                if vrmEnabled {
                    Toggle("Modern Hopfield retrieval", isOn: $hopfieldEnabled)
                        .help("Retrieve via Modern Hopfield associative recall (Ramsauer et al. 2008.02217). Defaults OFF; opt-in only.")
                        .padding(.leading, 16)
                }
            } header: {
                Text("Verified Research Mode")
                    .font(.headline)
            } footer: {
                Text("Verified | Plausible-but-unverified | Speculative | Blocked. Defaults OFF.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Connectome Browser", isOn: $connectomeBrowserEnabled)
                    .help("Bundled VPD component atlas — transparency surface only; never executes inference.")
                if connectomeBrowserEnabled {
                    Text("Atlas: Resources/connectome_atlas_v1.json (bundled in-app, no runtime download)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 16)
                }
            } header: {
                Text("Connectome Browser")
                    .font(.headline)
            } footer: {
                Text("Read-only metadata browser over precomputed VPD components. Defaults OFF.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Experimental Metal Kernels", isOn: $metalKernelsEnabled)
                    .help("Master toggle for T-MAC, BitNet 1.58, and Sparse Ternary GEMM.")
                if metalKernelsEnabled {
                    Toggle("T-MAC ternary path", isOn: $tMacEnabled)
                        .help("LUT-centric ternary GEMM (Wei et al. arXiv:2407.00088). Requires bundled ternary model.")
                        .padding(.leading, 16)
                    Toggle("BitNet 1.58-bit", isOn: $bitnetEnabled)
                        .help("BitNet b1.58 inference (Ma et al. arXiv:2504.12285). Requires bundled bitnet GGUF.")
                        .padding(.leading, 16)
                    Toggle("Sparse Ternary GEMM", isOn: $sparseTernaryEnabled)
                        .help("Sparse ternary GEMM (Lipshitz et al. arXiv:2510.06957). Requires bundled ternary model.")
                        .padding(.leading, 16)
                }
            } header: {
                Text("Experimental Metal Kernels")
                    .font(.headline)
            } footer: {
                Text("Each kernel requires a bundled model file. Defaults all OFF; behavior change requires explicit opt-in.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Text("HELIOS V5 Canon Lock v2 — Verified Floor: ac8c6d28")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("All toggles default OFF per App Review §2.5.2 compliance.")
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

#if DEBUG
#Preview("HELIOSv5SettingsView") {
    HELIOSv5SettingsView()
        .frame(width: 480, height: 600)
}
#endif
