import AppKit
import SwiftData
import SwiftUI

/// Pass 10 — Per-model vault surface in the Notes sidebar.
///
/// Kept intentionally lightweight:
/// - Directory scans happen only on expand / refresh.
/// - The section uses plain value types for vault/file metadata.
/// - File editing stays inline so the sidebar behaves like a real
///   folder tree instead of launching a second browser surface.
struct ModelVaultsSidebarSection: View {
    private static let maxExpandedListHeight: CGFloat = 320

    @Environment(InferenceState.self) private var inference
    @AppStorage("notesSidebar.modelVaultsExpanded") private var isExpanded = false
    @State private var modelVaults: [ModelVaultEntry] = []
    @State private var expandedModelIDs: Set<String> = []

    private var visibleModelVaults: [ModelVaultEntry] {
        let visibleModelIDs = inference.visibleModelVaultModelIDs
        guard !visibleModelIDs.isEmpty else { return modelVaults }
        return modelVaults.filter { $0.matchesVisibleModelIDs(visibleModelIDs) }
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
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(visibleModelVaults) { entry in
                            ModelVaultSidebarRow(
                                entry: entry,
                                isExpanded: expansionBinding(for: entry.id)
                            )
                        }
                    }
                }
                .frame(maxHeight: Self.maxExpandedListHeight)
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
    }

    private func expansionBinding(for modelID: String) -> Binding<Bool> {
        Binding(
            get: { expandedModelIDs.contains(modelID) },
            set: { shouldExpand in
                if shouldExpand {
                    expandedModelIDs.insert(modelID)
                } else {
                    expandedModelIDs.remove(modelID)
                }
            }
        )
    }

    private func refreshModelVaults() {
        modelVaults = Self.loadModelVaults()
        expandedModelIDs.formIntersection(Set(modelVaults.map(\.id)))
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
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return contents
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .map { ModelVaultEntry(url: $0) }
            .sorted { $0.sortKey < $1.sortKey }
    }

    static func revealInFinder(_ entry: ModelVaultEntry) {
        revealInFinder(entry.url)
    }

    static func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

private struct ModelVaultSidebarRow: View {
    let entry: ModelVaultEntry
    @Binding var isExpanded: Bool

    @State private var showInternalFiles = false
    @State private var fileEntries: [ModelVaultDocumentEntry] = []
    @State private var expandedFolderPaths: Set<String> = []
    @State private var selectedFilePath: String?
    @State private var loadedTextByPath: [String: String] = [:]
    @State private var draftTextByPath: [String: String] = [:]
    @State private var messageByPath: [String: String] = [:]
    @State private var errorByPath: [String: String] = [:]
    @State private var contributionsExpanded = false
    @State private var pendingDeleteTarget: ModelVaultDeleteTarget?

