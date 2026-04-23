import SwiftData
import SwiftUI

enum ModelInvolvementContentVariant: Equatable {
    case sheet
    case inline(maxRows: Int?)
}

/// Pass 11 — Per-model "involvement" view.
///
/// Given a `modelID`, shows every substantive `SDMessage` this model
/// authored across chats, worker sessions, and note flows. Cloud
/// models accept both the current vendor model id (`gpt-5.4`) and the
/// legacy provider-qualified id (`openai:gpt-5.4`) so older histories
/// still surface after the curated provider simplification.
struct ModelInvolvementSheet: View {
    let modelID: String

    @Environment(\.dismiss) private var dismiss

    private var prettyModelName: String {
        ModelVaultEntry.presentation(for: modelID).displayName
    }

    var body: some View {
        NavigationStack {
            ModelInvolvementContent(modelID: modelID)
                .navigationTitle(prettyModelName)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .frame(minWidth: 480, minHeight: 520)
    }
}

struct ModelInvolvementContent: View {
    let modelID: String
    let acceptedModelIDs: Set<String>
    let variant: ModelInvolvementContentVariant

    @Environment(\.modelContext) private var modelContext
    @State private var contributions: [SDMessage] = []

    init(
        modelID: String,
        acceptedModelIDs: Set<String>? = nil,
        variant: ModelInvolvementContentVariant = .sheet
    ) {
        self.modelID = modelID
        self.acceptedModelIDs = acceptedModelIDs ?? ModelVaultEntry.acceptedModelIDs(for: modelID)
        self.variant = variant
    }

    private var prettyModelName: String {
        ModelVaultEntry.presentation(for: modelID).displayName
    }

    private var acceptedModelIDsKey: String {
        acceptedModelIDs.sorted().joined(separator: "|")
    }

    var body: some View {
        Group {
            if contributions.isEmpty {
                emptyState
            } else {
                switch variant {
                case .sheet:
                    List {
                        Section {
                            ForEach(contributions, id: \.id) { message in
                                ModelInvolvementRow(message: message)
                            }
                        } header: {
                            Text("\(contributions.count) contribution\(contributions.count == 1 ? "" : "s")")
                        }
                    }
                    .listStyle(.plain)

                case .inline(let maxRows):
                    LazyVStack(alignment: .leading, spacing: 0) {
                        let visibleContributions = maxRows.map { Array(contributions.prefix($0)) } ?? contributions
                        ForEach(Array(visibleContributions.enumerated()), id: \.element.id) { index, message in
                            ModelInvolvementRow(message: message, compact: true)
                            if index < visibleContributions.count - 1 {
                                Divider()
                                    .padding(.leading, 28)
                            }
                        }
                        if let maxRows, contributions.count > maxRows {
                            Text("+\(contributions.count - maxRows) more")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .padding(.top, 6)
                                .padding(.leading, 28)
                        }
                    }
                }
            }
        }
        .task(id: acceptedModelIDsKey) {
            reload()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("No contributions yet from \(prettyModelName).")
                .font(.headline)
            Text("Turns this model authors will show up here automatically.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func reload() {
        contributions = Self.loadContributions(
            modelIDs: acceptedModelIDs,
            in: modelContext
        )
    }

    @MainActor
    static func loadContributions(
        modelIDs: Set<String>,
        in modelContext: ModelContext
    ) -> [SDMessage] {
        guard !modelIDs.isEmpty else { return [] }

        var mergedByID: [String: SDMessage] = [:]
        for modelID in modelIDs {
            let descriptor = FetchDescriptor<SDMessage>(
                predicate: #Predicate<SDMessage> { $0.authoredByModelID == modelID },
                sortBy: [SortDescriptor(\SDMessage.createdAt, order: .reverse)]
            )
            guard let fetched = try? modelContext.fetch(descriptor) else { continue }
            for message in fetched where message.role == "assistant" {
                mergedByID[message.id] = message
            }
        }

        return mergedByID.values.sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
                return lhs.id < rhs.id
            }
            return lhs.createdAt > rhs.createdAt
        }
    }
}

private struct ModelInvolvementRow: View {
    let message: SDMessage
    var compact = false

    private var chatTitle: String {
        message.chat?.title ?? "Untitled chat"
    }

    private var roleLabel: String {
        switch message.role {
        case "user": return "User"
        case "assistant": return "Assistant"
        case "system": return "System"
        default: return message.role.capitalized
        }
    }

    private var preview: String {
        let trimmed = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 240 { return trimmed }
        return String(trimmed.prefix(240)) + "…"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 3 : 4) {
            HStack(spacing: 8) {
                Text(chatTitle)
                    .font(compact ? .caption : .subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(message.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(preview)
                .font(compact ? .caption : .body)
                .foregroundStyle(.primary)
                .lineLimit(compact ? 4 : 6)
            HStack(spacing: 6) {
                Text(roleLabel)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(.quaternary, in: Capsule())
                if let provider = message.authoredByProviderID,
                   !provider.isEmpty {
                    Text(provider)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, compact ? 6 : 4)
    }
}
