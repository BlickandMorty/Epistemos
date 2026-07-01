import Foundation
import SwiftUI

struct HTMLWorkspaceRegenerateSheet: View {
    @Binding var instruction: String
    @Binding var streamedText: String
    @Binding var contextQuery: String
    let workspaceID: String
    let expectedContentHash: String
    let errorText: String?
    let contextStatusText: String?
    let isRegenerating: Bool
    let isRefreshingContext: Bool
    let hasPendingPreview: Bool
    let hasVaultContext: Bool
    let contextItems: [HTMLWorkspaceRegenerateContextItem]
    let canRestorePreviousSurface: Bool
    let onCancel: () -> Void
    let onCopyPrompt: () -> Void
    let onRefreshContext: () -> Void
    let onClearContext: () -> Void
    let onFocusContextItem: (HTMLWorkspaceRegenerateContextItem) -> Void
    let onRunPreset: (HTMLWorkspaceRegeneratePreset) -> Void
    let onSubmit: () -> Void
    let onApplyPreview: () -> Void
    let onPreviewStream: () -> Void
    let onApplyStream: () -> Void
    let onRestorePreview: () -> Void
    let onRestorePreviousSurface: () -> Void

    @State private var advancedFallbackVisible = false

    @Environment(UIState.self) private var ui

    private var theme: EpistemosTheme {
        ui.theme
    }

    private var sheetBackground: Color {
        MarkdownPreviewSurfaceStyle.flatBackground(for: theme.surfaceVariant(.other))
    }

    private var fieldBackground: Color {
        theme.resolved.card.color.opacity(theme.isDark ? 0.42 : 0.64)
    }

    private var streamBackground: Color {
        theme.resolved.card.color.opacity(theme.isDark ? 0.30 : 0.52)
    }

    private var mutedText: Color {
        theme.resolved.mutedForeground.color
    }

    private var pixelCaptionFont: Font {
        .system(size: 11, weight: .semibold, design: .monospaced)
    }

    private var pixelControlFont: Font {
        .system(size: 11, weight: .medium, design: .monospaced)
    }

    private var pixelMicroFont: Font {
        .system(size: 10, weight: .semibold, design: .monospaced)
    }