    private var nodes: [ModelVaultTreeNode] {
        ModelVaultTreeNode.build(entries: fileEntries)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            if isExpanded {
                expandedContent
            }
        }
        .alert(item: $pendingDeleteTarget) { target in
            Alert(
                title: Text("Delete \(target.title)?"),
                message: Text("This removes the item from the model vault immediately."),
                primaryButton: .destructive(Text("Delete")) {
                    delete(target)
                },
                secondaryButton: .cancel()
            )
        }
        .onChange(of: isExpanded) { _, nowExpanded in
            guard nowExpanded else { return }
            refreshFiles(preservingSelection: true)
        }
        .onChange(of: showInternalFiles) { _, _ in
            guard isExpanded else { return }
            refreshFiles(preservingSelection: true)
        }
    }

    private var headerRow: some View {
        HStack(spacing: 6) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 10)

                    Image(systemName: entry.systemImage)
                        .foregroundStyle(.secondary)
                        .frame(width: 14)

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
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                createFile(in: nil)
            } label: {
                Image(systemName: "doc.badge.plus")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Create file")

            Button {
                createFolder(in: nil)
            } label: {
                Image(systemName: "folder.badge.plus")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Create folder")

            Button {
                refreshFiles(preservingSelection: true)
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Refresh")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .contextMenu {
            Button("Reveal Vault in Finder") {
                ModelVaultsSidebarSection.revealInFinder(entry)
            }
            Button("Create File") {
                createFile(in: nil)
            }
            Button("Create Folder") {
                createFolder(in: nil)
            }
            Button(showInternalFiles ? "Hide Internal Files" : "Show Internal Files") {
                showInternalFiles.toggle()
            }
        }
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Toggle("Internal", isOn: $showInternalFiles)
                    .toggleStyle(.switch)
                    .font(.caption2)
                Spacer(minLength: 0)
                Text("\(fileEntries.count) file\(fileEntries.count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.leading, 28)
            .padding(.trailing, 10)
            .padding(.top, 2)
            .padding(.bottom, 6)

            if nodes.isEmpty {
                Text("No vault files yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 28)
                    .padding(.bottom, 6)
            } else {
                ForEach(nodes) { node in
                    ModelVaultTreeRow(
                        node: node,
                        indent: 1,
                        expandedFolderPaths: $expandedFolderPaths,
                        selectedFilePath: $selectedFilePath,
                        loadedTextByPath: $loadedTextByPath,
                        draftTextByPath: $draftTextByPath,
                        messageByPath: $messageByPath,
                        errorByPath: $errorByPath,
                        pendingDeleteTarget: $pendingDeleteTarget,
                        createFile: createFile,
                        createFolder: createFolder,
                        ensureLoaded: ensureLoaded,
                        saveFile: saveFile,
                        revertFile: revertFile
                    )
                }
            }

            DisclosureGroup(isExpanded: $contributionsExpanded) {
                ModelInvolvementContent(
                    modelID: entry.id,
                    acceptedModelIDs: entry.acceptedAuthoredModelIDs,
                    variant: .inline(maxRows: 8)
                )
                .padding(.leading, 28)
                .padding(.trailing, 10)
                .padding(.top, 6)
                .padding(.bottom, 4)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .foregroundStyle(.secondary)
                    Text("Contributions")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .padding(.leading, 28)
            .padding(.trailing, 10)
            .padding(.top, 6)
            .padding(.bottom, 4)
        }
        .padding(.bottom, 8)
    }

    private func refreshFiles(preservingSelection: Bool) {
        fileEntries = ModelVaultBrowserStore.loadEntries(
            rootURL: entry.url,
            includeHidden: showInternalFiles
        )
        expandedFolderPaths.formIntersection(
            Set(ModelVaultTreeNode.folderPaths(in: nodes))
        )
        guard preservingSelection else {
            selectedFilePath = nil
            return
        }
        if let selectedFilePath,
           fileEntries.contains(where: { $0.relativePath == selectedFilePath }) {
            return
        }
        self.selectedFilePath = nil
    }

    private func createFile(in relativeDirectory: String?) {
        guard let created = ModelVaultBrowserStore.createTextFile(
            named: "untitled",
            rootURL: entry.url,
            relativeDirectory: relativeDirectory
        ) else {
            return
        }
        expandAncestors(of: created.relativePath)
        refreshFiles(preservingSelection: true)
        selectedFilePath = created.relativePath
        ensureLoaded(created)
    }

    private func createFolder(in relativeParentDirectory: String?) {
        guard let createdURL = ModelVaultBrowserStore.createDirectory(
            named: "context",
            rootURL: entry.url,
            relativeParentDirectory: relativeParentDirectory
        ) else {
            return
        }
        let relativePath = relativePath(for: createdURL)
        expandedFolderPaths.insert(relativePath)
        expandAncestors(of: relativePath)
        refreshFiles(preservingSelection: true)
    }

    private func ensureLoaded(_ document: ModelVaultDocumentEntry) {
        if loadedTextByPath[document.relativePath] != nil || errorByPath[document.relativePath] != nil {
            return
        }
        do {
            let loaded = try ModelVaultBrowserStore.readText(at: document.url)
            loadedTextByPath[document.relativePath] = loaded
            draftTextByPath[document.relativePath] = loaded
            errorByPath[document.relativePath] = nil
        } catch {
            loadedTextByPath[document.relativePath] = ""
            draftTextByPath[document.relativePath] = ""
            errorByPath[document.relativePath] = "Couldn't decode this file as text."
        }
    }

    private func saveFile(_ document: ModelVaultDocumentEntry) {
        let draft = draftTextByPath[document.relativePath] ?? ""
        if ModelVaultBrowserStore.writeText(draft, to: document.url) {
            loadedTextByPath[document.relativePath] = draft
            draftTextByPath[document.relativePath] = draft
            errorByPath[document.relativePath] = nil
            messageByPath[document.relativePath] = "Saved"
            refreshFiles(preservingSelection: true)
        } else {
            errorByPath[document.relativePath] = "Save failed."
        }
    }

    private func revertFile(_ document: ModelVaultDocumentEntry) {
        let loaded = loadedTextByPath[document.relativePath] ?? ""
        draftTextByPath[document.relativePath] = loaded
        messageByPath[document.relativePath] = nil
        errorByPath[document.relativePath] = nil
    }

    private func delete(_ target: ModelVaultDeleteTarget) {
        guard ModelVaultBrowserStore.deleteItem(at: target.url) else { return }
        if let selectedFilePath,
           selectedFilePath == target.relativePath
                || selectedFilePath.hasPrefix(target.relativePath + "/") {
            self.selectedFilePath = nil
        }
        loadedTextByPath = loadedTextByPath.filter { key, _ in
            key != target.relativePath && !key.hasPrefix(target.relativePath + "/")
        }
        draftTextByPath = draftTextByPath.filter { key, _ in
            key != target.relativePath && !key.hasPrefix(target.relativePath + "/")
        }
        messageByPath = messageByPath.filter { key, _ in
            key != target.relativePath && !key.hasPrefix(target.relativePath + "/")
        }
        errorByPath = errorByPath.filter { key, _ in
            key != target.relativePath && !key.hasPrefix(target.relativePath + "/")
        }
        refreshFiles(preservingSelection: true)
    }

    private func expandAncestors(of relativePath: String) {
        let components = relativePath.split(separator: "/").map(String.init)
        guard components.count > 1 else { return }
        var current = ""
        for component in components.dropLast() {
            current = current.isEmpty ? component : current + "/" + component
            expandedFolderPaths.insert(current)
        }
    }

    private func relativePath(for url: URL) -> String {
        let rootPath = entry.url.standardizedFileURL.path
        let filePath = url.standardizedFileURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        if filePath.hasPrefix(prefix) {
            return String(filePath.dropFirst(prefix.count))
        }
        return url.lastPathComponent
    }
}

private struct ModelVaultTreeRow: View {
    let node: ModelVaultTreeNode
    let indent: Int
    @Binding var expandedFolderPaths: Set<String>
    @Binding var selectedFilePath: String?
    @Binding var loadedTextByPath: [String: String]
    @Binding var draftTextByPath: [String: String]
    @Binding var messageByPath: [String: String]
    @Binding var errorByPath: [String: String]
    @Binding var pendingDeleteTarget: ModelVaultDeleteTarget?
    let createFile: (String?) -> Void
    let createFolder: (String?) -> Void
    let ensureLoaded: (ModelVaultDocumentEntry) -> Void
    let saveFile: (ModelVaultDocumentEntry) -> Void
    let revertFile: (ModelVaultDocumentEntry) -> Void

    private var isFolderExpanded: Bool {
        expandedFolderPaths.contains(node.relativePath)
    }

    private var isSelectedFile: Bool {
        selectedFilePath == node.relativePath
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch node.kind {
            case .folder:
                Button {
                    toggleFolder()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(isFolderExpanded ? 90 : 0))
                            .frame(width: 10)
                        Image(systemName: isFolderExpanded ? "folder.fill" : "folder")
                            .foregroundStyle(.secondary)
                        Text(node.name)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, CGFloat(indent) * 16 + 12)
                    .padding(.trailing, 10)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Create File") { createFile(node.relativePath) }
                    Button("Create Folder") { createFolder(node.relativePath) }
                    Button("Reveal in Finder") {
                        ModelVaultsSidebarSection.revealInFinder(node.url)
                    }
                    Divider()
                    Button("Delete Folder", role: .destructive) {
                        pendingDeleteTarget = ModelVaultDeleteTarget(
                            url: node.url,
                            relativePath: node.relativePath,
                            title: node.name
                        )
                    }
                }

                if isFolderExpanded {
                    ForEach(node.children) { child in
                        ModelVaultTreeRow(
                            node: child,
                            indent: indent + 1,
                            expandedFolderPaths: $expandedFolderPaths,
                            selectedFilePath: $selectedFilePath,
                            loadedTextByPath: $loadedTextByPath,
                            draftTextByPath: $draftTextByPath,
                            messageByPath: $messageByPath,
                            errorByPath: $errorByPath,
                            pendingDeleteTarget: $pendingDeleteTarget,
                            createFile: createFile,
                            createFolder: createFolder,
                            ensureLoaded: ensureLoaded,
                            saveFile: saveFile,
                            revertFile: revertFile
                        )
                    }
                }

            case .file:
                if let document = node.document {
                    Button {
                        if selectedFilePath == document.relativePath {
                            selectedFilePath = nil
                        } else {
                            selectedFilePath = document.relativePath
                            ensureLoaded(document)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: document.systemImage)
                                .foregroundStyle(.secondary)
                            Text(document.displayName)
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.leading, CGFloat(indent) * 16 + 22)
                        .padding(.trailing, 10)
                        .padding(.vertical, 4)
                        .background(isSelectedFile ? Color.primary.opacity(0.06) : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Reveal in Finder") {
                            ModelVaultsSidebarSection.revealInFinder(document.url)
                        }
                        Divider()
                        Button("Delete File", role: .destructive) {
                            pendingDeleteTarget = ModelVaultDeleteTarget(
                                url: document.url,
                                relativePath: document.relativePath,
                                title: document.displayName
                            )
                        }
                    }

                    if isSelectedFile {
                        ModelVaultInlineEditor(
                            document: document,
                            draftText: Binding(
                                get: { draftTextByPath[document.relativePath] ?? loadedTextByPath[document.relativePath] ?? "" },
                                set: {
                                    draftTextByPath[document.relativePath] = $0
                                    messageByPath[document.relativePath] = nil
                                }
                            ),
                            loadedText: loadedTextByPath[document.relativePath] ?? "",
                            statusMessage: messageByPath[document.relativePath],
                            errorMessage: errorByPath[document.relativePath],
                            onSave: { saveFile(document) },
                            onRevert: { revertFile(document) }
                        )
                    }
                }
            }
        }
    }

    private func toggleFolder() {
        if expandedFolderPaths.contains(node.relativePath) {
            expandedFolderPaths.remove(node.relativePath)
        } else {
            expandedFolderPaths.insert(node.relativePath)
        }
    }
}

