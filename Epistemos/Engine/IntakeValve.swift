import Foundation
import OSLog

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - IntakeValve (Phase 14 / W10.14)
//
// Master plan Phase 14 / Wave 13 §"Phase 14": synchronous AFM
// intercept that classifies inbound user content (paste, dictation,
// brain dump) BEFORE it lands in the curated graph. The classifier
// emits an `IntakeRoute` decision; the caller routes accordingly:
//
//   .matchExisting  → merge into the existing structured note/graph
//                     node identified by `existingEntityId`
//   .newConcept     → mint a fresh note + sidecar; AFM enriches
//                     parentDomain + childConcept inline
//   .ambient        → push into QuarantineArchive (Phase 15) for
//                     later ambient-retrieval-only access
//   .noise          → discard quietly (boilerplate, repeated paste,
//                     clipboard cruft)
//
// Compass latency budget (Wave 13 §"Phase 14"):
//   Pasteboard poll detect       ≤ 50 ms
//   Read pasteboard string       <  5 ms
//   Pre-filter (length / URL)    <  2 ms
//   Tier A: deterministic match  < 10 ms (FTS5 + Levenshtein)
//   Tier B: NLEmbedding cosine   < 30 ms
//   Tier C: AFM classification   ~ 300-400 ms (warm cached prefix)
//   Route + UI flash             < 15 ms
//   TOTAL                        ~ 410 ms (within <500 ms budget)
//
// This module ships the Tier C AFM-classification path; Tier A/B
// pre-filters wire in alongside the pasteboard-watcher view.

// MARK: - IntakeRoute decision

#if canImport(FoundationModels)

@available(macOS 26.0, *)
@Generable
public enum IntakeRoute: Sendable, Equatable, Codable {
    case matchExisting
    case newConcept
    case ambient
    case noise
}

@available(macOS 26.0, *)
@Generable
public struct IntakeDecision: Sendable, Equatable, Codable {

    @Guide(description: "Where to route this content")
    public var route: IntakeRoute

    @Guide(description: "Confidence in the routing 0.0-1.0")
    public var confidence: Double

    @Guide(description: "When route=matchExisting, the entity_id of the existing note to merge into; nil otherwise")
    public var existingEntityId: String?

    @Guide(description: "When route=newConcept, the proposed parent domain (lowercase kebab-case)")
    public var proposedParentDomain: String?

    @Guide(description: "When route=newConcept, the proposed child concept (lowercase kebab-case)")
    public var proposedChildConcept: String?

    @Guide(description: "One-sentence rationale for the route decision (used by W11.4 Manual mode 'Why?' surface)")
    public var rationale: String
}

#else

public enum IntakeRoute: String, Sendable, Equatable, Codable {
    case matchExisting, newConcept, ambient, noise
}

public struct IntakeDecision: Sendable, Equatable, Codable {
    public var route: IntakeRoute
    public var confidence: Double
    public var existingEntityId: String?
    public var proposedParentDomain: String?
    public var proposedChildConcept: String?
    public var rationale: String
}

#endif

// MARK: - IntakeValve service

@MainActor
public final class IntakeValve {

    public static let shared = IntakeValve()

    private static let log = Logger(
        subsystem: "com.epistemos",
        category: "IntakeValve"
    )

    public enum IntakeError: Error {
        case notAvailable(SessionTelemetryClassifier.Readiness)
        case modelRefused(String)
        case decodeFailed(String)
    }

    /// Below this character count we don't even bother classifying
    /// — it's almost certainly noise (clipboard cruft, accidental
    /// paste, IDE breadcrumbs).
    public static let minLengthForClassification: Int = 12

    /// Above this character count we chunk-and-defer to
    /// SessionTelemetryClassifier-style map-reduce per Wave 13
    /// §"Map-reduce chunking" rather than try to classify in one
    /// AFM round-trip.
    public static let chunkAtCharCount: Int = 8_000

    /// Cached session — same 10-min lifetime as the other AFM-backed
    /// classifiers so the daemon shares warm weights.
    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private var session: LanguageModelSession? {
        get { _sessionStorage as? LanguageModelSession }
        set { _sessionStorage = newValue }
    }
    #endif
    private var _sessionStorage: AnyObject?
    private var sessionCreatedAt: Date = .distantPast
    private let sessionLifetime: TimeInterval = 600

    private init() {}

    public func readiness() -> SessionTelemetryClassifier.Readiness {
        SessionTelemetryClassifier.shared.readiness()
    }

    // MARK: - Pre-filter (Tier A/B before the AFM round-trip)

