import Foundation
import OSLog

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - SessionTelemetry
//
// Phase 9 of the master plan / Wave 13 §"Phase 9": replaces the
// existing naive text-summarizer with an AFM `@Generable`-bounded
// schema so the agent's session distillation is structurally
// machine-readable instead of free-form prose.
//
// Wave 13 schema mirrors the master plan Phase 9 spec line-for-line:
//   - sessionStart / sessionEnd ISO-8601 strings
//   - decisionsMade  ([Decision] capped at 8)
//   - unresolvedFriction ([FrictionPoint] capped at 10)
//   - activeThemes ([String] 1-12)
//   - emotionalTrajectory ([EmotionalBeat] 3-7)
//   - headline (≤160 chars summary)
//   - confidence (0-100 integer)
//
// Doc 2 amendment: this is the *structured* output that obsoletes
// "linear chat log → ad-hoc summary string" in the existing
// `compaction.rs`. The full transcript stays on disk; this struct is
// a *projection* the cloud agent receives in place of the raw
// transcript on continuation turns (~95% token reduction per
// compass).
//
// Property declaration order is significant for `@Generable` —
// scalar fields first, arrays last (the classifier fills sequentially
// per the macOS 26.0-26.2 schema-stability bug).

#if canImport(FoundationModels)

@available(macOS 26.0, *)
@Generable
public struct SessionTelemetry: Sendable, Equatable, Codable {

    @Guide(description: "ISO-8601 UTC start of the session")
    public var sessionStart: String

    @Guide(description: "ISO-8601 UTC end of the session")
    public var sessionEnd: String

    @Guide(description: "≤160-char one-line summary of the session")
    public var headline: String

    @Guide(description: "Confidence in this distillation, 0-100 integer")
    public var confidence: Int

    @Guide(.count(0...8))
    public var decisionsMade: [SessionDecision]

    @Guide(.count(0...10))
    public var unresolvedFriction: [SessionFrictionPoint]

    @Guide(.count(1...12))
    public var activeThemes: [String]

    @Guide(.count(3...7))
    public var emotionalTrajectory: [SessionEmotionalBeat]
}

@available(macOS 26.0, *)
@Generable
public struct SessionDecision: Sendable, Equatable, Codable {
    @Guide(description: "The decision in one sentence")
    public var statement: String

    @Guide(description: "Optional prior decision this supersedes")
    public var supersedes: String?

    @Guide(.anyOf(["hard", "soft", "exploratory"]))
    public var commitmentLevel: String
}

@available(macOS 26.0, *)
@Generable
public struct SessionFrictionPoint: Sendable, Equatable, Codable {
    @Guide(description: "Topic where friction occurred")
    public var topic: String

    @Guide(description: "One-line reason for the friction")
    public var reason: String

    @Guide(.anyOf(["needs_data", "values_conflict", "energy_depletion", "external_blocker"]))
    public var category: String
}

@available(macOS 26.0, *)
@Generable
public struct SessionEmotionalBeat: Sendable, Equatable, Codable {
    @Guide(description: "Position in the session as a 0.0-1.0 fraction (0=start, 1=end)")
    public var position: Double

    @Guide(.anyOf(["clarity", "frustration", "curiosity", "resignation", "excitement", "doubt", "resolve"]))
    public var valenceLabel: String

    @Guide(description: "What triggered this emotional beat")
    public var trigger: String
}

#else

// Stub for macOS 14/15 SDK builds. Field names + types match the
// canonical schema so the persistence layer can decode old artifacts
// even when the AFM-backed classifier isn't compilable.

public struct SessionTelemetry: Sendable, Equatable, Codable {
    public var sessionStart: String
    public var sessionEnd: String
    public var headline: String
    public var confidence: Int
    public var decisionsMade: [SessionDecision]
    public var unresolvedFriction: [SessionFrictionPoint]
    public var activeThemes: [String]
    public var emotionalTrajectory: [SessionEmotionalBeat]
}
public struct SessionDecision: Sendable, Equatable, Codable {
    public var statement: String
    public var supersedes: String?
    public var commitmentLevel: String
}
public struct SessionFrictionPoint: Sendable, Equatable, Codable {
    public var topic: String
    public var reason: String
    public var category: String
}
public struct SessionEmotionalBeat: Sendable, Equatable, Codable {
    public var position: Double
    public var valenceLabel: String
    public var trigger: String
}

#endif

// MARK: - SessionTelemetryClassifier service

/// AFM-backed session-distillation classifier. Drops in alongside
/// the existing free-form text summarizer; new call sites use this
/// for structured output, legacy call sites stay on the prose path
/// until they migrate.
@MainActor
public final class SessionTelemetryClassifier {

