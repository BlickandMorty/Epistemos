import SwiftUI

nonisolated struct NoteIdentityDraft: Equatable, Sendable {
    var title: String
    var tagsText: String
    var folderID: String?

    var normalizedTitle: String {
        let collapsedWhitespace = title
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        return VaultIndexActor.sanitizeTitle(collapsedWhitespace)
    }

    var normalizedTags: [String] {
        var seen = Set<String>()
        return tagsText
            .split(whereSeparator: { $0 == "," || $0.isNewline })
            .compactMap { fragment in
                let cleaned = String(
                    fragment.unicodeScalars.filter {
                        !CharacterSet.controlCharacters.contains($0)
                    }
                )
                .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleaned.isEmpty else { return nil }

                let key = cleaned.folding(
                    options: [.caseInsensitive, .diacriticInsensitive],
                    locale: .current
                )
                .lowercased()
                return seen.insert(key).inserted ? cleaned : nil
            }
    }
}

struct NoteIdentityFolderOption: Identifiable, Equatable {
    let folderID: String?
    let relativePath: String

    var id: String {
        folderID ?? "vault-root"
    }
}

struct NoteIdentityPopover: View {
    let folders: [NoteIdentityFolderOption]
    let theme: EpistemosTheme
    let onSave: @MainActor (NoteIdentityDraft) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFocused: Bool
    @State private var title: String
    @State private var tagsText: String
    @State private var folderID: String?
    @State private var isSaving = false
    @State private var saveError: String?

    init(
        title: String,
        tags: [String],
        folderID: String?,
        folders: [NoteIdentityFolderOption],
        theme: EpistemosTheme,
        onSave: @escaping @MainActor (NoteIdentityDraft) async -> Bool
    ) {
        self.folders = folders
        self.theme = theme
        self.onSave = onSave
        _title = State(initialValue: title)
        _tagsText = State(initialValue: tags.joined(separator: ", "))
        _folderID = State(initialValue: folderID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            identityField(label: "Name") {
                TextField("Name", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .focused($isNameFocused)
                    .accessibilityLabel("Name")
            }

            identityField(label: "Tags") {
                TextField("Comma-separated tags", text: $tagsText)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Tags")
            }

            identityField(label: "Where") {
                Picker("Where", selection: $folderID) {
                    Label("Vault root", systemImage: "externaldrive")
                        .tag(String?.none)
                    ForEach(folders) { folder in
                        Label(folder.relativePath, systemImage: "folder.fill")
                            .tag(folder.folderID)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("Where")
            }

            if let saveError {
                Label(saveError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .accessibilityLabel(saveError)
            }

            HStack {
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    commit()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isSaving)
            }
        }
        .padding(16)
        .frame(width: 390)
        .foregroundStyle(theme.textPrimary)
        .background(NoteWorkspaceSurfaceStyle.canvasBackground(for: theme))
        .onAppear {
            isNameFocused = true
        }
    }

    @ViewBuilder
    private func identityField<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.textSecondary)
            content()
        }
    }

    private func commit() {
        let draft = NoteIdentityDraft(
            title: title,
            tagsText: tagsText,
            folderID: folderID
        )
        isSaving = true
        saveError = nil
        Task { @MainActor in
            let didSave = await onSave(draft)
            isSaving = false
            if didSave {
                dismiss()
            } else {
                saveError = "Epistemos could not finish writing this identity. It remains marked for retry."
            }
        }
    }
}
