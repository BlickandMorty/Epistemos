import Foundation
import os
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Apple Intelligence Service
// Uses FoundationModels framework (macOS 26+) for on-device LLM tasks.
// Falls back to a clear error on older OS versions so the caller can handle gracefully.

@MainActor
final class AppleIntelligenceService {
    private static let log = Logger(subsystem: "com.epistemos.ai", category: "AppleIntelligenceService")

    static let shared = AppleIntelligenceService()

    /// Session recycle interval — Foundation Models sessions accumulate context;
    /// recycling every 10 minutes prevents memory bloat and stale KV caches.
    private let sessionRecycleInterval: TimeInterval = 600 // 10 minutes
    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private var _cachedSession: LanguageModelSession? {
        get { _cachedSessionStorage as? LanguageModelSession }
        set { _cachedSessionStorage = newValue }
    }
    #endif
    private var _cachedSessionStorage: AnyObject?
    private var _cachedSessionSystemPrompt: String?
    private var _sessionCreatedAt: Date = .distantPast
    private let knowledgeProfileStore = KnowledgeProfileStore()

    private init() {}

    func generate(prompt: String, systemPrompt: String? = nil) async throws -> String {
        let breaker = BreakerRegistry.shared.foundationModels
        let resolvedSystemPrompt = await knowledgeAwareSystemPrompt(from: systemPrompt)

        // Thermal clearance: park if thermal pressure is high, cancel if critical.
        // ThermalError is distinct from inference failure — the breaker's
        // isNeutral() classification handles this automatically.
        do {
            try await ThermalGuard.shared.acquireClearance()
        } catch let error as ThermalError {
            await breaker.recordThermalPause()
            throw error
        }

        // Route through the FoundationModels circuit breaker.
        // execute<T>() handles: open rejection, success/failure recording,
        // neutral error classification (thermal, cancellation, context exhaustion).
        return try await breaker.execute {
            if #available(macOS 26.0, *) {
                return try await self.generateWithFoundationModels(prompt: prompt, systemPrompt: resolvedSystemPrompt)
            } else {
                throw AppleIntelligenceError.unavailable("Apple Intelligence requires macOS 26 or later.")
            }
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

        // Recycle session every 10 minutes to prevent memory bloat / stale KV cache.
        // System prompt changes also force a new session.
        let session: LanguageModelSession
        let now = Date()
        let needsRecycle = now.timeIntervalSince(_sessionCreatedAt) > sessionRecycleInterval
        let normalizedSystemPrompt = Self.normalizedSystemPrompt(systemPrompt)
        let needsPromptRefresh = normalizedSystemPrompt != _cachedSessionSystemPrompt
        if let cached = _cachedSession, !needsRecycle, !needsPromptRefresh {
            session = cached
        } else {
            if let normalizedSystemPrompt {
                session = LanguageModelSession(instructions: normalizedSystemPrompt)
            } else {
                session = LanguageModelSession()
            }
            _cachedSession = session
            _cachedSessionSystemPrompt = normalizedSystemPrompt
            _sessionCreatedAt = now
        }

        // Token budget guard: proactively recycle when approaching context limit.
        // contextSize is on SystemLanguageModel; tokenCount requires macOS 26.4.
        if #available(macOS 26.4, *) {
            let slm = SystemLanguageModel.default
            let contextLimit = slm.contextSize
            if contextLimit > 0 {
                let transcriptEntries = Array(session.transcript)
                let currentUsage = try await slm.tokenCount(for: transcriptEntries)
                let budgetThreshold = Int(Double(contextLimit) * 0.78)
                if currentUsage >= budgetThreshold {
                    // Recycle: create fresh session, inject summary of prior context
                    let summary = try await summarizeTranscript(session: session)
                    let freshSession: LanguageModelSession
                    if let systemPrompt, !systemPrompt.isEmpty {
                        freshSession = LanguageModelSession(instructions: systemPrompt + "\n\nPrevious context: " + summary)
                    } else {
                        freshSession = LanguageModelSession(instructions: "Previous context: " + summary)
                    }
                    _cachedSession = freshSession
                    _cachedSessionSystemPrompt = normalizedSystemPrompt
                    _sessionCreatedAt = Date()
                    let content: String = try await withTimeout(seconds: 30.0) {
                        let response = try await freshSession.respond(to: prompt)
                        return response.content
                    }
                    return content
                }
            }
        }

        // Normal path with exceededContextWindowSize catch-and-retry
        do {
            let content: String = try await withTimeout(seconds: 30.0) {
                let response = try await session.respond(to: prompt)
                return response.content
            }
            return content
        } catch let error as LanguageModelSession.GenerationError {
            if case .exceededContextWindowSize = error {
                // Context window blown — force recycle and retry once
                let freshSession: LanguageModelSession
                if let normalizedSystemPrompt {
                    freshSession = LanguageModelSession(instructions: normalizedSystemPrompt)
                } else {
                    freshSession = LanguageModelSession()
                }
                _cachedSession = freshSession
                _cachedSessionSystemPrompt = normalizedSystemPrompt
                _sessionCreatedAt = Date()
                let content: String = try await withTimeout(seconds: 30.0) {
                    let response = try await freshSession.respond(to: prompt)
                    return response.content
                }
                return content
            }
            throw error
        }
        #else
        throw AppleIntelligenceError.unavailable("FoundationModels framework not available on this build machine.")
        #endif
    }

    private func knowledgeAwareSystemPrompt(from systemPrompt: String?) async -> String? {
        do {
            return try await knowledgeProfileStore.augmentedSystemPrompt(
                existingPrompt: systemPrompt,
                modelID: "apple-intelligence",
                budget: .compact
            )
        } catch {
            Self.log.error(
                "Failed to load Apple Intelligence model vault prompt context: \(error.localizedDescription, privacy: .public)"
            )
            return systemPrompt
        }
    }

    private nonisolated static func normalizedSystemPrompt(_ systemPrompt: String?) -> String? {
        guard let systemPrompt else { return nil }
        let trimmed = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Summarize transcript using a separate session to preserve context continuity.
    @available(macOS 26.0, *)
    private func summarizeTranscript(session: LanguageModelSession) async throws -> String {
        #if canImport(FoundationModels)
        let summarizerSession = LanguageModelSession(
            instructions: "You are a concise summarizer. Condense the conversation into key facts and context, no more than 500 tokens."
        )
        // Build a text representation — Transcript.Entry segments hold the content
        var parts: [String] = []
        for entry in session.transcript {
            switch entry {
            case .prompt(let p):
                let text = p.segments.compactMap { segment -> String? in
                    if case .text(let t) = segment { return t.content }
                    return nil
                }.joined()
                if !text.isEmpty { parts.append("User: \(text)") }
            case .response(let r):
                let text = r.segments.compactMap { segment -> String? in
                    if case .text(let t) = segment { return t.content }
                    return nil
                }.joined()
                if !text.isEmpty { parts.append("Assistant: \(text)") }
            default:
                break
            }
        }
        let transcriptText = parts.joined(separator: "\n")
        guard !transcriptText.isEmpty else { return "" }
        let response = try await summarizerSession.respond(to: transcriptText)
        return response.content
        #else
        return ""
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

enum AppleIntelligenceError: LocalizedError, CircuitBreakerIgnorable, Sendable {
    case unavailable(String)

    nonisolated var errorDescription: String? {
        switch self {
        case .unavailable(let reason): "Apple Intelligence unavailable: \(reason)"
        }
    }

    /// Unavailability is a precondition check, not a provider failure.
    nonisolated var isCircuitBreakerNeutral: Bool { true }
}
