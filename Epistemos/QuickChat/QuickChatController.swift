#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)

import Foundation
import Observation
import OSLog

// Retained quick-chat controller. The App Store Landing entry point is parked;
// MAS June is the active agent surface. Apple FM remains an on-device helper
// lane, while GGUF is an unavailable adapter in this build.

nonisolated struct QuickChatMessage: Identifiable, Equatable, Sendable {
    enum Role: Equatable, Sendable {
        case user
        case assistant(engine: QuickChatEngineID)
        case notice
    }

    let id: UUID
    let role: Role
    var text: String

    init(id: UUID = UUID(), role: Role, text: String) {
        self.id = id
        self.role = role
        self.text = text
    }
}

@MainActor
@Observable
final class QuickChatController {
    enum EngineStatus: Equatable {
        case ready(QuickChatEngineID)
        case unavailable(String)
    }

    private static let log = Logger(subsystem: "com.epistemos", category: "QuickChat")
    private static let instructions =
        "You are Epistemos's quick answer companion. Answer directly, plainly, and briefly. " +
        "Prefer concrete facts and short explanations over lists. Everything runs privately on this Mac."
    private static let replyBudgetTokens = 1024

    private(set) var messages: [QuickChatMessage] = []
    private(set) var isGenerating = false

    private let fmBackend = AppleFMQuickChatBackend()
    let ggufBackend = LocalGGUFQuickChatBackend.shared
    private var generationTask: Task<Void, Never>?

    var engineStatus: EngineStatus {
        if AppleFMQuickChatBackend.unavailability() == nil {
            return .ready(.appleFM)
        }
        if ggufBackend.unavailability() == nil, let entry = ggufBackend.resolvedEntry() {
            return .ready(.localGGUF(modelID: entry.id))
        }
        let fmReason = AppleFMQuickChatBackend.unavailability()?.userCopy
            ?? QuickChatEngineUnavailable.modelNotReady.userCopy
        let localReason = ggufBackend.unavailability()?.userCopy
            ?? QuickChatEngineUnavailable.noLocalModelInstalled.userCopy
        return .unavailable("\(fmReason) \(localReason)")
    }

    func send(_ rawPrompt: String) {
        let prompt = rawPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isGenerating else { return }

        messages.append(QuickChatMessage(role: .user, text: prompt))
        isGenerating = true

        generationTask = Task { [self] in
            defer {
                isGenerating = false
                generationTask = nil
            }
            switch engineStatus {
            case .ready(.appleFM):
                await runFM(prompt: prompt)
            case .ready(.localGGUF):
                await runGGUF(prompt: prompt, fellBackFromFM: false, fallbackReason: nil)
            case .ready:
                await runGGUF(prompt: prompt, fellBackFromFM: false, fallbackReason: nil)
            case .unavailable(let reason):
                messages.append(QuickChatMessage(role: .notice, text: reason))
            }
        }
    }

    func cancel() {
        generationTask?.cancel()
        ggufBackend.cancel()
    }

    // MARK: - Engine runs

    private func runFM(prompt: String) async {
        let messageID = appendAssistantPlaceholder(engine: .appleFM)
        do {
            for try await delta in fmBackend.stream(prompt: prompt, instructions: Self.instructions) {
                if Task.isCancelled { return }
                appendText(delta, to: messageID)
            }
            finalizeIfEmpty(messageID)
        } catch QuickChatError.guardrailBlocked {
            // §2.1: guardrails throw on legitimate scholarly content sometimes
            // — fall back to the local model, honestly labeled.
            removeMessage(messageID)
            if ggufBackend.unavailability() == nil {
                messages.append(QuickChatMessage(
                    role: .notice,
                    text: "Apple Intelligence declined this topic — answering with the on-device model instead."
                ))
                await runGGUF(prompt: prompt, fellBackFromFM: true, fallbackReason: "guardrail")
            } else {
                messages.append(QuickChatMessage(
                    role: .notice,
                    text: "Apple Intelligence declined this topic. Use MAS June with a configured cloud model for agent answers."
                ))
            }
        } catch is CancellationError {
            finalizeIfEmpty(messageID)
        } catch {
            removeMessage(messageID)
            if ggufBackend.unavailability() == nil {
                await runGGUF(prompt: prompt, fellBackFromFM: true, fallbackReason: "fm-error")
            } else {
                messages.append(QuickChatMessage(
                    role: .notice,
                    text: "Couldn't answer right now: \(describe(error))"
                ))
            }
        }
    }

    private func runGGUF(prompt: String, fellBackFromFM: Bool, fallbackReason: String?) async {
        guard let entry = ggufBackend.resolvedEntry() else {
            messages.append(QuickChatMessage(
                role: .notice,
                text: QuickChatEngineUnavailable.noLocalModelInstalled.userCopy
            ))
            return
        }
        if fellBackFromFM {
            Self.log.info("QuickChat fell back FM→GGUF reason=\(fallbackReason ?? "unknown", privacy: .public)")
        }
        // §2.2 refusal rule: refuse gracefully, never limp into swap.
        let promptTokenEstimate = prompt.count / 3
        guard GGUFModelCatalog.promptFits(
            entry: entry,
            promptTokenEstimate: promptTokenEstimate,
            replyBudgetTokens: Self.replyBudgetTokens
        ) else {
            messages.append(QuickChatMessage(
                role: .notice,
                text: "That's more text than \(entry.displayName) can read at once — a paper fits; a book needs chunking. Try a shorter passage."
            ))
            return
        }

        let messageID = appendAssistantPlaceholder(engine: .localGGUF(modelID: entry.id))
        do {
            for try await delta in ggufBackend.stream(
                prompt: prompt,
                instructions: Self.instructions,
                maxNewTokens: Self.replyBudgetTokens
            ) {
                if Task.isCancelled { return }
                appendText(delta, to: messageID)
            }
            finalizeIfEmpty(messageID)
        } catch {
            removeMessage(messageID)
            messages.append(QuickChatMessage(
                role: .notice,
                text: "Local answer failed: \(describe(error))"
            ))
        }
    }

    // MARK: - Transcript helpers

    private func appendAssistantPlaceholder(engine: QuickChatEngineID) -> UUID {
        let message = QuickChatMessage(role: .assistant(engine: engine), text: "")
        messages.append(message)
        return message.id
    }

    private func appendText(_ delta: String, to id: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].text += delta
    }

    private func finalizeIfEmpty(_ id: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        if messages[index].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages.remove(at: index)
        }
    }

    private func removeMessage(_ id: UUID) {
        messages.removeAll { $0.id == id }
    }

    private func describe(_ error: Error) -> String {
        if let quickChatError = error as? QuickChatError {
            switch quickChatError {
            case .guardrailBlocked:
                return "the on-device guardrails declined this topic."
            case .exceededContextWindow:
                return "that text is too long for the model's window."
            case .engineUnavailable(let reason):
                return reason.userCopy
            case .generationFailed(let detail):
                return detail
            }
        }
        return error.localizedDescription
    }
}

#endif