private struct ModelVaultInlineEditor: View {
    let document: ModelVaultDocumentEntry
    @Binding var draftText: String
    let loadedText: String
    let statusMessage: String?
    let errorMessage: String?
    let onSave: () -> Void
    let onRevert: () -> Void

    private var hasUnsavedChanges: Bool {
        draftText != loadedText
    }

    private var isEditable: Bool {
        ModelVaultBrowserStore.isEditableTextFile(document.url)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }

            if isEditable {
                TextEditor(text: $draftText)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 120, maxHeight: 180)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                HStack(spacing: 8) {
                    Button("Save") { onSave() }
                        .buttonStyle(.plain)
                        .foregroundStyle(hasUnsavedChanges ? .primary : .secondary)
                        .disabled(!hasUnsavedChanges)
                    Button("Revert") { onRevert() }
                        .buttonStyle(.plain)
                        .foregroundStyle(hasUnsavedChanges ? .secondary : .tertiary)
                        .disabled(!hasUnsavedChanges)
                    Spacer(minLength: 0)
                    if let statusMessage, !statusMessage.isEmpty {
                        Text(statusMessage)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            } else {
                Text("This file isn't editable inline yet.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.leading, 44)
        .padding(.trailing, 10)
        .padding(.bottom, 8)
    }
}

private struct ModelVaultDeleteTarget: Identifiable {
    let url: URL
    let relativePath: String
    let title: String

    var id: String { relativePath }
}

private struct ModelVaultTreeNode: Identifiable, Hashable {
    enum Kind: Hashable {
        case folder
        case file
    }

    let kind: Kind
    let name: String
    let relativePath: String
    let url: URL
    let document: ModelVaultDocumentEntry?
    let children: [ModelVaultTreeNode]

    var id: String { relativePath }

    var isFolder: Bool {
        kind == .folder
    }

    static func build(entries: [ModelVaultDocumentEntry]) -> [ModelVaultTreeNode] {
        final class BuilderNode {
            let name: String
            let relativePath: String
            let url: URL
            var document: ModelVaultDocumentEntry?
            var children: [String: BuilderNode] = [:]

            init(name: String, relativePath: String, url: URL) {
                self.name = name
                self.relativePath = relativePath
                self.url = url
            }

            func materialize() -> ModelVaultTreeNode {
                let sortedChildren = children.values
                    .map { $0.materialize() }
                    .sorted { lhs, rhs in
                        if lhs.kind != rhs.kind {
                            return lhs.kind == .folder
                        }
                        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                    }
                if let document {
                    return ModelVaultTreeNode(
                        kind: .file,
                        name: document.displayName,
                        relativePath: document.relativePath,
                        url: document.url,
                        document: document,
                        children: []
                    )
                }
                return ModelVaultTreeNode(
                    kind: .folder,
                    name: name,
                    relativePath: relativePath,
                    url: url,
                    document: nil,
                    children: sortedChildren
                )
            }
        }

        let rootURL = URL(fileURLWithPath: "/", isDirectory: true)
        let root = BuilderNode(name: "", relativePath: "", url: rootURL)

        for entry in entries {
            let components = entry.relativePath.split(separator: "/").map(String.init)
            guard !components.isEmpty else { continue }

            var current = root
            var currentComponents: [String] = []

            for component in components.dropLast() {
                currentComponents.append(component)
                let relativePath = currentComponents.joined(separator: "/")
                if let existing = current.children[component] {
                    current = existing
                    continue
                }
                let folderURL = entry.url.deletingLastPathComponent(
                    count: components.count - currentComponents.count
                )
                let folderNode = BuilderNode(
                    name: component,
                    relativePath: relativePath,
                    url: folderURL
                )
                current.children[component] = folderNode
                current = folderNode
            }

            let fileNode = BuilderNode(
                name: components.last ?? entry.displayName,
                relativePath: entry.relativePath,
                url: entry.url
            )
            fileNode.document = entry
            current.children[components.last ?? entry.displayName] = fileNode
        }

        return root.children.values
            .map { $0.materialize() }
            .sorted { lhs, rhs in
                if lhs.kind != rhs.kind {
                    return lhs.kind == .folder
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    static func folderPaths(in nodes: [ModelVaultTreeNode]) -> [String] {
        nodes.flatMap { node in
            var paths: [String] = []
            if node.isFolder {
                paths.append(node.relativePath)
                paths.append(contentsOf: folderPaths(in: node.children))
            }
            return paths
        }
    }
}

struct ModelVaultEntry: Identifiable, Hashable {
    let id: String
    let url: URL
    let displayName: String
    let subtitle: String
    let sortKey: String
    let systemImage: String
    let directoryName: String
    let acceptedAuthoredModelIDs: Set<String>

    init(url: URL) {
        self.url = url
        self.directoryName = url.lastPathComponent

        let metadata = Self.metadata(for: url)
        let rawMetadataModelID = metadata?.modelID
        let resolvedModelID = Self.canonicalModelID(
            for: rawMetadataModelID ?? directoryName
        )
        self.id = resolvedModelID
        self.acceptedAuthoredModelIDs = Self.acceptedModelIDs(
            for: resolvedModelID,
            additionalAliases: [rawMetadataModelID, directoryName]
        )

        let presentation = Self.presentation(
            for: resolvedModelID,
            fallbackDisplayName: metadata?.displayName
        )
        self.displayName = presentation.displayName
        self.systemImage = presentation.systemImage
        self.sortKey = presentation.displayName.lowercased()
        self.subtitle = resolvedModelID
    }

    func matchesVisibleModelIDs(_ visibleModelIDs: Set<String>) -> Bool {
        !acceptedAuthoredModelIDs.isDisjoint(with: visibleModelIDs)
    }

    static func acceptedModelIDs(
        for modelID: String,
        additionalAliases: [String?] = []
    ) -> Set<String> {
        let canonical = canonicalModelID(for: modelID)
        var ids: Set<String> = [canonical]

        if let localModel = localModel(matching: canonical) {
            ids.insert(localModel.rawValue)
        }
        if let cloudModel = cloudModel(matching: canonical) {
            ids.insert(cloudModel.vendorModelID)
            ids.insert(cloudModel.rawValue)
        }

        for alias in additionalAliases.compactMap({ $0 }) {
            let trimmed = alias.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            ids.insert(trimmed)
            let normalized = canonicalModelID(for: trimmed)
            ids.insert(normalized)
            if let cloudModel = cloudModel(matching: trimmed) {
                ids.insert(cloudModel.vendorModelID)
                ids.insert(cloudModel.rawValue)
            }
        }

        return ids
    }

    static func presentation(
        for modelID: String,
        fallbackDisplayName: String? = nil
    ) -> (displayName: String, systemImage: String) {
        if let localModel = localModel(matching: modelID) {
            return (localModel.displayName, systemImage(for: modelID))
        }
        if let cloudModel = cloudModel(matching: modelID) {
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

    private static func canonicalModelID(for value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return value
        }
        if let localMatch = localModel(matching: trimmed) {
            return localMatch.rawValue
        }
        if let cloudMatch = cloudModel(matching: trimmed) {
            return cloudMatch.vendorModelID
        }
        return trimmed
    }

    private static func localModel(matching value: String) -> LocalTextModelID? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return LocalTextModelID.allCases.first(where: {
            safePathComponent($0.rawValue) == trimmed || $0.rawValue == trimmed
        })
    }

    private static func cloudModel(matching value: String) -> CloudTextModelID? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return CloudTextModelID.allCases.first(where: {
            safePathComponent($0.rawValue) == trimmed
                || safePathComponent($0.vendorModelID) == trimmed
                || $0.vendorModelID == trimmed
                || $0.rawValue == trimmed
        })
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

private extension URL {
    func deletingLastPathComponent(count: Int) -> URL {
        guard count > 0 else { return self }
        var url = self
        for _ in 0..<count {
            url.deleteLastPathComponent()
        }
        return url
    }
}
