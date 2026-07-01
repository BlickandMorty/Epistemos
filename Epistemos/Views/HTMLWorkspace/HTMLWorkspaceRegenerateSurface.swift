import Foundation
import SwiftUI

struct HTMLWorkspaceRegenerateSheet: View {
    @Binding var instruction: String
    @Binding var streamedText: String
    let workspaceID: String
    let expectedContentHash: String
    let errorText: String?
    let isRegenerating: Bool
    let onCancel: () -> Void
    let onCopyPrompt: () -> Void
    let onSubmit: () -> Void
    let onPreviewStream: () -> Void
    let onApplyStream: () -> Void
    let onRestorePreview: () -> Void

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

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "wand.and.sparkles")
                    .foregroundStyle(theme.resolved.accent.color)
                Text("Regenerate Surface")
                    .font(.headline)
                    .foregroundStyle(theme.resolved.foreground.color)
                Spacer(minLength: 0)
                Button(action: onCancel) {
                    Label("Cancel", systemImage: "xmark.circle")
                }
                .keyboardShortcut(.cancelAction)
                Button(action: onCopyPrompt) {
                    Label("Copy Prompt", systemImage: "doc.on.doc")
                }
                .disabled(isRegenerating || instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button(action: onPreviewStream) {
                    Label("Preview Stream", systemImage: "eye")
                }
                .disabled(isRegenerating || streamedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button(action: onRestorePreview) {
                    Label("Show Current", systemImage: "arrow.uturn.backward.circle")
                }
                .disabled(isRegenerating)
                Button(action: onApplyStream) {
                    Label("Apply Stream", systemImage: "checkmark.circle")
                }
                .disabled(isRegenerating || streamedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button(action: onSubmit) {
                    Label(isRegenerating ? "Regenerating" : "Regenerate", systemImage: "wand.and.sparkles")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isRegenerating || instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(14)

            VStack(alignment: .leading, spacing: 10) {
                TextField("Describe the rebuilt surface", text: $instruction, axis: .vertical)
                    .textFieldStyle(.plain)
                    .foregroundStyle(theme.resolved.foreground.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(fieldBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .lineLimit(3...6)
                    .disabled(isRegenerating)

                HStack(spacing: 6) {
                    Label("Target", systemImage: "scope")
                    Text("\(workspaceID.prefix(10)) / \(expectedContentHash.prefix(10))")
                        .font(.caption.monospaced())
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .font(.caption)
                .foregroundStyle(mutedText)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Stream")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(mutedText)
                    ZStack(alignment: .topLeading) {
                        if streamedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(isRegenerating ? "Starting..." : "Paste or stream a regenerate response.")
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(streamBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
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
        .background(sheetBackground)
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
    Keep behavior local/offline. Do not use network calls, storage APIs, app bridge APIs, inline event handlers, or javascript: URLs.
    data.json must be valid JSON.
    """

    static func prompt(
        instruction: String,
        package: HTMLWorkspacePackage,
        expectedContentHash: String
    ) -> String {
        """
        Regenerate this HTML Workspace as one complete live site.

        Workspace:
        id: \(package.manifest.id)
        title: \(package.manifest.title)
        expected_content_hash: \(expectedContentHash)

        User request:
        \(instruction)

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
        expectedContentHash: String
    ) -> String {
        """
        System:
        \(systemPrompt)

        User:
        \(prompt(
            instruction: instruction,
            package: package,
            expectedContentHash: expectedContentHash
        ))
        """
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
