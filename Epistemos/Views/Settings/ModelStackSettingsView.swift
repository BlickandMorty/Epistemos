import SwiftUI

/// reqs 6/7 — "the stack": the Settings model-manager surface where the owner
/// toggles which RETAINED models are ADVERTISED (appear in the picker). Renders
/// rows from the pure `ModelStackAssembler`; a per-row toggle routes to
/// `AdvertisedModelStore`, and the picker reads `effectiveAdvertised`
/// (InferenceState wiring, commit 6b26319fe). This is a VISIBILITY control only —
/// every model stays installed and retained (req 2 KEEP-ALL); advertising just
/// decides what the picker shows.
///
/// Returns a `Section` so it drops directly into the `LocalModelManagerSheet`
/// Form. A local `@State` mirror of the advertised set drives re-render because
/// `UserDefaults` is not `@Observable`.
struct ModelStackSettingsView: View {
    @Environment(InferenceState.self) private var inference

    @State private var advertisedIDs: [String] = []

    private let store = AdvertisedModelStore()

    /// The full RETAINED catalog: the MLX/remote text descriptors PLUS the
    /// foundation GGUF models (Gemma / VibeThinker / coder), de-duped by id, so
    /// LFM2 / VibeThinker / the Gemma family are all listed (owner req 11).
    private var descriptors: [LocalModelDescriptor] {
        let base = LocalModelCatalog.textDescriptors
        let foundationGGUF = EpistemosFoundationLineup.models.compactMap {
            LocalModelCatalog.descriptor(for: $0.id)
        }
        var seen = Set(base.map(\.id))
        return base + foundationGGUF.filter { seen.insert($0.id).inserted }
    }

    private var fullCatalog: Set<String> {
        Set(descriptors.map(\.id))
    }

    private var installedIDs: Set<String> {
        inference.installedLocalTextModelIDs.union(inference.preparedLocalTextModelIDs)
    }

    private var rows: [ModelStackRow] {
        ModelStackAssembler.rows(
            descriptors: descriptors,
            installedIDs: installedIDs,
            advertisedIDs: Set(advertisedIDs)
        )
    }

    var body: some View {
        Section {
            ForEach(rows) { row in
                stackRow(row)
            }

            HStack {
                Text(store.isCustomized ? "Custom advertised set" : "Using canon defaults")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Reset to canon") {
                    store.resetToCanonDefaults()
                    refresh()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!store.isCustomized)
            }
            .padding(.top, 4)
        } header: {
            Text("Advertised models (the stack)")
        } footer: {
            Text("Toggle which models appear in the picker. Every model stays installed and retained — this only controls picker visibility.")
        }
        .onAppear(perform: refresh)
    }

    @ViewBuilder
    private func stackRow(_ row: ModelStackRow) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(row.displayName)
                        .font(.subheadline.weight(.semibold))
                    if row.isInstalled {
                        Text("Installed")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.green)
                    } else {
                        Text("Not installed")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                if !row.summary.isEmpty {
                    Text(row.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Text("\(row.sizeText) · \(row.ramText)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: Binding(
                get: { row.isAdvertised },
                set: { _ in
                    store.toggleAdvertised(row.id, fullCatalog: fullCatalog)
                    refresh()
                }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 2)
    }

    private func refresh() {
        advertisedIDs = store.effectiveAdvertised(fullCatalog: fullCatalog)
    }
}
