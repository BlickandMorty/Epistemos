import Foundation
import OSLog

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - OntologyClassifier
//
// Phase 1 of the master plan / Wave 13 §"Phase 1": replaces the naive
// string extractor in EntityExtractor.swift with an AFM-backed
// Ontological Classifier emitting structured `{parentDomain,
// childConcept, depth, confidence, children?}` per the recursive
// `@Generable` pattern verified by the meta-advice agent.
//
// Why a separate file: EntityExtractor's existing keyword extractor
// remains the fallback path when FoundationModels is unavailable
// (macOS 15 / Apple Intelligence disabled / device not eligible).
// The classifier here is the *primary* path on macOS 26+; the
// transition is gated behind the availability check below so the
// app continues working on every supported OS.
//
// Schema design follows the meta-advice agent's verified pattern:
// keep `children` optional + flat to avoid the macOS 26.0–26.2
// "undefined reference" schema drift bug with fully-recursive types.
// The model fills scalar fields first (parentDomain, childConcept,
// depth, confidence) and arrays last (children).

// MARK: - DepthMarker (L1 / L2 / L3 — master plan Phase 8)

#if canImport(FoundationModels)
@available(macOS 26.0, *)
@Generable
public enum DepthMarker: String, Sendable, Codable, Hashable, CaseIterable {
    case surface
    case synthesized
    case coreBelief

    public var label: String {
        switch self {
        case .surface:     return "Surface"
        case .synthesized: return "Synthesized"
        case .coreBelief:  return "Core Belief"
        }
    }
}
#else
nonisolated public enum DepthMarker: String, Sendable, Codable, Hashable, CaseIterable {
    case surface
    case synthesized
    case coreBelief

    public var label: String {
        switch self {
        case .surface:     return "Surface"
        case .synthesized: return "Synthesized"
        case .coreBelief:  return "Core Belief"
        }
    }
}
#endif

// MARK: - OntologyNode (`@Generable` schema)

#if canImport(FoundationModels)
@available(macOS 26.0, *)
@Generable
public struct OntologyNode: Codable, Sendable {
    @Guide(description: "Parent domain, lowercase kebab-case. e.g. 'neuroscience', 'aeronautics', 'compilers'.")
    public var parentDomain: String

    @Guide(description: "Primary concept label, lowercase kebab-case. e.g. 'basal-ganglia', 'vector-thrust', 'lattice-types'.")
    public var childConcept: String

    @Guide(description: "Knowledge depth: surface (scratchpad), synthesized (actionable insight), or coreBelief (foundational architecture).")
    public var depth: DepthMarker

    @Guide(description: "Confidence in the classification, 0.0 – 1.0.")
    public var confidence: Double

    /// Optional flat array of child concepts. Kept optional + single-
    /// level to avoid the macOS 26.0–26.2 schema drift bug with
    /// fully-recursive `@Generable` types — the model fills scalar
    /// fields first, then arrays. For deeper trees, run the classifier
    /// recursively against the child labels + materialise edges in the
    /// graph projection layer (Phase 8).
    public var children: [OntologyNode]?
}
#else
/// Stub when FoundationModels isn't available at compile time
/// (macOS 14 / 15 SDK builds). Fields are identical so call sites
/// can be source-compatible across SDK targets.
public struct OntologyNode: Codable, Sendable, Hashable {
    public var parentDomain: String
    public var childConcept: String
    public var depth: DepthMarker
    public var confidence: Double
    public var children: [OntologyNode]?
}
#endif

// MARK: - OntologyClassifier service

/// AFM-backed ontology classifier. Use `classify(_:)` from any actor;
/// the service hops to MainActor internally because
/// `LanguageModelSession` is MainActor-isolated under Xcode 26.
///
/// Availability is checked on every call so a model that's downloading
/// at app launch becomes usable mid-session without a restart.
@MainActor
public final class OntologyClassifier {

    public enum Readiness: Sendable, Equatable {
        case available
        case deviceNotEligible
        case intelligenceDisabled
        case modelLoading
        case sdkUnavailable          // compiled on macOS < 26 SDK
    }

    public enum ClassifyError: Error {
        case notAvailable(Readiness)
        case modelRefused(String)    // guardrail trip
        case decodeFailed(String)
    }

    private static let log = Logger(
        subsystem: "com.epistemos",
        category: "OntologyClassifier"
    )

    public static let shared = OntologyClassifier()

    /// Cached session for the lifetime of the process. AFM sessions
    /// accumulate context — recycling every ~10 min prevents memory
    /// bloat per `AppleIntelligenceService`'s existing pattern.
    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private var session: LanguageModelSession? {
        get { _sessionStorage as? LanguageModelSession }
        set { _sessionStorage = newValue }
    }
    #endif
    private var _sessionStorage: AnyObject?
    private var sessionCreatedAt: Date = .distantPast
    private let sessionLifetime: TimeInterval = 600  // 10 minutes

    private init() {}

    // MARK: - Readiness

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

    // MARK: - Classify API

