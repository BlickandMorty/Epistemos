import Foundation

nonisolated struct EpdocMarkdownWriteThroughRequest: Sendable {
    let mode: EpdocSourceOfTruthMode
    let vaultURL: URL?
    let manifest: EpdocManifest
    let markdown: String?
    let contentJSONHash: String?

    init(
        mode: EpdocSourceOfTruthMode = EpdocSourceOfTruthMode(),
        vaultURL: URL?,
        manifest: EpdocManifest,
        markdown: String?,
        contentJSONHash: String?
    ) {
        self.mode = mode
        self.vaultURL = vaultURL
        self.manifest = manifest
        self.markdown = markdown
        self.contentJSONHash = contentJSONHash
    }
}

nonisolated enum EpdocMarkdownWriteThroughSkipReason: Equatable, Sendable {
    case jsonOnly
    case markdownCanonicalReadPathPending
    case missingVault
    case missingMarkdownSnapshot
    case emptyMarkdownSnapshot
    case markdownAlreadyHasFrontmatter
    case invalidManifestID
}

nonisolated enum EpdocMarkdownWriteThroughResult: Equatable, Sendable {
    case wrote(URL)
    case skipped(EpdocMarkdownWriteThroughSkipReason)
    case failed(String)
}

nonisolated enum EpdocMarkdownWriteThrough {
    private static let notesDirectoryName = "notes"

    static func shouldAttemptWrite(_ request: EpdocMarkdownWriteThroughRequest) -> Bool {
        guard request.mode == .dualWrite,
              request.vaultURL != nil,
              let markdown = request.markdown,
              !isBlank(markdown),
              !startsWithYAMLFrontmatter(markdown),
              safeDocumentID(request.manifest.id) != nil else {
            return false
        }
        return true
    }

    static func writeIfEnabled(
        _ request: EpdocMarkdownWriteThroughRequest,
        fileManager: FileManager = .default
    ) -> EpdocMarkdownWriteThroughResult {
        switch request.mode {
        case .jsonOnly:
            return .skipped(.jsonOnly)
        case .markdownCanonical:
            return .skipped(.markdownCanonicalReadPathPending)
        case .dualWrite:
            break
        }

        guard let vaultURL = request.vaultURL else {
            return .skipped(.missingVault)
        }
        guard let markdown = request.markdown else {
            return .skipped(.missingMarkdownSnapshot)
        }
        guard !isBlank(markdown) else {
            return .skipped(.emptyMarkdownSnapshot)
        }
        guard !startsWithYAMLFrontmatter(markdown) else {
            return .skipped(.markdownAlreadyHasFrontmatter)
        }
        guard let targetURL = targetURL(vaultURL: vaultURL, manifestID: request.manifest.id) else {
            return .skipped(.invalidManifestID)
        }

        do {
            try fileManager.createDirectory(
                at: targetURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } catch {
            return .failed(error.localizedDescription)
        }

        let serialized = serializedMarkdown(
            manifest: request.manifest,
            markdown: markdown,
            contentJSONHash: request.contentJSONHash
        )
        let wrote = NoteFileStorage.writeTextAtomically(
            serialized,
            to: targetURL,
            itemLabel: "Epdoc markdown source \(request.manifest.id)"
        )
        return wrote ? .wrote(targetURL) : .failed("atomic markdown write failed")
    }

    static func targetURL(vaultURL: URL, manifestID: String) -> URL? {
        guard let safeID = safeDocumentID(manifestID) else { return nil }
        return vaultURL
            .appendingPathComponent(notesDirectoryName, isDirectory: true)
            .appendingPathComponent("\(safeID).md", isDirectory: false)
    }

    static func serializedMarkdown(
        manifest: EpdocManifest,
        markdown: String,
        contentJSONHash: String?
    ) -> String {
        var lines = [
            "---",
            "_epdoc_id: \(yamlString(manifest.id))",
            "_epdoc_kind: \(yamlString(manifest.kind.snakeCaseString))",
            "_epdoc_schema_version: \(manifest.schemaVersion)",
            "title: \(yamlString(manifest.title))",
            "created_at: \(manifest.createdAt)",
            "updated_at: \(manifest.updatedAt)",
            "_epdoc_producer: \(yamlString(manifest.provenance.producer.rawValue))",
        ]

        if let contentJSONHash, !isBlank(contentJSONHash) {
            lines.append("_epdoc_content_json_hash: \(yamlString(contentJSONHash))")
        }
        if let generatedByRun = manifest.provenance.generatedByRun,
           !isBlank(generatedByRun) {
            lines.append("_epdoc_generated_by_run: \(yamlString(generatedByRun))")
        }
        if let toolID = manifest.provenance.toolId, !isBlank(toolID) {
            lines.append("_epdoc_tool_id: \(yamlString(toolID))")
        }
        if let metadata = manifest.metadata {
            for key in metadata.keys.sorted() {
                guard let safeKey = safeFrontmatterKey(key),
                      let value = metadata[key] else {
                    continue
                }
                lines.append("_epdoc_metadata_\(safeKey): \(yamlString(value))")
            }
        }

        lines.append("---")
        lines.append("")

        var output = lines.joined(separator: "\n")
        output.append(normalizedBody(markdown))
        return output
    }

    static func startsWithYAMLFrontmatter(_ markdown: String) -> Bool {
        let cleaned = markdown.hasPrefix("\u{FEFF}") ? String(markdown.dropFirst()) : markdown
        let lines = cleaned.components(separatedBy: "\n")
        guard lines.first == "---" else { return false }
        return lines.dropFirst().contains { line in
            line.trimmingCharacters(in: .whitespaces) == "---"
        }
    }

    private static func isBlank(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func normalizedBody(_ markdown: String) -> String {
        let separator = markdown.hasPrefix("\n") ? "" : "\n"
        let terminal = markdown.hasSuffix("\n") ? "" : "\n"
        return "\(separator)\(markdown)\(terminal)"
    }

    private static func safeDocumentID(_ rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var output = ""
        var lastWasDash = false
        for scalar in trimmed.unicodeScalars {
            switch scalar.value {
            case 48...57, 65...90, 97...122, 46, 95:
                output.unicodeScalars.append(scalar)
                lastWasDash = false
            case 45:
                if !lastWasDash {
                    output.append("-")
                    lastWasDash = true
                }
            default:
                if !lastWasDash {
                    output.append("-")
                    lastWasDash = true
                }
            }
        }

        let cleaned = output
            .trimmingCharacters(in: CharacterSet(charactersIn: ".-"))
            .prefix(160)
        let safeID = String(cleaned)
        return safeID.isEmpty ? nil : safeID
    }

    private static func safeFrontmatterKey(_ rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var output = ""
        var lastWasUnderscore = false
        for scalar in trimmed.lowercased().unicodeScalars {
            switch scalar.value {
            case 48...57, 97...122:
                output.unicodeScalars.append(scalar)
                lastWasUnderscore = false
            default:
                if !lastWasUnderscore {
                    output.append("_")
                    lastWasUnderscore = true
                }
            }
        }

        let cleaned = output.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func yamlString(_ value: String) -> String {
        var escaped = ""
        for scalar in value.unicodeScalars {
            switch scalar.value {
            case 0x22:
                escaped.append("\\\"")
            case 0x5c:
                escaped.append("\\\\")
            case 0x0a:
                escaped.append("\\n")
            case 0x0d:
                escaped.append("\\r")
            case 0x09:
                escaped.append("\\t")
            default:
                if scalar.value < 0x20 {
                    escaped.append(" ")
                } else {
                    escaped.unicodeScalars.append(scalar)
                }
            }
        }
        return "\"\(escaped)\""
    }
}
