import SwiftUI
import SwiftData

/// Pass 10 — Per-model "involvement" surface in the Notes sidebar.
///
/// Renders a collapsible DisclosureGroup under the Notes sidebar that
/// lists every directory inside
/// `~/Library/Application Support/Epistemos/model_vaults/`. Clicking a
/// model opens a sheet with that model's involvement list —
/// every SDMessage whose `authoredByModelID` matches (from Pass 8).
///
/// Perf notes (NotesSidebar is performance-sensitive — see the
/// "denormalized for performance" warning in the April 22 handoff):
/// - The on-disk scan runs only on section expand / explicit refresh,
///   never on every body evaluation.
/// - The cached list is a plain `@State [ModelVaultEntry]`, a value
///   type, so SwiftUI's diffing stays cheap.
/// - The involvement sheet uses a one-shot `@Query` scoped to the
///   model id, so SwiftData only returns the matching messages.
struct ModelVaultsSidebarSection: View {
    @AppStorage("notesSidebar.modelVaultsExpanded") private var isExpanded = false
    @State private var modelVaults: [ModelVaultEntry] = []
    @State private var selectedModel: SelectedModel?

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if modelVaults.isEmpty {
                Text("No model vaults yet")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
            } else {
                ForEach(modelVaults) { entry in
                    Button {
                        selectedModel = SelectedModel(id: entry.id)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: entry.systemImage)
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(entry.displayName)
                                    .font(.callout)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text(entry.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Reveal Vault in Finder") {
                            ModelVaultsSidebarSection.revealInFinder(entry)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "cpu")
                    .foregroundStyle(.secondary)
                Text("Model Vaults")
                    .font(.callout)
                    .fontWeight(.medium)
                Spacer(minLength: 0)
                if !modelVaults.isEmpty {
                    Text("\(modelVaults.count)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .contentShape(Rectangle())
        }
        .onAppear {
            if modelVaults.isEmpty {
                refreshModelVaults()
            }
        }
        .onChange(of: isExpanded) { _, nowExpanded in
            if nowExpanded {
                refreshModelVaults()
            }
        }
        .sheet(item: $selectedModel) { selection in
            ModelInvolvementSheet(modelID: selection.id)
        }
    }

    private func refreshModelVaults() {
        modelVaults = Self.loadModelVaults()
    }

    static func modelVaultsRootURL() -> URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        return base
            .appendingPathComponent("Epistemos", isDirectory: true)
            .appendingPathComponent("model_vaults", isDirectory: true)
    }

    static func loadModelVaults() -> [ModelVaultEntry] {
        let root = modelVaultsRootURL()
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        let entries = contents
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .map { ModelVaultEntry(url: $0) }
            .sorted { $0.sortKey < $1.sortKey }
        return entries
    }

    static func revealInFinder(_ entry: ModelVaultEntry) {
        NSWorkspace.shared.activateFileViewerSelecting([entry.url])
    }
}

struct ModelVaultEntry: Identifiable, Hashable {
    let id: String        // directory name (also the model id we match on)
    let url: URL
    let displayName: String
    let subtitle: String
    let sortKey: String
    let systemImage: String

    init(url: URL) {
        self.url = url
        self.id = url.lastPathComponent
        let name = url.lastPathComponent
        self.sortKey = name.lowercased()

        let lower = name.lowercased()
        if lower.contains("opus-4-7") {
            self.displayName = "Claude Opus 4.7"
            self.systemImage = "c.circle"
        } else if lower.contains("sonnet-4-6") {
            self.displayName = "Claude Sonnet 4.6"
            self.systemImage = "c.circle"
        } else if lower.contains("gpt-5.4-mini") || lower.contains("gpt-5-4-mini") {
            self.displayName = "GPT-5.4 Mini"
            self.systemImage = "o.circle"
        } else if lower.contains("gpt-5.4") || lower.contains("gpt-5-4") {
            self.displayName = "GPT-5.4"
            self.systemImage = "o.circle"
        } else if lower.contains("gemini-3.1-pro") || lower.contains("gemini-3-pro") {
            self.displayName = "Gemini 3.1 Pro"
            self.systemImage = "g.circle"
        } else if lower.contains("gemini-3-flash") {
            self.displayName = "Gemini 3 Flash"
            self.systemImage = "g.circle"
        } else if lower.contains("apple-intelligence") {
            self.displayName = "Apple Intelligence"
            self.systemImage = "apple.logo"
        } else if lower.contains("qwen") {
            self.displayName = name
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: "_", with: " ")
            self.systemImage = "q.circle"
        } else {
            self.displayName = name
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: "_", with: " ")
            self.systemImage = "cpu"
        }

        self.subtitle = name
    }
}

struct SelectedModel: Identifiable, Hashable {
    let id: String
}
