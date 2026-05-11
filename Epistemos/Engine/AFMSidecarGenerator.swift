import Foundation
import OSLog

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - AFM Sidecar Generated Payload

#if canImport(FoundationModels)
@available(macOS 26.0, *)
@Generable
public struct AFMSidecarGeneratedLink: Codable, Sendable {
    @Guide(description: "Stable target note/page ID chosen from the supplied candidate list.")
    public var targetId: String

    @Guide(description: "Human-readable target note title.")
    public var title: String

    @Guide(description: "One short sentence explaining why this note may be related.")
    public var reason: String

    public init(targetId: String, title: String, reason: String) {
        self.targetId = targetId
        self.title = title
        self.reason = reason
    }
}

@available(macOS 26.0, *)
@Generable
public struct AFMSidecarGeneratedPayload: Codable, Sendable {
    @Guide(description: "A concise 1-2 sentence summary of the note.")
    public var summary: String

    @Guide(description: "Three to five lowercase retrieval tags.")
    public var tags: [String]

    @Guide(description: "Important people, projects, concepts, or named entities from the note.")
    public var entities: [String]

    @Guide(description: "Related notes selected only from the supplied candidate list.")
    public var suggestedLinks: [AFMSidecarGeneratedLink]

    public init(
        summary: String,
        tags: [String],
        entities: [String],
        suggestedLinks: [AFMSidecarGeneratedLink] = []
    ) {
        self.summary = summary
        self.tags = tags
        self.entities = entities
        self.suggestedLinks = suggestedLinks
    }
}
#else
public struct AFMSidecarGeneratedLink: Codable, Sendable, Equatable {
    public var targetId: String
    public var title: String
    public var reason: String

    public init(targetId: String, title: String, reason: String) {
        self.targetId = targetId
        self.title = title
        self.reason = reason
    }
}

public struct AFMSidecarGeneratedPayload: Codable, Sendable, Equatable {
    public var summary: String
    public var tags: [String]
    public var entities: [String]
    public var suggestedLinks: [AFMSidecarGeneratedLink]

    public init(
        summary: String,
        tags: [String],
        entities: [String],
        suggestedLinks: [AFMSidecarGeneratedLink] = []
    ) {
        self.summary = summary
        self.tags = tags
        self.entities = entities
        self.suggestedLinks = suggestedLinks
    }
}
#endif

public struct AFMSidecarCandidateLink: Sendable, Equatable {
    public var noteId: String
    public var title: String

    public init(noteId: String, title: String) {
        self.noteId = noteId
        self.title = title
    }
}

@MainActor
protocol AFMSidecarGenerating: AnyObject {
    func readiness() -> OntologyClassifier.Readiness

    func generateAndPersist(
        _ text: String,
        for source: URL,
        candidateLinks: [AFMSidecarCandidateLink]
    ) async throws -> AFMSidecarGeneratedPayload
}

@MainActor
public final class AFMSidecarGenerator: AFMSidecarGenerating {
    public static let shared = AFMSidecarGenerator()

    public enum GenerationError: Error {
        case emptyInput
        case ineligibleSource(String)
        case notAvailable(OntologyClassifier.Readiness)
        case modelRefused(String)
        case decodeFailed(String)
    }

    private static let log = Logger(
        subsystem: "com.epistemos",
        category: "AFMSidecarGenerator"
    )

    // RCA13 P1-023: bound to N concurrent generations, not 1.
    // Bulk note import previously serialized every sidecar job through
    // a global boolean flag — a 20-note import waited 20×AFM-latency
    // (10-40s) before the last job started. AFMSessionPool already
    // manages session reuse + recycle so 2 in-flight jobs share
    // sessions safely. 2 is the canonical M2 Pro ceiling: more jobs
    // pile up FoundationModels tokens against the 32k practical
    // context, and Apple Intelligence throttles aggressively past
    // that on a hardware-limited rig.
    private static let maxConcurrentGenerations: Int = 2
    private static var generationInFlightCount: Int = 0
    private static var generationWaiters: [CheckedContinuation<Void, Never>] = []

    private init() {}

    public func readiness() -> OntologyClassifier.Readiness {
        OntologyClassifier.shared.readiness()
    }

    public func generateAndPersist(
        _ text: String,
        for source: URL,
        candidateLinks: [AFMSidecarCandidateLink] = []
    ) async throws -> AFMSidecarGeneratedPayload {
        guard EpistemosSidecarPolicy.isEligible(source) else {
            throw GenerationError.ineligibleSource(source.path)
        }
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw GenerationError.emptyInput }
        let r = readiness()
        guard r == .available else { throw GenerationError.notAvailable(r) }

        await Self.acquireGenerationSlot()
        defer { Self.releaseGenerationSlot() }