    public static let shared = SessionTelemetryClassifier()

    private static let log = Logger(
        subsystem: "com.epistemos",
        category: "SessionTelemetryClassifier"
    )

    public enum Readiness: Sendable, Equatable {
        case available
        case deviceNotEligible
        case intelligenceDisabled
        case modelLoading
        case sdkUnavailable
    }

    public enum DistillError: Error {
        case notAvailable(Readiness)
        case transcriptTooLarge(tokensRequired: Int)
        case modelRefused(String)
        case decodeFailed(String)
    }

    /// Cached session — recycle on the same 10-minute interval as
    /// `OntologyClassifier` so the AFM daemon doesn't hold stale KV
    /// caches.
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

    public func readiness() -> Readiness {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available: return .available
            case .unavailable(let reason):
                switch reason {
                case .deviceNotEligible: return .deviceNotEligible
                case .appleIntelligenceNotEnabled: return .intelligenceDisabled
                case .modelNotReady: return .modelLoading
                @unknown default: return .modelLoading
                }
            @unknown default: return .modelLoading
            }
        } else {
            return .sdkUnavailable
        }
        #else
        return .sdkUnavailable
        #endif
    }

    /// Distill a session transcript into the structured telemetry
    /// schema. Caller is responsible for chunking transcripts that
    /// exceed the 4,096-token AFM ceiling (Wave 13 §"Map-reduce
    /// chunking" pattern).
    public func distill(
        transcript: String,
        sessionStart: Date,
        sessionEnd: Date
    ) async throws -> SessionTelemetry {
        let r = readiness()
        guard r == .available else { throw DistillError.notAvailable(r) }

        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            return try await runAFM(
                transcript: transcript,
                sessionStart: sessionStart,
                sessionEnd: sessionEnd
            )
        }
        #endif
        throw DistillError.notAvailable(.sdkUnavailable)
    }

    // MARK: - AFM dispatch

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private func ensureSession() -> LanguageModelSession {
        let now = Date()
        if let existing = session,
           now.timeIntervalSince(sessionCreatedAt) < sessionLifetime {
            return existing
        }
        // `.contentTagging` use-case is the smaller, friendlier model
        // (verified against FoundationModels.swiftinterface line 524-526
        // + 582). Same model the OntologyClassifier uses so the AFM
        // daemon shares warm weights across both call sites.
        let model = SystemLanguageModel(useCase: .contentTagging)
        let s = LanguageModelSession(
            model: model,
            instructions: Self.systemPrompt
        )
        session = s
        sessionCreatedAt = now
        return s
    }

    @available(macOS 26.0, *)
    private func runAFM(
        transcript: String,
        sessionStart: Date,
        sessionEnd: Date
    ) async throws -> SessionTelemetry {
        let s = ensureSession()
        let iso = ISO8601DateFormatter()
        let prompt = """
        Distill this session into the SessionTelemetry schema described
        in your instructions. Anchor sessionStart=\(iso.string(from: sessionStart))
        and sessionEnd=\(iso.string(from: sessionEnd)).

        Transcript:
        \(transcript)
        """
        do {
            let response = try await s.respond(
                to: prompt,
                generating: SessionTelemetry.self
            )
            return response.content
        } catch let error as LanguageModelSession.GenerationError {
            if case .exceededContextWindowSize = error {
                // Caller should chunk + reduce per Wave 13 §"Map-
                // reduce chunking" pattern. Surface a hint with the
                // approximate token-budget breakdown.
                throw DistillError.transcriptTooLarge(tokensRequired: -1)
            }
            throw DistillError.modelRefused(String(describing: error))
        } catch {
            throw DistillError.decodeFailed(error.localizedDescription)
        }
    }
    #endif

    private static let systemPrompt = """
    You distill agent + user conversation transcripts into a structured
    SessionTelemetry record. Be terse; favor verbatim user phrases
    over paraphrase when filling triggers and reasons. Decisions are
    things the user committed to, not things considered. Friction
    points are unresolved tensions worth surfacing in tomorrow's
    session. Active themes are 1-12 short topical tags, lowercase
    kebab-case (e.g. "ontology-design", "naming-debate"). Emotional
    trajectory is 3-7 beats with position 0.0 (start) → 1.0 (end);
    pick valence labels from the provided enum. Headline is ≤160
    chars and reads as one sentence. Confidence is 0-100, your honest
    estimate of how reliable this distillation is given the
    transcript's coherence.
    """
}
