import Foundation

nonisolated enum ModelVaultPromptBudget: Sendable {
    case full
    case compact
}

enum KnowledgeProfileStoreError: Error, LocalizedError {
    case failedToCreateDirectory(URL)
    case failedToPersistFile(URL)
    case failedToReadFile(URL)
    case failedToDecodeMetadata(URL)

    var errorDescription: String? {
        switch self {
        case .failedToCreateDirectory(let url):
            return "Failed to create knowledge profile directory at \(url.path)"
        case .failedToPersistFile(let url):
            return "Failed to persist knowledge profile file at \(url.path)"
        case .failedToReadFile(let url):
            return "Failed to read knowledge profile file at \(url.path)"
        case .failedToDecodeMetadata(let url):
            return "Failed to decode knowledge profile metadata at \(url.path)"
        }
    }
}

actor KnowledgeProfileStore {
    private let baseDirectory: URL
    private let fileManager: FileManager

    init(baseDirectory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.baseDirectory = baseDirectory ?? FoundationSafety.modelVaultsDirectory(fileManager: fileManager)
    }

    func save(_ vault: CompiledModelVault) throws {
        let directory = directoryURL(for: vault.modelID)
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw KnowledgeProfileStoreError.failedToCreateDirectory(directory)
        }

        let instructions = try resolvedInstructions(for: vault, in: directory)
        try persist(vault.knowledgeProfile, to: directory.appendingPathComponent("knowledge_profile.md"))
        try persist(vault.conceptIndex, to: directory.appendingPathComponent("concept_index.md"))
        try persist(vault.activeContext, to: directory.appendingPathComponent("active_context.md"))
        try persist(instructions, to: directory.appendingPathComponent("instructions.md"))
        try persistMetadata(vault.metadata, to: directory.appendingPathComponent("meta.json"))
    }

    func load(modelID: String) throws -> CompiledModelVault? {
        let directory = directoryURL(for: modelID)
        guard fileManager.fileExists(atPath: directory.path) else { return nil }

        let metadataURL = directory.appendingPathComponent("meta.json")
        let metadata = try loadMetadata(from: metadataURL)
        let knowledgeProfile = try readUTF8(at: directory.appendingPathComponent("knowledge_profile.md"))
        let conceptIndex = try readUTF8(at: directory.appendingPathComponent("concept_index.md"))
        let activeContext = try readUTF8(at: directory.appendingPathComponent("active_context.md"))
        let instructions = try readUTF8(at: directory.appendingPathComponent("instructions.md"))

        return CompiledModelVault(
            modelID: metadata.modelID,
            displayName: metadata.displayName,
            knowledgeProfile: knowledgeProfile,
            conceptIndex: conceptIndex,
            activeContext: activeContext,
            instructions: instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : instructions,
            metadata: metadata
        )
    }

    func instructionsURL(for modelID: String) -> URL {
        directoryURL(for: modelID).appendingPathComponent("instructions.md")
    }

    func modelVaultDirectoryURL(for modelID: String) -> URL {
        directoryURL(for: modelID)
    }

    func augmentedSystemPrompt(
        existingPrompt: String?,
        modelID: String,
        budget: ModelVaultPromptBudget
    ) throws -> String? {
        let normalizedExistingPrompt = Self.normalized(existingPrompt)
        guard let vault = try load(modelID: modelID) else {
            return normalizedExistingPrompt
        }

        let promptContext = Self.renderPromptContext(for: vault, budget: budget)
        guard !promptContext.isEmpty else {
            return normalizedExistingPrompt
        }
        guard let normalizedExistingPrompt else {
            return promptContext
        }
        return "\(promptContext)\n\n\(normalizedExistingPrompt)"
    }

    private func resolvedInstructions(for vault: CompiledModelVault, in directory: URL) throws -> String {
        if let instructions = vault.instructions?.trimmingCharacters(in: .whitespacesAndNewlines),
           !instructions.isEmpty {
            return instructions
        }

        let instructionsURL = directory.appendingPathComponent("instructions.md")
        if fileManager.fileExists(atPath: instructionsURL.path) {
            return try readUTF8(at: instructionsURL)
        }

        return defaultInstructions(for: vault.displayName)
    }

    private func persistMetadata(_ metadata: ModelVaultMetadata, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(metadata)
        guard let text = String(data: data, encoding: .utf8) else {
            throw KnowledgeProfileStoreError.failedToPersistFile(url)
        }
        try persist(text, to: url)
    }

    private func loadMetadata(from url: URL) throws -> ModelVaultMetadata {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw KnowledgeProfileStoreError.failedToReadFile(url)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let metadata = try? decoder.decode(ModelVaultMetadata.self, from: data) else {
            throw KnowledgeProfileStoreError.failedToDecodeMetadata(url)
        }
        return metadata
    }

    private func persist(_ content: String, to url: URL) throws {
        guard NoteFileStorage.writeTextAtomically(content, to: url, itemLabel: url.lastPathComponent) else {
            throw KnowledgeProfileStoreError.failedToPersistFile(url)
        }
    }

    private func readUTF8(at url: URL) throws -> String {
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw KnowledgeProfileStoreError.failedToReadFile(url)
        }
    }

    private func defaultInstructions(for displayName: String) -> String {
        [
            "# Instructions",
            "- Prefer concise answers with citations when the vault contains evidence.",
            "- Reference existing notes before introducing outside framing.",
            "- Match the user's established tone and terminology for \(displayName).",
        ].joined(separator: "\n")
    }

    private func directoryURL(for modelID: String) -> URL {
        baseDirectory.appendingPathComponent(safePathComponent(modelID), isDirectory: true)
    }

    private func safePathComponent(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "unknown-model" }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._"))
        let scalars = trimmed.unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        return String(scalars)
    }

    private nonisolated static func renderPromptContext(
        for vault: CompiledModelVault,
        budget: ModelVaultPromptBudget
    ) -> String {
        var contentSections: [String] = []
        if let instructions = normalized(vault.instructions) {
            contentSections.append(instructions)
        }

        switch budget {
        case .full:
            if let knowledgeProfile = normalized(vault.knowledgeProfile) {
                contentSections.append(knowledgeProfile)
            }
            if let conceptIndex = normalized(vault.conceptIndex) {
                contentSections.append(conceptIndex)
            }
            if let activeContext = normalized(vault.activeContext) {
                contentSections.append(activeContext)
            }
        case .compact:
            if let activeContext = normalized(vault.activeContext) {
                contentSections.append(activeContext)
            }
        }

        guard !contentSections.isEmpty else { return "" }
        return (
            [
                "# Model Vault Context",
                "Use this distilled vault knowledge when it is relevant to the user's request."
            ] + contentSections
        ).joined(separator: "\n\n")
    }

    private nonisolated static func normalized(_ text: String?) -> String? {
        guard let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
