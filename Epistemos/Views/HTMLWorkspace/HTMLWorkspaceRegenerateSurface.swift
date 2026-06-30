import Foundation
import SwiftUI

struct HTMLWorkspaceRegenerateSheet: View {
    @Binding var instruction: String
    let streamedText: String
    let errorText: String?
    let isRegenerating: Bool
    let onCancel: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "wand.and.sparkles")
                Text("Regenerate Surface")
                    .font(.headline)
                Spacer(minLength: 0)
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(isRegenerating ? "Regenerating" : "Regenerate", action: onSubmit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(isRegenerating || instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(14)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                TextField("Describe the rebuilt surface", text: $instruction, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
                    .disabled(isRegenerating)

                GroupBox {
                    ScrollView {
                        Text(streamedText.isEmpty ? (isRegenerating ? "Starting..." : "No streamed output yet.") : streamedText)
                            .font(.system(size: 12, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } label: {
                    Text("Stream")
                }

                if let errorText, !errorText.isEmpty {
                    Text(errorText)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(3)
                }
            }
            .padding(14)
        }
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
        HTMLWorkspaceDocument.contentHash(
            indexHTML: package.indexHTML,
            styleCSS: package.styleCSS,
            scriptJS: package.scriptJS,
            dataJSON: package.dataJSON,
            routes: package.routes
        )
    }
}

enum HTMLWorkspaceRegeneratePromptBuilder {
    static let systemPrompt = """
    You regenerate Epistemos HTML Workspace surfaces.
    Return a complete replacement for the live surface.
    Use only these fenced blocks, in this order: ```html```, ```css```, ```javascript```, ```json```.
    The HTML block is body markup only. Do not include <html>, <head>, <body>, <style>, or <script>.
    Put all CSS in the CSS block and all JavaScript in the JavaScript block.
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
        """
    }

    private static func bounded(_ value: String, limit: Int) -> String {
        guard value.count > limit else { return value }
        return String(value.prefix(limit)) + "\n/* truncated */"
    }
}

nonisolated enum HTMLWorkspaceRegeneratePatchSynthesizer {
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
        let replacement = try replacement(from: response)
        let batch = HTMLWorkspacePatchCommandBatch(
            workspaceID: package.manifest.id,
            expectedContentHash: expectedContentHash,
            operations: [.replaceDocument(replacement)]
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

    private static func replacement(from response: String) throws -> HTMLWorkspaceDocumentReplacement {
        if let patchReplacement = try replacementFromPatchBlock(response) {
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

        return HTMLWorkspaceDocumentReplacement(
            html: html,
            css: css,
            js: js,
            dataJSON: dataJSON,
            provenanceOperation: .regenerate
        )
    }

    private static func replacementFromPatchBlock(_ response: String) throws -> HTMLWorkspaceDocumentReplacement? {
        guard response.contains("```\(HTMLWorkspacePatchCommandParser.fencedLanguage)") else {
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
        return replacement
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
