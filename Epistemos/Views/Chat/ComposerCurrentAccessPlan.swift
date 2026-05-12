import Foundation

struct ComposerResourceGrantRow: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String
    let isRevocable: Bool
}

struct ComposerCurrentAccessPlan: Equatable {
    let rows: [ComposerResourceGrantRow]
    let summaryText: String
    let allowedToolNames: Set<String>
    let writableResourceURIs: Set<String>

    init(
        vaultURL: URL?,
        contextAttachments: [ContextAttachment],
        fileAttachments: [FileAttachment],
        compiledAllowedToolNames: [String] = []
    ) {
        var rows: [ComposerResourceGrantRow] = []
        var writableResourceURIs: Set<String> = []

        if let vaultURL {
            rows.append(
                ComposerResourceGrantRow(
                    id: "vault:\(vaultURL.path)",
                    title: vaultURL.lastPathComponent,
                    detail: "Read + Search active vault",
                    systemImage: "books.vertical",
                    isRevocable: false
                )
            )
        }

        for attachment in contextAttachments {
            if Self.isLiveWritableResource(attachment),
               let resourceURI = Self.normalizedResourceURI(attachment.resourceURI) {
                writableResourceURIs.insert(resourceURI)
            }
            rows.append(
                ComposerResourceGrantRow(
                    id: "context:\(attachment.id)",
                    title: attachment.title,
                    detail: Self.detail(for: attachment),
                    systemImage: attachment.systemImageName,
                    isRevocable: true
                )
            )
        }

        for attachment in fileAttachments {
            rows.append(
                ComposerResourceGrantRow(
                    id: "file:\(attachment.id)",
                    title: attachment.name,
                    detail: "Read attached file",
                    systemImage: Self.icon(for: attachment.type),
                    isRevocable: true
                )
            )
        }

        let allowedToolNames = Set(compiledAllowedToolNames.map { $0.lowercased() })
        self.rows = rows
        self.summaryText = Self.summaryText(
            vaultURL: vaultURL,
            contextAttachments: contextAttachments,
            fileAttachments: fileAttachments,
            allowedToolNames: allowedToolNames
        )
        self.allowedToolNames = allowedToolNames
        self.writableResourceURIs = writableResourceURIs
    }

    func canWriteResource(_ resourceURI: String) -> Bool {
        guard let normalized = Self.normalizedResourceURI(resourceURI) else {
            return false
        }
        return writableResourceURIs.contains(normalized)
    }

    static func detail(for attachment: ContextAttachment) -> String {
        switch attachment.kind {
        case .note:
            if attachment.resourceMode == .snapshot {
                return "Read attached note snapshot"
            }
            return isLiveWritableResource(attachment)
                ? "Read + Edit attached note"
                : "Read attached note context"
        case .chat:
            return "Read attached chat context"
        case .allNotes:
            return "Read + Search attached vault context"
        case .folder:
            if attachment.resourceMode == .snapshot {
                return "Read attached folder snapshot"
            }
            return isLiveWritableResource(attachment)
                ? "Read + Edit attached folder notes"
                : "Read attached folder context"
        case .file:
            if attachment.resourceMode == .snapshot {
                return "Read attached pasted snapshot"
            }
            return isLiveWritableResource(attachment)
                ? "Read + Edit attached file"
                : "Read attached file"
        }
    }

    private static func summaryText(
        vaultURL: URL?,
        contextAttachments: [ContextAttachment],
        fileAttachments: [FileAttachment],
        allowedToolNames: Set<String>
    ) -> String {
        var segments: [String] = []

        if contextAttachments.contains(where: { ($0.kind == .note || $0.kind == .folder) && isLiveWritableResource($0) }) {
            segments.append("Read + Edit attached notes")
        } else if contextAttachments.contains(where: { $0.kind == .file && isLiveWritableResource($0) }) {
            segments.append("Read + Edit attached files")
        } else if !contextAttachments.isEmpty || !fileAttachments.isEmpty {
            segments.append("Read attached resources")
        }

        if vaultURL != nil {
            segments.append("Read + Search vault")
        }

        if let toolSummary = toolSummary(for: allowedToolNames) {
            segments.append(toolSummary)
        }

        if segments.isEmpty {
            segments.append("Local chat")
        }
        return segments.joined(separator: " · ")
    }

    private static func toolSummary(for allowedToolNames: Set<String>) -> String? {
        let toolLabels: [(name: String, label: String)] = [
            ("web.search", "Web search"),
            ("web.fetch", "Web fetch"),
            ("web.extract", "Web extract"),
            ("google_search", "Grounding"),
            ("code_execution", "Provider code"),
        ]
        let labels = toolLabels.compactMap { tool in
            AgentToolNameAliases.containsEquivalent(allowedToolNames, tool.name) ? tool.label : nil
        }

        guard !labels.isEmpty else { return nil }
        return labels.joined(separator: " + ")
    }

    private static func isLiveWritableResource(_ attachment: ContextAttachment) -> Bool {
        guard attachment.resourceMode == .live,
              capabilityList(attachment.resourceCapabilities).contains("write"),
              let attachedResource = attachment.toAttachedResource()
        else {
            return false
        }
        return attachedResourceAllows(attachment: attachedResource, capability: .write)
    }

    private static func capabilityList(_ capabilities: [String]?) -> Set<String> {
        Set((capabilities ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
    }

    private static func normalizedResourceURI(_ resourceURI: String?) -> String? {
        guard let trimmed = resourceURI?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else {
            return nil
        }
        return trimmed
    }

    private static func icon(for type: AttachmentType) -> String {
        switch type {
        case .image: return "photo"
        case .pdf: return "doc.richtext"
        case .csv: return "tablecells"
        case .text: return "doc.text"
        case .other: return "paperclip"
        }
    }
}