    private var instructionIsEmpty: Bool {
        instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "wand.and.sparkles")
                    .foregroundStyle(theme.resolved.accent.color)
                Text("Regenerate Surface")
                    .font(.headline)
                    .foregroundStyle(theme.resolved.foreground.color)
                Spacer(minLength: 0)
                Button(action: onRestorePreview) {
                    Label("Current", systemImage: "eye")
                }
                .disabled(isRegenerating)
                Button(action: onRestorePreviousSurface) {
                    Label("Revert", systemImage: "clock.arrow.circlepath")
                }
                .disabled(isRegenerating || !canRestorePreviousSurface)
                Button(action: onApplyPreview) {
                    Label("Apply Preview", systemImage: "checkmark.circle")
                }
                .disabled(isRegenerating || !hasPendingPreview)
                Button(action: onCancel) {
                    Label("Cancel", systemImage: "xmark.circle")
                }
                .keyboardShortcut(.cancelAction)
                Button(action: onSubmit) {
                    Label(isRegenerating ? "Streaming" : "Stream Preview", systemImage: "wand.and.sparkles")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isRegenerating || isRefreshingContext || instructionIsEmpty)
            }
            .padding(14)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("Describe the rebuilt surface", text: $instruction, axis: .vertical)
                        .textFieldStyle(.plain)
                        .foregroundStyle(theme.resolved.foreground.color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(fieldBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .lineLimit(3...6)
                        .disabled(isRegenerating)

                    HStack(spacing: 10) {
                        Label("Target", systemImage: "scope")
                        Text("\(workspaceID.prefix(10)) / \(expectedContentHash.prefix(10))")
                            .font(.caption.monospaced())
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 0)
                        Label(statusLabel, systemImage: statusSymbol)
                            .foregroundStyle(hasPendingPreview ? theme.resolved.accent.color : mutedText)
                    }
                    .font(pixelControlFont)
                    .foregroundStyle(mutedText)

                    contextSection

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Presets")
                            .font(pixelCaptionFont)
                            .foregroundStyle(mutedText)
                        ForEach(HTMLWorkspaceRegeneratePreset.Family.allCases, id: \.self) { family in
                            presetSection(family)
                        }
                    }

                    DisclosureGroup(isExpanded: $advancedFallbackVisible) {
                        advancedFallback
                    } label: {
                        Label("Recovery response fallback", systemImage: "terminal")
                            .font(pixelCaptionFont)
                            .foregroundStyle(mutedText)
                    }

                    if let errorText, !errorText.isEmpty {
                        Text(errorText)
                            .font(.caption)
                            .foregroundStyle(theme.error)
                            .lineLimit(3)
                    }
                }
                .padding(14)
            }
        }
        .background(sheetBackground)
    }

    private var statusLabel: String {
        if hasPendingPreview {
            return "Preview ready"
        }
        if isRegenerating {
            return "Streaming into preview"
        }
        return "Preview first, then apply"
    }

    private var statusSymbol: String {
        if hasPendingPreview {
            return "checkmark.circle.fill"
        }
        if isRegenerating {
            return "dot.radiowaves.left.and.right"
        }
        return "eye"
    }

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label("Workspace Context", systemImage: "tray.full")
                    .font(pixelCaptionFont)
                    .foregroundStyle(mutedText)
                Spacer(minLength: 0)
                if hasVaultContext {
                    Label("Attached", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(theme.resolved.accent.color)
                }
            }

            HStack(spacing: 8) {
                TextField("Search notes, PDFs, folders, captures, clips, chats, graph, claims", text: $contextQuery)
                    .textFieldStyle(.plain)
                    .foregroundStyle(theme.resolved.foreground.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(fieldBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .disabled(isRegenerating || isRefreshingContext)
                Button(action: onRefreshContext) {
                    Label(isRefreshingContext ? "Searching" : "Add Context", systemImage: "magnifyingglass.circle")
                }
                .disabled(isRegenerating || isRefreshingContext || contextQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button(action: onClearContext) {
                    Label("Clear", systemImage: "xmark.circle")
                }
                .disabled(isRegenerating || isRefreshingContext || !hasVaultContext)
            }
            .font(.caption)

            if let contextStatusText, !contextStatusText.isEmpty {
                Text(contextStatusText)
                    .font(.caption2)
                    .foregroundStyle(mutedText)
                    .lineLimit(2)
            }

            if !contextItems.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(contextItems) { item in
                            Button {
                                onFocusContextItem(item)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(pixelControlFont)
                                        .lineLimit(1)
                                    Text(item.snippet)
                                        .font(.caption2)
                                        .foregroundStyle(mutedText)
                                        .lineLimit(2)
                                    Text(item.contextDescriptor)
                                        .font(pixelMicroFont)
                                        .foregroundStyle(mutedText)
                                        .lineLimit(1)
                                    Text(item.rankDescriptor)
                                        .font(pixelMicroFont)
                                        .foregroundStyle(mutedText)
                                        .lineLimit(1)
                                    Text(item.provenanceDescriptor)
                                        .font(pixelMicroFont)
                                        .foregroundStyle(mutedText)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                .frame(width: 178, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 7)
                                .background(fieldBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(theme.resolved.foreground.color)
                            .disabled(isRegenerating || isRefreshingContext)
                            .onDrag {
                                NSItemProvider(object: item.dragPayload as NSString)
                            }
                            .help(item.dragPayload)
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
        }
    }

    private func presetSection(_ family: HTMLWorkspaceRegeneratePreset.Family) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(family.rawValue)
                .font(pixelMicroFont)
                .foregroundStyle(mutedText)
            FlowLayout(spacing: 6) {
                ForEach(HTMLWorkspaceRegeneratePreset.presets(in: family)) { preset in
                    Button {
                        onRunPreset(preset)
                    } label: {
                        Label(preset.title, systemImage: preset.systemImage)
                            .font(pixelControlFont)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(fieldBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.resolved.foreground.color)
                    .disabled(isRegenerating || isRefreshingContext)
                    .help(preset.helpText)
                }
            }
        }
    }

    private var advancedFallback: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button(action: onCopyPrompt) {
                    Label("Copy Recovery Prompt", systemImage: "doc.on.doc")
                }
                .disabled(isRegenerating || instructionIsEmpty)
                Button(action: onPreviewStream) {
                    Label("Preview Recovery Response", systemImage: "eye")
                }
                .disabled(isRegenerating || streamedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button(action: onApplyStream) {
                    Label("Apply Recovery Response", systemImage: "checkmark.circle")
                }
                .disabled(isRegenerating || streamedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .font(pixelControlFont)

            ZStack(alignment: .topLeading) {
                if streamedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(isRegenerating ? "Streaming response..." : "Paste a saved regenerate response only if live streaming failed.")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(mutedText)
                        .padding(12)
                }
                TextEditor(text: $streamedText)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(theme.resolved.foreground.color)
                    .disabled(isRegenerating)
                    .scrollContentBackground(.hidden)
                    .padding(4)
            }
            .frame(maxWidth: .infinity, minHeight: 132, maxHeight: 180)
            .background(streamBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .padding(.top, 8)
    }
}

nonisolated struct HTMLWorkspaceRegeneratePreset: Identifiable, Sendable, Equatable {
    enum Family: String, CaseIterable, Hashable, Sendable {
        case layout = "Layout"
        case addThing = "Add-a-thing"
        case vaultData = "Vault-data"
    }

    var id: String
    var family: Family
    var title: String
    var systemImage: String
    var instruction: String
    var requiredContextKind: String? = nil

    static let all: [HTMLWorkspaceRegeneratePreset] = [
        .init(
            id: "layout-dashboard",
            family: .layout,
            title: "Dashboard",
            systemImage: "rectangle.grid.2x2",
            instruction: "Regenerate this workspace as a dense operational dashboard using the current content and data. When data.json provides records, include working local search/filter, context-kind tabs, or charts bound only to those real records. Keep it interactive, theme-aware, and offline."
        ),
        .init(
            id: "layout-landing-page",
            family: .layout,
            title: "Landing page",
            systemImage: "sparkles.rectangle.stack",
            instruction: "Regenerate this workspace as a focused landing page for the current subject. Use the existing material as the offer and keep the first viewport visually clear."
        ),
        .init(
            id: "layout-docs-page",
            family: .layout,
            title: "Docs page",
            systemImage: "doc.text",
            instruction: "Regenerate this workspace as a documentation page with working section navigation, examples, and a clear information hierarchy from the existing content."
        ),
        .init(
            id: "layout-single-column-article",
            family: .layout,
            title: "Single-column article",
            systemImage: "text.alignleft",
            instruction: "Regenerate this workspace as a polished single-column article with inline callouts and readable long-form pacing."
        ),
        .init(
            id: "add-chart",
            family: .addThing,
            title: "Add chart",
            systemImage: "chart.bar.xaxis",
            instruction: "Preserve the current surface and add an inline chart derived only from available data.json records or explicit content. Do not wipe existing sections; inject the chart where it fits. Prefer real rank, metric, or count fields, keep source_label/provenance visible near the chart, and include an honest empty state if no numeric data exists."
        ),
        .init(
            id: "add-search",
            family: .addThing,
            title: "Add search box",
            systemImage: "magnifyingglass",
            instruction: "Preserve the current surface and add working local search over the visible sections and data.json records. Do not wipe existing sections; inject the search controls where they fit. Search title, snippet, page_id, source_label, context_kind, and provenance when records are present. Keep it offline and responsive."
        ),
        .init(
            id: "add-table",
            family: .addThing,
            title: "Add table",
            systemImage: "tablecells",
            instruction: "Preserve the current surface and add a scannable table from the current content or data.json records. Do not wipe existing sections; inject the table where it fits. When records are present, expose real page_id, title, snippet, rank, context_kind, source_label, and provenance fields; preserve source honesty if records are sparse."
        ),
        .init(
            id: "add-nav",
            family: .addThing,
            title: "Add nav",
            systemImage: "sidebar.left",
            instruction: "Preserve the current surface and add persistent navigation for sections, routes, data.json context_kind groups, or key entities already present in the content. Do not wipe existing sections; inject the nav where it fits and avoid dead links."
        ),
        .init(
            id: "vault-notes-cards",
            family: .vaultData,
            title: "Notes -> cards",
            systemImage: "rectangle.stack",
            instruction: "Regenerate this workspace by turning available note context into cards with working local filter/tabs over data.json records. Use only real note data and include an honest empty state if no notes are available."
        ),
        .init(
            id: "vault-recent-captures",
            family: .vaultData,
            title: "Recent captures",
            systemImage: "tray.full",
            instruction: "Regenerate this workspace around available recent captures with working local filter/tabs over data.json records. Use real capture metadata only and clearly show when no captures are available.",
            requiredContextKind: "recent_capture"
        ),
        .init(
            id: "vault-related-notes",
            family: .vaultData,
            title: "Related notes",
            systemImage: "link",
            instruction: "Regenerate this workspace around related notes from available context with working local filter/tabs over data.json records. Do not invent relationships; show an honest empty state when context is missing.",
            requiredContextKind: "graph_related_note"
        ),
    ]

    static func presets(in family: Family) -> [HTMLWorkspaceRegeneratePreset] {
        all.filter { $0.family == family }
    }

    var helpText: String {
        guard !requiredContextKindInstruction.isEmpty else { return instruction }
        return "\(instruction) \(requiredContextKindInstruction)"
    }

    func contextQuery(
        typedQuery: String,
        packageTitle: String
    ) -> String {
        let trimmedTypedQuery = typedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTypedQuery.isEmpty else { return trimmedTypedQuery }

        let title = packageTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        switch id {
        case "vault-recent-captures":
            return title.isEmpty ? "recent captures" : "recent captures \(title)"
        case "vault-related-notes":
            return title.isEmpty ? "related notes" : "related notes \(title)"
        case "vault-notes-cards":
            return title.isEmpty ? "notes" : title
        default:
            return title
        }
    }

    func instruction(contextQuery: String) -> String {
        guard family == .vaultData else { return instruction }
        let query = bounded(contextQuery, limit: 160)
        return """
        \(instruction)
        Attached context query: "\(query)" via VaultSyncService.searchFullAsync. Use only records present in data.json, keep source provenance visible, and render an honest empty state when no matching notes, PDFs/arXiv papers, folders, captures, meeting notes, web clips, chats, provenance claims, or graph-related records are present. Prefer working local search/filter, context-kind tabs, cards, tables, or charts when records are present; bind them to data.json only.
        \(requiredContextKindInstruction)
        """
    }

    private var requiredContextKindInstruction: String {
        guard let requiredContextKind else { return "" }
        return "This preset requires explicit data.json records with context_kind \"\(requiredContextKind)\"; honor _epistemos.required_context_available, and if it is false or no matching records are present, show that source as unavailable instead of relabeling generic vault results."
    }

    private func bounded(_ value: String, limit: Int) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        guard limit > 3 else { return String(trimmed.prefix(limit)) }
        return String(trimmed.prefix(limit - 3)) + "..."
    }
}

nonisolated struct HTMLWorkspaceRegenerateApplicationResult: Sendable, Equatable {
    var package: HTMLWorkspacePackage
    var appliedOperations: Int
}

nonisolated enum HTMLWorkspaceRegenerateApplicationError: LocalizedError, Equatable {
    case missingPatchBlock
    case expectedSingleReplacement
    case targetWorkspaceMismatch(expected: String, actual: String)
    case contentHashMismatch(expected: String, actual: String)

    var errorDescription: String? {
        switch self {
        case .missingPatchBlock:
            "Regenerate response did not contain an HTML Workspace patch block."
        case .expectedSingleReplacement:
            "Regenerate must return exactly one full-surface replaceDocument/regenerate operation."
        case .targetWorkspaceMismatch(let expected, let actual):
            "Regenerate targeted workspace \(expected), but the visible workspace is \(actual)."
        case .contentHashMismatch(let expected, let actual):
            "HTML Workspace changed before regenerate applied. Expected \(expected), got \(actual)."
        }
    }
}

nonisolated enum HTMLWorkspaceRegenerateApplication {
    static func apply(
        _ patchResponse: String,
        to currentPackage: HTMLWorkspacePackage,
        expectedContentHash: String
    ) throws -> HTMLWorkspaceRegenerateApplicationResult {
        let parseResult = try HTMLWorkspacePatchCommandParser.parse(patchResponse)
        guard !parseResult.batches.isEmpty else {
            throw HTMLWorkspaceRegenerateApplicationError.missingPatchBlock
        }
        guard parseResult.batches.count == 1,
              let batch = parseResult.batches.first,
              batch.operations.count == 1,
              let operation = batch.operations.first,
              case .replaceDocument = operation else {
            throw HTMLWorkspaceRegenerateApplicationError.expectedSingleReplacement
        }

        if let targetID = batch.workspaceID?.trimmingCharacters(in: .whitespacesAndNewlines),
           !targetID.isEmpty,
           targetID != currentPackage.manifest.id {
            throw HTMLWorkspaceRegenerateApplicationError.targetWorkspaceMismatch(
                expected: targetID,
                actual: currentPackage.manifest.id
            )
        }

        let actualHash = contentHash(for: currentPackage)
        let requiredHash = batch.expectedContentHash ?? expectedContentHash
        guard requiredHash == actualHash else {
            throw HTMLWorkspaceRegenerateApplicationError.contentHashMismatch(
                expected: requiredHash,
                actual: actualHash
            )
        }

        let updated = try HTMLWorkspacePatchApplier.apply(operation.patchOperation(), to: currentPackage)
        return HTMLWorkspaceRegenerateApplicationResult(package: updated, appliedOperations: 1)
    }

    private static func contentHash(for package: HTMLWorkspacePackage) -> String {
        package.currentContentHash
    }
}

enum HTMLWorkspaceRegeneratePromptBuilder {
    static let systemPrompt = """
    You regenerate Epistemos HTML Workspace surfaces.
    Return a complete replacement for the live surface.
    Prefer one ```epistemos-html-workspace-patch``` block with a single regenerate operation when routes or assets should change.
    For source-only rebuilds, use only these fenced blocks, in this order: ```html```, ```css```, ```javascript```, ```json```.
    The HTML block is body markup only. Do not include <html>, <head>, <body>, <style>, or <script>.
    Put all CSS in the CSS block and all JavaScript in the JavaScript block.
    In a regenerate patch, optional routes and assets replace those package maps atomically; omitted routes/assets are preserved.
    Route names must be package-local filenames such as about.html; do not create a route named assets because site-folder export reserves routes/assets/ for mirrored package assets.
    Route pages may reference package assets with routes/assets/<name> in exported site folders and assets/<name> from the index route.
    When data.json contains an Epistemos vault_search envelope, treat it as read-only real context: build local search/filter/cards/charts/nav from those records only.
    Each data.json result carries page_id, title, snippet, rank, context_kind, source_label, and provenance. Keep source_label/provenance visible in generated cards, tables, charts, and detail panes.
    When _epistemos.required_context_kind is present and _epistemos.required_context_available is false, show that required source as unavailable instead of relabeling generic vault results.
    Include an in-surface add-context picker/filter over available data.json records when workspace context is part of the request; picking a record should visibly add/pin that real record into the workspace, and absent records must show an honest empty or stale state.
    When selected preview context is present, treat it as the user's intended surface target and preserve its selector relationship when practical.
    Do not infer captures, chats, graph links, folders, provenance claims, or record types from a title or query string. If a source family is not explicit in data.json, label it unavailable instead of inventing it.
    Keep behavior local/offline. Do not use network calls, storage APIs, app bridge APIs, inline event handlers, or javascript: URLs.
    data.json must be valid JSON.
    """

    static func prompt(
        instruction: String,
        package: HTMLWorkspacePackage,
        expectedContentHash: String,
        selectedSurfaceContext: String? = nil
    ) -> String {
        """
        Regenerate this HTML Workspace as one complete live site.

        Workspace:
        id: \(package.manifest.id)
        title: \(package.manifest.title)
        expected_content_hash: \(expectedContentHash)

        User request:
        \(instruction)

        Verified Epistemos context:
        \(HTMLWorkspaceRegenerateContext.promptSection(for: package))

        Selected preview context:
        \(selectedSurfaceSection(selectedSurfaceContext))

        Current index.html:
        ```html
        \(bounded(package.indexHTML, limit: 28_000))
        ```

        Current style.css:
        ```css
        \(bounded(package.styleCSS, limit: 20_000))
        ```

        Current main.js:
        ```javascript
        \(bounded(package.scriptJS, limit: 16_000))
        ```

        Current data.json:
        ```json
        \(bounded(package.dataJSON, limit: 16_000))
        ```

        Current routes:
        \(boundedRoutes(package.routes, limit: 20_000))

        Current assets:
        \(assetManifest(package.assets))
        """
    }

    static func clipboardPrompt(
        instruction: String,
        package: HTMLWorkspacePackage,
        expectedContentHash: String,
        selectedSurfaceContext: String? = nil
    ) -> String {
        """
        System:
        \(systemPrompt)

        User:
        \(prompt(
            instruction: instruction,
            package: package,
            expectedContentHash: expectedContentHash,
            selectedSurfaceContext: selectedSurfaceContext
        ))
        """
    }

    private static func selectedSurfaceSection(_ context: String?) -> String {
        let trimmed = context?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "none" : bounded(trimmed, limit: 2_000)
    }

    private static func bounded(_ value: String, limit: Int) -> String {
        guard value.count > limit else { return value }
        return String(value.prefix(limit)) + "\n/* truncated */"
    }

    private static func boundedRoutes(_ routes: [String: String], limit: Int) -> String {
        guard !routes.isEmpty else { return "none" }
        var remaining = limit
        var rows: [String] = []
        for name in routes.keys.sorted() {
            guard remaining > 0 else {
                rows.append("[omitted: route context budget exhausted]")
                break
            }
            let html = routes[name, default: ""]
            let snippet = bounded(html, limit: remaining)
            rows.append("routes/\(name):\n```html\n\(snippet)\n```")
            remaining -= snippet.count
        }
        return rows.joined(separator: "\n\n")
    }

    private static func assetManifest(_ assets: [String: Data]) -> String {
        guard !assets.isEmpty else { return "none" }
        return assets.keys.sorted().map { name in
            "assets/\(name)  \(assets[name]?.count ?? 0) bytes"
        }.joined(separator: "\n")
    }
}

nonisolated struct HTMLWorkspaceRegenerateContextItem: Identifiable, Sendable, Equatable {
    var id: String { contextID }
    var pageID: String
    var title: String
    var snippet: String
    var rank: Double
    var contextKind: String
    var sourceLabel: String
    var provenance: String

    var contextID: String {
        "context_kind:\(Self.inlineIDPart(contextKind))|source:\(Self.inlineIDPart(sourceLabel))|page_id:\(Self.inlineIDPart(pageID))"
    }

    var contextDescriptor: String {
        "\(sourceLabel) / \(contextKind)"
    }

    var provenanceDescriptor: String {
        "via \(provenance)"
    }

    var rankDescriptor: String {
        "rank \(formattedRank)"
    }

    var systemImage: String {
        HTMLWorkspaceRegenerateContextPresentation.systemImage(for: contextKind)
    }

    var dragPayload: String {
        let safeTitle = Self.bounded(title, limit: 160)
        let safePageID = Self.bounded(pageID, limit: 120)
        let safeKind = Self.bounded(contextKind, limit: 80)
        let safeSource = Self.bounded(sourceLabel, limit: 120)
        let safeProvenance = Self.bounded(provenance, limit: 160)
        let safeContextID = Self.bounded(contextID, limit: 220)
        let safeSnippet = Self.bounded(snippet, limit: 560)
        return """
        Workspace context: \(safeTitle) [\(safePageID)]
        context_id: \(safeContextID)
        drop_action: regenerate_preview_context
        readonly: true
        page_id: \(safePageID)
        title: \(safeTitle)
        context_kind: \(safeKind)
        source_label: \(safeSource)
        rank: \(formattedRank)
        Source: \(safeSource) / \(safeKind)
        Provenance: \(safeProvenance)
        snippet: \(safeSnippet)
        """
    }

    static func verifiedPreviewDropPayload(from payload: String) -> String? {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 4_096 else { return nil }
        let lines = trimmed
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard lines.contains("drop_action: regenerate_preview_context"),
              lines.contains("readonly: true"),
              hasLinePrefix("context_id: context_kind:", in: lines),
              hasLinePrefix("page_id: ", in: lines),
              hasLinePrefix("title: ", in: lines),
              hasLinePrefix("context_kind: ", in: lines),
              hasLinePrefix("source_label: ", in: lines),
              hasLinePrefix("Provenance: ", in: lines),
              hasLinePrefix("snippet: ", in: lines) else {
            return nil
        }

        return trimmed
    }

    static func items(from package: HTMLWorkspacePackage, limit: Int = 12) -> [HTMLWorkspaceRegenerateContextItem] {
        guard let feed = package.manifest.dataFeed,
              let envelope = HTMLWorkspaceRegenerateContext.dataFeedEnvelope(from: package.dataJSON, matching: feed) else {
            return []
        }
        return envelope.results.prefix(limit).map { dataFeedItem(from: $0) }
    }

    static func dataFeedItem(from result: HTMLWorkspaceDataFeedResult) -> HTMLWorkspaceRegenerateContextItem {
        HTMLWorkspaceRegenerateContextItem(
            pageID: bounded(result.pageID, limit: 120),
            title: bounded(result.title, limit: 160),
            snippet: bounded(result.snippet, limit: 360),
            rank: result.rank,
            contextKind: bounded(result.contextKind, limit: 80),
            sourceLabel: bounded(result.sourceLabel, limit: 120),
            provenance: bounded(result.provenance, limit: 160)
        )
    }

    var promptRecordLines: [String] {
        let safeTitle = Self.bounded(title, limit: 160)
        let safePageID = Self.bounded(pageID, limit: 120)
        let safeKind = Self.bounded(contextKind, limit: 80)
        let safeSource = Self.bounded(sourceLabel, limit: 120)
        let safeProvenance = Self.bounded(provenance, limit: 160)
        let safeContextID = Self.bounded(contextID, limit: 220)
        let safeSnippet = Self.bounded(snippet, limit: 240)
        return [
            "- record:",
            "  context_id: \(safeContextID)",
            "  page_id: \(safePageID)",
            "  title: \(safeTitle)",
            "  context_kind: \(safeKind)",
            "  source_label: \(safeSource)",
            "  provenance: \(safeProvenance)",
            "  rank: \(formattedRank)",
            "  snippet: \(safeSnippet)",
        ]
    }

    private var formattedRank: String {
        if rank.isFinite {
            return String(format: "%.4f", rank)
        }
        return "unavailable"
    }

    private static func bounded(_ value: String, limit: Int) -> String {
        let bounded = String(value.prefix(limit + 32))
        guard bounded.count > limit else { return bounded }
        guard limit > 3 else { return String(bounded.prefix(limit)) }
        return String(bounded.prefix(limit - 3)) + "..."
    }

    private static func inlineIDPart(_ value: String) -> String {
        value.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
    }

    private static func hasLinePrefix(_ prefix: String, in lines: [String]) -> Bool {
        lines.contains { $0.hasPrefix(prefix) && $0.count > prefix.count }
    }
}

nonisolated enum HTMLWorkspaceRegenerateContext {
    static func promptSection(for package: HTMLWorkspacePackage) -> String {
        var lines: [String] = [
            "current_surface: live HTML Workspace package sources are included below.",
        ]

        if let feed = package.manifest.dataFeed {
            lines.append("vault_search.query: \(feed.normalizedQuery)")
            lines.append("vault_search.limit: \(feed.effectiveLimit)")
            if let envelope = dataFeedEnvelope(from: package.dataJSON, matching: feed) {
                let metadata = envelope.epistemos
                lines.append("vault_search.status: \(metadata.status)")
                lines.append("vault_search.stale: \(metadata.stale)")
                lines.append("vault_search.result_count: \(metadata.resultCount)")
                lines.append("vault_search.context_kinds: \(metadata.contextKinds.isEmpty ? "none" : metadata.contextKinds.joined(separator: ", "))")
                if let requiredKind = metadata.requiredContextKind, !requiredKind.isEmpty {
                    lines.append("vault_search.required_context_kind: \(requiredKind)")
                    lines.append("vault_search.required_context_available: \(metadata.requiredContextAvailable == true)")
                }
                lines.append("vault_search.provenance: \(metadata.provenance)")
                if let error = metadata.error, !error.isEmpty {
                    lines.append("vault_search.error: \(bounded(error, limit: 240))")
                }
                lines.append(contentsOf: resultLines(from: envelope.results))
            } else {
                lines.append("vault_search.status: missing or mismatched data.json envelope")
                lines.append("vault_search.results: unavailable; render an honest empty state instead of inventing notes.")
            }
        } else {
            lines.append("vault_search: not attached")
            lines.append("vault_search.results: unavailable; do not invent vault notes, PDFs/arXiv papers, folders, graph links, captures, meeting notes, web clips, chats, or provenance claims.")
        }

        lines.append("notes/PDFs/folders/captures/meeting-notes/web-clips/chats/graph/provenance-claims: use only explicit records present in data.json or the current surface; otherwise show an honest empty state.")
        lines.append("record_display_rule: show each attached record's source_label, context_kind, and provenance when rendering context-derived UI.")
        lines.append("grounding_rule: preserve real data provenance and avoid fabricated counts, titles, links, or relationships.")
        return lines.joined(separator: "\n")
    }

    static func dataFeedEnvelope(from dataJSON: String) -> HTMLWorkspaceDataFeedEnvelope? {
        guard let data = dataJSON.data(using: .utf8) else { return nil }
        return try? JSONDecoder.epdocCanonical.decode(HTMLWorkspaceDataFeedEnvelope.self, from: data)
    }

    static func dataFeedEnvelope(
        from dataJSON: String,
        matching feed: HTMLWorkspaceDataFeed
    ) -> HTMLWorkspaceDataFeedEnvelope? {
        guard let envelope = dataFeedEnvelope(from: dataJSON),
              envelope.epistemos.source == feed.source.rawValue,
              envelope.epistemos.query == feed.normalizedQuery else {
            return nil
        }
        return envelope
    }

    private static func resultLines(from results: [HTMLWorkspaceDataFeedResult]) -> [String] {
        guard !results.isEmpty else {
            return ["vault_search.results: none"]
        }
        var lines = ["vault_search.results:"]
        for result in results.prefix(12) {
            lines.append(contentsOf: HTMLWorkspaceRegenerateContextItem.dataFeedItem(from: result).promptRecordLines)
        }
        if results.count > 12 {
            lines.append("- omitted \(results.count - 12) additional result(s)")
        }
        return lines
    }

    private static func bounded(_ value: String, limit: Int) -> String {
        let bounded = String(value.prefix(limit + 32))
        guard bounded.count > limit else { return bounded }
        guard limit > 3 else { return String(bounded.prefix(limit)) }
        return String(bounded.prefix(limit - 3)) + "..."
    }
}

nonisolated enum HTMLWorkspaceRegeneratePatchSynthesizer {
    private struct ReplacementCandidate {
        var replacement: HTMLWorkspaceDocumentReplacement
        var workspaceID: String?
        var expectedContentHash: String?
    }

    enum Error: LocalizedError {
        case missingBlock(String)
        case malformedResponse
        case malformedPatchData

        var errorDescription: String? {
            switch self {
            case .missingBlock(let name):
                return "Regenerate response is missing the \(name) block."
            case .malformedResponse:
                return "Regenerate response could not be parsed."
            case .malformedPatchData:
                return "Regenerate patch could not be encoded."
            }
        }
    }

    static func patchResponse(
        from response: String,
        package: HTMLWorkspacePackage,
        expectedContentHash: String
    ) throws -> String {
        let candidate = try replacementCandidate(from: response)
        let batch = HTMLWorkspacePatchCommandBatch(
            workspaceID: candidate.workspaceID ?? package.manifest.id,
            expectedContentHash: candidate.expectedContentHash ?? expectedContentHash,
            operations: [.replaceDocument(candidate.replacement)]
        )
        let data = try JSONEncoder.epdocCanonical.encode(batch)
        guard let json = String(data: data, encoding: .utf8) else {
            throw Error.malformedPatchData
        }
        return """
        ```epistemos-html-workspace-patch
        \(json)
        ```
        """
    }

    private static func replacementCandidate(from response: String) throws -> ReplacementCandidate {
        if let patchReplacement = try replacementCandidateFromPatchBlock(response) {
            return patchReplacement
        }

        let blocks = fencedBlocks(in: response)
        guard let html = firstBlock(named: ["html"], in: blocks) else {
            throw Error.missingBlock("html")
        }
        guard let css = firstBlock(named: ["css"], in: blocks) else {
            throw Error.missingBlock("css")
        }
        guard let js = firstBlock(named: ["javascript", "js"], in: blocks) else {
            throw Error.missingBlock("javascript")
        }
        guard let dataJSON = firstBlock(named: ["json", "data", "data-json", "data.json"], in: blocks) else {
            throw Error.missingBlock("json")
        }

        let replacement = HTMLWorkspaceDocumentReplacement(
            html: html,
            css: css,
            js: js,
            dataJSON: dataJSON,
            provenanceOperation: .regenerate
        )
        try HTMLWorkspacePatchCommandParser.validate(
            HTMLWorkspacePatchCommandBatch(operations: [.replaceDocument(replacement)])
        )
        return ReplacementCandidate(replacement: replacement, workspaceID: nil, expectedContentHash: nil)
    }

    private static func replacementCandidateFromPatchBlock(_ response: String) throws -> ReplacementCandidate? {
        guard HTMLWorkspacePatchCommandParser.containsPatchBlock(in: response) else {
            return nil
        }

        let parseResult: HTMLWorkspacePatchParseResult
        do {
            parseResult = try HTMLWorkspacePatchCommandParser.parse(response)
        } catch {
            throw Error.malformedResponse
        }

        guard parseResult.batches.count == 1,
              let batch = parseResult.batches.first,
              batch.operations.count == 1,
              let operation = batch.operations.first,
              case .replaceDocument(var replacement) = operation else {
            throw Error.malformedResponse
        }

        replacement.provenanceOperation = .regenerate
        try HTMLWorkspacePatchCommandParser.validate(
            HTMLWorkspacePatchCommandBatch(operations: [.replaceDocument(replacement)])
        )
        return ReplacementCandidate(
            replacement: replacement,
            workspaceID: batch.workspaceID,
            expectedContentHash: batch.expectedContentHash
        )
    }

    private static func firstBlock(
        named names: Set<String>,
        in blocks: [(language: String, body: String)]
    ) -> String? {
        blocks.first { names.contains($0.language) }?.body
    }

    private static func fencedBlocks(in source: String) -> [(language: String, body: String)] {
        guard let expression = try? NSRegularExpression(pattern: #"(?s)```([A-Za-z0-9_+.#-]*)[^\n]*\n(.*?)```"#) else {
            return []
        }
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        return expression.matches(in: source, range: range).compactMap { match in
            guard let languageRange = Range(match.range(at: 1), in: source),
                  let bodyRange = Range(match.range(at: 2), in: source) else { return nil }
            let language = String(source[languageRange])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            guard !language.isEmpty else { return nil }
            return (
                language: language,
                body: String(source[bodyRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }
}
