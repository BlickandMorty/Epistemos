import SwiftUI

/// PER-CLONE SETTINGS (owner 2026-06-21; queue 0.21/0.30, B-gate) — the "Beyond"
/// clone tab. This is the reserved settings surface for FUTURE non-agent clones
/// per the plan (Tolaria reference lane, Epdoc-fuse, Tamagotchi render-fix, and
/// other proven-engine adoptions layered with Epistemos IP). It is an HONEST STUB:
/// no beyond clone is wired live yet, so the tab states exactly that and points at
/// the plan rather than implying a capability that does not exist.
///
/// SCOPE GUARD (queue 0.30 B2): Companion-backend clones are OFF-LIMITS — this tab
/// never hosts `companions.rs` / `CompanionCreationFlow` / new-model interrupt
/// internals. It is for work + future non-agent integration clones only.
struct BeyondCloneSettingsView: View {
    private struct FutureClone: Identifiable {
        let id = UUID()
        let name: String
        let planRef: String
        let summary: String
    }

    private let futureClones: [FutureClone] = [
        FutureClone(
            name: "Tolaria (reference lane)",
            planRef: "PLAN_V2 / addendum — Tolaria reference",
            summary: "Reference-lane clone for cross-checking outputs. Not wired."
        ),
        FutureClone(
            name: "Epdoc-fuse",
            planRef: "🆕 EPDOC MD-V2 (queue 4.4/4.18)",
            summary: "MD-V2 document fusion surface. Not wired as a clone tab yet."
        ),
        FutureClone(
            name: "Tamagotchi (agent-creation render)",
            planRef: "🆕 OSAURUS AGENT CREATION = KEEP TAMAGOTCHI (queue 4.5)",
            summary: "Agent-creation render lane. Render-fix tracked separately; not a live beyond clone."
        ),
    ]

    var body: some View {
        Form {
            Section {
                SettingsDescriptionText(
                    text: "Beyond is the reserved tab for future non-agent integration clones. "
                    + "Nothing here is wired live yet — this tab is an honest placeholder so the "
                    + "per-clone settings matrix (Epistemos | Act | Work | Beyond) is complete and "
                    + "future clones have a home. Each clone keeps its own settings when it lands."
                )
            } header: {
                Text("Beyond = future clones")
            } footer: {
                Text("Companion-backend clones are out of scope for this tab.")
            }

            Section {
                ForEach(futureClones) { clone in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(clone.name).font(.body.weight(.semibold))
                            Spacer()
                            Text("STUBBED")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15), in: Capsule())
                                .foregroundStyle(.secondary)
                        }
                        Text(clone.summary)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Text(clone.planRef)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("Planned (not yet wired)")
            }
        }
        .formStyle(.grouped)
    }
}
