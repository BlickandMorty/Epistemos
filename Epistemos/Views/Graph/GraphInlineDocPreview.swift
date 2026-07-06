import SwiftUI
import SwiftData

/// SS-GE (A) first increment (L4435, owner "risky core"): a read-only INLINE preview
/// of a note in the graph sidebar, so a note can be read in-place instead of bouncing
/// to a detached Notes window (the "utility" the owner wants gone). This is the SAFE
/// foundation — read-only, ZERO vault writes; inline EDIT via the existing note-save
/// pipeline is the next increment. Behind EPISTEMOS_GRAPH_INLINE_DOC_EDIT_V0 (default
/// OFF): OFF → the affordance never shows and note nodes keep opening a window
/// (byte-identical). Scoped to note nodes (SDPage load path); Epdoc-manifest documents
/// are a follow-on.
enum GraphInlineDocPreviewFlag {
    /// Default OFF. Set `EPISTEMOS_GRAPH_INLINE_DOC_EDIT_V0=1` to enable.
    static var enabled: Bool {
        ProcessInfo.processInfo.environment["EPISTEMOS_GRAPH_INLINE_DOC_EDIT_V0"] == "1"
    }
}

/// Read-only inline preview of a note page, loaded by id from SwiftData. Pure read
/// (no writes), so there is no data-loss surface. Reads `\.modelContext` from the
/// environment (the app installs the model container at its root) + the page's
/// on-disk body via the same `loadBodyAsync` path the editor uses.
struct GraphInlineDocPreviewCard: View {
    let pageId: String
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var title: String = ""
    @State private var bodyText: String = ""
    @State private var didLoad = false
    @State private var isEditing = false
    @State private var editedBody = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(title.isEmpty ? "Note" : title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 4)
                if isEditing {
                    Button("Cancel") { isEditing = false }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Button("Save") { save() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tint)
                        .help("Save edits to the note")
                } else if didLoad {
                    Button {
                        editedBody = bodyText
                        isEditing = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Edit inline")
                }
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close preview")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)

            Divider().opacity(0.3)

            if isEditing {
                TextEditor(text: $editedBody)
                    .font(.system(size: 11.5, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 140, maxHeight: 280)
                    .padding(6)
            } else {
                ScrollView {
                    Text(displayText)
                        .font(.system(size: 11.5))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(maxHeight: 280)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        )
        .task(id: pageId) { await load() }
    }

    private var displayText: String {
        if !bodyText.isEmpty { return bodyText }
        return didLoad ? "(empty note)" : "Loading…"
    }

    @MainActor
    private func load() async {
        let targetId = pageId
        var descriptor = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == targetId })
        descriptor.fetchLimit = 1
        guard let page = try? modelContext.fetch(descriptor).first else {
            didLoad = true
            return
        }
        // Pull Sendable primitives on the main actor; NEVER send the non-Sendable SDPage
        // across the await. The from-primitives loader reads the on-disk body off-main.
        let pageTitle = page.title
        let pageIdValue = page.id
        let pageFilePath = page.filePath
        let pageInlineBody = page.body
        let loadedBody = await SDPage.loadBodyAsyncFromPrimitives(
            pageId: pageIdValue,
            filePath: pageFilePath,
            inlineBody: pageInlineBody,
            fast: true
        )
        title = pageTitle
        bodyText = loadedBody
        didLoad = true
    }

    /// Persist inline edits through the same whole-buffer vault write path as the note editor.
    @MainActor
    private func save() {
        let targetId = pageId
        let newBody = editedBody
        Task { @MainActor in
            guard await AppBootstrap.shared?.vaultSync.savePageBodyFileFirst(
                pageId: targetId,
                body: newBody
            ) == true else { return }
            bodyText = newBody
            isEditing = false
        }
    }
}

/// SS-GE (A) — read-only inline preview for an EPDOC DOCUMENT node (the .document branch, which
/// otherwise opens a detached window). Epdoc content is a structured ProseMirror package, so this
/// shows the package's `projections/plain.txt` (the FTS-friendly plain-text projection) — read-only,
/// off-main, zero writes. Inline EDIT for documents needs the Epdoc package writer (a later
/// increment); read-only here keeps the data-loss floor. Same flag (EPISTEMOS_GRAPH_INLINE_DOC_EDIT_V0).
struct GraphEpdocDocPreviewCard: View {
    let manifestID: String
    let vaultURL: URL?
    let onClose: () -> Void

    @State private var title: String = ""
    @State private var bodyText: String = ""
    @State private var didLoad = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(title.isEmpty ? "Document" : title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close preview")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)

            Divider().opacity(0.3)

            ScrollView {
                Text(displayText)
                    .font(.system(size: 11.5))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .frame(maxHeight: 280)
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        )
        .task(id: manifestID) { await load() }
    }

    private var displayText: String {
        if !bodyText.isEmpty { return bodyText }
        return didLoad ? "(no text preview available for this document)" : "Loading…"
    }

    private func load() async {
        let targetID = manifestID
        let vault = vaultURL
        // Resolve + read the package off the main actor (the locator crawls the vault). Captures are
        // Sendable (String / URL?) and the result is a (String, String?) tuple — nothing non-Sendable
        // crosses back.
        let result: (title: String, text: String?) = await Task.detached {
            guard let packageURL = EpdocDocumentLocator.url(forManifestID: targetID, in: vault) else {
                return ("", nil)
            }
            var resolvedTitle = ""
            let manifestURL = packageURL.appendingPathComponent(EpdocPackageEntry.manifest)
            if let data = try? Data(contentsOf: manifestURL),
               let manifest = try? JSONDecoder.epdocCanonical.decode(EpdocManifest.self, from: data) {
                resolvedTitle = manifest.title
            }
            let plainURL = packageURL
                .appendingPathComponent(EpdocPackageEntry.projections)
                .appendingPathComponent(EpdocPackageEntry.Projection.plainText)
            let text = (try? Data(contentsOf: plainURL)).flatMap { String(data: $0, encoding: .utf8) }
            return (resolvedTitle, text)
        }.value
        title = result.title
        bodyText = result.text ?? ""
        didLoad = true
    }
}