        let payload = try await generatePayload(cleaned, candidateLinks: candidateLinks)
        try Self.persist(payload: payload, for: source)
        return payload
    }

    public static func persist(
        payload: AFMSidecarGeneratedPayload,
        for source: URL
    ) throws {
        guard EpistemosSidecarPolicy.isEligible(source) else {
            throw EpistemosSidecarStore.SidecarError.ineligibleSource(source)
        }

        var sidecar: EpistemosSidecar
        do {
            sidecar = try EpistemosSidecarStore.read(for: source)
                ?? EpistemosSidecarStore.mintStub(for: source)
        } catch {
            Self.log.warning(
                "sidecar read failed for \(source.lastPathComponent, privacy: .public) - mint fresh: \(error.localizedDescription, privacy: .public)"
            )
            sidecar = EpistemosSidecarStore.mintStub(for: source)
        }

        let normalized = normalize(payload)
        sidecar.schemaVersion = EpistemosSidecar.currentSchemaVersion
        sidecar.summary = normalized.summary
        sidecar.tags = normalized.tags.isEmpty ? nil : normalized.tags
        sidecar.entities = normalized.entities.isEmpty ? nil : normalized.entities
        sidecar.suggestedLinks = normalized.suggestedLinks.isEmpty
            ? nil
            : normalized.suggestedLinks.map {
                AFMSidecarSuggestedLink(
                    targetId: $0.targetId,
                    title: $0.title,
                    reason: $0.reason
                )
            }
        sidecar.cognitiveMeta.lastClassifiedAt = iso8601.string(from: Date())
        sidecar.annotations.removeAll {
            $0.author == "afm" && $0.body == generatedPayloadAnnotationBody
        }
        sidecar.annotations.append(Annotation(
            at: sidecar.cognitiveMeta.lastClassifiedAt ?? iso8601.string(from: Date()),
            author: "afm",
            body: generatedPayloadAnnotationBody
        ))
        try EpistemosSidecarStore.write(sidecar, for: source, modelDerived: true)
    }

    private func generatePayload(
        _ text: String,
        candidateLinks: [AFMSidecarCandidateLink]
    ) async throws -> AFMSidecarGeneratedPayload {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            return try await runAFM(text, candidateLinks: candidateLinks)
        }
        #endif
        throw GenerationError.notAvailable(.sdkUnavailable)
    }

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private func runAFM(
        _ text: String,
        candidateLinks: [AFMSidecarCandidateLink]
    ) async throws -> AFMSidecarGeneratedPayload {
        let session = await AFMSessionPool.shared.session(
            useCase: .contentTagging,
            instructions: Self.systemPrompt,
            useCaseLabel: "AFMSidecarGenerator"
        )
        let prompt = """
        Generate a model-derived sidecar payload for this note. Use the
        supplied candidates only when suggesting links; do not invent IDs.

        Candidate notes:
        \(Self.renderCandidates(candidateLinks))

        Note:
        \(text)
        """
        do {
            let response = try await session.respond(
                to: prompt,
                generating: AFMSidecarGeneratedPayload.self
            )
            return response.content
        } catch let error as LanguageModelSession.GenerationError {
            if case .exceededContextWindowSize = error {
                throw GenerationError.decodeFailed("input exceeded AFM context window")
            }
            throw GenerationError.modelRefused(String(describing: error))
        } catch {
            throw GenerationError.decodeFailed(error.localizedDescription)
        }
    }
    #endif

    private static func acquireGenerationSlot() async {
        if generationInFlightCount < maxConcurrentGenerations {
            generationInFlightCount += 1
            return
        }
        await withCheckedContinuation { continuation in
            generationWaiters.append(continuation)
        }
    }

    private static func releaseGenerationSlot() {
        if generationWaiters.isEmpty {
            generationInFlightCount = max(0, generationInFlightCount - 1)
        } else {
            // Hand the slot directly to the next waiter — the count
            // stays the same because one job ends as another starts.
            let next = generationWaiters.removeFirst()
            next.resume()
        }
    }

    private static func normalize(
        _ payload: AFMSidecarGeneratedPayload
    ) -> AFMSidecarGeneratedPayload {
        AFMSidecarGeneratedPayload(
            summary: payload.summary.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: uniqueCleaned(payload.tags, limit: 5).map { $0.lowercased() },
            entities: uniqueCleaned(payload.entities, limit: 12),
            suggestedLinks: payload.suggestedLinks.prefix(5).map {
                AFMSidecarGeneratedLink(
                    targetId: $0.targetId.trimmingCharacters(in: .whitespacesAndNewlines),
                    title: $0.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    reason: $0.reason.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }.filter { !$0.targetId.isEmpty && !$0.title.isEmpty }
        )
    }

    private static func uniqueCleaned(_ values: [String], limit: Int) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        result.reserveCapacity(min(values.count, limit))
        for value in values {
            let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { continue }
            let key = cleaned.lowercased()
            guard seen.insert(key).inserted else { continue }
            result.append(cleaned)
            if result.count == limit { break }
        }
        return result
    }

    private static func renderCandidates(_ candidates: [AFMSidecarCandidateLink]) -> String {
        guard !candidates.isEmpty else { return "None" }
        return candidates
            .prefix(20)
            .map { "- \($0.noteId): \($0.title)" }
            .joined(separator: "\n")
    }

    private static let generatedPayloadAnnotationBody =
        "generated sidecar payload"

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let systemPrompt = """
    You generate additive JSON sidecar metadata for a personal knowledge note.
    The Markdown source is canonical. The sidecar is only model-facing
    retrieval metadata and must not replace or rewrite user-authored text.
    Return concise, factual summaries; lowercase tags; salient entities; and
    suggested links only from the provided candidate notes.
    """
}
