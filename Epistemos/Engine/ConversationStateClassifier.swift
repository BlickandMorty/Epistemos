import Foundation
import OSLog

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - ConversationState (Phase 16 / W10.16)
//
// Master plan Phase 16 / Wave 13 §"Phase 16" structured replacement
// for the linear chat log. After every user turn, the AFM 3B
// "stenographer" updates the canonical ConversationState document so
// the cloud reasoning model receives:
//
//   structured ConversationState  +  last 2 raw turns  +  user msg
//
// instead of the full transcript. Compass token-economics: 50-turn
// conversation drops from ~15-25k tokens to ~600-1200 tokens
// (~95% reduction) while preserving the *intent* the agent needs
// (active thesis, what's been resolved, what's still open).
//
// Doc 2 alignment: "state compaction + tool-gated retrieval" is the
// canonical pattern Apple recommends for the Foundation Models 4096-
// token transcript window. ConversationState is the compaction half;
// tool-use retrieval (Phase 6 corrected) is the retrieval half.
//
// Schema is stable across sessions so the user can scroll a
// "structured timeline" UI: active thesis pinned to top, resolved
// nodes collapsing into checkmarks, open loops glowing. User can
// edit `activeThesis` directly to *steer* the AI's frame mid-
// conversation (the SwiftUI surface lands separately).

#if canImport(FoundationModels)

@available(macOS 26.0, *)
@Generable
public struct ConversationState: Sendable, Equatable, Codable {

    @Guide(description: "Single sentence the user is currently arguing for or working toward")
    public var activeThesis: String

    @Guide(description: "Compressed semantic-vector summary, ≤120 chars")
    public var semanticGist: String

    @Guide(description: "Number of turns this state covers")
    public var turnsCovered: Int

    @Guide(description: "0-100 honest estimate of how reliable this state projection is")
    public var fidelity: Int

    @Guide(.count(0...20))
    public var resolvedNodes: [ConversationResolvedNode]

    @Guide(.count(0...8))
    public var openLoops: [ConversationOpenLoop]

    @Guide(.count(0...5))
    public var emotionalTrajectory: [SessionEmotionalBeat]   // re-uses Phase 9 type

    @Guide(.count(0...30))
    public var referencedConcepts: [String]
}

@available(macOS 26.0, *)
@Generable
public struct ConversationResolvedNode: Sendable, Equatable, Codable {
    @Guide(description: "The claim the user resolved on")
    public var claim: String

    @Guide(.anyOf(["accepted", "rejected", "reframed", "tabled"]))
    public var resolution: String

    @Guide(description: "Verbatim user phrase ≤80 chars that supports the resolution")
    public var evidence: String
}

@available(macOS 26.0, *)
@Generable
public struct ConversationOpenLoop: Sendable, Equatable, Codable {
    @Guide(description: "The unresolved question, in the user's voice")
    public var question: String

    @Guide(.anyOf(["awaiting_user", "awaiting_data", "contested", "blocked"]))
    public var status: String

    @Guide(description: "1-based turn number where this loop opened")
    public var raisedAtTurn: Int
}

#else

// Stub set for macOS 14/15 SDK builds.

public struct ConversationState: Sendable, Equatable, Codable {
    public var activeThesis: String
    public var semanticGist: String
    public var turnsCovered: Int
    public var fidelity: Int
    public var resolvedNodes: [ConversationResolvedNode]
    public var openLoops: [ConversationOpenLoop]
    public var emotionalTrajectory: [SessionEmotionalBeat]
    public var referencedConcepts: [String]
}
public struct ConversationResolvedNode: Sendable, Equatable, Codable {
    public var claim: String
    public var resolution: String
    public var evidence: String
}
public struct ConversationOpenLoop: Sendable, Equatable, Codable {
    public var question: String
    public var status: String
    public var raisedAtTurn: Int
}

#endif

// MARK: - Stenographer service

/// Continuously updates the canonical ConversationState after every
/// user turn. Designed to run *off* the critical reasoning path —
/// the cloud agent reads `currentState` synchronously when assembling
/// its next prompt; the stenographer rebuilds `currentState` async
/// in the background.
@MainActor
public final class ConversationStateClassifier {

    public static let shared = ConversationStateClassifier()

    private static let log = Logger(
        subsystem: "com.epistemos",
        category: "ConversationStateClassifier"
    )

