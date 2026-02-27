import Foundation
import Observation
import os

// MARK: - Notes Operation

/// Classifies each notes AI operation with a base complexity score.
/// Simple transforms (grammar, summarize) route to Apple Intelligence;
/// complex reasoning (analyze, learn) routes to the user's API provider.
nonisolated enum NotesOperation: Sendable {
    case grammarFix        // 0.15 — simple transform, ideal for on-device
    case summarize         // 0.20 — focused extraction
    case rewrite           // 0.25 — focused transformation
    case continueWriting   // 0.30 — needs tone matching
    case ask(query: String)// 0.35 — depends on query; uses QueryAnalyzer
    case outline           // 0.40 — structural analysis
    case expand            // 0.50 — needs creative depth
    case analyze           // 0.60 — deep reasoning
    case learn             // 0.70 — multi-step protocol, always API

    var baseComplexity: Double {
        switch self {
        case .grammarFix:      0.15
        case .summarize:       0.20
        case .rewrite:         0.25
        case .continueWriting: 0.30
        case .ask:             0.35
        case .outline:         0.40
        case .expand:          0.50
        case .analyze:         0.60
        case .learn:           0.70
        }
    }

    var displayName: String {
        switch self {
        case .grammarFix:      "Grammar Fix"
        case .summarize:       "Summarize"
        case .rewrite:         "Rewrite"
        case .continueWriting: "Continue Writing"
        case .ask:             "Ask"
        case .outline:         "Outline"
        case .expand:          "Expand"
        case .analyze:         "Analyze"
        case .learn:           "Learn"
        }
    }
}

// MARK: - General Operation

/// Classifies non-notes AI operations for triage routing.
nonisolated enum GeneralOperation: Sendable {
    case chatResponse(query: String)  // 0.35 — user-facing streaming answer
    case epistemicLens                    // 0.65 — multi-paragraph analytical prose
    case brainstorm                   // 0.25 — creative, short output
    case apiOnly                      // 1.00 — JSON-dependent stages

    var baseComplexity: Double {
        switch self {
        case .chatResponse: 0.35
        case .epistemicLens:    0.65
        case .brainstorm:   0.25
        case .apiOnly:      1.00
        }
    }

    var displayName: String {
        switch self {
        case .chatResponse: "Chat Response"
        case .epistemicLens:    "Epistemic Lens"
        case .brainstorm:   "Brainstorm"
        case .apiOnly:      "API Only"
        }
    }
}

// MARK: - Triage Decision

nonisolated enum TriageDecision: Sendable, Equatable {
    case appleIntelligence
    case apiProvider

    var isOnDevice: Bool { self == .appleIntelligence }

    var label: String {
        switch self {
        case .appleIntelligence: "On-device"
        case .apiProvider:       "Cloud"
        }
    }

    var icon: String {
        switch self {
        case .appleIntelligence: "cpu"
        case .apiProvider:       "cloud"
        }
    }
}

// MARK: - Triage Service

/// Routes AI operations between Apple Intelligence (on-device) and the user's
/// configured cloud API provider based on automatic complexity scoring.
///
/// Apple Intelligence is always-on when available — it silently handles simple
/// operations (grammar, summarize, short queries) on-device for free.
/// Complex operations route to whatever cloud API the user configured.
/// If Apple Intelligence refuses or fails, the cloud API is used as fallback.
@MainActor @Observable
final class TriageService {

    private let inference: InferenceState
    private let llmService: LLMService

    private let complexityThreshold: Double = 0.25
    private let maxAppleIntelligenceContentLength: Int = 6_000

    var lastDecision: TriageDecision?

    /// Returns true if the response looks like a polite refusal.
    /// Checks only the first 500 chars — long Apple refusals start with the refusal
    /// then pad with resources/disclaimers. Checking the opening is sufficient and fast.
    nonisolated static func isRefusalResponse(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true } // Empty = refusal

        // Check the opening of the response (refusals always lead with the refusal)
        let prefix = String(trimmed.prefix(500)).lowercased()

