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
    private var _sessionCreatedAt: Date = .distantPast

    private init() {}

    func generate(prompt: String, systemPrompt: String? = nil) async throws -> String {
        // Check circuit breaker before attempting inference
        if let supervisor = AppBootstrap.shared?.supervisor,
           await supervisor.inferenceCircuitBreaker.isOpen {
            throw AppleIntelligenceError.unavailable("Inference circuit breaker is open — too many recent failures. Will auto-reset.")
        }

        // Thermal clearance: park if thermal pressure is high, cancel if critical.
        // ThermalError is distinct from inference failure — don't trip the breaker.
        do {
            try await ThermalGuard.shared.acquireClearance()
        } catch is ThermalError {
            // Record thermal pause (NOT a failure) so the breaker stays closed
            if let supervisor = AppBootstrap.shared?.supervisor {
                await supervisor.inferenceCircuitBreaker.recordThermalPause()
            }
            throw AppleIntelligenceError.unavailable("Inference blocked by thermal pressure.")
        }

        do {
            let result: String
            if #available(macOS 26.0, *) {
                result = try await generateWithFoundationModels(prompt: prompt, systemPrompt: systemPrompt)
            } else {
                throw AppleIntelligenceError.unavailable("Apple Intelligence requires macOS 26 or later.")
            }
            // Record success to close circuit breaker
            if let supervisor = AppBootstrap.shared?.supervisor {
                await supervisor.inferenceCircuitBreaker.recordSuccess()
            }
            return result
        } catch is ThermalError {
            // Thermal errors during inference are not the API's fault
            if let supervisor = AppBootstrap.shared?.supervisor {
                await supervisor.inferenceCircuitBreaker.recordThermalPause()
            }
            throw AppleIntelligenceError.unavailable("Inference interrupted by thermal pressure.")
        } catch {
            // Real inference failure — record against circuit breaker
            if let supervisor = AppBootstrap.shared?.supervisor {
                await supervisor.inferenceCircuitBreaker.recordFailure()
            }
            throw error
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
        if let cached = _cachedSession, !needsRecycle, systemPrompt == nil {
            session = cached
        } else {
            if let systemPrompt, !systemPrompt.isEmpty {
                session = LanguageModelSession(instructions: systemPrompt)
            } else {
                session = LanguageModelSession()
            }
            _cachedSession = session
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
                let freshSession = LanguageModelSession()
                _cachedSession = freshSession
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

enum AppleIntelligenceError: LocalizedError {
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let reason): "Apple Intelligence unavailable: \(reason)"
        }
    }
}


