import Foundation
import OSLog

#if canImport(FoundationModels)
import FoundationModels
#endif

// Surface A engine 1 (Plan 1-MAS §2.1): Apple Foundation Models — the
// zero-download, instant-open default when available. Availability-gated;
// guardrailViolation maps to QuickChatError.guardrailBlocked so the router
// can fall back to the GGUF lane with honest copy.
//
// Reuses the app's FM discipline: EVERY generation goes through
// AFMSerialGate.shared (concurrent FM respond/stream calls trap inside the
// framework — verified in-repo 2026-06-09/11), and sessions recycle on a
// 10-minute cadence to bound KV growth (AFMSessionPool pattern).
nonisolated final class AppleFMQuickChatBackend: @unchecked Sendable {
    private static let log = Logger(subsystem: "com.epistemos", category: "QuickChatFM")
    private static let sessionLifetime: TimeInterval = 600

    private let stateLock = NSLock()
    #if canImport(FoundationModels)
    private var cachedSession: LanguageModelSession?
    private var cachedInstructions: String?
    private var sessionCreatedAt = Date.distantPast
    #endif

    init() {}

    /// nil when FM can answer right now; otherwise the honest reason.
    static func unavailability() -> QuickChatEngineUnavailable? {
        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(.deviceNotEligible):
            return .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled):
            return .appleIntelligenceNotEnabled
        case .unavailable(.modelNotReady):
            return .modelNotReady
        case .unavailable(_):
            return .modelNotReady
        @unknown default:
            return .modelNotReady
        }
        #else
        return .deviceNotEligible
        #endif
    }

    /// Streams TEXT DELTAS (FM yields cumulative snapshots; this converts to
    /// deltas via prefix diff). Throws QuickChatError.guardrailBlocked when
    /// the FM guardrails refuse — the router's fallback trigger.
    func stream(prompt: String, instructions: String?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream(bufferingPolicy: .bufferingNewest(256)) { continuation in
            #if canImport(FoundationModels)
            let session = self.session(instructions: instructions)
            let task = Task.detached(priority: .userInitiated) {
                do {
                    try await AFMSerialGate.shared.run {
                        let responseStream = session.streamResponse(to: prompt)
                        var previous = ""
                        for try await snapshot in responseStream {
                            let full = snapshot.content
                            if full.count > previous.count, full.hasPrefix(previous) {
                                continuation.yield(String(full.dropFirst(previous.count)))
                            } else if full != previous {
                                // Snapshot rewrote earlier text (rare) — emit whole.
                                continuation.yield(full)
                            }
                            previous = full
                        }
                    }
                    continuation.finish()
                } catch let error as LanguageModelSession.GenerationError {
                    self.discardSession()
                    switch error {
                    case .guardrailViolation:
                        continuation.finish(throwing: QuickChatError.guardrailBlocked)
                    case .exceededContextWindowSize:
                        continuation.finish(throwing: QuickChatError.exceededContextWindow)
                    default:
                        continuation.finish(throwing: QuickChatError.generationFailed(
                            String(describing: error)
                        ))
                    }
                } catch {
                    self.discardSession()
                    continuation.finish(throwing: QuickChatError.generationFailed(
                        error.localizedDescription
                    ))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
            #else
            continuation.finish(throwing: QuickChatError.engineUnavailable(.deviceNotEligible))
            #endif
        }
    }

    func reset() {
        discardSession()
    }

    #if canImport(FoundationModels)
    private func session(instructions: String?) -> LanguageModelSession {
        stateLock.lock()
        defer { stateLock.unlock() }
        let now = Date()
        let normalized = instructions?.trimmingCharacters(in: .whitespacesAndNewlines)
        let usable = (normalized?.isEmpty ?? true) ? nil : normalized
        if let cached = cachedSession,
           cachedInstructions == usable,
           now.timeIntervalSince(sessionCreatedAt) < Self.sessionLifetime {
            return cached
        }
        let fresh: LanguageModelSession
        if let usable {
            fresh = LanguageModelSession(instructions: usable)
        } else {
            fresh = LanguageModelSession()
        }
        cachedSession = fresh
        cachedInstructions = usable
        sessionCreatedAt = now
        return fresh
    }

    private func discardSession() {
        stateLock.lock()
        defer { stateLock.unlock() }
        cachedSession = nil
        cachedInstructions = nil
        sessionCreatedAt = .distantPast
    }
    #else
    private func discardSession() {}
    #endif
}