        let patterns = [
            // Generic AI refusals
            "i can't help", "i cannot help",
            "i'm not able to", "i am not able to",
            "i don't have the ability",
            "i'm unable to", "i am unable to",
            "as an ai",
            "i can't assist", "i cannot assist",
            "i'm sorry, but i can't", "i'm sorry, but i cannot",
            "beyond my capabilities", "outside my capabilities",
            "not something i can do",
            "i don't have enough context",
            "i can't provide", "i cannot provide",
            "could not help", "couldn't help",
            // Apple Intelligence specific
            "as a language model created by apple",
            "beyond my remit",
            "adhere to ethical guidelines",
            "i'm not able to assist",
            "i am not able to assist",
            "i'm sorry, but as a language model",
            "i am sorry, but as a language model",
            "ensure the safety and well-being",
            "is beyond my",
            "outside my remit",
            "not within my capabilities",
            "i'm designed to",
            "as an apple",
        ]
        return patterns.contains { prefix.contains($0) }
    }

    /// Returns true if the response appears truncated or too short to be useful.
    /// Catches: empty responses, mid-sentence cutoffs, suspiciously brief answers.
    nonisolated static func isTruncatedResponse(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Empty or near-empty
        if trimmed.count < 20 { return true }

        // Ends mid-sentence: no terminal punctuation and response is substantial
        if trimmed.count > 40 {
            let lastChar = trimmed.last ?? " "
            let terminalChars: Set<Character> = [".", "!", "?", ":", ")", "]", "\"", "'", "`", "-", "*"]
            if !terminalChars.contains(lastChar) {
                // Check it's not a list item or code block (which may end without punctuation)
                let lastLine = trimmed.components(separatedBy: "\n").last ?? ""
                let isListOrCode = lastLine.hasPrefix("-") || lastLine.hasPrefix("*") ||
                    lastLine.hasPrefix("```") || lastLine.hasPrefix("  ")
                if !isListOrCode { return true }
            }
        }

        return false
    }

    /// Combined check: is the response a failure that should trigger API fallback?
    nonisolated static func shouldFallbackToAPI(_ text: String) -> Bool {
        isRefusalResponse(text) || isTruncatedResponse(text)
    }

    init(inference: InferenceState, llmService: LLMService) {
        self.inference = inference
        self.llmService = llmService
    }

    // MARK: - Triage Logic

    /// Routes a notes operation to Apple Intelligence or the cloud API.
    /// Apple Intelligence is always-on: if available and the operation is simple enough,
    /// it runs on-device. The user's selected cloud provider handles everything else.
    func triage(operation: NotesOperation, contentLength: Int, query: String? = nil) -> TriageDecision {
        // Force on-device when cloud API has no key but Apple Intelligence is available.
        // This ensures notes operations always work even without cloud API setup.
        if inference.apiKey.isEmpty && inference.appleIntelligenceAvailable {
            return .appleIntelligence
        }

        // Apple Intelligence must be available on this Mac
        guard inference.appleIntelligenceAvailable else { return .apiProvider }

        // Content too long for on-device processing
        guard contentLength <= maxAppleIntelligenceContentLength else { return .apiProvider }

        var effectiveComplexity = operation.baseComplexity
        let lengthFactor = min(0.20, Double(contentLength) / 60_000)
        effectiveComplexity += lengthFactor

        if case .ask(let q) = operation, !q.isEmpty {
            let analysis = QueryAnalyzer.analyze(query: q)
            effectiveComplexity += analysis.complexity * 0.30
        }

        effectiveComplexity = min(1.0, effectiveComplexity)
        return effectiveComplexity <= complexityThreshold ? .appleIntelligence : .apiProvider
    }

    // MARK: - Stream with Triage

    func stream(
        prompt: String,
        systemPrompt: String? = nil,
        operation: NotesOperation,
        contentLength: Int,
        query: String? = nil
    ) -> AsyncThrowingStream<String, Error> {
        let decision = triage(operation: operation, contentLength: contentLength, query: query)
        lastDecision = decision
        Log.engine.info("Triage: \(operation.displayName) → \(decision.label) (content: \(contentLength) chars)")

        switch decision {
        case .appleIntelligence:
            return appleIntelligenceStreamWithFallback(prompt: prompt, systemPrompt: systemPrompt)
        case .apiProvider:
            return apiStreamWithAppleIntelligenceFallback(prompt: prompt, systemPrompt: systemPrompt)
        }
    }

    // MARK: - Generate with Triage

    func generate(
        prompt: String,
        systemPrompt: String? = nil,
        operation: NotesOperation,
        contentLength: Int,
        query: String? = nil
    ) async throws -> String {
        let decision = triage(operation: operation, contentLength: contentLength, query: query)
        lastDecision = decision
        Log.engine.info("Triage: \(operation.displayName) → \(decision.label) (content: \(contentLength) chars)")

        switch decision {
        case .appleIntelligence:
            do {
                let result = try await AppleIntelligenceService.shared.generate(prompt: prompt, systemPrompt: systemPrompt)
                if Self.shouldFallbackToAPI(result) {
                    Log.engine.info("Apple Intelligence response inadequate, falling back to API silently")
                    lastDecision = .apiProvider
                    return try await llmService.generate(prompt: prompt, systemPrompt: systemPrompt)
                }
                return result
            } catch {
                Log.engine.warning("Apple Intelligence failed, falling back to API silently: \(error.localizedDescription, privacy: .public)")
                lastDecision = .apiProvider
                return try await llmService.generate(prompt: prompt, systemPrompt: systemPrompt)
            }
        case .apiProvider:
            return try await llmService.generate(prompt: prompt, systemPrompt: systemPrompt)
        }
    }

    // MARK: - General Triage Logic

    /// Routes a general operation to Apple Intelligence or the cloud API.
    /// Same always-on logic as notes triage.
    ///
    /// **Fallback rule**: When the user's selected cloud provider has no API key
    /// but Apple Intelligence IS available, force-route to on-device regardless of
    /// complexity. This prevents 401 errors for users who haven't entered a key yet.
    func triageGeneral(operation: GeneralOperation, contentLength: Int) -> TriageDecision {
        // Force on-device when cloud API has no key but Apple Intelligence is available.
        // This ensures the user always gets a response even without cloud API setup.
        if inference.apiKey.isEmpty && inference.appleIntelligenceAvailable {
            return .appleIntelligence
        }

        guard operation.baseComplexity < 1.0 else { return .apiProvider }
        guard inference.appleIntelligenceAvailable else { return .apiProvider }
        guard contentLength <= maxAppleIntelligenceContentLength else { return .apiProvider }

        var effectiveComplexity = operation.baseComplexity
        let lengthFactor = min(0.20, Double(contentLength) / 60_000)
        effectiveComplexity += lengthFactor

        if case .chatResponse(let query) = operation, !query.isEmpty {
            let analysis = QueryAnalyzer.analyze(query: query)
            effectiveComplexity += analysis.complexity * 0.30
        }

        effectiveComplexity = min(1.0, effectiveComplexity)
        return effectiveComplexity <= complexityThreshold ? .appleIntelligence : .apiProvider
    }

    func streamGeneral(
        prompt: String,
        systemPrompt: String? = nil,
        operation: GeneralOperation,
        contentLength: Int
    ) -> AsyncThrowingStream<String, Error> {
        let decision = triageGeneral(operation: operation, contentLength: contentLength)
        lastDecision = decision
        Log.engine.info("Triage: \(operation.displayName) → \(decision.label) (content: \(contentLength) chars)")

        switch decision {
        case .appleIntelligence:
            return appleIntelligenceStreamWithFallback(prompt: prompt, systemPrompt: systemPrompt)
        case .apiProvider:
            return apiStreamWithAppleIntelligenceFallback(prompt: prompt, systemPrompt: systemPrompt)
        }
    }

    func generateGeneral(
        prompt: String,
        systemPrompt: String? = nil,
        operation: GeneralOperation,
        contentLength: Int
    ) async throws -> String {
        let decision = triageGeneral(operation: operation, contentLength: contentLength)
        lastDecision = decision
        Log.engine.info("Triage: \(operation.displayName) → \(decision.label) (content: \(contentLength) chars)")

        switch decision {
        case .appleIntelligence:
            do {
                let result = try await AppleIntelligenceService.shared.generate(prompt: prompt, systemPrompt: systemPrompt)
                if Self.shouldFallbackToAPI(result) {
                    Log.engine.info("Apple Intelligence response inadequate (general), falling back to API silently")
                    lastDecision = .apiProvider
                    return try await llmService.generate(prompt: prompt, systemPrompt: systemPrompt)
                }
                return result
            } catch {
                Log.engine.warning("Apple Intelligence failed (general), falling back to API silently: \(error.localizedDescription, privacy: .public)")
                lastDecision = .apiProvider
                return try await llmService.generate(prompt: prompt, systemPrompt: systemPrompt)
            }
        case .apiProvider:
            do {
                return try await llmService.generate(prompt: prompt, systemPrompt: systemPrompt)
            } catch let error as LLMError where error.isAuthError {
                // Check Apple Intelligence availability FRESH — cached flag may be stale
                let aiFresh = AppleIntelligenceService.shared.checkAvailability()
                guard aiFresh.available else {
                    Log.engine.warning("Cloud API auth error (generate) but Apple Intelligence unavailable (\(aiFresh.reason ?? "unknown", privacy: .public))")
                    throw error
                }
                Log.engine.warning("Cloud API auth error (generate), falling back to Apple Intelligence")
                lastDecision = .appleIntelligence
                inference.appleIntelligenceAvailable = aiFresh.available
                let result = try await AppleIntelligenceService.shared.generate(prompt: prompt, systemPrompt: systemPrompt)
                if Self.shouldFallbackToAPI(result) {
                    throw error // Both failed — propagate the original error
                }
                return result
            }
        }
    }

    // MARK: - Cloud API Stream with Apple Intelligence Fallback

    /// Streams from the cloud API, falling back to Apple Intelligence if:
    /// - The API returns an auth/validation error (400, 401, 403)
    /// - Apple Intelligence is available on this Mac
    /// This covers the case where a user has an invalid API key but Apple Intelligence works.
    private func apiStreamWithAppleIntelligenceFallback(
        prompt: String,
        systemPrompt: String?
    ) -> AsyncThrowingStream<String, Error> {
        let llm = self.llmService

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let cloudStream = llm.stream(prompt: prompt, systemPrompt: systemPrompt)
                    for try await chunk in cloudStream {
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch let error as LLMError where error.isAuthError {
                    // Check Apple Intelligence availability FRESH — the cached flag in
                    // InferenceState may be stale (set once at app launch).
                    let aiFresh = AppleIntelligenceService.shared.checkAvailability()
                    guard aiFresh.available else {
                        Log.engine.warning("Cloud API auth error but Apple Intelligence unavailable (\(aiFresh.reason ?? "unknown", privacy: .public))")
                        continuation.finish(throwing: error)
                        return
                    }
                    Log.engine.warning("Cloud API auth error, falling back to Apple Intelligence: \(error.localizedDescription, privacy: .public)")
                    await MainActor.run {
                        self.lastDecision = .appleIntelligence
                        self.inference.appleIntelligenceAvailable = aiFresh.available
                    }
                    // Seamless fallback — user sees Apple Intelligence response instead of error
                    do {
                        let result = try await AppleIntelligenceService.shared.generate(
                            prompt: prompt,
                            systemPrompt: systemPrompt
                        )
                        if !Self.isRefusalResponse(result) {
                            continuation.yield(result)
                            continuation.finish()
                        } else {
                            // Apple Intelligence also refused — propagate original error
                            continuation.finish(throwing: error)
                        }
                    } catch {
                        // Apple Intelligence also failed — propagate original cloud error
                        continuation.finish(throwing: error)
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Apple Intelligence Stream with Fallback

    /// Streams from Apple Intelligence, falling back to the cloud API seamlessly if:
    /// - Apple Intelligence throws an error (timeout, unavailable)
    /// - The response is a polite refusal ("I can't help with that")
    /// - The response appears truncated (stops mid-sentence)
    /// The user never sees the failed response — fallback replaces it entirely.
    private func appleIntelligenceStreamWithFallback(
        prompt: String,
        systemPrompt: String?
    ) -> AsyncThrowingStream<String, Error> {
        let llm = self.llmService

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let result = try await AppleIntelligenceService.shared.generate(
                        prompt: prompt,
                        systemPrompt: systemPrompt
                    )

                    // Check for refusal, truncation, or suspiciously short response
                    if Self.shouldFallbackToAPI(result) {
                        Log.engine.info("Apple Intelligence response inadequate (stream), falling back to API silently")
                        await MainActor.run { self.lastDecision = .apiProvider }
                        // Don't yield the bad response — go straight to API
                        let fallbackStream = llm.stream(prompt: prompt, systemPrompt: systemPrompt)
                        for try await chunk in fallbackStream {
                            continuation.yield(chunk)
                        }
                        continuation.finish()
                        return
                    }

                    continuation.yield(result)
                    continuation.finish()
                } catch {
                    Log.engine.warning("Apple Intelligence failed (stream), falling back to API silently: \(error.localizedDescription, privacy: .public)")
                    await MainActor.run { self.lastDecision = .apiProvider }
                    // Seamless fallback — user sees nothing from the failed attempt
                    let fallbackStream = llm.stream(prompt: prompt, systemPrompt: systemPrompt)
                    do {
                        for try await chunk in fallbackStream {
                            continuation.yield(chunk)
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
