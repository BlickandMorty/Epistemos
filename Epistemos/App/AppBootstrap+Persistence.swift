import Foundation
import SwiftData

// MARK: - Chat Persistence
// Writes chat messages and enrichment data to SwiftData.

extension AppBootstrap {

    /// Write user + assistant messages to SwiftData after pipeline completion.
    /// Creates SDChat on first message, reuses existing chat for subsequent exchanges.
    func persistChatCompletion(
        chatId: String?,
        query: String,
        answer: String,
        dual: DualMessage?,
        truth: TruthAssessment?,
        confidence: Double,
        grade: EvidenceGrade,
        mode: InferenceMode,
        isResearch: Bool = false,
        isNotes: Bool = false
    ) {
        guard let chatId else { return }
        let context = modelContainer.mainContext

        let chat: SDChat
        let predicate = #Predicate<SDChat> { $0.id == chatId }
        let descriptor = FetchDescriptor<SDChat>(predicate: predicate)

        if let existing = try? context.fetch(descriptor).first {
            chat = existing
            chat.updatedAt = .now
        } else {
            let firstWords = String(query.prefix(50))
            chat = SDChat(title: firstWords, chatType: "chat")
            chat.id = chatId
            context.insert(chat)
        }
        if isResearch { chat.hasDeepResearch = true }
        if isNotes { chat.chatType = "notes" }

        // User message
        let userMsg = SDMessage(role: "user", content: query)
        userMsg.chat = chat
        context.insert(userMsg)

        // Assistant message
        let assistantMsg = SDMessage(role: "assistant", content: answer)
        assistantMsg.confidenceScore = confidence
        assistantMsg.evidenceGrade = grade.rawValue
        assistantMsg.inferenceMode = mode.rawValue
        assistantMsg.dualMessageData = try? JSONEncoder().encode(dual)
        assistantMsg.truthAssessmentData = try? JSONEncoder().encode(truth)
        assistantMsg.chat = chat
        context.insert(assistantMsg)

        do {
            try context.save()
            Log.db.info("Persisted chat \(chatId, privacy: .public): user + assistant messages")
        } catch {
            Log.db.error("Failed to persist chat: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Persist enrichment data (Passes 2-6) to the last assistant SDMessage.
    /// Called when `.enriched` fires so reloading the chat retains Lucid Lens data.
    func persistEnrichment(
        chatId: String?,
        dualMessage: DualMessage,
        truthAssessment: TruthAssessment
    ) {
        guard let chatId else { return }
        let context = modelContainer.mainContext

        let predicate = #Predicate<SDChat> { $0.id == chatId }
        let descriptor = FetchDescriptor<SDChat>(predicate: predicate)

        guard let chat = try? context.fetch(descriptor).first,
              let lastAssistant = (chat.messages ?? [])
                  .filter({ $0.role == "assistant" })
                  .max(by: { $0.createdAt < $1.createdAt })
        else {
            Log.db.warning("persistEnrichment: no assistant message found for chat \(chatId, privacy: .public)")
            return
        }

        lastAssistant.dualMessageData = try? JSONEncoder().encode(dualMessage)
        lastAssistant.truthAssessmentData = try? JSONEncoder().encode(truthAssessment)
        lastAssistant.confidenceScore = truthAssessment.overallTruthLikelihood
        let grade = Self.gradeFromConfidence(truthAssessment.overallTruthLikelihood)
        lastAssistant.evidenceGrade = grade.rawValue

        do {
            try context.save()
            Log.db.info("Persisted enrichment for chat \(chatId, privacy: .public)")
        } catch {
            Log.db.error("Failed to persist enrichment: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Map pipeline confidence to evidence grade.
    static func gradeFromConfidence(_ confidence: Double) -> EvidenceGrade {
        switch confidence {
        case 0.85...: .a
        case 0.70..<0.85: .b
        case 0.50..<0.70: .c
        case 0.30..<0.50: .d
        default: .f
        }
    }
}
