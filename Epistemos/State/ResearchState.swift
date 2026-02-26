import Foundation
import Observation
import os

// MARK: - Notes → Research Bridge

struct NotesResearchPrefill: Equatable, Sendable {
    var title: String
    var content: String
}

// MARK: - Research State
// Ephemeral observable state for research UI.
// MIGRATION NOTE: savedPapers currently uses UserDefaults (v2 carryover).
// v3 architecture says persistent data → SwiftData. When Phase 03+ adds
// the library view, create SDSavedPaper @Model and migrate this.

@MainActor @Observable
final class ResearchState {
    var researchPapers: [ResearchPaper] = []
    var savedPapers: [SavedPaper] = []
    var currentCitations: [Citation] = []
    var pendingReroute: RerouteInstruction?
    var researchBooks: [ResearchBook] = []
    var pendingNotesContent: NotesResearchPrefill?

    // MARK: - Research Papers

    func addResearchPaper(_ paper: ResearchPaper) {
        guard !researchPapers.contains(where: { $0.id == paper.id }) else { return }
        researchPapers.append(paper)
    }

    // MARK: - Saved Papers (Library)
    // TODO: Migrate to SDSavedPaper @Model when library view is built.
    // UserDefaults is a v2 holdover — persistent data should live in SwiftData.

    private static let savedPapersKey = "epistemos.research.savedPapers"

    func addSavedPaper(_ paper: SavedPaper) {
        // Deduplicate by ID or by normalized title (auto-extracted papers won't share IDs)
        let normalizedTitle = paper.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !savedPapers.contains(where: {
            $0.id == paper.id || $0.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedTitle
        }) else { return }
        savedPapers.append(paper)
        persistSavedPapers()
    }

    func removeSavedPaper(_ id: String) {
        savedPapers.removeAll { $0.id == id }
        persistSavedPapers()
    }

    func togglePaperFavorite(_ id: String) {
        guard let idx = savedPapers.firstIndex(where: { $0.id == id }) else { return }
        savedPapers[idx].isFavorite.toggle()
        persistSavedPapers()
    }

    func restoreSavedPapers() {
        if let data = UserDefaults.standard.data(forKey: Self.savedPapersKey) {
            do {
                savedPapers = try JSONDecoder().decode([SavedPaper].self, from: data)
            } catch {
                Log.research.error("Failed to decode saved papers: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func persistSavedPapers() {
        do {
            let data = try JSONEncoder().encode(savedPapers)
            UserDefaults.standard.set(data, forKey: Self.savedPapersKey)
        } catch {
            Log.research.error("Failed to encode saved papers: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Citations

    func setCurrentCitations(_ citations: [Citation]) {
        currentCitations = citations
    }

    // MARK: - Reroute

    func setPendingReroute(_ instruction: RerouteInstruction?) {
        pendingReroute = instruction
    }

    // MARK: - Reset

    func reset() {
        researchPapers = []
        currentCitations = []
        pendingReroute = nil
        pendingNotesContent = nil
    }
}
