import Foundation
import os
import SwiftData
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Apple Intelligence Service
// Uses FoundationModels framework (macOS 26+) for on-device LLM tasks.
// Falls back to a clear error on older OS versions so the caller can handle gracefully.

@MainActor
final class AppleIntelligenceService {
    static let shared = AppleIntelligenceService()

    private init() {}

    func generate(prompt: String, systemPrompt: String? = nil) async throws -> String {
        if #available(macOS 26.0, *) {
            return try await generateWithFoundationModels(prompt: prompt, systemPrompt: systemPrompt)
        } else {
            throw AppleIntelligenceError.unavailable("Apple Intelligence requires macOS 26 or later.")
        }
    }

    @available(macOS 26.0, *)
    private func generateWithFoundationModels(prompt: String, systemPrompt: String?) async throws -> String {
        #if canImport(FoundationModels)
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            let reason: String
            switch model.availability {
            case .available:
                reason = "Unknown"
            case .unavailable(.deviceNotEligible):
                reason = "This device is not eligible for Apple Intelligence."
            case .unavailable(.appleIntelligenceNotEnabled):
                reason = "Apple Intelligence is not enabled. Turn it on in System Settings → Apple Intelligence & Siri."
            case .unavailable(.modelNotReady):
                reason = "The on-device model is still downloading. Please try again later."
            case .unavailable(_):
                reason = "Apple Intelligence is currently unavailable."
            @unknown default:
                reason = "Apple Intelligence is currently unavailable."
            }
            throw AppleIntelligenceError.unavailable(reason)
        }

        let session: LanguageModelSession
        if let systemPrompt, !systemPrompt.isEmpty {
            session = LanguageModelSession(instructions: systemPrompt)
        } else {
            session = LanguageModelSession()
        }
        let response = try await session.respond(to: prompt)
        return response.content
        #else
        throw AppleIntelligenceError.unavailable("FoundationModels framework not available on this build machine.")
        #endif
    }

    // MARK: - Notes-Aware Reasoning (v3: SwiftData)

    /// Generate a response with notes context from SwiftData.
    /// Apple Intelligence runs on-device, so all notes stay private.
    func generateWithNotesContext(
        prompt: String,
        modelContext: ModelContext,
        systemPrompt: String? = nil,
        targetPageIds: [String]? = nil
    ) async throws -> String {
        let notesContext = collectNotesContext(modelContext: modelContext, targetPageIds: targetPageIds)
        let enrichedPrompt = """
        You have access to the user's personal knowledge base. Use it to provide deeper, more contextual reasoning.

        <knowledge-base>
        \(notesContext)
        </knowledge-base>

        User request: \(prompt)
        """
        return try await generate(prompt: enrichedPrompt, systemPrompt: systemPrompt)
    }

    /// Stream a response with notes context (on-device, private).
    func streamWithNotesContext(
        prompt: String,
        modelContext: ModelContext,
        llm: LLMService,
        systemPrompt: String? = nil,
        targetPageIds: [String]? = nil
    ) -> AsyncThrowingStream<String, Error> {
        let notesContext = collectNotesContext(modelContext: modelContext, targetPageIds: targetPageIds)
        let enrichedPrompt = """
        You have access to the user's personal knowledge base. Use it to provide deeper, more contextual reasoning.

        <knowledge-base>
        \(notesContext)
        </knowledge-base>

        User request: \(prompt)
        """
        return llm.stream(prompt: enrichedPrompt, systemPrompt: systemPrompt)
    }

    /// Collect notes content from SwiftData as a single context string.
    private func collectNotesContext(modelContext: ModelContext, targetPageIds: [String]?) -> String {
        let pages: [SDPage]
        do {
            if let targets = targetPageIds {
                let descriptor = FetchDescriptor<SDPage>(predicate: #Predicate { targets.contains($0.id) })
                pages = try modelContext.fetch(descriptor)
            } else {
                var descriptor = FetchDescriptor<SDPage>()
                descriptor.fetchLimit = 50
                pages = try modelContext.fetch(descriptor)
            }
        } catch {
            Log.notes.error("Failed to fetch notes for AI context: \(error.localizedDescription, privacy: .private)")
            return "No notes available."
        }

        guard !pages.isEmpty else { return "No notes available." }

        return pages.map { page in
            "## \(page.title)\n\(page.body)"
        }.joined(separator: "\n\n---\n\n")
    }

    /// Analyze notes and generate insights using on-device AI.
    func analyzeNotes(
        modelContext: ModelContext,
        question: String,
        targetPageIds: [String]? = nil
    ) async throws -> String {
        let systemPrompt = """
        You are a knowledge analyst with access to the user's personal note system. \
        Analyze the notes deeply, finding patterns, connections, and insights that the user might not have noticed. \
        Be specific and reference actual content from the notes.
        """
        return try await generateWithNotesContext(
            prompt: question,
            modelContext: modelContext,
            systemPrompt: systemPrompt,
            targetPageIds: targetPageIds
        )
    }

    // MARK: - Structured Output via @Generable

    @available(macOS 26.0, *)
    func analyzeNoteStructured(
        modelContext: ModelContext,
        targetPageIds: [String]? = nil
    ) async throws -> NoteAnalysisResult {
        #if canImport(FoundationModels)
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            throw AppleIntelligenceError.unavailable("Apple Intelligence is not available.")
        }

        let notesContext = collectNotesContext(modelContext: modelContext, targetPageIds: targetPageIds)
        let instructions = """
        You are a knowledge analyst. Analyze the user's notes and produce structured insights. \
        Identify key themes, connections between notes, and suggested actions.
        """
        let session = LanguageModelSession(instructions: instructions)
        let result = try await session.respond(to: notesContext, generating: NoteAnalysisResult.self)
        return result.content
        #else
        throw AppleIntelligenceError.unavailable("FoundationModels not available on this build machine.")
        #endif
    }

    @available(macOS 26.0, *)
    func summarizeNoteStructured(
        noteContent: String,
        noteTitle: String
    ) async throws -> NoteSummaryResult {
        #if canImport(FoundationModels)
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            throw AppleIntelligenceError.unavailable("Apple Intelligence is not available.")
        }

        let instructions = """
        You are a note summarization expert. Given a note, produce a concise structured summary \
        with key points, action items, and suggested tags.
        """
        let session = LanguageModelSession(instructions: instructions)
        let prompt = "Summarize this note titled \"\(noteTitle)\":\n\n\(noteContent)"
        let result = try await session.respond(to: prompt, generating: NoteSummaryResult.self)
        return result.content
        #else
        throw AppleIntelligenceError.unavailable("FoundationModels not available on this build machine.")
        #endif
    }

    /// Check if Apple Intelligence is available on this device.
    func checkAvailability() -> (available: Bool, reason: String?) {
        if #available(macOS 26.0, *) {
            #if canImport(FoundationModels)
            let model = SystemLanguageModel.default
            switch model.availability {
            case .available:
                return (true, nil)
            case .unavailable(.deviceNotEligible):
                return (false, "This device is not eligible for Apple Intelligence.")
            case .unavailable(.appleIntelligenceNotEnabled):
                return (false, "Apple Intelligence is not enabled. Turn it on in System Settings → Apple Intelligence & Siri.")
            case .unavailable(.modelNotReady):
                return (false, "The on-device model is still downloading. Try again later.")
            case .unavailable(_):
                return (false, "Apple Intelligence is currently unavailable.")
            @unknown default:
                return (false, "Apple Intelligence is currently unavailable.")
            }
            #else
            return (false, "FoundationModels framework not available on this build.")
            #endif
        } else {
            return (false, "Apple Intelligence requires macOS 26 or later.")
        }
    }
}

enum AppleIntelligenceError: LocalizedError {
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let reason): "Apple Intelligence unavailable: \(reason)"
        }
    }
}

// MARK: - @Generable Structured Output Types

#if canImport(FoundationModels)
import FoundationModels

@available(macOS 26.0, *)
@Generable
struct NoteAnalysisResult: Sendable {
    var themes: [String]
    var connections: [NoteConnection]
    var suggestedActions: [String]
    var summary: String
}

@available(macOS 26.0, *)
@Generable
struct NoteConnection: Sendable {
    var fromNote: String
    var toNote: String
    var relationship: String
}

@available(macOS 26.0, *)
@Generable
struct NoteSummaryResult: Sendable {
    var summary: String
    var keyPoints: [String]
    var actionItems: [String]
    var suggestedTags: [String]
}

#else

struct NoteAnalysisResult: Sendable {
    var themes: [String]
    var connections: [NoteConnection]
    var suggestedActions: [String]
    var summary: String
}

struct NoteConnection: Sendable {
    var fromNote: String
    var toNote: String
    var relationship: String
}

struct NoteSummaryResult: Sendable {
    var summary: String
    var keyPoints: [String]
    var actionItems: [String]
    var suggestedTags: [String]
}
#endif