    /// Quick deterministic pre-filter that rules out obvious noise
    /// without an AFM round-trip. Returns `nil` when the content
    /// passes the pre-filter and should go to AFM; returns a
    /// pre-decided `IntakeDecision` when the answer is obvious.
    public func preFilter(_ text: String) -> IntakeDecision? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count < Self.minLengthForClassification {
            return IntakeDecision(
                route: .noise,
                confidence: 0.95,
                existingEntityId: nil,
                proposedParentDomain: nil,
                proposedChildConcept: nil,
                rationale: "below \(Self.minLengthForClassification)-char threshold; almost certainly clipboard cruft"
            )
        }
        // Pure URL → ambient (the user is bookmarking, not authoring)
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://"),
           !trimmed.contains(" "),
           !trimmed.contains("\n") {
            return IntakeDecision(
                route: .ambient,
                confidence: 0.85,
                existingEntityId: nil,
                proposedParentDomain: nil,
                proposedChildConcept: nil,
                rationale: "single bare URL; route to ambient archive for later retrieval"
            )
        }
        return nil
    }

    // MARK: - Classify

    /// Classify inbound text into an IntakeRoute. Combines the
    /// deterministic pre-filter with the AFM round-trip; the
    /// pre-filter is always cheap so we run it first.
    public func classify(_ text: String) async throws -> IntakeDecision {
        if let cheap = preFilter(text) {
            return cheap
        }
        let r = readiness()
        guard r == .available else { throw IntakeError.notAvailable(r) }

        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            return try await runAFM(text)
        }
        #endif
        throw IntakeError.notAvailable(.sdkUnavailable)
    }

    // MARK: - Convenience routing

    /// Classify-and-route in one call. Side-effects per IntakeRoute:
    ///   .ambient → push to QuarantineArchive with kind=.ambientPaste
    ///   .noise   → no-op (returns the decision; caller can log)
    ///   .newConcept / .matchExisting → caller is responsible for
    ///     downstream routing (mint sidecar, merge into existing,
    ///     etc.) — IntakeValve doesn't know about those surfaces.
    @discardableResult
    public func classifyAndRoute(
        _ text: String,
        anchor: QuarantineAnchor? = nil
    ) async throws -> IntakeDecision {
        let decision = try await classify(text)
        if decision.route == .ambient {
            QuarantineArchive.shared.capture(
                body: text,
                kind: .ambientPaste,
                anchor: anchor
            )
        }
        Self.log.info(
            "intake routed=\(String(describing: decision.route), privacy: .public) confidence=\(decision.confidence, privacy: .public) chars=\(text.count, privacy: .public)"
        )
        return decision
    }

    // MARK: - AFM dispatch

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private func ensureSession() async -> LanguageModelSession {
        // AP6 — shared AFM session pool across all classifiers.
        await AFMSessionPool.shared.session(
            useCase: .contentTagging,
            instructions: Self.systemPrompt,
            useCaseLabel: "IntakeValve"
        )
    }

    @available(macOS 26.0, *)
    private func runAFM(_ text: String) async throws -> IntakeDecision {
        let s = await ensureSession()
        let prompt = """
        Classify this incoming user text into one IntakeRoute. Return
        an IntakeDecision with the route, your confidence, and a
        one-sentence rationale.

        Text:
        \(text)
        """
        do {
            let response = try await s.respond(
                to: prompt,
                generating: IntakeDecision.self
            )
            return response.content
        } catch let error as LanguageModelSession.GenerationError {
            throw IntakeError.modelRefused(String(describing: error))
        } catch {
            throw IntakeError.decodeFailed(error.localizedDescription)
        }
    }
    #endif

    private static let systemPrompt = """
    You are an intake valve. The user just typed, dictated, or pasted
    content into Epistemos. Classify into one IntakeRoute:

      matchExisting — content semantically duplicates or extends an
        existing note in the user's vault. (Caller will look up the
        candidate; you propose the route.)
      newConcept — content is a new, structured idea worth its own
        note. Propose lowercase-kebab-case parent_domain +
        child_concept.
      ambient — content is messy, raw, or unstructured (a brain
        dump, a quote with no analysis, a URL with no commentary).
        Route to the quarantine for later ambient retrieval; do
        NOT pollute the structured graph.
      noise — boilerplate, clipboard cruft, IDE breadcrumbs,
        accidental paste. Discard.

    Confidence is your honest 0-1 estimate. Rationale is one sentence
    the user will see in the W11.4 Manual-mode "Why?" surface.
    """
}
