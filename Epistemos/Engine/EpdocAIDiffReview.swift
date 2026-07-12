import Foundation

/// Settled AI edit proposal passed from native Epdoc chrome into the JS
/// ProseMirror AI-diff extension. The JS side rejects token-stream payloads;
/// Swift mirrors that contract by always encoding `settled: true`.
nonisolated public struct EpdocAIDiffStageRequest: Sendable, Hashable {
    public let markdown: String
    public let claimId: String
    public let batchId: String
    public let settled: Bool

    public init?(markdown: String, claimId: String, batchId: String) {
        let trimmedMarkdown = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedClaimID = claimId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBatchID = batchId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMarkdown.isEmpty,
              !trimmedClaimID.isEmpty,
              !trimmedBatchID.isEmpty else {
            return nil
        }
        self.markdown = trimmedMarkdown
        self.claimId = trimmedClaimID
        self.batchId = trimmedBatchID
        self.settled = true
    }
}

/// Native review affordance for a staged Epdoc AI edit. This keeps the dock
/// bounded: it can preview, accept, or reject a settled proposal, but it does
/// not invent a free-form chat loop inside the editor chrome.
nonisolated public struct EpdocAIDiffReviewDraft: Sendable, Hashable, Identifiable {
    public let request: EpdocAIDiffStageRequest
    public let title: String
    public let summary: String

    public init(
        request: EpdocAIDiffStageRequest,
        title: String = "AI edit",
        summary: String = "Preview a settled edit before applying it."
    ) {
        self.request = request
        self.title = title
        self.summary = summary
    }

    public var id: String { request.batchId }

    public var previewCommand: EpdocEditorCommand {
        .stageAIDiff(request: request)
    }

    public var acceptCommand: EpdocEditorCommand {
        .acceptAIDiff
    }

    public var rejectCommand: EpdocEditorCommand {
        .rejectAIDiff
    }
}

/// Native review affordance for a tracked suggestion span. Unlike the settled
/// AI-diff preview above, this stages one bounded replacement through the
/// LumenLens SuggestionAdapter so JS emits provenance events and the user still
/// accepts or rejects the change.
nonisolated public struct EpdocSuggestionReviewDraft: Sendable, Hashable, Identifiable {
    public let payload: EpdocSuggestionSpanPayload
    public let title: String
    public let summary: String

    public init(
        payload: EpdocSuggestionSpanPayload,
        title: String = "June suggestion",
        summary: String = "Stage a tracked suggestion before accepting it."
    ) {
        self.payload = payload
        self.title = title
        self.summary = summary
    }

    public var id: String { payload.id }

    public var stageCommand: EpdocEditorCommand {
        .applySuggestion(payload: payload)
    }

    public var acceptCommand: EpdocEditorCommand {
        .acceptSuggestion(id: payload.id)
    }

    public var rejectCommand: EpdocEditorCommand {
        .rejectSuggestion(id: payload.id)
    }
}