    public enum SteneoError: Error {
        case notAvailable(SessionTelemetryClassifier.Readiness)
        case modelRefused(String)
        case decodeFailed(String)
    }

    /// Re-derive the conversation state every N turns so drift between
    /// the projection and the raw transcript stays bounded. Master
    /// plan default = 10 turns; if drift exceeds 0.30 cosine vs the
    /// previous fidelity, surface a warning to the user.
    public static let driftRederiveCadence: Int = 10

    private var stateByConversationId: [String: ConversationState] = [:]

    private init() {}

    // MARK: - Lookup

    public func currentState(for conversationId: String) -> ConversationState? {
        stateByConversationId[conversationId]
    }

    public func setState(
        _ state: ConversationState,
        for conversationId: String
    ) {
        stateByConversationId[conversationId] = state
    }

    public func clearState(for conversationId: String) {
        stateByConversationId.removeValue(forKey: conversationId)
    }

    // MARK: - Rebuild (called after every user turn or periodically)

    /// Rebuild the conversation state from the recent transcript.
    /// `priorState` is optional — when present, the model is asked to
    /// merge new content into the existing state rather than rebuild
    /// from scratch (preserves resolution stability + emotional
    /// trajectory continuity).
    public func rebuild(
        recentTurns: String,
        priorState: ConversationState? = nil,
        turnNumber: Int
    ) async throws -> ConversationState {
        let r = SessionTelemetryClassifier.shared.readiness()
        guard r == .available else { throw SteneoError.notAvailable(r) }

        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            return try await runAFM(
                recentTurns: recentTurns,
                priorState: priorState,
                turnNumber: turnNumber
            )
        }
        #endif
        throw SteneoError.notAvailable(.sdkUnavailable)
    }

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private func runAFM(
        recentTurns: String,
        priorState: ConversationState?,
        turnNumber: Int
    ) async throws -> ConversationState {
        // AP6 — shared AFM session pool. Each AFM-backed classifier
        // gets its own pool entry keyed on (useCase, instructions
        // hash) so the daemon shares weights across all four.
        let session = await AFMSessionPool.shared.session(
            useCase: .contentTagging,
            instructions: Self.systemPrompt,
            useCaseLabel: "ConversationStateClassifier"
        )
        var prompt = """
        Update the ConversationState. Current turn number: \(turnNumber).
        Recent transcript:
        \(recentTurns)
        """
        if let prior = priorState,
           let priorJSON = try? JSONEncoder().encode(prior),
           let priorString = String(data: priorJSON, encoding: .utf8) {
            prompt += "\n\nPrior state to merge into:\n\(priorString)"
        }
        do {
            let response = try await session.respond(
                to: prompt,
                generating: ConversationState.self
            )
            return response.content
        } catch let error as LanguageModelSession.GenerationError {
            throw SteneoError.modelRefused(String(describing: error))
        } catch {
            throw SteneoError.decodeFailed(error.localizedDescription)
        }
    }
    #endif

    private static let systemPrompt = """
    You are a real-time stenographer. After each user turn you update
    the canonical ConversationState document — a structured projection
    of the conversation that the cloud reasoning agent will receive
    *in place of* the full raw transcript.

    Active thesis: ONE sentence the user is currently arguing for or
      working toward. Update if the user pivots; preserve verbatim
      user phrasing when possible.
    Resolved nodes: claims the user explicitly resolved on (accepted,
      rejected, reframed, or tabled). Evidence is a verbatim user
      phrase ≤80 chars supporting the resolution.
    Open loops: unresolved questions still in flight. Track the turn
      number where each loop opened so you can show "this question
      has been open for 14 turns" UI.
    Emotional trajectory: 0-5 beats reusing the Phase 9 valence enum.
      Position 0.0 = start of conversation, 1.0 = current turn.
    Referenced concepts: 0-30 lowercase-kebab-case tags the user has
      cited in this conversation; deduped.
    Semantic gist: ≤120-char compressed summary so a cold reader
      could pick up the thread without seeing the full state.
    Fidelity: 0-100 honest estimate of how reliable this projection
      is given the transcript's coherence.

    When prior state is provided, MERGE — preserve resolved-node
    stability + emotional trajectory continuity unless the user has
    explicitly contradicted them.
    """
}
