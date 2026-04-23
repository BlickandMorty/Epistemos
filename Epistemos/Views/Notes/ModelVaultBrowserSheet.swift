import AppKit
import SwiftUI

private enum ModelVaultBrowserSurface: String, CaseIterable, Identifiable {
    case files
    case contributions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .files: "Vault Files"
        case .contributions: "Contributions"
        }
    }
}

struct ModelVaultDocumentEntry: Identifiable, Hashable {
    let url: URL
    let relativePath: String
    let isHidden: Bool

    var id: String { relativePath }

    var displayName: String {
        URL(fileURLWithPath: relativePath).lastPathComponent
    }

    var systemImage: String {
        switch relativePath.lowercased() {
        case "instructions.md":
            return "slider.horizontal.3"
        case "knowledge_profile.md":
            return "brain.head.profile"
        case "concept_index.md":
            return "list.number"
        case "active_context.md":
            return "sparkles.rectangle.stack"
        case "meta.json":
            return "curlybraces"
        default:
            let ext = url.pathExtension.lowercased()
            switch ext {
            case "md", "markdown", "txt", "mdx":
                return "doc.text"
            case "json", "yaml", "yml", "toml":
                return "curlybraces"
            default:
                return "doc"
            }
        }
    }
}

enum ModelVaultBrowserStore {
    private static let preferredFiles = [
        "instructions.md",
        "knowledge_profile.md",
        "concept_index.md",
        "active_context.md",
        "meta.json",
    ]

    static func loadEntries(rootURL: URL, includeHidden: Bool = false) -> [ModelVaultDocumentEntry] {
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsPackageDescendants]
        ) else {
            return []
        }

        var entries: [ModelVaultDocumentEntry] = []
        let normalizedRootPath = rootURL.standardizedFileURL.path
        let rootPrefix = normalizedRootPath.hasSuffix("/") ? normalizedRootPath : normalizedRootPath + "/"

        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
            if values?.isDirectory == true, !includeHidden, isInternalPath(relativePath(for: url, rootPrefix: rootPrefix)) {
                enumerator.skipDescendants()
                continue
            }
            guard values?.isRegularFile == true else { continue }

            let relativePath = relativePath(for: url, rootPrefix: rootPrefix)
            let isHidden = isInternalPath(relativePath)
            if isHidden && !includeHidden {
                continue
            }

            entries.append(
                ModelVaultDocumentEntry(
                    url: url,
                    relativePath: relativePath,
                    isHidden: isHidden
                )
            )
        }

        return entries.sorted { lhs, rhs in
            let lhsRank = sortRank(for: lhs)
            let rhsRank = sortRank(for: rhs)
            if lhsRank == rhsRank {
                return lhs.relativePath.localizedCaseInsensitiveCompare(rhs.relativePath) == .orderedAscending
            }
            return lhsRank < rhsRank
        }
    }

    static func isEditableTextFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if ["md", "markdown", "mdx", "txt", "json", "yaml", "yml", "toml", "xml", "html", "css", "js", "ts", "swift", "py", "rs", "sh"].contains(ext) {
            return true
        }
        return url.lastPathComponent.hasPrefix(".")
    }

    static func readText(at url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        for encoding in [String.Encoding.utf8, .utf16, .unicode, .ascii] {
            if let text = String(data: data, encoding: encoding) {
                return text
            }
        }
        throw CocoaError(.fileReadInapplicableStringEncoding)
    }

    static func writeText(_ content: String, to url: URL) -> Bool {
        NoteFileStorage.writeTextAtomically(content, to: url, itemLabel: url.lastPathComponent)
    }

    private static func relativePath(for url: URL, rootPrefix: String) -> String {
        let path = url.standardizedFileURL.path
        if path.hasPrefix(rootPrefix) {
            return String(path.dropFirst(rootPrefix.count))
        }
        return url.lastPathComponent
    }

    private static func isInternalPath(_ relativePath: String) -> Bool {
        relativePath.split(separator: "/").contains { $0.hasPrefix(".") }
    }

    private static func sortRank(for entry: ModelVaultDocumentEntry) -> Int {
        let lowercasedPath = entry.relativePath.lowercased()
        if let index = preferredFiles.firstIndex(of: lowercasedPath) {
            return index
        }
        return entry.isHidden ? preferredFiles.count + 1 : preferredFiles.count
    }
}

struct ModelVaultBrowserSheet: View {
    let entry: ModelVaultEntry

    @Environment(\.dismiss) private var dismiss
    @AppStorage("notesSidebar.modelVaultBrowser.showInternalFiles") private var showInternalFiles = false

    @State private var surface: ModelVaultBrowserSurface = .files
    @State private var fileEntries: [ModelVaultDocumentEntry] = []
    @State private var selectedRelativePath: String?
    @State private var loadedText = ""
    @State private var draftText = ""
    @State private var loadError: String?
    @State private var saveError: String?
    @State private var saveStatus: String?

    private var selectedFile: ModelVaultDocumentEntry? {
        guard let selectedRelativePath else { return nil }
        return fileEntries.first { $0.relativePath == selectedRelativePath }
    }

