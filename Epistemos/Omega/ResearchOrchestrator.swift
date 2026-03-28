import Foundation

// MARK: - Research Orchestrator

/// Coordinates multi-pass research loops within OrchestratorState.
/// Monitors evidence confidence, triggers pauses, handles depth escalation.
///
/// This is NOT a separate service or agent — it is internal orchestration logic
/// called by OrchestratorState when a research task type is detected.
@MainActor @Observable
final class ResearchOrchestrator {

    private(set) var confidenceState = ResearchConfidenceState()
    private(set) var isResearchTask = false
    private(set) var escalationCount = 0

    /// Maximum depth escalation rounds (prevents infinite loops).
    private let maxEscalations = 2

    // MARK: - Task Detection

    /// Returns true if the task description indicates a research task.
    nonisolated static func isResearchTask(_ description: String) -> Bool {
        let lowered = description.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return lowered.hasPrefix("research:") ||
               lowered.hasPrefix("research ") ||
               lowered.hasPrefix("/research ") ||
               lowered.hasPrefix("find evidence") ||
               lowered.hasPrefix("investigate ")
    }

    /// Called when a new task is submitted. Resets state if research.
    func beginTask(_ description: String) {
        isResearchTask = Self.isResearchTask(description)
        if isResearchTask {
            confidenceState.reset()
            escalationCount = 0
        }
    }

    /// Called after each tool execution to update confidence tracking.
    func processResult(toolName: String, resultJson: String) {
        guard isResearchTask else { return }

        switch toolName {
        case "collectsnippet":
            processSnippetResult(resultJson)
        case "scoreevidence":
            processEvidenceResult(resultJson)
        case "analyzecontradiction":
            processContradictionResult(resultJson)
        case "createresearchnote":
            processResearchNoteResult(resultJson)
        default:
            break
        }
    }

    /// Returns pause questions if confidence is too low, nil otherwise.
    func evaluatePauseNeeded() -> [String]? {
        guard isResearchTask, confidenceState.requiresPause else { return nil }

        var questions: [String] = []
        if confidenceState.overallConfidence < 0.45 {
            questions.append(
                "Evidence confidence is low (\(String(format: "%.0f%%", confidenceState.overallConfidence * 100))). "
                + "Should I search for additional sources?"
            )
        }
        if confidenceState.hasDissonance && confidenceState.snippets.count < 2 {
            questions.append(
                "Contradictions detected with limited sources. "
                + "Should I find more evidence to resolve the conflict?"
            )
        }
        return questions.isEmpty ? nil : questions
    }

    /// Returns true if depth escalation should occur (and increments counter).
    func shouldEscalate() -> Bool {
        guard isResearchTask,
              escalationCount < maxEscalations,
              confidenceState.overallConfidence < 0.45 else {
            return false
        }
        escalationCount += 1
        return true
    }

    /// The session note ID tracked across collectsnippet calls.
    var sessionNoteId: String? { confidenceState.sessionNoteId }

    // MARK: - Result Processing

    private func processSnippetResult(_ json: String) {
        guard let data = json.data(using: .utf8),
              let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let success = result["success"] as? Bool, success else { return }

        if let noteId = result["sessionNoteId"] as? String, confidenceState.sessionNoteId == nil {
            confidenceState.setSessionNoteId(noteId)
        }

        let url = result["sourceUrl"] as? String ?? ""
        let tier = ResearchEvidenceScorer.tier(for: url)
        confidenceState.addSnippet(
            text: result["text"] as? String ?? "",
            url: url,
            confidence: tier.confidence
        )
    }

    private func processEvidenceResult(_ json: String) {
        guard let data = json.data(using: .utf8),
              let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let confidence = result["confidence"] as? Double,
              let url = result["url"] as? String else { return }

        // Update the most recent snippet matching this URL with the scored confidence
        if let idx = confidenceState.snippets.lastIndex(where: { $0.url == url }) {
            let updated = confidenceState
            var snippets = updated.snippets
            snippets[idx] = .init(text: snippets[idx].text, url: url, confidence: confidence)
            // Re-assign since struct is value type
            confidenceState = ResearchConfidenceState()
            for s in snippets { confidenceState.addSnippet(text: s.text, url: s.url, confidence: s.confidence) }
            for c in updated.contradictions { confidenceState.addContradiction(snippetA: c.snippetA, snippetB: c.snippetB, verdict: c.verdict) }
            if let nid = updated.sessionNoteId { confidenceState.setSessionNoteId(nid) }
        }
    }

    private func processContradictionResult(_ json: String) {
        guard let data = json.data(using: .utf8),
              let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let verdict = result["verdict"] as? String,
              verdict == "contradict" else { return }

        confidenceState.addContradiction(
            snippetA: result["snippetA"] as? String ?? "",
            snippetB: result["snippetB"] as? String ?? "",
            verdict: verdict
        )
    }

    private func processResearchNoteResult(_ json: String) {
        guard let data = json.data(using: .utf8),
              let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let noteId = result["pageId"] as? String else { return }

        confidenceState.setSessionNoteId(noteId)
    }
}
