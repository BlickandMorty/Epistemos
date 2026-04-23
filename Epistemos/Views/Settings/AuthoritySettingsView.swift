import SwiftUI

/// User-facing Authority & Installs panel. One row per
/// AgentAuthorityCategory with a three-state picker (auto-allow / ask /
/// never). Backed by the @Observable AgentAuthorityStore so changes
/// persist across launches and other settings surfaces stay in sync.
///
/// This is the single place the user answers "what is the agent allowed to
/// do on my behalf without asking" — the existing pattern-level allow /
/// block list sits one layer down for exceptions.
struct AuthoritySettingsView: View {
    @State private var store: AgentAuthorityStore
    private let onResetConfirmed: (() -> Void)?

    init(
        store: AgentAuthorityStore,
        onResetConfirmed: (() -> Void)? = nil
    ) {
        self._store = State(initialValue: store)
        self.onResetConfirmed = onResetConfirmed
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                quickSetupCard

                ForEach(AgentAuthorityCategory.allCases, id: \.self) { category in
                    categoryCard(for: category)
                }

                footer
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Authority & Installs")
                .font(.title2.weight(.semibold))
            Text("Decide what the agent can do without asking you first. These apply to every agent turn until you change them.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var quickSetupCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Quick Setup")
                    .font(.headline)
                Text("Apply a permission posture in one step, then fine-tune any category below.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                ForEach(AgentAuthorityQuickSetupPreset.allCases) { preset in
                    Button {
                        applyPreset(preset)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(quickSetupTitle(for: preset))
                                .font(.subheadline.weight(.semibold))
                            Text(preset.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func categoryCard(for category: AgentAuthorityCategory) -> some View {
        SettingsSurfaceCard {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.displayName)
                        .font(.headline)
                    Text(category.shortExplanation)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                authorityPicker(for: category)
                    .frame(width: 150)
            }
        }
    }

    private func authorityPicker(for category: AgentAuthorityCategory) -> some View {
        let binding = Binding<AuthorityDecision>(
            get: { store.snapshot.decision(for: category) },
            set: { store.setDecision($0, for: category) }
        )

        return Picker("", selection: binding) {
            ForEach(AuthorityDecision.allCases, id: \.self) { decision in
                Text(decision.displayName).tag(decision)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
    }

    private var footer: some View {
        HStack(alignment: .center) {
            if let lastModified = store.snapshot.lastModified {
                Text("Last updated \(lastModified.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Using recommended defaults.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Reset to defaults") {
                store.reset()
                onResetConfirmed?()
            }
            .buttonStyle(.bordered)
        }
        .padding(.top, 4)
    }

    private func applyPreset(_ preset: AgentAuthorityQuickSetupPreset) {
        if preset == .recommended {
            store.reset(
                to: AgentAuthorityPolicySnapshot(
                    decisions: preset.decisions,
                    lastModified: Date()
                )
            )
        } else {
            store.applyPreset(preset.decisions)
        }
        onResetConfirmed?()
    }

    private func quickSetupTitle(for preset: AgentAuthorityQuickSetupPreset) -> String {
        switch preset {
        case .recommended:
            return "Recommended"
        case .lessInterruptions:
            return "Less Interruptions"
        case .cautious:
            return "Review More"
        }
    }
}

#Preview("Authority Settings") {
    AuthoritySettingsView(store: AgentAuthorityStore())
        .frame(width: 680, height: 640)
}