    private var hasUnsavedChanges: Bool {
        draftText != loadedText
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                Divider()

                Picker("Model Vault Surface", selection: $surface) {
                    ForEach(ModelVaultBrowserSurface.allCases) { surface in
                        Text(surface.title).tag(surface)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Group {
                    switch surface {
                    case .files:
                        filesSurface
                    case .contributions:
                        ModelInvolvementContent(modelID: entry.id)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle(entry.displayName)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 920, minHeight: 600)
        .onAppear {
            refreshFiles(preservingSelection: false)
        }
        .onChange(of: showInternalFiles) { _, _ in
            if !showInternalFiles,
               selectedFile?.isHidden == true,
               hasUnsavedChanges {
                showInternalFiles = true
                saveError = "Save or revert your changes before hiding this internal file."
                return
            }
            refreshFiles(preservingSelection: true)
        }
        .onChange(of: draftText) { _, newValue in
            if newValue != loadedText {
                saveStatus = nil
                if saveError == "Save or revert your changes before switching files." {
                    saveError = nil
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.systemImage)
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.displayName)
                    .font(.headline)
                Text(entry.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Text("Inspect the compiled vault, edit its live text files, and review everything this model has authored.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 10) {
                Toggle("Show Internal Files", isOn: $showInternalFiles)
                    .toggleStyle(.switch)
                    .font(.caption)

                HStack(spacing: 8) {
                    Button("Reveal Vault") {
                        NSWorkspace.shared.activateFileViewerSelecting([entry.url])
                    }
                    .buttonStyle(.bordered)

                    if let selectedFile {
                        Button("Reveal File") {
                            NSWorkspace.shared.activateFileViewerSelecting([selectedFile.url])
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private var filesSurface: some View {
        HSplitView {
            VStack(spacing: 0) {
                if fileEntries.isEmpty {
                    ContentUnavailableView(
                        "No vault files yet",
                        systemImage: "tray",
                        description: Text("Rebuild this model vault to generate its compiled files.")
                    )
                } else {
                    List {
                        ForEach(fileEntries) { file in
                            Button {
                                selectFile(file.relativePath)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: file.systemImage)
                                        .foregroundStyle(file.isHidden ? .tertiary : .secondary)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(file.displayName)
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        Text(file.relativePath)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                            .lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.vertical, 2)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(
                                selectedRelativePath == file.relativePath
                                    ? Color.accentColor.opacity(0.12)
                                    : Color.clear
                            )
                        }
                    }
                    .listStyle(.sidebar)
                }
            }
            .frame(minWidth: 250, idealWidth: 280, maxWidth: 320)

            fileDetailPane
        }
    }

    private var fileDetailPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let selectedFile {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedFile.displayName)
                            .font(.headline)
                        Text(selectedFile.relativePath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    Spacer(minLength: 12)

                    if let saveStatus {
                        Text(saveStatus)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Button("Revert") {
                        draftText = loadedText
                        saveError = nil
                    }
                    .buttonStyle(.bordered)
                    .disabled(!hasUnsavedChanges)

                    Button("Save") {
                        saveSelectedFile()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!hasUnsavedChanges || !ModelVaultBrowserStore.isEditableTextFile(selectedFile.url))
                }

                if let loadError {
                    Text(loadError)
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else if let saveError {
                    Text(saveError)
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else if hasUnsavedChanges {
                    Text("Save or revert before switching files.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if ModelVaultBrowserStore.isEditableTextFile(selectedFile.url) {
                    TextEditor(text: $draftText)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    ContentUnavailableView(
                        "Preview unavailable",
                        systemImage: "doc",
                        description: Text("This file type is not editable inline yet. Reveal it in Finder to inspect it with another app.")
                    )
                }
            } else {
                ContentUnavailableView(
                    "Select a vault file",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Instructions, distilled knowledge, active context, metadata, and any internal files for this model appear here.")
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func refreshFiles(preservingSelection: Bool) {
        let nextEntries = ModelVaultBrowserStore.loadEntries(
            rootURL: entry.url,
            includeHidden: showInternalFiles
        )
        fileEntries = nextEntries

        let nextSelection: String?
        if preservingSelection,
           let selectedRelativePath,
           nextEntries.contains(where: { $0.relativePath == selectedRelativePath }) {
            nextSelection = selectedRelativePath
        } else {
            nextSelection = nextEntries.first?.relativePath
        }

        if selectedRelativePath != nextSelection {
            selectedRelativePath = nextSelection
            loadSelectedFile()
        } else if nextSelection == nil {
            loadedText = ""
            draftText = ""
            loadError = nil
            saveError = nil
            saveStatus = nil
        }
    }

    private func selectFile(_ relativePath: String) {
        guard selectedRelativePath != relativePath else { return }
        guard !hasUnsavedChanges else {
            saveError = "Save or revert your changes before switching files."
            return
        }
        selectedRelativePath = relativePath
        loadSelectedFile()
    }

    private func loadSelectedFile() {
        guard let selectedFile else {
            loadedText = ""
            draftText = ""
            loadError = nil
            saveError = nil
            saveStatus = nil
            return
        }

        do {
            let text = try ModelVaultBrowserStore.readText(at: selectedFile.url)
            loadedText = text
            draftText = text
            loadError = nil
            saveError = nil
            saveStatus = nil
        } catch {
            loadedText = ""
            draftText = ""
            loadError = "This file could not be decoded as plain text: \(error.localizedDescription)"
            saveError = nil
            saveStatus = nil
        }
    }

    private func saveSelectedFile() {
        guard let selectedFile else { return }
        guard ModelVaultBrowserStore.isEditableTextFile(selectedFile.url) else { return }

        if ModelVaultBrowserStore.writeText(draftText, to: selectedFile.url) {
            loadedText = draftText
            loadError = nil
            saveError = nil
            saveStatus = "Saved just now"
        } else {
            saveError = "Epistemos couldn't write this file."
            saveStatus = nil
        }
    }
}