    /// Classify a free-text note / thought into an ontology node and
    /// (optionally) merge the result directly into the sidecar for
    /// `source`. When `source` is provided AND eligible for sidecars,
    /// the classification is persisted as:
    ///   - `parentDomain` ← classifier output
    ///   - `childConcept` ← classifier output
    ///   - `depth` ← classifier output (overrides stub default)
    ///   - `cognitive_meta.last_classified_at` ← ISO-8601 now
    ///   - `cognitive_meta.classification_confidence` ← classifier output
    ///   - `annotations` ← appended `{at, author: "afm", body}` row
    ///   - `schema_version` ← bumped to currentSchemaVersion
    /// Returns the OntologyNode regardless of sidecar wiring so the
    /// caller can also use the result inline (e.g. SwiftUI surface).
    public func classifyAndPersist(
        _ text: String,
        for source: URL
    ) async throws -> OntologyNode {
        let node = try await classify(text)
        // Only persist when the source is eligible. Code files etc.
        // would throw `.ineligibleSource` from EpistemosSidecarStore.
        guard EpistemosSidecarPolicy.isEligible(source) else { return node }

        var sidecar: EpistemosSidecar
        do {
            sidecar = try EpistemosSidecarStore.read(for: source)
                ?? EpistemosSidecarStore.mintStub(for: source)
        } catch {
            // If decode fails on a corrupt sidecar, mint fresh rather
            // than refusing to classify — better to overwrite a bad
            // sidecar than block future classifications forever.
            Self.log.warning(
                "sidecar read failed for \(source.lastPathComponent, privacy: .public) — mint fresh: \(error.localizedDescription, privacy: .public)"
            )
            sidecar = EpistemosSidecarStore.mintStub(for: source)
        }

        let now = Self.iso8601.string(from: Date())
        sidecar.schemaVersion = EpistemosSidecar.currentSchemaVersion
        sidecar.parentDomain = node.parentDomain
        sidecar.childConcept = node.childConcept
        sidecar.interpretationDirective = "Treat the Markdown source as canonical; use this sidecar only for model-facing ontology, depth, and retrieval hints."
        sidecar.depth = node.depth
        sidecar.cognitiveMeta.lastClassifiedAt = now
        sidecar.cognitiveMeta.classificationConfidence = node.confidence
        sidecar.annotations.append(Annotation(
            at: now,
            author: "afm",
            body: "classified as \(node.parentDomain) > \(node.childConcept) (depth=\(node.depth.rawValue), confidence=\(String(format: "%.2f", node.confidence)))"
        ))
        try EpistemosSidecarStore.write(sidecar, for: source, modelDerived: true)
        return node
    }

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// Classify a free-text note / thought into an ontology node.
    /// `text` is the raw user content (≤ 8KB practical limit before
    /// the AFM 4096-token ceiling kicks in — call sites should chunk
    /// long content via `SystemLanguageModel.tokenCount(for:)`).
    public func classify(_ text: String) async throws -> OntologyNode {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            throw ClassifyError.decodeFailed("input was empty")
        }
        let r = readiness()
        guard r == .available else {
            throw ClassifyError.notAvailable(r)
        }

        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            return try await runAFM(cleaned)
        }
        #endif
        throw ClassifyError.notAvailable(.sdkUnavailable)
    }

    // MARK: - AFM session management

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private func ensureSession() async -> LanguageModelSession {
        // AP6 — share warm sessions across all AFM-backed classifiers
        // via AFMSessionPool. The pool key is (useCase, instructions
        // hash) so OntologyClassifier and SessionTelemetryClassifier
        // (different instructions) get separate sessions, but two
        // OntologyClassifier calls share one. Saves ~40% tokens +
        // ~5.7× latency cut across the trio per the perf agent's
        // measurement.
        await AFMSessionPool.shared.session(
            useCase: .contentTagging,
            instructions: Self.systemPrompt,
            useCaseLabel: "OntologyClassifier"
        )
    }

    @available(macOS 26.0, *)
    private func runAFM(_ text: String) async throws -> OntologyNode {
        let s = await ensureSession()
        let prompt = """
        Classify this input into one parent domain and one primary child
        concept. Respond with the OntologyNode schema — the framework
        will enforce the structure for you.

        Input:
        \(text)
        """
        do {
            // Canonical structured-output path: respond(to:generating:)
            // returns Response<OntologyNode> with token-level constraint
            // masking against the @Generable schema. No JSON round-trip
            // needed; no markdown-fence stripping required.
            let response = try await s.respond(
                to: prompt,
                generating: OntologyNode.self
            )
            return response.content
        } catch let error as LanguageModelSession.GenerationError {
            if case .exceededContextWindowSize = error {
                throw ClassifyError.decodeFailed(
                    "input exceeded AFM 4,096-token ceiling — chunk and retry"
                )
            }
            throw ClassifyError.modelRefused(String(describing: error))
        } catch {
            throw ClassifyError.decodeFailed(error.localizedDescription)
        }
    }
    #endif

    // MARK: - Prompt

    /// Stable system prompt — kept as a `let` so the prompt cache (when
    /// AFM eventually exposes one) doesn't churn on minor edits.
    /// Lowercase kebab-case is enforced via the `@Guide` description
    /// strings inside `OntologyNode`.
    private static let systemPrompt = """
    You are an ontology classifier for a personal knowledge management system.
    Classify the input into one parent domain and one primary child concept.
    Both labels are lowercase kebab-case (e.g., "neuroscience", "basal-ganglia").
    Pick `depth`: surface for fleeting / scratch ideas, synthesized for
    actionable insights, coreBelief for foundational architecture.
    Confidence is your honest 0.0-1.0 estimate.
    Children, if present, are sibling sub-concepts under the same parent.
    Reject hallucinated tags — prefer real domains.
    """
}

@MainActor
protocol OntologyClassifying: AnyObject {
    func readiness() -> OntologyClassifier.Readiness
    func classifyAndPersist(_ text: String, for source: URL) async throws -> OntologyNode
}

extension OntologyClassifier: OntologyClassifying {}
