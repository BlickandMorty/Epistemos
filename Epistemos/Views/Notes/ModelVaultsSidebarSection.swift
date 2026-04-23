import SwiftUI
import SwiftData

/// Pass 10 — Per-model vault surface in the Notes sidebar.
///
/// Renders a collapsible DisclosureGroup under the Notes sidebar that
/// lists every directory inside
/// `~/Library/Application Support/Epistemos/model_vaults/`. Clicking a
/// model opens a dedicated browser for that vault's compiled files and
/// contribution history.
///
/// Perf notes (NotesSidebar is performance-sensitive — see the
/// "denormalized for performance" warning in the April 22 handoff):
/// - The on-disk scan runs only on section expand / explicit refresh,
///   never on every body evaluation.
/// - The cached list is a plain `@State [ModelVaultEntry]`, a value
///   type, so SwiftUI's diffing stays cheap.
/// - The browser sheet lazily loads files only when opened, so the
///   sidebar itself stays lightweight.
struct ModelVaultsSidebarSection: View {
    private static let maxExpandedListHeight: CGFloat = 320
    private static let estimatedRowHeight: CGFloat = 44

    @Environment(InferenceState.self) private var inference
    @AppStorage("notesSidebar.modelVaultsExpanded") private var isExpanded = false
    @State private var modelVaults: [ModelVaultEntry] = []
    @State private var selectedModel: ModelVaultEntry?

    private var visibleModelVaults: [ModelVaultEntry] {
        let visibleModelIDs = inference.visibleModelVaultModelIDs
        guard !visibleModelIDs.isEmpty else { return modelVaults }
        return modelVaults.filter { visibleModelIDs.contains($0.id) }
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if visibleModelVaults.isEmpty {
                Text("No visible model vaults yet")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(visibleModelVaults) { entry in
                            Button {
                                selectedModel = entry
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
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Open Vault Browser") {
                                    selectedModel = entry
                                }
                                Button("Reveal Vault in Finder") {
                                    ModelVaultsSidebarSection.revealInFinder(entry)
                                }
                            }
                        }
                    }
                }
                .frame(
                    maxHeight: min(
                        CGFloat(visibleModelVaults.count) * Self.estimatedRowHeight,
                        Self.maxExpandedListHeight
                    )
                )
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "cpu")
                    .foregroundStyle(.secondary)
                Text("Model Vaults")
                    .font(.callout)
                    .fontWeight(.medium)
                Spacer(minLength: 0)
                if !visibleModelVaults.isEmpty {
                    Text("\(visibleModelVaults.count)")
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
        .onChange(of: inference.visibleModelVaultModelIDs) { _, _ in
            if isExpanded {
                refreshModelVaults()
            }
        }
        .sheet(item: $selectedModel) { selection in
            ModelVaultBrowserSheet(entry: selection)
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
        loadModelVaults(rootURL: modelVaultsRootURL())
    }

    static func loadModelVaults(rootURL: URL) -> [ModelVaultEntry] {
        let root = rootURL
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
    let id: String        // canonical model id used by authoredByModelID
    let url: URL
    let displayName: String
    let subtitle: String
    let sortKey: String
    let systemImage: String
    let directoryName: String

    init(url: URL) {
        self.url = url
        self.directoryName = url.lastPathComponent

        let metadata = Self.metadata(for: url)
        let canonicalModelID = metadata?.modelID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedModelID: String
        if let canonicalModelID, !canonicalModelID.isEmpty {
            resolvedModelID = canonicalModelID
        } else {
            resolvedModelID = Self.canonicalModelID(forDirectoryName: directoryName)
        }
        self.id = resolvedModelID

        let presentation = Self.presentation(
            for: resolvedModelID,
            fallbackDisplayName: metadata?.displayName
        )
        self.displayName = presentation.displayName
        self.systemImage = presentation.systemImage
        self.sortKey = presentation.displayName.lowercased()
        self.subtitle = resolvedModelID
    }

    static func presentation(
        for modelID: String,
        fallbackDisplayName: String? = nil
    ) -> (displayName: String, systemImage: String) {
        if let localModel = LocalTextModelID.allCases.first(where: { $0.rawValue == modelID }) {
            return (localModel.displayName, systemImage(for: modelID))
        }
        if let cloudModel = CloudTextModelID.allCases.first(where: {
            $0.rawValue == modelID || $0.vendorModelID == modelID
        }) {
            let displayName = switch cloudModel.provider {
            case .google:
                cloudModel.compactDisplayName
            default:
                cloudModel.displayName
            }
            return (displayName, systemImage(for: modelID))
        }

        let explicitDisplayName = fallbackDisplayName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let explicitDisplayName, !explicitDisplayName.isEmpty {
            return (explicitDisplayName, systemImage(for: modelID))
        }

        let lower = modelID.lowercased()
        if lower.contains("opus-4-7") {
            return ("Claude Opus 4.7", "c.circle")
        }
        if lower.contains("sonnet-4-6") {
            return ("Claude Sonnet 4.6", "c.circle")
        }
        if lower.contains("gpt-5.4-mini") || lower.contains("gpt-5-4-mini") {
            return ("GPT-5.4 Mini", "o.circle")
        }
        if lower.contains("gpt-5.4") || lower.contains("gpt-5-4") {
            return ("GPT-5.4", "o.circle")
        }
        if lower.contains("gemini-3.1-pro") || lower.contains("gemini-3-pro") {
            return ("Gemini 3.1 Pro", "g.circle")
        }
        if lower.contains("gemini-3-flash") {
            return ("Gemini 3 Flash", "g.circle")
        }
        if lower.contains("apple-intelligence") {
            return ("Apple Intelligence", "apple.logo")
        }
        if lower.contains("qwen") {
            return (
                modelID
                    .replacingOccurrences(of: "-", with: " ")
                    .replacingOccurrences(of: "_", with: " "),
                "q.circle"
            )
        }
        return (
            modelID
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: "/", with: " ")
                .replacingOccurrences(of: "_", with: " "),
            "cpu"
        )
    }

    private static func canonicalModelID(forDirectoryName directoryName: String) -> String {
        let trimmed = directoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return directoryName
        }
        if let localMatch = LocalTextModelID.allCases.first(where: {
            safePathComponent($0.rawValue) == trimmed || $0.rawValue == trimmed
        }) {
            return localMatch.rawValue
        }
        if let cloudMatch = CloudTextModelID.allCases.first(where: {
            safePathComponent($0.rawValue) == trimmed
                || safePathComponent($0.vendorModelID) == trimmed
                || $0.vendorModelID == trimmed
                || $0.rawValue == trimmed
        }) {
            return cloudMatch.rawValue
        }
        return directoryName
    }

    private static func metadata(for directoryURL: URL) -> ModelVaultMetadata? {
        let metadataURL = directoryURL.appendingPathComponent("meta.json", isDirectory: false)
        guard let data = try? Data(contentsOf: metadataURL) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ModelVaultMetadata.self, from: data)
    }

    private static func safePathComponent(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "unknown-model" }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._"))
        let scalars = trimmed.unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        return String(scalars)
    }

    private static func systemImage(for modelID: String) -> String {
        let lower = modelID.lowercased()
        if lower.contains("opus") || lower.contains("sonnet") || lower.contains("claude") {
            return "c.circle"
        }
        if lower.contains("gpt") || lower.contains("openai") {
            return "o.circle"
        }
        if lower.contains("gemini") || lower.contains("google") {
            return "g.circle"
        }
        if lower.contains("apple-intelligence") {
            return "apple.logo"
        }
        if lower.contains("qwen") {
            return "q.circle"
        }
        return "cpu"
    }
}
