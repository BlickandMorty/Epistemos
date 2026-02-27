import SwiftUI
import SwiftData
import os

// MARK: - Vault Organizer View
// AI-powered vault organization: auto-tagging, folder suggestions, and duplicate detection.
// Presented as a sheet from the Notes sidebar. Follows "AI suggests → human approves → system executes".

struct VaultOrganizerView: View {
    let allPages: [SDPage]
    let allFolders: [SDFolder]

    @Environment(UIState.self) private var ui
    @Environment(TriageService.self) private var triage
    @Environment(VaultSyncService.self) private var vaultSync
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var suggestions: [OrgSuggestion] = []
    @State private var isScanning = false
    @State private var scanTask: Task<Void, Never>?
    @State private var scanProgress = ""
    @State private var appliedCount = 0

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.3)

            if isScanning {
                scanningView
            } else if suggestions.isEmpty {
                emptyView
            } else {
                suggestionsList
            }

            Divider().opacity(0.3)
            footer
        }
        .frame(width: 480, height: 560)
        .background(theme.background)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 16))
                .foregroundStyle(theme.accent)
            Text("Vault Organizer")
                .font(.epHeading)
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(theme.mutedForeground.opacity(0.5))
            }
            .buttonStyle(.plain)
            .help("Close")
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Scanning State

    private var scanningView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            ProgressView()
                .controlSize(.regular)
            Text("Analyzing your vault...")
                .font(.epBody)
                .foregroundStyle(theme.textSecondary)
            Text(scanProgress)
                .font(.epCaption)
                .foregroundStyle(theme.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundStyle(theme.textTertiary)
            Text("Your vault is well-organized")
                .font(.epBody)
                .foregroundStyle(theme.textSecondary)
            Text("Tap 'Scan' to analyze notes for tagging and folder suggestions.")
                .font(.epCaption)
                .foregroundStyle(theme.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            Button("Scan Vault") { startScan() }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Suggestions List

    private var suggestionsList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(suggestions) { suggestion in
                    SuggestionCard(
                        suggestion: suggestion,
                        theme: theme,
                        onApply: { applySuggestion(suggestion) },
                        onDismiss: { dismissSuggestion(suggestion) }
                    )
                }
            }
            .padding(12)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if !suggestions.isEmpty {
                Text("\(suggestions.count) suggestions")
                    .font(.epCaption)
                    .foregroundStyle(theme.textTertiary)
                if appliedCount > 0 {
                    Text("· \(appliedCount) applied")
                        .font(.epCaption)
                        .foregroundStyle(theme.accent)
                }
            }
            Spacer()
            if isScanning {
                Button("Cancel") { cancelScan() }
                    .font(.epBodyMedium)
            } else if !suggestions.isEmpty {
                Button("Apply All") { applyAll() }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.accent)
                    .font(.epBodyMedium)
            } else {
                Button("Scan Vault") { startScan() }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.accent)
                    .font(.epBodyMedium)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Scan Logic

    private func startScan() {
        scanTask?.cancel()
        isScanning = true
        suggestions = []
        appliedCount = 0

        scanTask = Task {
            // Phase 1: Find pages needing tags
            let untagged = allPages.filter { $0.tags.isEmpty }.prefix(20)
            let loose = allPages.filter { !$0.isJournal && $0.folder == nil }.prefix(20)

            if !untagged.isEmpty {
                scanProgress = "Analyzing \(untagged.count) untagged notes..."
                await generateTagSuggestions(for: Array(untagged))
            }

            guard !Task.isCancelled else { isScanning = false; return }

            if !loose.isEmpty {
                scanProgress = "Finding folder matches for \(loose.count) loose notes..."
                await generateFolderSuggestions(for: Array(loose))
            }

            guard !Task.isCancelled else { isScanning = false; return }

            isScanning = false
            scanProgress = ""
        }
    }

    private func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
    }

    // MARK: - Tag Suggestions

    private func generateTagSuggestions(for pages: [SDPage]) async {
        // Batch pages into groups of 8 to keep prompt size manageable
        let batchSize = 8
        for batchStart in stride(from: 0, to: pages.count, by: batchSize) {
            guard !Task.isCancelled else { return }
            let batchEnd = min(batchStart + batchSize, pages.count)
            let batch = Array(pages[batchStart..<batchEnd])

            let pagesJSON = batch.enumerated().map { i, page in
                """
                {"index": \(i), "title": "\(page.title.replacingOccurrences(of: "\"", with: "'"))", "snippet": "\(String(page.body.prefix(200)).replacingOccurrences(of: "\"", with: "'").replacingOccurrences(of: "\n", with: " "))"}
                """
            }.joined(separator: ",\n")

            // Collect all existing tags for consistency
            let existingTags = Set(allPages.flatMap(\.tags)).sorted().prefix(50)
            let existingTagsList = existingTags.isEmpty ? "none yet" : existingTags.joined(separator: ", ")

            // Include vault manifest for cross-note context awareness
            var vaultContext = ""
            if let manifest = AppBootstrap.shared?.ambientManifest {
                vaultContext = "\n\nVault overview for context (use existing tags and themes):\n" + manifest.asManifestOnly()
            }

            let prompt = """
            Suggest 2-4 tags for each note. Prefer reusing existing tags when relevant.
            Consider thematic connections between notes when choosing tags.
            Existing tags in vault: [\(existingTagsList)]

            Notes:
            [\(pagesJSON)]
            \(vaultContext)

            Return ONLY a JSON array: [{"index": 0, "tags": ["tag1", "tag2"]}, ...]
            Use lowercase, short tags (1-2 words). No explanations.
            """

            do {
                let result = try await triage.generateGeneral(
                    prompt: prompt,
                    systemPrompt: "You are a note organization assistant. Return only valid JSON arrays.",
                    operation: .brainstorm,
                    contentLength: prompt.count
                )

                let parsed = parseTagSuggestions(result, pages: batch)
                suggestions.append(contentsOf: parsed)
            } catch {
                Log.vault.warning("⚠️ Tag suggestion batch failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func parseTagSuggestions(_ json: String, pages: [SDPage]) -> [OrgSuggestion] {
        // Extract JSON array from response (LLM might include markdown fences)
        let cleaned = json
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8),
              let items = try? JSONDecoder().decode([TagSuggestionItem].self, from: data) else {
            return []
        }

        return items.compactMap { item in
            guard item.index >= 0, item.index < pages.count, !item.tags.isEmpty else { return nil }
            let page = pages[item.index]
            // Don't suggest tags the page already has
            let newTags = item.tags.filter { !page.tags.contains($0) }
            guard !newTags.isEmpty else { return nil }
            return OrgSuggestion(
                id: UUID().uuidString,
                pageId: page.id,
                pageTitle: page.title,
                type: .addTags(newTags)
            )
        }
    }

    // MARK: - Folder Suggestions

    private func generateFolderSuggestions(for pages: [SDPage]) async {
        let existingFolders = allFolders.filter { !$0.isCollection }
        let folderNames = existingFolders.map(\.name)

        guard !folderNames.isEmpty else {
            // No folders exist — suggest creating some based on page clusters
            await generateNewFolderSuggestions(for: pages)
            return
        }

        // Batch pages
        let batchSize = 8
        for batchStart in stride(from: 0, to: pages.count, by: batchSize) {
            guard !Task.isCancelled else { return }
            let batchEnd = min(batchStart + batchSize, pages.count)
            let batch = Array(pages[batchStart..<batchEnd])

            let pagesJSON = batch.enumerated().map { i, page in
                let snippet = String(page.body.prefix(150)).replacingOccurrences(of: "\"", with: "'").replacingOccurrences(of: "\n", with: " ")
                return """
                {"index": \(i), "title": "\(page.title.replacingOccurrences(of: "\"", with: "'"))", "snippet": "\(snippet)"}
                """
            }.joined(separator: ",\n")

            let prompt = """
            Match each note to the most relevant folder based on its content, or "none" if no good fit.
            Available folders: [\(folderNames.map { "\"\($0)\"" }.joined(separator: ", "))]

            Notes:
            [\(pagesJSON)]

            Return ONLY a JSON array: [{"index": 0, "folder": "FolderName"}, ...]
            Use "none" if no folder fits. No explanations.
            """

            do {
                let result = try await triage.generateGeneral(
                    prompt: prompt,
                    systemPrompt: "You are a note organization assistant. Return only valid JSON arrays.",
                    operation: .brainstorm,
                    contentLength: prompt.count
                )

                let parsed = parseFolderSuggestions(result, pages: batch, folders: existingFolders)
                suggestions.append(contentsOf: parsed)
            } catch {
                Log.vault.warning("⚠️ Folder suggestion batch failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func generateNewFolderSuggestions(for pages: [SDPage]) async {
        let titlesWithSnippets = pages.prefix(20).map { page in
            let snippet = String(page.body.prefix(100)).replacingOccurrences(of: "\n", with: " ")
            return "\"\(page.title)\" — \(snippet)"
        }

        var vaultHint = ""
        if let manifest = AppBootstrap.shared?.ambientManifest {
            let allTags = Set(manifest.entries.flatMap(\.tags)).sorted().prefix(20)
            if !allTags.isEmpty {
                vaultHint = "\nExisting vault themes/tags: \(allTags.joined(separator: ", "))\n"
            }
        }

        let prompt = """
        Given these notes, suggest 3-5 folder names to organize them thematically.
        Notes:
        \(titlesWithSnippets.joined(separator: "\n"))
        \(vaultHint)
        Return ONLY a JSON array of folder names: ["Folder1", "Folder2", ...]
        Use clear, short names. No explanations.
        """

        do {
            let result = try await triage.generateGeneral(
                prompt: prompt,
                systemPrompt: "You are a note organization assistant. Return only valid JSON arrays.",
                operation: .brainstorm,
                contentLength: prompt.count
            )

            let cleaned = result
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard let data = cleaned.data(using: .utf8),
                  let names = try? JSONDecoder().decode([String].self, from: data) else { return }

            for name in names.prefix(5) {
                suggestions.append(OrgSuggestion(
                    id: UUID().uuidString,
                    pageId: nil,
                    pageTitle: nil,
                    type: .createFolder(name)
                ))
            }
        } catch {
            Log.vault.warning("⚠️ New folder suggestion failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func parseFolderSuggestions(_ json: String, pages: [SDPage], folders: [SDFolder]) -> [OrgSuggestion] {
        let cleaned = json
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8),
              let items = try? JSONDecoder().decode([FolderSuggestionItem].self, from: data) else {
            return []
        }

        return items.compactMap { item in
            guard item.index >= 0, item.index < pages.count else { return nil }
            let folderName = item.folder.trimmingCharacters(in: .whitespacesAndNewlines)
            guard folderName.lowercased() != "none", !folderName.isEmpty else { return nil }

            let page = pages[item.index]
            // Don't suggest if page is already in this folder
            if page.folder?.name == folderName { return nil }

            guard let folder = folders.first(where: { $0.name.lowercased() == folderName.lowercased() }) else { return nil }

            return OrgSuggestion(
                id: UUID().uuidString,
                pageId: page.id,
                pageTitle: page.title,
                type: .moveToFolder(folder.id, folderName)
            )
        }
    }

    // MARK: - Apply / Dismiss

    private func applySuggestion(_ suggestion: OrgSuggestion) {
        switch suggestion.type {
        case .addTags(let tags):
            guard let pageId = suggestion.pageId else { return }
            let descriptor = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == pageId })
            guard let page = try? modelContext.fetch(descriptor).first else { return }
            page.tags.append(contentsOf: tags.filter { !page.tags.contains($0) })
            page.updatedAt = .now

        case .moveToFolder(let folderId, _):
            guard let pageId = suggestion.pageId else { return }
            let pageDescriptor = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == pageId })
            let folderDescriptor = FetchDescriptor<SDFolder>(predicate: #Predicate { $0.id == folderId })
            guard let page = try? modelContext.fetch(pageDescriptor).first,
                  let folder = try? modelContext.fetch(folderDescriptor).first else { return }
            page.folder = folder
            page.updatedAt = .now

        case .createFolder(let name):
            let folder = SDFolder(name: name)
            modelContext.insert(folder)
            vaultSync.createDirectory(relativePath: folder.relativePath)
        }

        appliedCount += 1
        suggestions.removeAll { $0.id == suggestion.id }
    }

    private func dismissSuggestion(_ suggestion: OrgSuggestion) {
        suggestions.removeAll { $0.id == suggestion.id }
    }

    private func applyAll() {
        let toApply = suggestions
        for suggestion in toApply {
            applySuggestion(suggestion)
        }
    }
}

// MARK: - Suggestion Card

private struct SuggestionCard: View {
    let suggestion: OrgSuggestion
    let theme: EpistemosTheme
    let onApply: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            icon
            VStack(alignment: .leading, spacing: 2) {
                if let title = suggestion.pageTitle {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                }
                description
            }
            Spacer()
            HStack(spacing: 6) {
                Button { onDismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.mutedForeground.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help("Dismiss suggestion")
                .accessibilityLabel("Dismiss suggestion")
                Button { onApply() } label: {
                    Text("Apply")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(theme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.muted.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    }

    private var icon: some View {
        Group {
            switch suggestion.type {
            case .addTags:
                Image(systemName: "tag")
                    .foregroundStyle(theme.accent)
            case .moveToFolder:
                Image(systemName: "folder")
                    .foregroundStyle(.orange)
            case .createFolder:
                Image(systemName: "folder.badge.plus")
                    .foregroundStyle(.green)
            }
        }
        .font(.system(size: 14))
        .frame(width: 24)
    }

    @ViewBuilder
    private var description: some View {
        switch suggestion.type {
        case .addTags(let tags):
            HStack(spacing: 4) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(theme.accent.opacity(0.15), in: Capsule())
                        .foregroundStyle(theme.accent)
                }
            }
        case .moveToFolder(_, let name):
            Text("Move to \(name)")
                .font(.epCaption)
                .foregroundStyle(theme.textSecondary)
        case .createFolder(let name):
            Text("Create folder: \(name)")
                .font(.epCaption)
                .foregroundStyle(theme.textSecondary)
        }
    }
}

// MARK: - Data Types

struct OrgSuggestion: Identifiable {
    let id: String
    let pageId: String?
    let pageTitle: String?
    let type: OrgSuggestionType
}

enum OrgSuggestionType {
    case addTags([String])
    case moveToFolder(String, String) // folderId, folderName
    case createFolder(String)
}

// JSON parsing helpers
private struct TagSuggestionItem: Decodable {
    let index: Int
    let tags: [String]
}

private struct FolderSuggestionItem: Decodable {
    let index: Int
    let folder: String
}
